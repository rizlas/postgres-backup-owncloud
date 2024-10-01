# postgres-backup-owncloud

Postgres-backup-owncloud provides a simple solution for automating PostgreSQL database
backups, encrypting them via GPG, and securely uploading them to an OwnCloud server.
This is based on multiple solutions already available on github, main two are:

- [docker-postgres-backup-local](https://github.com/prodrigestivill/docker-postgres-backup-local)
- [postgres-backup-s3](https://github.com/eeshugerman/postgres-backup-s3)

A [docker image](https://hub.docker.com/r/rizl4s/postgres-backup-owncloud) is provided,
therefore it can be used in any environment that support containers.

Backups are cron based using [go-cron](https://github.com/prodrigestivill/go-cron).

## Environment variables

|             Name             |                                                                                                                                    Description                                                                                                                                    | Default |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- |
| BACKUP_KEEP_DAYS             | Number of daily backups to keep before removal.                                                                                                                                                                                                                                   | 7       |
| SCHEDULE                     | [Cron-schedule](http://godoc.org/github.com/robfig/cron#hdr-Predefined_schedules) specifying the interval between postgres backups.                                                                                                                                               | @daily  |
| HEALTHCHECK_PORT             | Port listening for cron-schedule health check.                                                                                                                                                                                                                                    | 8080    |
| DRY_RUN                      | Test container functionality. It will not upload or restore dumps if set to true.                                                                                                                                                                                                 | false   |
| RESTORE_MODE                 | Specifies where the backup should be restored from during the restore process. It defaults to 'remote', which means the backup will be fetched from OwnCloud. If set to 'local', the backup will be restored from a local directory specified in SHARE_PATH environment variable. | remote  |
| SHARE_PATH                   | Path to a shared ownCloud folder containing backups. Mandatory when using restore mode 'local'.                                                                                                                                                                                   | ""      |
| PGDUMP_EXTRA_OPTS            | Additional options for pg_dump.                                                                                                                                                                                                                                                   | ""      |
| POSTGRES_HOST                | Postgres connection parameter; postgres host to connect to. **Required**.                                                                                                                                                                                                         |         |
| POSTGRES_PORT                | Postgres connection parameter; postgres port to connect to. **Required**.                                                                                                                                                                                                         |         |
| POSTGRES_DB                  | Postgres connection parameter; postgres database name to connect to. **Required**.                                                                                                                                                                                                |         |
| POSTGRES_PASSWORD            | Postgres connection parameter; postgres password to connect with. **Required**.                                                                                                                                                                                                   |         |
| POSTGRES_USER                | Postgres connection parameter; postgres user to connect with. **Required**.                                                                                                                                                                                                       |         |
| OWNCLOUD_FQDN                | ownCloud FQDN without protocol (Fixed protocol is https, no http). **Required**.                                                                                                                                                                                                  |         |
| OWNCLOUD_SHARE_ID            | ownCloud public share ID. **Required**.                                                                                                                                                                                                                                           |         |
| OWNCLOUD_SHARE_PASSWORD      | ownCloud share password. **Required**.                                                                                                                                                                                                                                            |         |
| PASSPHRASE                   | Passphrase used to encrypt or decrypt dumps.                                                                                                                                                                                                                                      |         |
| GPG_EMAILS                   | Comma separated list of emails that will be used to encrypt dumps. This will take precedence over PASSPHRASE.                                                                                                                                                                     | ""      |
| GPG_TRUST_MODEL              | Set what trust model GnuPG should follow. Check gpg manual for available options.                                                                                                                                                                                                 | auto    |
| GPG_KEY_LOCATE               | Set retrieval mechanism when encrypting with an email address. Check gpg manual for available options.                                                                                                                                                                            | wkd     |
| GPG_RESTORE_EMAIL            | Email used to decrypt dumps.                                                                                                                                                                                                                                                      |         |
| GPG_RESTORE_EMAIL_PASSPHRASE | Passphrase of the private GPG key. Use this if you want to avoid user interaction.                                                                                                                                                                                                |         |
| WEBHOOK_URL                  | URL to be called after an error or after a successful backup (POST with a JSON payload, check hooks/00-webhook file for more info).                                                                                                                                               | ""      |
| WEBHOOK_ERROR_URL            | URL to be called in case backup fails.                                                                                                                                                                                                                                            | ""      |
| WEBHOOK_PRE_BACKUP_URL       | URL to be called when backup starts.                                                                                                                                                                                                                                              | ""      |
| WEBHOOK_POST_BACKUP_URL      | URL to be called when backup completes successfully.                                                                                                                                                                                                                              | ""      |
| WEBHOOK_EXTRA_ARGS           | Extra arguments for the curl execution in the webhook (check hooks/00-webhook file for more info).                                                                                                                                                                                | ""      |
| TZ                           | Container timezone.                                                                                                                                                                                                                                                               | UTC     |

## GPG Encryption

The script supports two modes of encryption:

1. Using a GPG public key. Specify the email in the GPG_EMAILS environment variable. The
   backup will be encrypted using the provided GPG emails.

2. Using a passphrase. If no GPG public key is provided, set the PASSPHRASE environment
   variable to encrypt the backup using a passphrase.

Encryption is optional. If neither GPG_EMAILS nor PASSPHRASE is provided, the backup
will not be encrypted.

## Usage

Once the environment variables are set (e.g. postgres.env, pgbackups.env), you can fire
up the stack using the provided `docker-compose.yml`. You should modify it to fit your
needs.

## Development

### Build the image locally

It is also possibile to leverage the docker compose to build the image locally, using:

```bash
docker compose up -d --build --force-recreate
```

### Run a simple test environment with Docker Compose

```sh
cp example.env pgbackups.env
# fill out your secrets/params in .env
docker compose up -d
```

### Development of get_backups.py

1. Get an xml file with curl

    ```bash
    cd src
    curl -s -X PROPFIND -u "$OWNCLOUD_SHARE_ID:$OWNCLOUD_SHARE_PASSWORD" \
        https://$OWNCLOUD_FQDN/public.php/webdav -o test.xml
    ```

2. Make adjustment and run the script. For example

    ```bash
    python3 get_backups.py latest --xml-file test.xml --database-name postgres --passphrase-crypted
    ```

## Hooks

The folder `hooks` inside the container can contain hooks/scripts to be run in
differrent cases getting the exact situation as a first argument (`error`, `pre-backup`
or `post-backup`).

Just create an script in that folder with execution permission so that
[run-parts](https://manpages.debian.org/stable/debianutils/run-parts.8.en.html) can
execute it on each state change.

Please, as an example take a look in the script already present there that implements
the `WEBHOOK_URL` functionality.

## Manual backups

```bash
docker exec -it cron-remote-backup-test sh
sh backup.sh
```

## Restore example

> [!CAUTION]
> DATA LOSS! Target database will be dropped and re-created.

```bash
docker exec -it cron-remote-backup-test sh
sh restore.sh
```

> [!NOTE]
> If GPG_RESTORE_EMAIL and GPG_RESTORE_EMAIL_PASSPHRASE env vars are set, restore will
> continue without the need of user inputs. Otherwise if only GPG_RESTORE_EMAIL is set
> user must enter passphrase to unlock the key.

### Restore modes

1. Restore mode 'remote'

    - Lastest backup will be downloaded from ownCloud and restored

2. Restore mode 'local'. You must also set SHARE_PATH env var.

    - You must mount in the docker container your local shared folder where backups are
      stored
    - Lastest backup from the mounted directory will be used and restored

---

Feel free to make pull requests, fork, destroy or whatever you like most. Any criticism is more than welcome.

<br/>

<div align="center"><img src="https://avatars1.githubusercontent.com/u/8522635?s=96&v=4"/></div>
<p align="center">#followtheturtle</p>

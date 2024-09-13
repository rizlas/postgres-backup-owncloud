#!/bin/sh

mandatory_env_vars="
    PASSPHRASE
    POSTGRES_HOST
    POSTGRES_PORT
    POSTGRES_DB
    POSTGRES_PASSWORD
    POSTGRES_USER
    OWNCLOUD_SHARE_ID
    OWNCLOUD_SHARE_PASSWORD
    OWNCLOUD_FQDN
"

# Iterate through the list and print the variables and their values
for var in $mandatory_env_vars; do
    value=$(eval echo \${$var})
    if [ -z "$value" ]; then
      echo "You need to set the $var environment variable."
      exit 1
    fi
done

exec go-cron -s "$SCHEDULE" -p "$HEALTHCHECK_PORT" -- /bin/sh backup.sh

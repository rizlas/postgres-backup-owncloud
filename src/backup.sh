#!/bin/sh

set -euo pipefail

upload_to_owncloud() {
    # Check if it is a file (not a directory)
    if [ -f "$1" ]; then
      echo "Uploading: $1"
      filename=$(basename "$1")

      curl -k -T $1 -u "$OWNCLOUD_SHARE_ID:$OWNCLOUD_SHARE_PASSWORD" \
          -H 'X-Requested-With: XMLHttpRequest' \
          https://$OWNCLOUD_FQDN/public.php/webdav/$filename
      echo -e "$filename uploaded to https://$OWNCLOUD_FQDN\n"
    else
      echo -e "Not a file, $1 not uploaded\n"
    fi
}

export PGUSER="${POSTGRES_USER}"
export PGPASSWORD="${POSTGRES_PASSWORD}"
export PGHOST="${POSTGRES_HOST}"
export PGPORT="${POSTGRES_PORT}"
export PGDATABASE="${POSTGRES_DB}"

TIMESTAMP=$(date +"%Y-%m-%d")
BACKUPS_DIR=backups
ENCRYPTED_BACKUPS_DIR=encrypted_backups
DUMP_FILENAME=${POSTGRES_DB}_${TIMESTAMP}.dump

echo "Creating backup of '$POSTGRES_DB' database..."
mkdir -p $BACKUPS_DIR
mkdir -p $ENCRYPTED_BACKUPS_DIR
pg_dump --format=custom $PGDUMP_EXTRA_OPTS > $BACKUPS_DIR/$DUMP_FILENAME

# Encrypt the backup based on provided environment variables
if [ -n "${GPG_EMAILS:-}" ]; then
  echo -e "Encrypting backup using gpg emails...\n"
  for EMAIL in $(echo $GPG_EMAILS | tr "," "\n"); do
    echo "Using $EMAIL"
    ENCRYPTED_DUMP_FILENAME=${POSTGRES_DB}_${TIMESTAMP}_${EMAIL}.dump.gpg

    # Fetch the public key
    gpg --auto-key-locate $GPG_KEY_LOCATE --locate-keys "$EMAIL"

    # Encrypt the dump file using the located public key
    gpg --batch --encrypt --recipient "$EMAIL" --trust-model $GPG_TRUST_MODEL --output $ENCRYPTED_BACKUPS_DIR/$ENCRYPTED_DUMP_FILENAME $BACKUPS_DIR/$DUMP_FILENAME
    echo -e "Backup encrypted for $EMAIL as $ENCRYPTED_DUMP_FILENAME\n"
    upload_to_owncloud "$ENCRYPTED_BACKUPS_DIR/$ENCRYPTED_DUMP_FILENAME"
  done
elif [ -n "${PASSPHRASE:-}" ]; then
  ENCRYPTED_DUMP_FILENAME=${POSTGRES_DB}_${TIMESTAMP}.dump.gpg
  # Remove a file with the same name if exists
  if [ -f $ENCRYPTED_BACKUPS_DIR/$ENCRYPTED_DUMP_FILENAME ]; then
    rm $ENCRYPTED_BACKUPS_DIR/$ENCRYPTED_DUMP_FILENAME
  fi

  echo "Encrypting backup using passphrase..."
  gpg --symmetric --batch --passphrase "$PASSPHRASE" --output $ENCRYPTED_BACKUPS_DIR/$ENCRYPTED_DUMP_FILENAME $BACKUPS_DIR/$DUMP_FILENAME
  upload_to_owncloud "$ENCRYPTED_BACKUPS_DIR/$ENCRYPTED_DUMP_FILENAME"
else
  echo "No encryption specified. Skipping encryption step."
  upload_to_owncloud "$BACKUPS_DIR/$DUMP_FILENAME"
fi

echo -e "\nBackup complete.\n"

echo "Removing old backups older than $BACKUP_KEEP_DAYS days from ownCloud shared folder and filesystem"

XML_TEMP_FILE=$(mktemp)

# List files
curl -s -X PROPFIND -u "$OWNCLOUD_SHARE_ID:$OWNCLOUD_SHARE_PASSWORD" \
    https://$OWNCLOUD_FQDN/public.php/webdav -o $XML_TEMP_FILE

OUTPUT=$(python3 "parse_xml.py" filterdate "$XML_TEMP_FILE" --days "$BACKUP_KEEP_DAYS")

if [ -n "${OUTPUT:-}" ]; then
  for file in $(echo $OUTPUT | tr "," "\n"); do
    echo "Deleting: $file"

    # Delete file
    curl -s -X DELETE -u "$OWNCLOUD_SHARE_ID:$OWNCLOUD_SHARE_PASSWORD" \
        "https://$OWNCLOUD_FQDN/public.php/webdav/$file"

    echo "$file deleted."
  done
else
  echo "No files to delete."
fi

find ${BACKUPS_DIR} -type f -mtime "+${BACKUP_KEEP_DAYS}" -name "*.dump" -exec rm {} \;
find ${ENCRYPTED_BACKUPS_DIR} -type f -mtime "+${BACKUP_KEEP_DAYS}" -name "*.dump.gpg" -exec rm {} \;

#Clean up /tmp
rm /tmp/tmp.*

#!/bin/sh

set -euo pipefail

cleanup() {
    echo -e "\nCleaning up backup directories..."
    rm -f "$BACKUPS_DIR"/*
    rm -f "$ENCRYPTED_BACKUPS_DIR"/*
    echo -e "Backup directories cleaned.\n"
}

trap cleanup EXIT

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

ENCRYPTION_DONE=false

# Encrypt the backup based on provided environment variables
if [ -n "${GPG_EMAILS:-}" ]; then
  echo -e "Encrypting backup using gpg emails...\n"
  for EMAIL in $(echo $GPG_EMAILS | tr "," "\n"); do
    echo "Using $EMAIL"
    ENCRYPTED_DUMP_FILENAME=${POSTGRES_DB}_${TIMESTAMP}_${EMAIL}.dump.gpg

    # Fetch the public key using WKD
    gpg --auto-key-locate clear,wkd --locate-keys "$EMAIL"

    # Encrypt the dump file using the located public key
    gpg --batch --encrypt --recipient "$EMAIL" --trust-model $TRUST_MODEL --output $ENCRYPTED_BACKUPS_DIR/$ENCRYPTED_DUMP_FILENAME $BACKUPS_DIR/$DUMP_FILENAME

    echo -e "Backup encrypted for $EMAIL as $ENCRYPTED_DUMP_FILENAME\n"
    ENCRYPTION_DONE=true
  done
elif [ -n "${PASSPHRASE:-}" ]; then
  echo "Encrypting backup using passphrase..."
  gpg --symmetric --batch --passphrase "$PASSPHRASE" --output $ENCRYPTED_BACKUPS_DIR/$DUMP_FILENAME.gpg $BACKUPS_DIR/$DUMP_FILENAME
  ENCRYPTION_DONE=true
else
  echo "No encryption specified. Skipping encryption step."
fi

if [ "$ENCRYPTION_DONE" = true ]; then
  folder="$ENCRYPTED_BACKUPS_DIR"
else
  folder="$BACKUPS_DIR"
fi

# Loop over all files in the folder
for file in "$folder"/*
do
  # Check if it is a file (not a directory)
  if [ -f "$file" ]; then
    echo "Uploading: $file"
    filename=$(basename "$file")

    curl -k -T $file -u "$OWNCLOUD_SHARE_ID:$OWNCLOUD_SHARE_PASSWORD" \
        -H 'X-Requested-With: XMLHttpRequest' \
        https://$OWNCLOUD_FQDN/public.php/webdav/$filename
  fi
done

echo -e "\nBackup complete.\n"

echo "Removing old backups from shared folder"

XML_TEMP_FILE=$(mktemp)

# List files
curl -s -X PROPFIND -u "$OWNCLOUD_SHARE_ID:$OWNCLOUD_SHARE_PASSWORD" \
    https://$OWNCLOUD_FQDN/public.php/webdav -o $XML_TEMP_FILE

OUTPUT=$(python3 "parse_xml.py" "$XML_TEMP_FILE" --days "$BACKUP_KEEP_DAYS")

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

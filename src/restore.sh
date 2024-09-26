#!/bin/sh

set -euo pipefail

cleanup() {
  #Clean up /tmp
  rm -f /tmp/*.dump*
  rm -f /tmp/tmp.*
}

download_from_owncloud() {
  if [ -z "${LATEST_BACKUP:-}" ]; then
    echo "No backup file specified to download. Skipping download."
    return 1
  fi

  echo "Downloading $LATEST_BACKUP"
  curl -s -u "$OWNCLOUD_SHARE_ID:$OWNCLOUD_SHARE_PASSWORD" \
      https://$OWNCLOUD_FQDN/public.php/webdav/$LATEST_BACKUP -o /tmp/$LATEST_BACKUP

  if [ $? -ne 0 ]; then
    echo "Error: Failed to download $LATEST_BACKUP."
    exit 1
  fi
}

trap cleanup EXIT
source ./env.sh

XML_TEMP_FILE=$(mktemp)

# List files
curl -s -X PROPFIND -u "$OWNCLOUD_SHARE_ID:$OWNCLOUD_SHARE_PASSWORD" \
    https://$OWNCLOUD_FQDN/public.php/webdav -o $XML_TEMP_FILE

if [ -n "${GPG_RESTORE_EMAIL:-}" ]; then
  echo "Getting latest backup crypted with $GPG_RESTORE_EMAIL gpg key..."
  LATEST_BACKUP=$(python3 "parse_xml.py" latest "$XML_TEMP_FILE" --database-name $POSTGRES_DB --user-email "$GPG_RESTORE_EMAIL")
  download_from_owncloud
  # You must have the recipient key that was used to encrypt
  KEY_PASSHPRASE=""
  if [ -n "${GPG_RESTORE_EMAIL_PASSPHRASE:-}" ]; then
    KEY_PASSHPRASE="--pinentry-mode=loopback --passphrase $GPG_RESTORE_EMAIL_PASSPHRASE"
  fi
  gpg --batch --yes $KEY_PASSHPRASE --output /tmp/${LATEST_BACKUP%.gpg} --decrypt /tmp/$LATEST_BACKUP
elif [ -n "${PASSPHRASE:-}" ]; then
  echo "Getting latest backup crypted with passphrase..."
  LATEST_BACKUP=$(python3 "parse_xml.py" latest "$XML_TEMP_FILE" --database-name $POSTGRES_DB --passphrase-crypted)
  download_from_owncloud
  gpg --batch --passphrase "$PASSPHRASE" --output /tmp/${LATEST_BACKUP%.gpg} --decrypt /tmp/$LATEST_BACKUP
else
  echo "Getting latest backup without encryption..."
  LATEST_BACKUP=$(python3 "parse_xml.py" latest "$XML_TEMP_FILE" --database-name $POSTGRES_DB)
  download_from_owncloud
fi

if [ "$DRY_RUN" = true ]; then
  echo "File to restore: /tmp/${LATEST_BACKUP%.gpg}"
  echo "Dry run mode: Skipping actual restore."
else
  echo "Restoring from backup..."
  pg_restore --clean --if-exists -d $PGDATABASE /tmp/${LATEST_BACKUP%.gpg}
  echo "Restore complete!"
fi

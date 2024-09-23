#!/bin/sh

set -euo pipefail

download_from_owncloud() {
  echo "Downloading $LATEST_BACKUP"
  curl -s -u "$OWNCLOUD_SHARE_ID:$OWNCLOUD_SHARE_PASSWORD" \
      https://$OWNCLOUD_FQDN/public.php/webdav/$LATEST_BACKUP -o /tmp/$LATEST_BACKUP
}

XML_TEMP_FILE=$(mktemp)

# List files
curl -s -X PROPFIND -u "$OWNCLOUD_SHARE_ID:$OWNCLOUD_SHARE_PASSWORD" \
    https://$OWNCLOUD_FQDN/public.php/webdav -o $XML_TEMP_FILE

if [ -n "${RESTORE_GPG_EMAIL:-}" ]; then
  echo "Getting latest backup crypted with $RESTORE_GPG_EMAIL gpg key..."
  LATEST_BACKUP=$(python3 "parse_xml.py" latest "$XML_TEMP_FILE" --user-email "$RESTORE_GPG_EMAIL")
  download_from_owncloud
elif [ -n "${PASSPHRASE:-}" ]; then
  echo "Getting latest backup crypted with passphrase..."
  LATEST_BACKUP=$(python3 "parse_xml.py" latest "$XML_TEMP_FILE" --passphrase-crypted)
  download_from_owncloud
  gpg --batch --passphrase "$PASSPHRASE" --output /tmp/${LATEST_BACKUP%.gpg} --decrypt /tmp/$LATEST_BACKUP
else
  echo "Getting latest backup without encryption..."
  LATEST_BACKUP=$(python3 "parse_xml.py" latest "$XML_TEMP_FILE")
  download_from_owncloud
fi


# rm /tmp/*.dump*
# rm /tmp/tmp.*

# if [ -n "$PASSPHRASE" ]; then
#   echo "Decrypting backup..."
#   gpg --decrypt --batch --passphrase "$PASSPHRASE" db.dump.gpg > db.dump
#   rm db.dump.gpg
# fi

# conn_opts="-h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER -d $POSTGRES_DB"

# echo "Restoring from backup..."
# pg_restore $conn_opts --clean --if-exists db.dump
# rm db.dump

# echo "Restore complete."

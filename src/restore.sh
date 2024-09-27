#!/bin/sh

set -euo pipefail

cleanup() {
    #Clean up /tmp
    rm -f /tmp/*.dump*
    rm -f /tmp/tmp.*
}

trap "cleanup" EXIT
source ./env.sh

echo -e "Restoring backup using $RESTORE_MODE mode!\n"

if [ "$RESTORE_MODE" = "remote" ]; then
    XML_TEMP_FILE=$(mktemp)
    SOURCE="--xml-file $XML_TEMP_FILE"
    
    # List files
    curl -s -X PROPFIND -u "$OWNCLOUD_SHARE_ID:$OWNCLOUD_SHARE_PASSWORD" \
    https://$OWNCLOUD_FQDN/public.php/webdav -o $XML_TEMP_FILE
    elif [ "$RESTORE_MODE" = "local" ]; then
    SOURCE="--share-path $SHARE_PATH"
fi

if [ -n "${GPG_RESTORE_EMAIL:-}" ]; then
    echo "Getting latest backup crypted with $GPG_RESTORE_EMAIL gpg key"
    LATEST_BACKUP=$(python3 "get_backups.py" latest $SOURCE --database-name $POSTGRES_DB --user-email "$GPG_RESTORE_EMAIL")
    elif [ -n "${PASSPHRASE:-}" ]; then
    echo "Getting latest backup crypted with passphrase"
    LATEST_BACKUP=$(python3 "get_backups.py" latest $SOURCE --database-name $POSTGRES_DB --passphrase-crypted)
else
    echo "Getting latest backup without encryption"
    LATEST_BACKUP=$(python3 "get_backups.py" latest $SOURCE --database-name $POSTGRES_DB)
fi

if [ "$RESTORE_MODE" = "remote" ]; then
    # Download from ownCloud
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
fi

# In case of mode is set to local, copy backup to /tmp
# Avoid use the original file
# Avoid to mess with path between mode remote and mode local when gpg or pg_restore
# need to retrieve the file
if [ "$RESTORE_MODE" = "local" ]; then
    cp $SHARE_PATH/$LATEST_BACKUP /tmp/$LATEST_BACKUP
fi

if [ -n "${GPG_RESTORE_EMAIL:-}" ]; then
    echo "Decrypting $LATEST_BACKUP"
    # Check if key passphrase exist and if it is, disable interactive mode
    KEY_PASSHPRASE=""
    if [ -n "${GPG_RESTORE_EMAIL_PASSPHRASE:-}" ]; then
        KEY_PASSHPRASE="--pinentry-mode=loopback --passphrase $GPG_RESTORE_EMAIL_PASSPHRASE"
    fi
    # You must have the recipient key that was used to encrypt
    gpg --batch --yes $KEY_PASSHPRASE --output /tmp/${LATEST_BACKUP%.gpg} --decrypt /tmp/$LATEST_BACKUP
    elif [ -n "${PASSPHRASE:-}" ]; then
    echo "Decrypting $LATEST_BACKUP"
    gpg --batch --passphrase "$PASSPHRASE" --output /tmp/${LATEST_BACKUP%.gpg} --decrypt /tmp/$LATEST_BACKUP
fi

echo "Restoring from: /tmp/${LATEST_BACKUP%.gpg}"

if [ "$DRY_RUN" = true ]; then
    echo "Dry run mode: skipping actual restore!"
else
    pg_restore --clean --if-exists -d $PGDATABASE /tmp/${LATEST_BACKUP%.gpg}
    echo "Restore complete!"
fi

#!/bin/sh

set -euo pipefail

export PGUSER="${POSTGRES_USER}"
export PGPASSWORD="${POSTGRES_PASSWORD}"
export PGHOST="${POSTGRES_HOST}"
export PGPORT="${POSTGRES_PORT}"
export PGDATABASE="${POSTGRES_DB}"

TIMESTAMP=$(date +"%Y-%m-%d_%H:%M:%S")
BACKUPS_DIR=backups
ENCRYPTED_BACKUPS_DIR=encrypted_backups
DUMP_FILENAME=${POSTGRES_DB}_${TIMESTAMP}.dump

echo "Creating backup of '$POSTGRES_DB' database..."
mkdir -p $BACKUPS_DIR
mkdir -p $ENCRYPTED_BACKUPS_DIR
pg_dump --format=custom $PGDUMP_EXTRA_OPTS > $BACKUPS_DIR/$DUMP_FILENAME

# Encrypt the backup based on provided environment variables
if [ -n "${GPG_EMAILS:-}" ]; then
  echo "Encrypting backup using gpg emails..."
  for EMAIL in $(echo $GPG_EMAILS | tr "," "\n"); do
    echo "Using $EMAIL"
    OUTPUT_FILENAME=${DUMP_FILENAME}_${EMAIL}.gpg

    # Fetch the public key using WKD
    gpg --auto-key-locate clear,wkd --locate-keys "$EMAIL"

    # Encrypt the dump file using the located public key
    gpg --batch --encrypt --recipient "$EMAIL" --trust-model always --output $ENCRYPTED_BACKUPS_DIR/$OUTPUT_FILENAME $BACKUPS_DIR/$DUMP_FILENAME

    echo "Backup encrypted for $EMAIL as $OUTPUT_FILENAME"
  done
elif [ -n "${PASSPHRASE:-}" ]; then
  echo "Encrypting backup using passphrase..."
  gpg --symmetric --batch --passphrase "$PASSPHRASE" --output $ENCRYPTED_BACKUPS_DIR/$DUMP_FILENAME.gpg $BACKUPS_DIR/$DUMP_FILENAME
else
  echo "No encryption specified. Skipping encryption step."
fi


  # local_file="db.dump.gpg"
# else
#   local_file="db.dump"
#   s3_uri="$s3_uri_base"
# fi

# echo "Uploading backup to $S3_BUCKET..."
# aws $aws_args s3 cp "$local_file" "$s3_uri"
# rm "$local_file"

# echo "Backup complete."

# if [ -n "$BACKUP_KEEP_DAYS" ]; then
#   sec=$((86400*BACKUP_KEEP_DAYS))
#   date_from_remove=$(date -d "@$(($(date +%s) - sec))" +%Y-%m-%d)
#   backups_query="Contents[?LastModified<='${date_from_remove} 00:00:00'].{Key: Key}"

#   echo "Removing old backups from $S3_BUCKET..."
#   aws $aws_args s3api list-objects \
#     --bucket "${S3_BUCKET}" \
#     --prefix "${S3_PREFIX}" \
#     --query "${backups_query}" \
#     --output text \
#     | xargs -n1 -t -I 'KEY' aws $aws_args s3 rm s3://"${S3_BUCKET}"/'KEY'
#   echo "Removal complete."
# fi

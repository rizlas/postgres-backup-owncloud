#!/bin/sh

set -euo pipefail

export PGUSER="${POSTGRES_USER}"
export PGPASSWORD="${POSTGRES_PASSWORD}"
export PGHOST="${POSTGRES_HOST}"
export PGPORT="${POSTGRES_PORT}"
export PGDATABASE="${POSTGRES_DB}"

timestamp=$(date +"%Y-%m-%d_%H:%M:%S")

echo "Creating backup of $POSTGRES_DB database..."
mkdir backups
DUMP_FILE=${POSTGRES_DB}_${timestamp}.dump
pg_dump --format=custom $PGDUMP_EXTRA_OPTS > backups/$DUMP_FILE

if [ -n "$PASSPHRASE" ]; then
  echo "Encrypting backup..."
  mkdir encrypted
  rm -f db.dump.gpg
  gpg --symmetric --batch --passphrase "$PASSPHRASE" --output encrypted/$DUMP_FILE.gpg backups/$DUMP_FILE
  # rm db.dump
  # local_file="db.dump.gpg"
  # s3_uri="${s3_uri_base}.gpg"
else
  local_file="db.dump"
  s3_uri="$s3_uri_base"
fi

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

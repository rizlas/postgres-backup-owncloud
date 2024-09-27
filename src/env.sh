#!/bin/sh

export PGUSER="${POSTGRES_USER}"
export PGPASSWORD="${POSTGRES_PASSWORD}"
export PGHOST="${POSTGRES_HOST}"
export PGPORT="${POSTGRES_PORT}"
export PGDATABASE="${POSTGRES_DB}"

if [ "$RESTORE_MODE" == "local" ]; then
  if [ -z "$SHARE_PATH" ]; then
    echo "Error: SHARE_PATH must be set when RESTORE_MODE is set to 'local'."
    exit 1
  fi
fi

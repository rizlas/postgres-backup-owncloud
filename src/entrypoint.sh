#!/bin/bash

# Prefer WEBDAV_* vars; fall back to OWNCLOUD_* for backward compatibility
WEBDAV_FQDN="${WEBDAV_FQDN:-${OWNCLOUD_FQDN:-}}"
WEBDAV_SHARE_ID="${WEBDAV_SHARE_ID:-${OWNCLOUD_SHARE_ID:-}}"
WEBDAV_SHARE_PASSWORD="${WEBDAV_SHARE_PASSWORD:-${OWNCLOUD_SHARE_PASSWORD:-}}"

mandatory_env_vars="
POSTGRES_HOST
POSTGRES_PORT
POSTGRES_DB
POSTGRES_PASSWORD
POSTGRES_USER
WEBDAV_SHARE_ID
WEBDAV_SHARE_PASSWORD
WEBDAV_FQDN
"

# Iterate through the list and print the missing variables
for var in $mandatory_env_vars; do
    value=$(eval echo \${$var})
    if [ -z "$value" ]; then
      echo "You need to set the $var environment variable."
      exit 1
    fi
done

exec /usr/local/bin/go-cron -s "$SCHEDULE" -p "$HEALTHCHECK_PORT" -- /bin/bash /app/backup.sh

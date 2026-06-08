#!/bin/bash

export PGUSER="${POSTGRES_USER}"
export PGPASSWORD="${POSTGRES_PASSWORD}"
export PGHOST="${POSTGRES_HOST}"
export PGPORT="${POSTGRES_PORT}"
export PGDATABASE="${POSTGRES_DB}"

# Prefer WEBDAV_* vars; fall back to OWNCLOUD_* for backward compatibility
WEBDAV_FQDN="${WEBDAV_FQDN:-${OWNCLOUD_FQDN:-}}"
WEBDAV_SHARE_ID="${WEBDAV_SHARE_ID:-${OWNCLOUD_SHARE_ID:-}}"
WEBDAV_SHARE_PASSWORD="${WEBDAV_SHARE_PASSWORD:-${OWNCLOUD_SHARE_PASSWORD:-}}"

# Returns the full WebDAV URL for the configured cloud provider.
# CLOUD_TYPE=nextcloud uses /public.php/dav/files/SHARE_TOKEN/
# CLOUD_TYPE=owncloud  uses /public.php/webdav/
get_webdav_url() {
    local path="${1:-}"
    case "${CLOUD_TYPE:-owncloud}" in
        nextcloud)
            echo "https://$WEBDAV_FQDN/public.php/dav/files/$WEBDAV_SHARE_ID/${path}"
            ;;
        *)
            echo "https://$WEBDAV_FQDN/public.php/webdav/${path}"
            ;;
    esac
}

if [ "$RESTORE_MODE" == "local" ]; then
    if [ -z "$SHARE_PATH" ]; then
        echo "Error: SHARE_PATH must be set when RESTORE_MODE is set to 'local'."
        exit 1
    fi
fi

#!/bin/sh

set -eu

exec go-cron -s "$SCHEDULE" -p "$HEALTHCHECK_PORT" -- /bin/sh backup.sh

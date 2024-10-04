ARG ALPINE_VERSION
FROM alpine:$ALPINE_VERSION

ARG TARGETOS
ARG TARGETARCH
ARG GO_CRON_VERSION=v0.0.11
ARG GO_CRON_URL=https://github.com/prodrigestivill/go-cron/releases/download/$GO_CRON_VERSION/go-cron-$TARGETOS-$TARGETARCH-static.gz
ARG UID=1000
ARG GID=1000
ARG USER=pbo
ARG GROUP=pbo

RUN <<EOF
apk update
apk add --no-cache tzdata postgresql-client python3 gnupg curl
curl --fail --retry 4 --retry-all-errors -L $GO_CRON_URL | gzip -d > /usr/local/bin/go-cron
addgroup -g $GID $GROUP && adduser -D -u $UID -G $GROUP $USER
chown $USER:$GROUP /usr/local/bin/go-cron
chmod 770 /usr/local/bin/go-cron
EOF

# Environment defaults
ENV BACKUP_KEEP_DAYS=7
ENV SCHEDULE=@daily
ENV HEALTHCHECK_PORT=8080
ENV PGDUMP_EXTRA_OPTS=""
ENV GPG_TRUST_MODEL=auto
ENV GPG_KEY_LOCATE=wkd
ENV DRY_RUN=false
ENV RESTORE_MODE=remote
ENV TZ="UTC"

WORKDIR /app
RUN chown $USER:$GROUP /app

USER $USER

COPY --chown=$USER:$GROUP src/ .

CMD ["sh", "entrypoint.sh"]

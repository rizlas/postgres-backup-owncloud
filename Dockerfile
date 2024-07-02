ARG ALPINE_VERSION
FROM alpine:${ALPINE_VERSION}

ARG TARGETOS
ARG TARGETARCH
ARG GO_CRON_VERSION=v0.0.10
ARG GO_CRON_URL=https://github.com/prodrigestivill/go-cron/releases/download/$GO_CRON_VERSION/go-cron-$TARGETOS-$TARGETARCH-static.gz

RUN <<EOF
apk update
apk add --no-cache tzdata postgresql-client gnupg aws-cli curl
curl --fail --retry 4 --retry-all-errors -L $GO_CRON_URL | gzip -d > /usr/local/bin/go-cron
apk del curl
addgroup -S pbo && adduser -DS pbo -G pbo
chown pbo:pbo /usr/local/bin/go-cron
chmod 770 /usr/local/bin/go-cron
EOF

# Environment defaults
ENV BACKUP_KEEP_DAYS=7
ENV SCHEDULE="@daily"
ENV HEALTHCHECK_PORT=8080
ENV PGDUMP_EXTRA_OPTS=""
ENV TZ="UTC"

WORKDIR /app
USER pbo
COPY --chown=pbo:pbo src/ .

# CMD ["sh", "entrypoint.sh"]
CMD ["tail", "-f", "/dev/null"]

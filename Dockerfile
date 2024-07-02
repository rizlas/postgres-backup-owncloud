ARG ALPINE_VERSION
FROM alpine:${ALPINE_VERSION}
ARG TARGETARCH

ARG GO_CRON_VERSION=v0.0.10
ARG GO_CRON_URL=https://github.com/prodrigestivill/go-cron/releases/download/$GO_CRON_VERSION/go-cron-linux-$TARGETARCH-static.gz

RUN <<EOF
apk update
apk add --no-cache tzdata postgresql-client gnupg aws-cli curl
curl --fail --retry 4 --retry-all-errors -L $GO_CRON_URL | gzip -d > /usr/local/bin/go-cron
apk del curl
addgroup -S pbo && adduser -DS pbo -G pbo
chown pbo:pbo /usr/local/bin/go-cron
chmod 770 /usr/local/bin/go-cron
EOF

WORKDIR /app
USER pbo
COPY --chown=pbo:pbo src/ .

CMD ["sh", "run.sh"]

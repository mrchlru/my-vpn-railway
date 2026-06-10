FROM debian:bookworm-slim

ARG OUTLINE_SS_VERSION=1.9.2

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        nginx \
        ca-certificates \
        curl \
        openssl \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL \
        "https://github.com/Jigsaw-Code/outline-ss-server/releases/download/v${OUTLINE_SS_VERSION}/outline-ss-server_${OUTLINE_SS_VERSION}_linux_x86_64.tar.gz" \
        | tar -xz -C /usr/local/bin outline-ss-server \
    && chmod +x /usr/local/bin/outline-ss-server

COPY public/index.html /var/www/html/index.html
COPY scripts/docker-entrypoint.sh /docker-entrypoint.sh

RUN chmod +x /docker-entrypoint.sh

ENV OUTLINE_INTERNAL_PORT=8081

EXPOSE 8080

ENTRYPOINT ["/docker-entrypoint.sh"]

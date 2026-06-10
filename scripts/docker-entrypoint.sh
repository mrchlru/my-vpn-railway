#!/bin/sh
set -eu

OUTLINE_INTERNAL_PORT="${OUTLINE_INTERNAL_PORT:-8081}"
PUBLIC_PORT="${PORT:-8080}"

generate_secret() {
    openssl rand -base64 24 | tr -d '/+=' | head -c 32
}

generate_uuid() {
    if command -v uuidgen >/dev/null 2>&1; then
        uuidgen | tr '[:upper:]' '[:lower:]'
        return
    fi

    openssl rand -hex 16 | sed 's/\(........\)\(....\)\(....\)\(....\)\(............\)/\1-\2-\3-\4-\5/'
}

VPN_SECRET="${VPN_SECRET:-$(generate_secret)}"
WS_PATH="${WS_PATH:-$(generate_secret)}"
KEY_PREFIX="${KEY_PREFIX:-vanya}"
KEY_UUID="${KEY_UUID:-$(generate_uuid)}"
VPN_DOMAIN="${VPN_DOMAIN:-}"

if [ -z "$VPN_DOMAIN" ]; then
    echo "WARNING: VPN_DOMAIN не задан. После деплоя укажите публичный домен Railway."
    VPN_DOMAIN="your-app.up.railway.app"
fi

mkdir -p /etc/outline /var/log/nginx

cat > /etc/outline/server.yaml <<EOF
web:
  servers:
    - id: server1
      listen:
        - "127.0.0.1:${OUTLINE_INTERNAL_PORT}"

services:
  - listeners:
      - type: websocket-stream
        web_server: server1
        path: /${WS_PATH}/tcp
      - type: websocket-packet
        web_server: server1
        path: /${WS_PATH}/udp
    keys:
      - id: 1
        cipher: chacha20-ietf-poly1305
        secret: ${VPN_SECRET}
EOF

cat > /etc/outline/dynamic-key.yaml <<EOF
transport:
  \$type: tcpudp
  tcp:
    \$type: shadowsocks
    endpoint:
      \$type: websocket
      url: wss://${VPN_DOMAIN}/${WS_PATH}/tcp
    cipher: chacha20-ietf-poly1305
    secret: ${VPN_SECRET}
  udp:
    \$type: shadowsocks
    endpoint:
      \$type: websocket
      url: wss://${VPN_DOMAIN}/${WS_PATH}/udp
    cipher: chacha20-ietf-poly1305
    secret: ${VPN_SECRET}
EOF

cat > /etc/nginx/nginx.conf <<EOF
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /tmp/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    access_log /var/log/nginx/access.log;
    sendfile on;
    keepalive_timeout 65;

    server {
        listen ${PUBLIC_PORT};
        server_name _;

        location = /${KEY_PREFIX}/${KEY_UUID} {
            default_type text/yaml;
            charset utf-8;
            alias /etc/outline/dynamic-key.yaml;
        }

        location /${WS_PATH}/ {
            proxy_pass http://127.0.0.1:${OUTLINE_INTERNAL_PORT};
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_read_timeout 86400;
        }

        location / {
            root /var/www/html;
            try_files /index.html =404;
        }
    }
}
EOF

outline-ss-server -config=/etc/outline/server.yaml &
OUTLINE_PID=$!

cleanup() {
    kill "$OUTLINE_PID" 2>/dev/null || true
}

trap cleanup INT TERM

echo "============================================================"
echo "VPN на Railway запущен"
echo "Домен:          ${VPN_DOMAIN}"
echo "Префикс ключа:  ${KEY_PREFIX}"
echo "UUID ключа:     ${KEY_UUID}"
echo "Секрет SS:      ${VPN_SECRET}"
echo "WS путь:        /${WS_PATH}/tcp и /${WS_PATH}/udp"
echo ""
echo "Ссылка для Outline Client (ssconf):"
echo "ssconf://${VPN_DOMAIN}/${KEY_PREFIX}/${KEY_UUID}"
echo ""
echo "Проверка конфига:"
echo "https://${VPN_DOMAIN}/${KEY_PREFIX}/${KEY_UUID}"
echo "============================================================"

exec nginx -g 'daemon off;'

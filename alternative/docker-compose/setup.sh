#!/bin/bash
# Creates .env from .env.example with generated secrets, and a self-signed TLS
# certificate in ./certs, if they do not exist yet. Safe to re-run: existing
# values are kept. Then: docker compose up -d
set -euo pipefail
cd "$(dirname "$0")"

gen() { openssl rand -base64 30 | tr -d '/+=' | cut -c1-32; }

if [ ! -f .env ]; then
    cp .env.example .env
    echo "created .env from .env.example"
fi

# Fill empty secrets only.
fill() {
    local key="$1" value="$2"
    if grep -qE "^${key}=$" .env; then
        sed -i "s|^${key}=$|${key}=${value}|" .env
        echo "generated ${key}"
    fi
}
fill ASCENDER_ADMIN_PASSWORD "$(gen)"
fill ASCENDER_PGSQL_PWD "$(gen)"
fill ASCENDER_SECRET_KEY "$(gen)$(gen)"
fill ASCENDER_WEBSOCKET_SECRET "$(gen)"

hostname_value=$(grep -E '^ASCENDER_HOSTNAME=' .env | cut -d= -f2-)
hostname_value=${hostname_value:-localhost}

if [ ! -f certs/ascender.crt ] || [ ! -f certs/ascender.key ]; then
    openssl req -x509 -nodes -newkey rsa:2048 -days 825 \
        -keyout certs/ascender.key -out certs/ascender.crt \
        -subj "/CN=${hostname_value}" \
        -addext "subjectAltName=DNS:${hostname_value},DNS:localhost,IP:127.0.0.1" 2>/dev/null
    # nginx runs as uid 1000 inside the container; it needs to read the key.
    chmod 644 certs/ascender.crt certs/ascender.key
    echo "generated self-signed certificate for ${hostname_value} in certs/"
    echo "  (replace certs/ascender.crt and certs/ascender.key with your own to use a real certificate)"
fi

echo
echo "Ready. Start Ascender with:  docker compose up -d"
echo "Admin user: $(grep -E '^ASCENDER_ADMIN_USER=' .env | cut -d= -f2-)"
echo "Admin password is ASCENDER_ADMIN_PASSWORD in .env"

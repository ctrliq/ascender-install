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
chmod 0600 .env

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
    echo "generated self-signed certificate for ${hostname_value} in certs/"
    echo "  (replace certs/ascender.crt and certs/ascender.key with your own to use a real certificate)"
fi

# certs/ is bind-mounted read-only into the web container, so host permissions
# decide who can read the key. nginx runs there as uid 1000, gid 0: give the
# group (0) read access and keep the private key away from other local users.
# Only root can hand a file to group 0, hence the fallback.
chmod 0644 certs/ascender.crt
if [ "$(id -u)" = "0" ]; then
    chown root:0 certs/ascender.key
    chmod 0640 certs/ascender.key
else
    chmod 0600 certs/ascender.key
    echo "WARNING: not running as root, so certs/ascender.key stays $(id -un)-only (0600)."
    echo "  nginx in the web container (uid 1000, gid 0) cannot read it unless your uid is 1000."
    echo "  Re-run ./setup.sh as root to make the key root:0 0640."
fi

# Point the http->https redirect at the published HTTPS port, not the default 443.
https_port=$(grep -E '^ASCENDER_HTTPS_PORT=' .env | cut -d= -f2-)
https_port=${https_port:-443}
if [ "${https_port}" = "443" ]; then https_suffix=""; else https_suffix=":${https_port}"; fi
sed -i -E "s#^(return 301 https://\\\$host)(:[0-9]+)?(\\\$request_uri;)#\\1${https_suffix}\\3#" \
    config/nginx-http-redirect.conf

echo
echo "Ready. Start Ascender with:  docker compose up -d"
echo "Admin user: $(grep -E '^ASCENDER_ADMIN_USER=' .env | cut -d= -f2-)"
echo "Admin password is ASCENDER_ADMIN_PASSWORD in .env"

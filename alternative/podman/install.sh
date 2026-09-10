#!/usr/bin/env bash
# Installs Ascender (Podman native) on this host:
#   /usr/libexec/ascender/            manage-containers.sh, scripts/, receptor/ (image build context)
#   /etc/ascender/                    ascender.conf (secrets generated), settings.py, nginx*.conf,
#                                     receptor.conf, valkey.conf, certs/
#   /etc/systemd/system/ascender.service
# then enables and starts the service. Re-running upgrades the scripts and
# config templates but never touches ascender.conf or certs/. Run as root.
#
#   ./install.sh [--no-start]
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
LIBEXEC=/usr/libexec/ascender
CONFDIR=/etc/ascender
CONF="${CONFDIR}/ascender.conf"
UNIT=/etc/systemd/system/ascender.service
START=yes
[[ "${1:-}" == "--no-start" ]] && START=no

if [[ "$(id -u)" -ne 0 ]]; then
    echo "run as root" >&2; exit 1
fi
command -v podman >/dev/null || { echo "podman is not installed" >&2; exit 1; }
command -v openssl >/dev/null || { echo "openssl is not installed" >&2; exit 1; }

echo "installing scripts to ${LIBEXEC}"
mkdir -p "${LIBEXEC}"
install -m 0755 "${SRC_DIR}/manage-containers.sh" "${LIBEXEC}/manage-containers.sh"
rm -rf "${LIBEXEC}/scripts" "${LIBEXEC}/receptor"
cp -r "${SRC_DIR}/scripts" "${LIBEXEC}/scripts"
cp -r "${SRC_DIR}/receptor" "${LIBEXEC}/receptor"
chmod 0755 "${LIBEXEC}"/scripts/*.sh "${LIBEXEC}"/receptor/*.sh

echo "installing config to ${CONFDIR}"
mkdir -p "${CONFDIR}/certs"
chmod 0755 "${CONFDIR}"
for f in settings.py nginx.conf nginx-locations.conf nginx-http-redirect.conf nginx-http-insecure.conf receptor.conf valkey.conf; do
    install -m 0644 "${SRC_DIR}/config/${f}" "${CONFDIR}/${f}"
done

gen() { openssl rand -base64 30 | tr -d '/+=' | cut -c1-32; }
if [[ ! -f "${CONF}" ]]; then
    install -m 0600 "${SRC_DIR}/ascender.conf.example" "${CONF}"
    echo "created ${CONF}"
fi
chmod 0600 "${CONF}"
fill() {
    local key="$1" value="$2"
    if grep -qE "^${key}=$" "${CONF}"; then
        sed -i "s|^${key}=$|${key}=${value}|" "${CONF}"
        echo "generated ${key}"
    fi
}
fill ASCENDER_ADMIN_PASSWORD "$(gen)"
fill ASCENDER_PGSQL_PWD "$(gen)"
fill ASCENDER_SECRET_KEY "$(gen)$(gen)"
fill ASCENDER_WEBSOCKET_SECRET "$(gen)"

hostname_value="$(grep -E '^ASCENDER_HOSTNAME=' "${CONF}" | cut -d= -f2- | tr -d '"'"'" || true)"
hostname_value="${hostname_value:-localhost}"
if [[ ! -f "${CONFDIR}/certs/ascender.crt" || ! -f "${CONFDIR}/certs/ascender.key" ]]; then
    openssl req -x509 -nodes -newkey rsa:2048 -days 825 \
        -keyout "${CONFDIR}/certs/ascender.key" -out "${CONFDIR}/certs/ascender.crt" \
        -subj "/CN=${hostname_value}" \
        -addext "subjectAltName=DNS:${hostname_value},DNS:localhost,IP:127.0.0.1" 2>/dev/null
    # nginx runs as uid 1000 inside the container and must read the key.
    chmod 0644 "${CONFDIR}/certs/ascender.crt" "${CONFDIR}/certs/ascender.key"
    echo "generated self-signed certificate for ${hostname_value} in ${CONFDIR}/certs/"
    echo "  (replace ascender.crt / ascender.key with your own for a real certificate)"
fi

echo "installing ${UNIT}"
install -m 0644 "${SRC_DIR}/ascender.service" "${UNIT}"
systemctl daemon-reload

if [[ "${START}" == yes ]]; then
    echo "enabling and starting ascender.service (first start pulls images and migrates; follow with: journalctl -fu ascender)"
    echo "This will take a while..."
    systemctl enable --now ascender.service
    systemctl --no-pager --lines=0 status ascender.service || true
else
    systemctl enable ascender.service
    echo "not started (--no-start). Review ${CONF}, then: systemctl start ascender"
fi
echo
echo "Admin user: $(grep -E '^ASCENDER_ADMIN_USER=' "${CONF}" | cut -d= -f2-)"
echo "Admin password: ASCENDER_ADMIN_PASSWORD in ${CONF}"

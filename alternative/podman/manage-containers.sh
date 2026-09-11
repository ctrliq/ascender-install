#!/usr/bin/env bash
# Ascender on Podman: creates and manages the containers. Driven by
# /etc/ascender/ascender.conf and run by ascender.service (up/down); also
# usable by hand: manage-containers.sh {up|down|restart|status|destroy}.
#
# Layout (same containers as the Kubernetes pod and the docker-compose install):
#   pod "ascender"       shared hostname + network namespace, publishes the UI ports
#     ascender-valkey      cache / channel layer (unix socket only)
#     ascender-receptor    receptor node running jobs in rootless podman (privileged)
#     ascender-task        dispatcher, callback receiver, websocket relay
#     ascender-web         nginx, uwsgi, daphne
#     ascender-rsyslog     external log forwarder
#     ascender-postgres    database (bundled; ENABLE_POSTGRES=false for an external one)
#   one-shots            ascender-init (volume ownership), ascender-migrate
set -euo pipefail

CONF_FILE="${ASCENDER_CONFIG:-/etc/ascender/ascender.conf}"

load_conf_file() {
    local file="$1" line key value first last lineno=0
    while IFS= read -r line || [[ -n "${line}" ]]; do
        lineno=$((lineno + 1))
        line="${line%$'\r'}"
        [[ "${line}" =~ ^[[:space:]]*$ ]] && continue
        [[ "${line}" =~ ^[[:space:]]*# ]] && continue
        if [[ ! "${line}" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=(.*)$ ]]; then
            echo "ERROR: invalid config line ${file}:${lineno}: ${line}" >&2
            return 1
        fi
        key="${BASH_REMATCH[1]}"; value="${BASH_REMATCH[2]}"
        value="${value#"${value%%[![:space:]]*}"}"
        if [[ ${#value} -ge 2 ]]; then
            first="${value:0:1}"; last="${value: -1}"
            if [[ "${first}" == "${last}" && ( "${first}" == '"' || "${first}" == "'" ) ]]; then
                value="${value:1:${#value}-2}"
            fi
        fi
        printf -v "${key}" '%s' "${value}"
        export "${key}"
    done < "${file}"
}

if [[ -f "${CONF_FILE}" ]]; then
    load_conf_file "${CONF_FILE}"
fi

: "${ASCENDER_IMAGE:=ghcr.io/ctrliq/ascender}"
: "${ASCENDER_VERSION:=latest}"
: "${ASCENDER_RECEPTOR_IMAGE:=ghcr.io/ctrliq/ascender-receptor}"
: "${RECEPTOR_IMAGE:=quay.io/ansible/receptor:v1.6.8}"
: "${POSTGRES_IMAGE:=quay.io/sclorg/postgresql-15-c9s}"
: "${VALKEY_IMAGE:=ghcr.io/valkey-io/valkey:9-alpine}"
: "${ASCENDER_HOSTNAME:=localhost}"
: "${ASCENDER_HTTP_PORT:=80}"
: "${ASCENDER_HTTPS_PORT:=443}"
: "${ASCENDER_HTTP_MODE:=redirect}"
: "${ASCENDER_NODE_NAME:=ascender}"
: "${ASCENDER_ADMIN_USER:=admin}"
: "${ASCENDER_ADMIN_PASSWORD:=}"
: "${ASCENDER_ADMIN_EMAIL:=admin@example.com}"
: "${ENABLE_POSTGRES:=true}"
: "${ASCENDER_PGSQL_HOST:=postgres}"
: "${ASCENDER_PGSQL_PORT:=5432}"
: "${ASCENDER_PGSQL_DB:=ascender}"
: "${ASCENDER_PGSQL_USER:=ascender}"
: "${ASCENDER_PGSQL_PWD:=}"
: "${POSTGRES_MAX_CONNECTIONS:=1024}"
: "${ASCENDER_SECRET_KEY:=}"
: "${ASCENDER_WEBSOCKET_SECRET:=}"
: "${ASCENDER_CONFIG_DIR:=/etc/ascender}"
: "${ASCENDER_LIBEXEC_DIR:=/usr/libexec/ascender}"

is_true_quiet() { local v="${1,,}"; v="${v// /}"; [[ "${v}" == 1 || "${v}" == true || "${v}" == yes || "${v}" == on ]]; }

POD="ascender"
NETWORK="ascender"
SECRET="ascender_secret_key"
CERT_DIR="${ASCENDER_CONFIG_DIR}/certs"
SCRIPTS_DIR="${ASCENDER_LIBEXEC_DIR}/scripts"
RECEPTOR_BUILD_DIR="${ASCENDER_LIBEXEC_DIR}/receptor"
ASCENDER_REF="${ASCENDER_IMAGE}:${ASCENDER_VERSION}"
# The bundled PostgreSQL runs inside the pod, so it is reached on the pod's
# loopback; ASCENDER_PGSQL_HOST only matters for an external database.
if is_true_quiet "${ENABLE_POSTGRES}"; then
    DATABASE_HOST="127.0.0.1"
else
    DATABASE_HOST="${ASCENDER_PGSQL_HOST}"
fi
RECEPTOR_REF="${ASCENDER_RECEPTOR_IMAGE}:${ASCENDER_VERSION}"

# Named volumes; prefixed because rootful podman's namespace is global.
VOL_PG="ascender_postgres_data"
VOL_PROJECTS="ascender_projects"
VOL_JOBDATA="ascender_job_private_data"
VOL_RECEPTOR_SOCK="ascender_receptor_socket"
VOL_RSYSLOG_SOCK="ascender_rsyslog_socket"
VOL_VALKEY_SOCK="ascender_valkey_socket"
VOL_RSYSLOG_SPOOL="ascender_rsyslog_spool"
VOL_PODMAN="ascender_podman_storage"
ALL_VOLUMES=("${VOL_PG}" "${VOL_PROJECTS}" "${VOL_JOBDATA}" "${VOL_RECEPTOR_SOCK}" "${VOL_RSYSLOG_SOCK}" "${VOL_VALKEY_SOCK}" "${VOL_RSYSLOG_SPOOL}" "${VOL_PODMAN}")

# Config bind mounts shared by every Ascender container. ":z" gives the files a
# shared SELinux label so several containers can read them.
COMMON_MOUNTS=(
    -v "${ASCENDER_CONFIG_DIR}/settings.py:/etc/tower/settings.py:ro,z"
    -v "${ASCENDER_CONFIG_DIR}/receptor.conf:/etc/receptor/receptor.conf:ro,z"
)
SECRET_MOUNT=(--secret "${SECRET},type=mount,target=/etc/tower/SECRET_KEY,uid=1000,gid=0,mode=0440")
COMMON_ENV=(
    -e AWX_LOGGING_MODE=stdout
    -e ASCENDER_HOSTNAME="${ASCENDER_HOSTNAME}"
    -e ASCENDER_HTTP_PORT="${ASCENDER_HTTP_PORT}"
    -e ASCENDER_HTTPS_PORT="${ASCENDER_HTTPS_PORT}"
    -e ASCENDER_HTTP_MODE="${ASCENDER_HTTP_MODE}"
    -e DATABASE_HOST="${DATABASE_HOST}"
    -e DATABASE_PORT="${ASCENDER_PGSQL_PORT}"
    -e DATABASE_NAME="${ASCENDER_PGSQL_DB}"
    -e DATABASE_USER="${ASCENDER_PGSQL_USER}"
)

is_true() {
    local v="${1:-}"; v="${v#"${v%%[![:space:]]*}"}"; v="${v%"${v##*[![:space:]]}"}"; v="${v,,}"
    case "${v}" in
        1|true|yes|on) return 0 ;;
        0|false|no|off|"") return 1 ;;
        *) echo "ERROR: invalid boolean value '${1}' (expected true/false)" >&2; exit 1 ;;
    esac
}

log() { echo "[ascender] $*"; }

check_config() {
    local missing=() v
    for v in ASCENDER_ADMIN_PASSWORD ASCENDER_PGSQL_PWD ASCENDER_SECRET_KEY ASCENDER_WEBSOCKET_SECRET; do
        [[ -n "${!v}" ]] || missing+=("${v}")
    done
    if (( ${#missing[@]} > 0 )); then
        echo "ERROR: these must be set in ${CONF_FILE}: ${missing[*]} (install.sh generates them)" >&2
        return 1
    fi
    local f
    case "${ASCENDER_HTTP_MODE}" in redirect|insecure) ;; *) echo "ERROR: ASCENDER_HTTP_MODE must be redirect or insecure" >&2; return 1 ;; esac
    for f in settings.py nginx.conf nginx-locations.conf nginx-http-redirect.conf nginx-http-insecure.conf receptor.conf valkey.conf certs/ascender.crt certs/ascender.key; do
        [[ -r "${ASCENDER_CONFIG_DIR}/${f}" ]] || { echo "ERROR: missing ${ASCENDER_CONFIG_DIR}/${f}" >&2; return 1; }
    done
    for f in init.sh bootstrap.sh launch_task.sh; do
        [[ -r "${SCRIPTS_DIR}/${f}" ]] || { echo "ERROR: missing ${SCRIPTS_DIR}/${f}" >&2; return 1; }
    done
    if ! is_true "${ENABLE_POSTGRES}" && [[ -z "${ASCENDER_PGSQL_HOST}" ]]; then
        echo "ERROR: ENABLE_POSTGRES=false requires ASCENDER_PGSQL_HOST to point at an external database" >&2
        return 1
    fi
}

# Secrets go through a 0600 env file so they never appear in podman's argv.
mk_secret_env_file() {
    local f
    f="$(mktemp /run/ascender-env.XXXXXX)"
    chmod 600 "${f}"
    printf '%s\n' "$@" > "${f}"
    printf '%s' "${f}"
}

container_exists() { podman container exists "$1"; }

remove_if_exists() {
    local name="$1" timeout="${2:-10}"
    if container_exists "${name}"; then
        podman stop -t "${timeout}" "${name}" >/dev/null 2>&1 || true
        podman rm -f "${name}" >/dev/null
    fi
}

stop_if_exists() {
    local name="$1" timeout="${2:-10}"
    if container_exists "${name}"; then
        podman stop -t "${timeout}" "${name}" >/dev/null || true
    fi
}

ensure_secret() {
    # Recreate when the value changed. Containers using it are removed by up()
    # before this runs, so the removal is not blocked.
    local current
    if podman secret exists "${SECRET}"; then
        current="$(podman secret inspect --showsecret --format '{{.SecretData}}' "${SECRET}" 2>/dev/null || true)"
        [[ "${current}" == "${ASCENDER_SECRET_KEY}" ]] && return 0
        podman secret rm "${SECRET}" >/dev/null
    fi
    printf '%s' "${ASCENDER_SECRET_KEY}" | podman secret create "${SECRET}" - >/dev/null
}

ensure_network() {
    # DNS is disabled on the network on purpose: aardvark-dns (podman's
    # internal resolver) drops answers over 512 bytes, which breaks pulling
    # execution environments from ghcr.io's CDN. Containers then get the host's
    # resolvers, and the containers find each other on the pod's loopback.
    if podman network exists "${NETWORK}"; then
        if [[ "$(podman network inspect -f '{{.DNSEnabled}}' "${NETWORK}")" != "false" ]]; then
            log "network ${NETWORK} has DNS enabled, recreating it without"
            if podman pod exists "${POD}"; then
                stop_if_exists ascender-postgres 60
                podman pod rm -f "${POD}" >/dev/null
            fi
            podman network rm -f "${NETWORK}" >/dev/null
        fi
    fi
    podman network exists "${NETWORK}" || podman network create --disable-dns "${NETWORK}" >/dev/null
}

ensure_prereqs() {
    local v
    for v in "${ALL_VOLUMES[@]}"; do
        podman volume exists "${v}" || podman volume create "${v}" >/dev/null
    done
    ensure_secret
    podman image exists "${ASCENDER_REF}" || { log "pulling ${ASCENDER_REF}"; podman pull -q "${ASCENDER_REF}" >/dev/null; }
    if ! podman image exists "${RECEPTOR_REF}"; then
        if podman pull -q "${RECEPTOR_REF}" >/dev/null 2>&1; then
            log "pulled ${RECEPTOR_REF}"
        else
            log "building ${RECEPTOR_REF} from ${RECEPTOR_BUILD_DIR}"
            podman build -q \
                --build-arg ASCENDER_IMAGE="${ASCENDER_IMAGE}" \
                --build-arg ASCENDER_VERSION="${ASCENDER_VERSION}" \
                --build-arg RECEPTOR_IMAGE="${RECEPTOR_IMAGE}" \
                -t "${RECEPTOR_REF}" "${RECEPTOR_BUILD_DIR}" >/dev/null
        fi
    fi
}

ensure_pod() {
    # The pod carries the shared hostname (= Instance name) and the published
    # ports, so changing either in the config means recreating the pod. The
    # settings are kept in a pod label for the comparison.
    local want have
    want="${ASCENDER_NODE_NAME}|${ASCENDER_HTTP_PORT}|${ASCENDER_HTTPS_PORT}"
    if podman pod exists "${POD}"; then
        have="$(podman pod ps --filter "name=^${POD}\$" --format '{{ index .Labels "ascender.settings" }}' 2>/dev/null || true)"
        [[ "${have}" == "${want}" ]] && return 0
        log "pod settings changed (${have:-unknown} -> ${want}), recreating pod"
        stop_if_exists ascender-postgres 60
        podman pod rm -f "${POD}" >/dev/null
    fi
    podman pod create --name "${POD}" \
        --hostname "${ASCENDER_NODE_NAME}" \
        --network "${NETWORK}" \
        --label "ascender.settings=${want}" \
        -p "${ASCENDER_HTTP_PORT}:8052" \
        -p "${ASCENDER_HTTPS_PORT}:8053" >/dev/null
}

run_init() {
    remove_if_exists ascender-init
    podman run --rm --name ascender-init \
        --user 0:0 \
        -v "${SCRIPTS_DIR}:/opt/ascender:ro,z" \
        -v "${VOL_PROJECTS}:/var/lib/awx/projects" \
        -v "${VOL_JOBDATA}:/tmp" \
        -v "${VOL_RECEPTOR_SOCK}:/var/run/awx-receptor" \
        -v "${VOL_RSYSLOG_SOCK}:/var/run/awx-rsyslog" \
        -v "${VOL_PODMAN}:/var/lib/awx/.local/share/containers" \
        --entrypoint /bin/bash "${ASCENDER_REF}" /opt/ascender/init.sh
}

run_postgres() {
    remove_if_exists ascender-postgres 60
    local envfile status=0
    envfile="$(mk_secret_env_file "POSTGRESQL_PASSWORD=${ASCENDER_PGSQL_PWD}")"
    podman run -d --name ascender-postgres --pod "${POD}" \
        --restart on-failure \
        --env-file "${envfile}" \
        -e POSTGRESQL_USER="${ASCENDER_PGSQL_USER}" \
        -e POSTGRESQL_DATABASE="${ASCENDER_PGSQL_DB}" \
        -v "${VOL_PG}:/var/lib/pgsql/data" \
        --health-cmd 'pg_isready -q -h 127.0.0.1 -U "${POSTGRESQL_USER}" -d "${POSTGRESQL_DATABASE}"' \
        --health-interval 5s --health-timeout 5s --health-retries 30 --health-start-period 10s \
        "${POSTGRES_IMAGE}" \
        run-postgresql -c max_connections="${POSTGRES_MAX_CONNECTIONS}" -c log_destination=stderr >/dev/null || status=$?
    rm -f "${envfile}"
    return "${status}"
}

run_valkey() {
    remove_if_exists ascender-valkey
    # Entrypoint bypassed so valkey runs as root: the socket is then root:root
    # 0770 and the Ascender processes (uid 1000, gid 0) can use it.
    podman run -d --name ascender-valkey --pod "${POD}" \
        --restart on-failure \
        -v "${ASCENDER_CONFIG_DIR}/valkey.conf:/usr/local/etc/valkey/valkey.conf:ro,z" \
        -v "${VOL_VALKEY_SOCK}:/var/run/valkey" \
        --health-cmd 'valkey-cli -s /var/run/valkey/valkey.sock ping' \
        --health-interval 5s --health-timeout 5s --health-retries 30 \
        --entrypoint valkey-server "${VALKEY_IMAGE}" /usr/local/etc/valkey/valkey.conf >/dev/null
}

run_migrate() {
    remove_if_exists ascender-migrate
    local envfile status=0
    envfile="$(mk_secret_env_file \
        "DATABASE_PASSWORD=${ASCENDER_PGSQL_PWD}" \
        "BROADCAST_WEBSOCKET_SECRET=${ASCENDER_WEBSOCKET_SECRET}" \
        "ASCENDER_ADMIN_PASSWORD=${ASCENDER_ADMIN_PASSWORD}")"
    podman run --rm --name ascender-migrate --pod "${POD}" \
        --user 1000:0 \
        --env-file "${envfile}" "${COMMON_ENV[@]}" \
        -e ASCENDER_ADMIN_USER="${ASCENDER_ADMIN_USER}" \
        -e ASCENDER_ADMIN_EMAIL="${ASCENDER_ADMIN_EMAIL}" \
        "${COMMON_MOUNTS[@]}" "${SECRET_MOUNT[@]}" \
        -v "${SCRIPTS_DIR}:/opt/ascender:ro,z" \
        -v "${VOL_VALKEY_SOCK}:/var/run/valkey" \
        "${ASCENDER_REF}" /bin/bash /opt/ascender/bootstrap.sh || status=$?
    rm -f "${envfile}"
    return "${status}"
}

run_receptor() {
    remove_if_exists ascender-receptor
    # Privileged: it runs rootless podman for the job containers, as the
    # development environment's hybrid node does. Receptor takes its node id
    # from the pod hostname, which matches the Instance the task registers.
    # SELinux: spc_t keeps it unconfined (nested podman needs that) while the
    # explicit level s0 labels its filesystem plainly. Without it podman gives
    # the rootfs random MCS categories, ansible-runner copies that label along
    # with the callback plugins it places in the job directory, and the task
    # container is then denied access to them.
    podman run -d --name ascender-receptor --pod "${POD}" \
        --user 1000:0 \
        --privileged \
        --security-opt label=type:spc_t --security-opt label=level:s0 \
        --restart on-failure \
        -e RECEPTORCTL_SOCKET=/var/run/awx-receptor/receptor.sock \
        -e XDG_RUNTIME_DIR=/run/user/1000 \
        --mount type=tmpfs,destination=/run/user/1000,tmpfs-mode=0700,U=true \
        -v "${ASCENDER_CONFIG_DIR}/receptor.conf:/etc/receptor/receptor.conf:ro,z" \
        -v "${VOL_PROJECTS}:/var/lib/awx/projects" \
        -v "${VOL_JOBDATA}:/tmp" \
        -v "${VOL_RECEPTOR_SOCK}:/var/run/awx-receptor" \
        -v "${VOL_PODMAN}:/var/lib/awx/.local/share/containers" \
        -v /sys/fs/cgroup:/sys/fs/cgroup \
        "${RECEPTOR_REF}" >/dev/null
}

run_task() {
    remove_if_exists ascender-task 60
    local envfile status=0
    envfile="$(mk_secret_env_file \
        "DATABASE_PASSWORD=${ASCENDER_PGSQL_PWD}" \
        "BROADCAST_WEBSOCKET_SECRET=${ASCENDER_WEBSOCKET_SECRET}")"
    podman run -d --name ascender-task --pod "${POD}" \
        --user 1000:0 \
        --restart on-failure \
        --env-file "${envfile}" "${COMMON_ENV[@]}" \
        -e SUPERVISOR_CONFIG_PATH=/etc/supervisord_task.conf \
        -e RECEPTORCTL_SOCKET=/var/run/awx-receptor/receptor.sock \
        "${COMMON_MOUNTS[@]}" "${SECRET_MOUNT[@]}" \
        -v "${SCRIPTS_DIR}:/opt/ascender:ro,z" \
        -v "${VOL_PROJECTS}:/var/lib/awx/projects" \
        -v "${VOL_JOBDATA}:/tmp" \
        -v "${VOL_VALKEY_SOCK}:/var/run/valkey" \
        -v "${VOL_RECEPTOR_SOCK}:/var/run/awx-receptor" \
        -v "${VOL_RSYSLOG_SOCK}:/var/run/awx-rsyslog" \
        "${ASCENDER_REF}" /opt/ascender/launch_task.sh >/dev/null || status=$?
    rm -f "${envfile}"
    return "${status}"
}

run_web() {
    remove_if_exists ascender-web
    # Redirect users to the published HTTPS port, not the internal 8053/default 443.
    local https_suffix=""
    [[ "${ASCENDER_HTTPS_PORT}" != "443" ]] && https_suffix=":${ASCENDER_HTTPS_PORT}"
    sed -i -E "s#^(return 301 https://\\\$host)(:[0-9]+)?(\\\$request_uri;)#\\1${https_suffix}\\3#" \
        "${ASCENDER_CONFIG_DIR}/nginx-http-redirect.conf"
    local envfile status=0
    envfile="$(mk_secret_env_file \
        "DATABASE_PASSWORD=${ASCENDER_PGSQL_PWD}" \
        "BROADCAST_WEBSOCKET_SECRET=${ASCENDER_WEBSOCKET_SECRET}")"
    podman run -d --name ascender-web --pod "${POD}" \
        --user 1000:0 \
        --restart on-failure \
        --env-file "${envfile}" "${COMMON_ENV[@]}" \
        -e SUPERVISOR_CONFIG_PATH=/etc/supervisord_web.conf \
        "${COMMON_MOUNTS[@]}" "${SECRET_MOUNT[@]}" \
        -v "${ASCENDER_CONFIG_DIR}/nginx.conf:/etc/nginx/nginx.conf:ro,z" \
        -v "${ASCENDER_CONFIG_DIR}/nginx-locations.conf:/etc/nginx/ascender-locations.conf:ro,z" \
        -v "${ASCENDER_CONFIG_DIR}/nginx-http-${ASCENDER_HTTP_MODE}.conf:/etc/nginx/ascender-http.conf:ro,z" \
        -v "${CERT_DIR}:/etc/tower/certs:ro,z" \
        -v "${VOL_PROJECTS}:/var/lib/awx/projects" \
        -v "${VOL_VALKEY_SOCK}:/var/run/valkey" \
        -v "${VOL_RSYSLOG_SOCK}:/var/run/awx-rsyslog" \
        --health-cmd 'curl -kfsS -o /dev/null https://127.0.0.1:8053/api/v2/ping/' \
        --health-interval 15s --health-timeout 5s --health-retries 20 --health-start-period 60s \
        "${ASCENDER_REF}" launch_awx_web.sh >/dev/null || status=$?
    rm -f "${envfile}"
    return "${status}"
}

run_rsyslog() {
    remove_if_exists ascender-rsyslog
    local envfile status=0
    envfile="$(mk_secret_env_file \
        "DATABASE_PASSWORD=${ASCENDER_PGSQL_PWD}" \
        "BROADCAST_WEBSOCKET_SECRET=${ASCENDER_WEBSOCKET_SECRET}")"
    podman run -d --name ascender-rsyslog --pod "${POD}" \
        --user 1000:0 \
        --restart on-failure \
        --env-file "${envfile}" "${COMMON_ENV[@]}" \
        -e SUPERVISOR_CONFIG_PATH=/etc/supervisord_rsyslog.conf \
        "${COMMON_MOUNTS[@]}" "${SECRET_MOUNT[@]}" \
        -v "${VOL_VALKEY_SOCK}:/var/run/valkey" \
        -v "${VOL_RSYSLOG_SOCK}:/var/run/awx-rsyslog" \
        -v "${VOL_RSYSLOG_SPOOL}:/var/lib/awx/rsyslog" \
        "${ASCENDER_REF}" launch_awx_rsyslog.sh >/dev/null || status=$?
    rm -f "${envfile}"
    return "${status}"
}

# Poll a container's healthcheck; fail early on unhealthy or crash-looping.
wait_for_healthy() {
    local name="$1" attempts="${2:-600}" out health restarts
    while (( attempts > 0 )); do
        out="$(podman inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}} {{.RestartCount}}' "${name}" 2>/dev/null || true)"
        read -r health restarts <<<"${out}"
        case "${health}" in
            healthy|none) return 0 ;;
            unhealthy)
                echo "ERROR: ${name} became unhealthy" >&2
                podman logs --tail 50 "${name}" >&2 || true
                return 1 ;;
        esac
        if [[ "${restarts}" =~ ^[0-9]+$ ]] && (( restarts > 0 )); then
            echo "ERROR: ${name} is restarting before it became healthy; check its logs" >&2
            podman logs --tail 50 "${name}" >&2 || true
            return 1
        fi
        attempts=$((attempts - 1))
        sleep 1
    done
    echo "ERROR: ${name} did not become healthy in time" >&2
    podman logs --tail 50 "${name}" >&2 || true
    return 1
}

# `podman run -d` succeeds once the container is created even if its command
# exits at once; sample it for a few seconds so a dead service fails the unit.
wait_for_running() {
    local name="$1" state running restarts
    for _ in 1 2 3 4 5 6; do
        sleep 1
        state="$(podman container inspect -f '{{.State.Running}} {{.RestartCount}}' "${name}" 2>/dev/null || true)"
        running="${state%% *}"; restarts="${state##* }"
        if [[ "${running}" != "true" ]] || { [[ "${restarts}" =~ ^[0-9]+$ ]] && (( restarts > 0 )); }; then
            echo "ERROR: ${name} did not stay running (running=${running:-unknown} restarts=${restarts:-unknown})" >&2
            podman logs --tail 50 "${name}" >&2 || true
            return 1
        fi
    done
}

up() {
    # Preflight before anything is touched: a config error must not stop a
    # stack that is already running (the rollback trap below would).
    check_config

    # systemd does not run ExecStop when ExecStart fails: roll back ourselves so
    # a failed start never leaves half the stack running.
    up_succeeded=""
    trap '[[ -n "${up_succeeded}" ]] || down' EXIT

    # Containers must be gone before the pod, network or secret can be replaced.
    for c in ascender-web ascender-task ascender-rsyslog ascender-receptor ascender-valkey; do
        remove_if_exists "${c}"
    done
    ensure_network
    ensure_prereqs
    ensure_pod

    log "preparing volumes"
    run_init

    if is_true "${ENABLE_POSTGRES}"; then
        log "starting postgres"
        run_postgres
        wait_for_healthy ascender-postgres || return 1
    else
        remove_if_exists ascender-postgres 60
    fi

    log "starting valkey"
    run_valkey
    wait_for_healthy ascender-valkey 120 || return 1

    log "running migrations and bootstrap"
    run_migrate || return 1

    log "starting receptor"
    run_receptor
    wait_for_running ascender-receptor || return 1

    log "starting task"
    run_task
    wait_for_running ascender-task || return 1

    log "starting web"
    run_web
    wait_for_running ascender-web || return 1

    log "starting rsyslog"
    run_rsyslog
    wait_for_running ascender-rsyslog || return 1

    log "waiting for the web service"
    wait_for_healthy ascender-web 600 || return 1

    up_succeeded=1
    trap - EXIT
    log "up: https://${ASCENDER_HOSTNAME}:${ASCENDER_HTTPS_PORT}/ (admin user: ${ASCENDER_ADMIN_USER})"
}

# Stop but keep the containers so the named volumes stay referenced and are
# not reaped by `podman volume prune`. up() recreates them.
down() {
    # supervisord in the web container needs more than podman's default 10s to
    # bring nginx, uwsgi and daphne down cleanly.
    stop_if_exists ascender-web 30
    stop_if_exists ascender-rsyslog
    # The dispatcher gets time to cancel running jobs cleanly.
    stop_if_exists ascender-task 60
    stop_if_exists ascender-receptor
    stop_if_exists ascender-valkey
    stop_if_exists ascender-postgres 60
}

status() {
    podman ps -a --pod --filter "name=^ascender-" --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'
}

# Remove everything including data. Deliberately not wired to the unit.
destroy() {
    if [[ "${2:-}" != "--yes" ]]; then
        echo "destroy removes the containers, pod, network, secret AND all data volumes." >&2
        echo "Run: $0 destroy --yes" >&2
        return 1
    fi
    for c in ascender-web ascender-task ascender-rsyslog ascender-receptor ascender-valkey ascender-migrate ascender-init; do
        remove_if_exists "${c}"
    done
    remove_if_exists ascender-postgres 60
    podman pod exists "${POD}" && podman pod rm -f "${POD}" >/dev/null
    podman secret exists "${SECRET}" && podman secret rm "${SECRET}" >/dev/null
    for v in "${ALL_VOLUMES[@]}"; do
        podman volume exists "${v}" && podman volume rm "${v}" >/dev/null
    done
    podman network exists "${NETWORK}" && podman network rm "${NETWORK}" >/dev/null
    log "destroyed"
}

case "${1:-}" in
    up) up ;;
    down) down ;;
    restart) down; up ;;
    status) status ;;
    destroy) destroy "$@" ;;
    *)
        echo "Usage: $0 {up|down|restart|status|destroy --yes}" >&2
        exit 1
        ;;
esac

# Ascender on Docker Compose

Runs a complete Ascender installation on a single Docker host from the
published container images. It is the third deployment option next to the
Kubernetes install (`ascender-install`, the operator) and the development
environment (`tools/docker-compose`), and it runs the **same containers the
Kubernetes pod runs**:

| Service    | Image                                            | Role |
| ---------- | ------------------------------------------------ | ---- |
| `web`      | `ghcr.io/ctrliq/ascender`                        | nginx, uwsgi (API + UI), daphne (websockets) |
| `task`     | `ghcr.io/ctrliq/ascender`                        | dispatcher, callback receiver, websocket relay |
| `rsyslog`  | `ghcr.io/ctrliq/ascender`                        | external log aggregation forwarder |
| `receptor` | `ghcr.io/ctrliq/ascender-receptor` (see below)   | receptor node that runs jobs, the docker equivalent of the `awx-ee` sidecar |
| `valkey`   | `ghcr.io/valkey-io/valkey`                       | cache and channel layer, unix socket only |
| `postgres` | `quay.io/sclorg/postgresql-15-c9s`               | database |
| `init`     | `ghcr.io/ctrliq/ascender` (one-shot, root)       | sets ownership on the shared volumes |
| `migrate`  | `ghcr.io/ctrliq/ascender` (one-shot)             | migrations, admin user, preload data, default EEs |

Jobs run the way they do on a hybrid node: the task container hands each job
to receptor over a shared unix socket, receptor runs `ansible-runner worker`,
and ansible-runner starts the job in a rootless podman container from the
job's execution environment image (`ghcr.io/ctrliq/ascender-ee` by default).
Because podman runs inside the `receptor` container, that container is
privileged. Nothing else is.

## Requirements

- Docker Engine 24+ with the Compose plugin (v2.23 or newer; tested on 28.3 / v2.39)
- `openssl` on the host, for `setup.sh`
- A cgroup v2 host with `/dev/fuse` (any current EL9, Fedora, Ubuntu)
- Roughly 6 GB of disk for images: the Ascender image, the receptor sidecar
  built on top of it, and the execution environment that podman pulls on the
  first job

## Quick start

```bash
cd alternative/docker-compose
sudo ./setup.sh             # writes .env with generated secrets, self-signed cert in certs/
docker compose up -d        # pulls the images, builds the receptor sidecar, starts everything
docker compose logs -f migrate task   # watch the first-run migrations (a few minutes)
```

`setup.sh` runs as root only to make the TLS key readable by the web
container and nobody else; under `sudo` it hands `.env` (mode `0600`) and the
other files it writes back to you, so `docker compose` runs as your own user.
If you run it as root directly, run the compose commands as root too: `.env`
is only readable by its owner.

Then open `https://<host>/` (or `http://<host>/`) and log in with
`ASCENDER_ADMIN_USER` / `ASCENDER_ADMIN_PASSWORD` from `.env`. The first job
takes a few extra minutes while podman pulls the execution environment image.

`docker compose up -d` is idempotent: it re-runs `init` and `migrate` (both
are safe to repeat; `migrate` also resets the admin password to the `.env`
value, like the operator does) and only recreates services whose
configuration changed.

## Configuration

Everything lives in `.env`; `.env.example` documents every variable. The
important ones:

| Variable | Default | Purpose |
| -------- | ------- | ------- |
| `ASCENDER_VERSION` | `latest` | Tag of `ghcr.io/ctrliq/ascender` to run (e.g. `25.6.2`) |
| `ASCENDER_HOSTNAME` | `localhost` | Name users reach the UI with; CSRF trusted origins and the generated certificate |
| `ASCENDER_ALLOWED_HOSTS` | empty | Other names users reach the UI with, comma-separated (an IP address, an alias); added to the CSRF trusted origins |
| `ASCENDER_HTTP_PORT` / `ASCENDER_HTTPS_PORT` | `80` / `443` | Host ports |
| `ASCENDER_HTTP_MODE` | `redirect` | `redirect`: port 80 only redirects to https. `insecure`: serve the UI over plain http; the session and CSRF cookies lose their Secure flag (a plain-http login otherwise fails with "CSRF cookie not set") |
| `ASCENDER_NODE_NAME` | `ascender-task` | Instance name shown in the UI |
| `ASCENDER_ADMIN_*` | `admin` | Admin user, password, email |
| `ASCENDER_PGSQL_*` | bundled `postgres` | Point `ASCENDER_PGSQL_HOST` at an external database to use it instead of the bundled one; also clear the profile (`COMPOSE_PROFILES=`) so the bundled `postgres` service is not started |
| `ASCENDER_SECRET_KEY` | generated | Django secret key; **do not change after install**, stored credentials are encrypted with it |
| `ASCENDER_WEBSOCKET_SECRET` | generated | Shared secret between web nodes and the websocket relay |

Config files under `config/` are mounted read-only into the containers and
need no editing for a standard install:

- `config/settings.py`: `/etc/tower/settings.py`, reads the values above from
  the environment
- `config/nginx.conf`, `config/nginx-locations.conf`: nginx for the web
  container, http on 8052 and https on 8053 inside the container
- `config/receptor.conf`: the receptor node; also mounted into the task
  container, which reads the control socket path from it
- `config/valkey.conf`: unix-socket-only valkey

TLS: `setup.sh` generates a self-signed certificate for `ASCENDER_HOSTNAME`.
Replace `certs/ascender.crt` and `certs/ascender.key` with your own, re-run
`sudo ./setup.sh` to fix the permissions, then `docker compose up -d web` (or
`docker compose restart web`). `certs/` is bind-mounted into the web
container, where nginx runs as uid 1000, gid 0, so `setup.sh` leaves the key
as `root:0` mode `0640`: readable by that process and not by other local
users. That is why it should run as root.

## Upgrading

```bash
# edit ASCENDER_VERSION in .env, then
docker compose pull --ignore-buildable
docker compose build receptor
docker compose up -d
```

`migrate` applies the new migrations before the web and task containers start.

## Operations

```bash
docker compose ps                         # state and health
docker compose logs -f task               # dispatcher / job lifecycle
docker compose exec task awx-manage <cmd> # any awx-manage command
docker compose exec receptor podman images     # EE images cached by podman
docker compose down                       # stop, keep data
docker compose down -v                    # stop and DELETE the database, projects, EE cache
```

Data lives in named volumes: `postgres_data`, `projects`, `podman_storage`
(execution environment images), `rsyslog_spool`. The rest are sockets and
scratch space.

### Back up / restore

```bash
docker compose exec postgres pg_dump -U ascender ascender > ascender.sql
```

Restore into a fresh install by loading the dump before the first
`docker compose up -d` (start only `postgres`, load, then `up -d`), and reuse
the original `.env` so `ASCENDER_SECRET_KEY` matches.

## How it maps to the Kubernetes deployment

| Kubernetes (operator)                     | This compose file |
| ----------------------------------------- | ----------------- |
| Pod hostname shared by all containers     | Every Ascender container gets `hostname: ${ASCENDER_NODE_NAME}`; it is the Instance name, the receptor node id, and it lets daphne read job events straight from valkey instead of through the websocket relay |
| `awx-ee` sidecar running receptor         | `receptor` service; its image adds receptor and podman to the Ascender image because the published image ships neither |
| Container groups (jobs as pods)           | Not available without a Kubernetes API; jobs run in podman inside `receptor` on the hybrid node |
| Instance auto-registration (`IS_K8S`)     | `scripts/launch_task.sh` registers the hybrid instance and the `controlplane` / `default` queues explicitly |
| Secrets mounted as files                  | `/etc/tower/SECRET_KEY` is a compose secret sourced from `.env`; the rest are environment variables read by `config/settings.py` |
| `fsGroup` / init container                | `init` service |
| Migration job, admin-password job         | `migrate` service |
| emptyDir sockets (redis, receptor, rsyslog) | named volumes `valkey_socket`, `receptor_socket`, `rsyslog_socket` |

## The receptor sidecar image

`receptor/Dockerfile` builds `ghcr.io/ctrliq/ascender-receptor:${ASCENDER_VERSION}`
from `ghcr.io/ctrliq/ascender:${ASCENDER_VERSION}` plus the receptor binary
(copied from `quay.io/ansible/receptor`) and podman with the rootless tooling
(crun, fuse-overlayfs, slirp4netns), configured the same way as the
development image. `docker compose up` builds it automatically when it is not
present; if CIQ publishes it under that name later, the same compose file
will pull it instead.

## Adding execution nodes

The receptor node listens on 27199 inside the compose network. To peer remote
execution or hop nodes into it, publish that port (commented out in
`docker-compose.yml`), add TLS to `config/receptor.conf`, register the address
and peers with `awx-manage add_receptor_address` / `register_peers` in the
`task` container, and set the remote node's `tcp-peer` to this host.

## Known limitations

- Single control node. Scaling `web` works for the API (put a load balancer
  in front), but all web replicas must keep the shared hostname; scaling
  `task` is not supported by this layout.
- The periodic `cleanup_images_and_files` task (every 3 hours) tries to run
  `podman image prune` on the task container, which has no podman, and logs an
  error. Harmless; the EE cache lives in the `receptor` container and can be
  pruned there with `docker compose exec receptor podman image prune`.
- The `receptor` container is privileged, as the development environment's
  hybrid node is. Everything else runs unprivileged as uid 1000.

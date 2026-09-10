# Ascender on Podman (systemd, no compose)

Runs the complete Ascender stack on a single host with rootful Podman, managed
by one systemd unit. It is the Podman counterpart of
[../docker-compose](../docker-compose/README.md) and runs the same containers
the Kubernetes deployment runs:

| Container            | Image                                         | Role |
| -------------------- | --------------------------------------------- | ---- |
| pod `ascender`       |                                               | shared hostname (= Instance name) and network namespace for every container below, publishes the UI ports |
| `ascender-web`       | `ghcr.io/ctrliq/ascender`                     | nginx, uwsgi (API + UI), daphne (websockets) |
| `ascender-task`      | `ghcr.io/ctrliq/ascender`                     | dispatcher, callback receiver, websocket relay |
| `ascender-rsyslog`   | `ghcr.io/ctrliq/ascender`                     | external log forwarder |
| `ascender-receptor`  | `ghcr.io/ctrliq/ascender-receptor`            | receptor node running jobs in rootless podman; the `awx-ee` sidecar of the k8s pod |
| `ascender-valkey`    | `ghcr.io/valkey-io/valkey`                    | cache and channel layer, unix socket only |
| `ascender-postgres`  | `quay.io/sclorg/postgresql-15-c9s`            | database, reached on the pod's loopback (`ENABLE_POSTGRES=false` for an external one) |
| `ascender-init`      | one-shot, root                                | ownership of the shared volumes |
| `ascender-migrate`   | one-shot                                      | migrations, admin user, preload data, default EEs |

Jobs run as on a hybrid node: the task container hands each job to receptor
over a shared unix socket, receptor runs `ansible-runner worker`, and
ansible-runner starts the job in a rootless podman container from the job's
execution environment image (`ghcr.io/ctrliq/ascender-ee` by default). That
nested podman is why `ascender-receptor` is privileged; nothing else is.

## Requirements

- Rocky/RHEL 9 or similar with Podman 4.4+ (tested: Rocky 9.6, Podman 5.8),
  rootful, systemd, cgroup v2, SELinux enforcing is fine
- `openssl` for `install.sh`
- 4 GB RAM recommended, ~6 GB disk for images (Ascender, the receptor sidecar
  built on top of it, and the execution environment pulled on the first job)
- Ports 80 and 443 free (configurable)

## Install

```bash
# copy this directory to the host, then as root:
cd /path/to/podman
./install.sh                       # installs, generates secrets + self-signed cert, starts the service
journalctl -fu ascender            # first start: image pulls, sidecar build, migrations (several minutes)
```

Open `https://<host>/` and log in with `ASCENDER_ADMIN_USER` /
`ASCENDER_ADMIN_PASSWORD` from `/etc/ascender/ascender.conf`. The first job
takes a few extra minutes while podman pulls the execution environment image.

To review the configuration before the first start: `./install.sh --no-start`,
edit `/etc/ascender/ascender.conf`, then `systemctl start ascender`.

## What gets installed

| Path | Content |
| ---- | ------- |
| `/etc/ascender/ascender.conf` | all settings and secrets (0600); see `ascender.conf.example` |
| `/etc/ascender/settings.py`, `nginx.conf`, `nginx-locations.conf`, `receptor.conf`, `valkey.conf` | config files mounted read-only into the containers |
| `/etc/ascender/certs/` | `ascender.crt` / `ascender.key`; replace with your own and `systemctl restart ascender` |
| `/usr/libexec/ascender/manage-containers.sh` | creates/starts/stops the containers (`up`, `down`, `restart`, `status`, `destroy --yes`) |
| `/usr/libexec/ascender/scripts/` | `init.sh`, `bootstrap.sh`, `launch_task.sh` mounted into the one-shots and the task container |
| `/usr/libexec/ascender/receptor/` | build context for the receptor sidecar image |
| `/etc/systemd/system/ascender.service` | oneshot unit: `ExecStart=... up`, `ExecStop=... down` |

Data lives in podman named volumes: `ascender_postgres_data`,
`ascender_projects`, `ascender_podman_storage` (execution environment images),
`ascender_rsyslog_spool`; the rest hold sockets and job scratch space.
`systemctl stop ascender` stops the containers but keeps them, so the volumes
stay referenced.

## Configuration

`/etc/ascender/ascender.conf` uses the same variable names as the compose
`.env`. The important ones:

| Variable | Default | Purpose |
| -------- | ------- | ------- |
| `ASCENDER_VERSION` | `latest` | Tag of `ghcr.io/ctrliq/ascender` to run (e.g. `25.6.2`) |
| `ASCENDER_HOSTNAME` | `localhost` | Name users reach the UI with (CSRF trusted origins, generated cert) |
| `ASCENDER_HTTP_PORT` / `ASCENDER_HTTPS_PORT` | `80` / `443` | Published ports |
| `ASCENDER_HTTP_MODE` | `redirect` | `redirect`: port 80 only redirects to https. `insecure`: serve the UI over plain http; the session and CSRF cookies lose their Secure flag (a plain-http login otherwise fails with "CSRF cookie not set") |
| `ASCENDER_NODE_NAME` | `ascender` | Instance name shown in the UI (pod hostname) |
| `ASCENDER_ADMIN_*` | `admin` | Admin user, password, email; the password is re-applied on every start |
| `ENABLE_POSTGRES`, `ASCENDER_PGSQL_*` | bundled | The bundled database lives in the pod and is reached on `127.0.0.1`; set `ENABLE_POSTGRES=false` and `ASCENDER_PGSQL_HOST` for an external database |
| `ASCENDER_SECRET_KEY` | generated | Django secret key, **never change after install** (stored credentials are encrypted with it) |
| `ASCENDER_WEBSOCKET_SECRET` | generated | Shared secret between web nodes and the websocket relay |

After editing the file: `systemctl restart ascender` (containers are recreated
from the config on every start; the pod is recreated when the node name or
ports change).

## Upgrade

```bash
# edit ASCENDER_VERSION in /etc/ascender/ascender.conf, then
podman pull ghcr.io/ctrliq/ascender:<version>
systemctl restart ascender        # builds the matching receptor sidecar, migrates, starts
```

To pick up a new version of these install files, copy them over and re-run
`./install.sh`; it refreshes the scripts and config templates and keeps
`ascender.conf` and `certs/`. If `receptor/` changed, rebuild the sidecar for
the running version too:

```bash
systemctl stop ascender
podman rmi -f ghcr.io/ctrliq/ascender-receptor:<version>   # also drops the stopped container using it
systemctl start ascender                                    # manage-containers.sh rebuilds the image
```

## Operations

```bash
systemctl status ascender
/usr/libexec/ascender/manage-containers.sh status
podman logs -f ascender-task                           # dispatcher / job lifecycle
podman exec ascender-task awx-manage <command>
podman exec ascender-receptor podman images            # EE images cached for jobs
podman exec ascender-postgres pg_dump -U ascender ascender > ascender.sql   # backup
/usr/libexec/ascender/manage-containers.sh destroy --yes   # remove everything INCLUDING data
```

## How it maps to the Kubernetes deployment

| Kubernetes (operator) | Here |
| --------------------- | ---- |
| Pod with shared hostname and network | podman pod `ascender` with `--hostname ASCENDER_NODE_NAME` |
| `awx-ee` sidecar running receptor | `ascender-receptor`: Ascender image + receptor + podman, because the published image ships neither |
| Container groups (jobs as pods) | not available without a Kubernetes API; jobs run in nested podman on the hybrid node |
| Instance auto-registration (`IS_K8S`) | `scripts/launch_task.sh` registers the hybrid instance and the `controlplane` / `default` queues |
| `/etc/tower/SECRET_KEY` secret | `podman secret ascender_secret_key`, mounted at that path in every Ascender container |
| `fsGroup` / init container | `ascender-init` |
| Migration and admin-password jobs | `ascender-migrate` |
| emptyDir sockets | named volumes `ascender_valkey_socket`, `ascender_receptor_socket`, `ascender_rsyslog_socket` |

## Podman-specific notes

- **SELinux.** Containers in the pod share one MCS level, so they can use each
  other's sockets and files. The receptor sidecar is started as `spc_t` at
  level `s0`: privileged alone would still give its filesystem random MCS
  categories, ansible-runner copies that label along with the callback plugins
  it places in the job directory, and the task container would then be denied
  access to them (`PermissionError` on `artifacts/<id>/callback/`). Nested
  podman inside the sidecar runs with `label = false`.
- **DNS.** The `ascender` network is created with `--disable-dns`, so
  containers use the host's resolvers. Podman's internal resolver
  (aardvark-dns) drops answers larger than 512 bytes, which is exactly what
  ghcr.io's CDN returns, and execution environment pulls then fail with
  `lookup pkg-containers.githubusercontent.com ... i/o timeout`. With no
  container-name DNS, the containers talk over the pod's loopback instead, which
  is why postgres also lives in the pod.
- Hosts whose `/etc/resolv.conf` points at a local stub (`127.0.0.53`) need real
  resolver addresses in it, or the containers cannot resolve anything.

## Known limitations

- Single control node; jobs run on this host inside `ascender-receptor`.
- The periodic `cleanup_images_and_files` task (every 3 hours) logs a podman
  error on the task container, which has no podman. Harmless; prune the EE
  cache with `podman exec ascender-receptor podman image prune` if needed.
- `ascender-receptor` is privileged (nested rootless podman), as the
  development environment's hybrid node is.

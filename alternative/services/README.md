# Ascender as host services (Rocky 9, Ansible)

Installs Ascender directly on one Rocky 9 host: PostgreSQL, Valkey, nginx and
the Ascender processes run as regular system services from a Python virtualenv
built from the source tree. No application containers; podman is still
installed because jobs run in rootless podman containers from the execution
environment image, exactly as on a hybrid node.

This is the third install flavour beside [../docker-compose](../docker-compose/README.md)
and [../podman](../podman/README.md). It is an Ansible playbook, so a re-run
converges the host and upgrades are a variable change plus a re-run.

## What ends up on the host

| Component | How |
| --------- | --- |
| PostgreSQL 15 | AppStream module `postgresql:15`, local TCP only, scram passwords |
| Valkey | AppStream package, unix socket `/run/valkey/valkey.sock` shared with the `awx` user |
| nginx | AppStream package, `/etc/nginx/nginx.conf` templated: 443 with TLS, 80 redirects (or serves, see `ascender_http_mode`) |
| Ascender | git checkout in `/var/lib/awx/src`, virtualenv `/var/lib/awx/venv/awx` built with the tree's own `make requirements_awx` and `make sdist` (includes the UI build), static files in `/var/lib/awx/public/static` |
| Processes | one `ascender.service` (user `awx`) running supervisord with the same programs the web, task and rsyslog containers run, plus receptor. Logs in `/var/log/tower/<program>.log` |
| Receptor | binary from the GitHub release under `/usr/local/lib/receptor-<version>`, config `/etc/receptor/receptor.conf`, control socket `/run/ascender/receptor.sock` |
| rsyslog | from the `ansible/Rsyslog` COPR (the `omhttp` module the log aggregator needs), run as `awx` by supervisord with the config the app generates |
| Config | `/etc/tower/settings.py`, `/etc/tower/conf.d/{postgres,channels}.py`, `/etc/tower/SECRET_KEY`, `/etc/tower/uwsgi.ini`, `/etc/tower/supervisord.conf`, `/etc/tower/environment`, certs in `/etc/tower/certs/` |
| Secrets | generated once into `/etc/tower/.secrets/` (`secret_key`, `websocket_secret`, `admin_password`, `pg_password`) and reused on every run |

## Requirements

- Rocky Linux 9 (or another EL9) target with root SSH access, 4 GB RAM and 4 CPUs
  recommended (the UI build is the heavy part), internet access to GitHub,
  npm and the package repositories
- On the machine running the playbook: Ansible 2.15+ and the collections in
  `requirements.yml`

`setup.sh` installs `ansible-core` and the collections when they are missing;
to do it by hand: `ansible-galaxy collection install -r requirements.yml`.

## Install

```bash
cd alternative/services
cp inventory.example inventory      # set the host, ascender_hostname, ascender_version
./setup.sh                          # checks ansible + collections + inventory, runs install.yml
```

`setup.sh` passes extra arguments to `ansible-playbook`, so `./setup.sh --check`
or `./setup.sh -e ascender_version=25.6.2` work; `ansible-playbook install.yml`
is equivalent once the tooling is in place.

The first run takes 15 to 30 minutes: package installs, the virtualenv build
(several packages compile from source), the UI build and the database
migrations. The play ends by printing the URL and where the admin password is
(`/etc/tower/.secrets/admin_password` on the host unless you set
`ascender_admin_password`).

## Variables

Defaults live in `roles/ascender_defaults/defaults/main.yml`; override them in
the inventory or `group_vars/all.yml`.

| Variable | Default | Purpose |
| -------- | ------- | ------- |
| `ascender_version` | `25.6.2` | git tag, branch or commit of `ascender_repo` to install |
| `ascender_python` | `python3.12` | interpreter the tree targets: `python3.12` for the 25.x releases, `python3.14` for `main`. Rocky 9 ships both as AppStream packages (`python3.<x>` and `python3.<x>-devel`), installed by the system role |
| `ascender_hostname` | host FQDN | name users reach the UI with (certificate, CSRF trusted origins) |
| `ascender_allowed_hosts` | `[]` | other names users reach the UI with (an IP address, an alias); requests with any other Host header get a 400 |
| `ascender_node_name` | host nodename | Instance name in the UI and receptor node id |
| `ascender_http_mode` | `redirect` | `redirect`: port 80 redirects to https. `insecure`: serve over plain http too, cookies lose the Secure flag |
| `ascender_admin_user` / `_password` / `_email` | `admin` / generated | admin account; the password is re-applied on every run |
| `ascender_pg_*` | bundled, generated password | database name, user, password, version, `max_connections` |
| `ascender_receptor_version` | `1.6.8` | receptor release to download |
| `ascender_manage_firewalld` | `true` | open http/https when firewalld is running |
| `ascender_subid_start` / `_count` / `_min` | free range / `65536` / `100000` | subordinate uid/gid range of the `awx` user for rootless podman. By default the role picks the first free range above every entry already in `/etc/subuid` and `/etc/subgid`; set `ascender_subid_start` to pin it. An existing `awx` entry is kept. Either way the play fails if the range overlaps another account's, and says how to move it |

## Upgrade

Set `ascender_version` to the new tag and re-run the playbook. The build role
compares the checked-out commit (and Python version) with the stamp from the
last build in `/var/lib/awx/.ascender-build` and rebuilds only when it changed.
An upgrade means downtime: `ascender.service` is stopped before the virtualenv
is replaced (and, on a re-run, before any still-pending migrations), the
services role then runs the migrations and starts it again on the new code.
A run that changes nothing but configuration restarts the service instead.
Take a `pg_dump -U ascender ascender` first; migrations are forward-only.

## Operations

```bash
systemctl status ascender nginx postgresql valkey
sudo -u awx supervisorctl -c /etc/tower/supervisord.conf status   # per-process state
tail -f /var/log/tower/dispatcher.log                             # job lifecycle
sudo -u awx awx-manage <command>
sudo -u awx XDG_RUNTIME_DIR=/run/user/$(id -u awx) podman images   # cached EE images
systemctl restart ascender                                        # after editing /etc/tower
```

Replace `/etc/tower/certs/ascender.crt` and `.key` with a real certificate and
`systemctl reload nginx`.

## How it compares to the container installs

| Container installs | Here |
| ------------------ | ---- |
| `/etc/tower/SECRET_KEY` secret shared by all containers | one file read by every process |
| web/task/rsyslog containers | supervisord programs in one `ascender.service`, so `awx-manage` reload helpers (`supervisorctl`) keep working |
| receptor sidecar with nested podman | receptor as a supervisord program; jobs in rootless podman of the `awx` user (subordinate ids, systemd lingering for `/run/user/<uid>`) |
| `init` container fixing volume ownership | directories created by the playbook |
| `migrate` one-shot | migration tasks in the services role, run on every play |
| nginx in the web container on 8052/8053 | system nginx on 80/443 |
| SELinux handled per container | `httpd_can_network_connect` on, static files labelled `httpd_sys_content_t` |

## Known limitations

- Single host, single hybrid node. Adding execution nodes means peering to
  the receptor listener on 27199 (add TLS, open the firewall, register the
  address and peers with `awx-manage`).
- The periodic `cleanup_images_and_files` task prunes podman images as the
  `awx` user every 3 hours; that is the intended behaviour here, unlike the
  container installs where it only logs an error.

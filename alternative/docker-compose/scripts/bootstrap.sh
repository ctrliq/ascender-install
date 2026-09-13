#!/bin/bash
# Runs once per `docker compose up`, before the web/task/rsyslog containers:
# waits for PostgreSQL, applies migrations, creates/updates the admin user,
# loads the demo data and registers the default execution environments.
# Idempotent; equivalent to the operator's migration + admin-password tasks.
set -euo pipefail

if [ "$(id -u)" -ge 500 ]; then
    echo "awx:x:$(id -u):$(id -g):,,,:/var/lib/awx:/bin/bash" >> /etc/passwd
fi

echo "bootstrap: waiting for PostgreSQL at ${DATABASE_HOST}:${DATABASE_PORT}"
until pg_isready -q -h "${DATABASE_HOST}" -p "${DATABASE_PORT}" -U "${DATABASE_USER}"; do
    sleep 2
done

echo "bootstrap: applying database migrations"
ascender-manage migrate --noinput

echo "bootstrap: ensuring admin user '${ASCENDER_ADMIN_USER}'"
if DJANGO_SUPERUSER_PASSWORD="${ASCENDER_ADMIN_PASSWORD}" \
   ascender-manage createsuperuser --noinput --username "${ASCENDER_ADMIN_USER}" --email "${ASCENDER_ADMIN_EMAIL}" 2>/dev/null; then
    echo "bootstrap: created admin user"
else
    # Already exists: make the password match .env, like the operator does.
    # Not `ascender-manage update_password`: it takes the password on the command
    # line, visible in /proc; the environment is not.
    ascender-manage shell -c '
import os
from django.contrib.auth.models import User
u = User.objects.get(username=os.environ["ASCENDER_ADMIN_USER"])
p = os.environ["ASCENDER_ADMIN_PASSWORD"]
if not u.check_password(p):
    u.set_password(p)
    u.save()
' >/dev/null
    echo "bootstrap: admin user exists, password synced from .env"
fi

echo "bootstrap: loading preload data and default execution environments"
ascender-manage create_preload_data
ascender-manage register_default_execution_environments

echo "bootstrap: done"

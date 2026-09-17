# Ascender settings for the Docker Compose deployment.
#
# Loaded by ascender/settings/production.py after the defaults. Everything
# deployment-specific comes from environment variables set in
# docker-compose.yml (which reads them from .env), so this file is the same for
# every install. Any setting that is not read-only can still be changed in the
# UI or API under Settings; values set here become read-only.

import os

STATIC_ROOT = '/var/lib/awx/public/static'
PROJECTS_ROOT = '/var/lib/awx/projects'
JOBOUTPUT_ROOT = '/var/lib/awx/job_status'

# docker-compose.yml mounts ASCENDER_SECRET_KEY from .env at this path.
with open('/etc/tower/SECRET_KEY', 'rb') as _f:
    SECRET_KEY = _f.read().strip()

_hostname = os.environ.get('ASCENDER_HOSTNAME', 'localhost')
_http_port = os.environ.get('ASCENDER_HTTP_PORT', '80')
_https_port = os.environ.get('ASCENDER_HTTPS_PORT', '443')
# Other names users reach the UI with (comma-separated), e.g. an IP address or
# a second DNS name; each becomes a CSRF trusted origin alongside ASCENDER_HOSTNAME.
_extra_hosts = [h.strip() for h in os.environ.get('ASCENDER_ALLOWED_HOSTS', '').split(',') if h.strip()]

# Accept any Host header, as the Kubernetes install and upstream AWX do: the
# UI is commonly reached by IP address or a name other than ASCENDER_HOSTNAME,
# and a strict list turned every such request into a 400. Trade-off: Django's
# host-header validation is off, so the first request seen can set
# TOWER_URL_BASE (the base of links in notifications) to whatever Host it
# carried; set ASCENDER_HOSTNAME and TOWER_URL_BASE in the UI to the real name.
ALLOWED_HOSTS = ['*']

CSRF_TRUSTED_ORIGINS = []
for _h in dict.fromkeys([_hostname] + _extra_hosts):
    CSRF_TRUSTED_ORIGINS += [
        f'http://{_h}',
        f'https://{_h}',
        f'http://{_h}:{_http_port}',
        f'https://{_h}:{_https_port}',
    ]
USE_X_FORWARDED_PORT = True

# The session and CSRF cookies carry the Secure flag by default, so browsers
# only send them over https and a plain-http login fails with "CSRF cookie not
# set". ASCENDER_HTTP_MODE=insecure serves the UI over http (nginx stops
# redirecting) and needs the flag off.
if os.environ.get('ASCENDER_HTTP_MODE', 'redirect').strip().lower() == 'insecure':
    SESSION_COOKIE_SECURE = False
    CSRF_COOKIE_SECURE = False

DATABASES = {
    'default': {
        'ATOMIC_REQUESTS': True,
        'ENGINE': 'awx.main.db.profiled_pg',
        'NAME': os.environ.get('DATABASE_NAME', 'ascender'),
        'USER': os.environ.get('DATABASE_USER', 'ascender'),
        'PASSWORD': os.environ['DATABASE_PASSWORD'],
        'HOST': os.environ.get('DATABASE_HOST', 'postgres'),
        'PORT': os.environ.get('DATABASE_PORT', '5432'),
        'OPTIONS': {
            'sslmode': os.environ.get('DATABASE_SSLMODE', 'prefer'),
        },
    }
}

# valkey listens only on this unix socket (see config/valkey.conf), shared with
# the Ascender containers through the valkey_socket volume. The image defaults
# (ascender/settings/defaults.py) already point the broker (BROKER_URL), the cache
# (awx.main.cache.AWXValkeyCache) and the channel layer (channels_valkey) at
# unix:///var/run/valkey/valkey.sock, so nothing is overridden here. Do not copy
# upstream AWX's ansible_base / channels_redis backends into this file: the
# image ships neither package and every ascender-manage call fails at startup.

# The web and task containers share one hostname, so the task's websocket
# relay skips the local web node and daphne reads job events straight from
# valkey. Should a web node ever run under another hostname, the relay dials
# its nginx here: the https port, because in ASCENDER_HTTP_MODE=redirect the
# plain-http port only answers 301 and a websocket handshake cannot follow it.
BROADCAST_WEBSOCKET_SECRET = os.environ['BROADCAST_WEBSOCKET_SECRET']
BROADCAST_WEBSOCKET_PORT = 8053
BROADCAST_WEBSOCKET_PROTOCOL = 'https'
BROADCAST_WEBSOCKET_VERIFY_CERT = False

# Not Kubernetes: jobs run on the hybrid node (in podman, inside the receptor
# sidecar), never as container-group pods.
IS_K8S = False
AWX_AUTO_DEPROVISION_INSTANCES = False

# The receptor control socket path is not a setting: the task container reads
# it from the control-service entry of /etc/receptor/receptor.conf, which is
# mounted into it, and reaches the socket through the shared receptor volume.
RECEPTOR_LOG_LEVEL = os.environ.get('RECEPTOR_LOG_LEVEL', 'info')

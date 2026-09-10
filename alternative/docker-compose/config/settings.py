# Ascender settings for the Docker Compose deployment.
#
# Loaded by awx/settings/production.py after the defaults. Everything
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

# nginx in the web container is the only thing that can reach uwsgi.
ALLOWED_HOSTS = ['*']

_hostname = os.environ.get('ASCENDER_HOSTNAME', 'localhost')
_http_port = os.environ.get('ASCENDER_HTTP_PORT', '80')
_https_port = os.environ.get('ASCENDER_HTTPS_PORT', '443')
CSRF_TRUSTED_ORIGINS = [
    f'http://{_hostname}',
    f'https://{_hostname}',
    f'http://{_hostname}:{_http_port}',
    f'https://{_hostname}:{_https_port}',
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
# the Ascender containers through the valkey_socket volume. The defaults point at
# /var/run/redis/redis.sock, so the broker, cache and channel layer must be
# repointed here or they cannot connect.
_VALKEY_SOCKET = 'unix:///var/run/valkey/valkey.sock'
BROKER_URL = _VALKEY_SOCKET
CACHES = {
    'default': {
        'BACKEND': 'ansible_base.lib.cache.redis_cache.DABRedisCache',
        'LOCATION': f'{_VALKEY_SOCKET}?db=1',
    }
}
CHANNEL_LAYERS = {
    'default': {
        'BACKEND': 'channels_redis.core.RedisChannelLayer',
        'CONFIG': {'hosts': [_VALKEY_SOCKET], 'capacity': 10000, 'group_expiry': 157784760},
    }
}

# The task container's websocket relay connects to each web node's nginx over
# the compose network, plain http on the internal port.
BROADCAST_WEBSOCKET_SECRET = os.environ['BROADCAST_WEBSOCKET_SECRET']
BROADCAST_WEBSOCKET_PORT = 8052
BROADCAST_WEBSOCKET_PROTOCOL = 'http'
BROADCAST_WEBSOCKET_VERIFY_CERT = False

# Not Kubernetes: jobs run on the hybrid node (in podman, inside the receptor
# sidecar), never as container-group pods.
IS_K8S = False
AWX_AUTO_DEPROVISION_INSTANCES = False

# Where the receptor sidecar keeps its control socket; shared with the task
# container through the receptor_socket volume (see /etc/receptor/receptor.conf).
RECEPTOR_LOG_LEVEL = os.environ.get('RECEPTOR_LOG_LEVEL', 'info')

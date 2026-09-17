#!/usr/bin/env bash
set -e

uid="$(id -u)"
if [ "${uid}" -ge 500 ] && ! getent passwd "${uid}" >/dev/null; then
    echo "awx:x:${uid}:$(id -g):,,,:/var/lib/ascender:/bin/bash" >> /etc/passwd
fi

# Rootless podman keeps its runtime state (runroot, cached boot id, locks)
# under XDG_RUNTIME_DIR, falling back to /tmp/storage-run-<uid>. /tmp here is
# the job data volume shared with the task container, and it survives reboots;
# podman then refuses to start ("current system boot ID differs from cached
# boot ID; an unhandled reboot has occurred"). Two measures:
#  1. XDG_RUNTIME_DIR points at /run/user/<uid>, a tmpfs the container runtime
#     mounts fresh on every start. Podman records the runroot in its database
#     on first use, so this takes effect on new storage volumes.
#  2. Any /tmp/storage-run-<uid> from an existing installation is removed on
#     start. It only holds runtime state, and a missing runroot is exactly
#     what podman expects to find after a reboot.
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/${uid}}"
mkdir -p "${XDG_RUNTIME_DIR}" 2>/dev/null || true
rm -rf "/tmp/storage-run-${uid}"

# Required once per storage volume for rootless podman to set up its user
# namespace state; harmless when already done.
podman system migrate >/dev/null 2>&1 || true

exec receptor --config /etc/receptor/receptor.conf

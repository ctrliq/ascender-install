#!/bin/bash
# Runs once as root before anything else: makes the shared volumes writable by
# the unprivileged service containers (uid 1000, gid 0). Fresh named volumes
# mounted on paths the image does not ship are created root-owned 0755.
set -euo pipefail

for dir in \
    /var/lib/ascender/projects \
    /var/run/ascender-receptor \
    /var/run/ascender-rsyslog \
    /var/lib/ascender/.local/share/containers \
    /var/lib/ascender/.local/share/containers/storage ; do
    mkdir -p "$dir"
    chgrp 0 "$dir"
    chmod 2775 "$dir"
done

# Job private data dirs live here; keep the usual sticky world-writable /tmp.
chmod 1777 /tmp

echo "init: shared volumes ready"

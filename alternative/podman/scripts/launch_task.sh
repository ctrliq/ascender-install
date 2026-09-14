#!/usr/bin/env bash
# Task container entrypoint. Replaces the image's launch_awx_task.sh, whose
# bare `provision_instance` call is the Kubernetes form (control node plus a
# container group). Here the node is a hybrid instance: the dispatcher runs in
# this container and hands jobs to the receptor sidecar over the shared socket.

if [ "$(id -u)" -ge 500 ]; then
    echo "awx:x:$(id -u):$(id -g):,,,:/var/lib/awx:/bin/bash" >> /etc/passwd
fi

set -e

wait-for-migrations

mkdir -p /var/lib/awx/job_status

ascender-manage provision_instance --hostname="$(hostname)" --node_type=hybrid
ascender-manage register_queue --queuename=controlplane --instance_percent=100
ascender-manage register_queue --queuename=default --instance_percent=100

exec supervisord -c /etc/supervisord_task.conf

# Execution sidecar for the Docker Compose deployment: the published Ascender
# image plus receptor and podman. This is what the awx-ee sidecar is to the
# Kubernetes pod, except that jobs here run in rootless podman containers
# (hybrid-node style) instead of container-group pods.
ARG ASCENDER_IMAGE=ghcr.io/ctrliq/ascender
ARG ASCENDER_VERSION=latest
ARG RECEPTOR_IMAGE=quay.io/ansible/receptor:v1.6.8

FROM ${RECEPTOR_IMAGE} AS receptor

FROM ${ASCENDER_IMAGE}:${ASCENDER_VERSION}

USER root

# rpm --restore puts back the setuid bits on newuidmap/newgidmap that rootless
# podman needs; container builds tend to lose them. Only the restore is optional;
# a failed package install must fail the build.
RUN dnf -y install podman crun fuse-overlayfs slirp4netns shadow-utils && \
    { rpm --restore shadow-utils 2>/dev/null || true; } && \
    dnf -y clean all

COPY --from=receptor /usr/bin/receptor /usr/bin/receptor

# Fuse storage for nested podman, same tweaks as the development image. The
# sed relies on the stock storage.conf layout (an uncommented, two-line
# additionalimagestores array); the parse afterwards fails the build, instead
# of the first job, if a containers-common update ever changes that.
RUN sed -i -e 's|^#mount_program|mount_program|g' \
           -e '/additionalimage.*/a "/var/lib/shared",' \
           -e 's|^mountopt[[:space:]]*=.*$|mountopt = "nodev,fsync=0"|g' \
           /etc/containers/storage.conf && \
    /var/lib/ascender/venv/ascender/bin/python3 -c "import tomllib; \
o = tomllib.load(open('/etc/containers/storage.conf', 'rb'))['storage']['options']; \
assert o['additionalimagestores'] == ['/var/lib/shared'], o.get('additionalimagestores'); \
assert o['overlay']['mount_program'] == '/usr/bin/fuse-overlayfs', o['overlay'].get('mount_program'); \
assert o['overlay']['mountopt'] == 'nodev,fsync=0', o['overlay'].get('mountopt'); \
print('storage.conf ok:', o['additionalimagestores'], o['overlay']['mount_program'], o['overlay']['mountopt'])" && \
    mkdir -p /etc/containers/registries.conf.d && \
    echo 'unqualified-search-registries = []' > /etc/containers/registries.conf.d/force-fully-qualified-images.conf

COPY containers.conf /etc/containers/containers.conf
COPY launch_awx_receptor.sh /usr/bin/launch_awx_receptor.sh

# Rootless podman needs a named user with subordinate id ranges.
RUN echo "awx:x:1000:0:Ascender:/var/lib/ascender:/bin/bash" >> /etc/passwd && \
    echo "awx:100000:65536" > /etc/subuid && \
    echo "awx:100000:65536" > /etc/subgid && \
    for dir in /var/lib/ascender/projects /var/run/ascender-receptor \
               /var/lib/ascender/.local/share/containers/storage \
               /var/lib/shared/overlay-images /var/lib/shared/overlay-layers \
               /var/lib/shared/vfs-images /var/lib/shared/vfs-layers ; do \
        mkdir -p "$dir"; chgrp 0 "$dir"; chmod 2775 "$dir"; \
    done && \
    for f in /var/lib/shared/overlay-images/images.lock /var/lib/shared/overlay-layers/layers.lock \
             /var/lib/shared/vfs-images/images.lock /var/lib/shared/vfs-layers/layers.lock ; do \
        touch "$f"; chmod g+rw "$f"; \
    done

ENV _CONTAINERS_USERNS_CONFIGURED=""
# ansible-runner comes from the Ascender virtualenv.
ENV PATH="/var/lib/ascender/venv/ascender/bin:${PATH}"
ENV HOME="/var/lib/ascender"

USER 1000
EXPOSE 27199

ENTRYPOINT ["dumb-init", "--"]
CMD ["launch_awx_receptor.sh"]

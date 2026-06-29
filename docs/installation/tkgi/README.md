# Ascender Installation on VMware Tanzu Kubernetes Grid Integrated Edition (TKGI)

The Ascender installer supports a first-pass TKGI platform path for installing Ascender onto an
existing TKGI cluster. This path follows the same upstream installer flow as the other Kubernetes
platforms and does not provision a TKGI cluster for you.

## General Prerequisites

If you have not done so already, follow the general prerequisites in the
[Ascender-Install main README](../../../README.md#general-prerequisites).

## TKGI-specific Prerequisites

- These instructions assume you already have a reachable TKGI cluster.
- You need a working `kubectl` installation on the machine running the installer.
- You need a valid kubeconfig for the target TKGI cluster.
- You need cluster permissions that allow namespace creation plus the creation of the resources
  required by the AWX Operator and Ascender manifests.
- You need at least one usable StorageClass for PostgreSQL persistence.
- You need a working ingress controller. TKGI environments commonly use Contour, and the installer
  will try to detect that automatically.

## Install Instructions

### Prepare the inventory and config files

Use the TKGI example files in this directory as your starting point:

- [tkgi.inventory](./tkgi.inventory)
- [tkgi.custom.config.yml](./tkgi.custom.config.yml)

Copy them to the repository root as needed:

```text
$ cp docs/installation/tkgi/tkgi.inventory inventory
$ cp docs/installation/tkgi/tkgi.custom.config.yml custom.config.yml
```

### Required TKGI settings

Update your `custom.config.yml` with the values for your environment:

- `k8s_platform: tkgi`
- `kube_install: false`
- `ASCENDER_HOSTNAME`
- `ASCENDER_NAMESPACE`
- `ASCENDER_ADMIN_PASSWORD`

You should also review these TKGI-specific settings:

- `TKGI_KUBECONFIG_PATH`: optional kubeconfig path if you are not using `~/.kube/config`
- `TKGI_K8S_CONTEXT`: optional kubeconfig context if you do not want to use the current context
- `TKGI_INGRESS_CLASS_NAME`: optional explicit ingress class name if auto-detection is not enough
- `POSTGRES_STORAGE_CLASS`: optional explicit storage class if you do not want to rely on the
  cluster default

### Optional external PostgreSQL settings

If you are using an existing PostgreSQL instance instead of the operator-managed in-cluster
PostgreSQL, also set these values in `custom.config.yml`:

- `ASCENDER_PGSQL_HOST`
- `ASCENDER_PGSQL_PORT`
- `ASCENDER_PGSQL_USER`
- `ASCENDER_PGSQL_PWD`
- `ASCENDER_PGSQL_DB`

For TKGI, `ASCENDER_PGSQL_HOST` must be resolvable and reachable from the Ascender pods, not just
from the workstation running the installer. If your external DNS name does not resolve from the
cluster, use a cluster-reachable address instead.

If you plan to use strict certificate hostname validation later, prefer a DNS name that resolves
from the cluster over a bare IP address.

### Validate cluster access

Before running the installer, confirm that the kubeconfig and context you plan to use can reach the
TKGI cluster:

```text
$ kubectl config get-contexts
$ kubectl config current-context
$ kubectl get nodes
```

### Run the setup script

Run the installer from the repository root:

```text
$ sudo ./setup.sh
```

The TKGI path validates the kubeconfig, cluster connectivity, Kubernetes version, ingress
controller, storage class availability, namespace access, and the RBAC needed for installation.

When external PostgreSQL settings are provided, the TKGI install path treats PostgreSQL as
installer-managed external infrastructure and does not wait for or patch an in-cluster Postgres
StatefulSet.

### Accessing Ascender

After the installation completes, access Ascender at the hostname configured in
`ASCENDER_HOSTNAME`.

If you are relying on `/etc/hosts` instead of external DNS, point `ASCENDER_HOSTNAME` and
`LEDGER_HOSTNAME` at the ingress address used by your TKGI environment.

For HTTPS installs, set `k8s_lb_protocol: https` and provide `tls_crt_path` and `tls_key_path` to
local certificate files on the installing machine. The validated TKGI path uses a fullchain
certificate for `tls_crt_path`.


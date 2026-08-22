# Ascender Installer

[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](./LICENSE.md)
[![Ascender](https://img.shields.io/badge/ascender-25.5.1-blue.svg)](https://github.com/ctrliq/ascender)
[![Platforms](https://img.shields.io/badge/platforms-8-blue.svg)](./docs/README.md)

An Ansible-driven installer that deploys [Ascender](https://github.com/ctrliq/ascender), [Ledger](https://github.com/ctrliq/ascender-ledger), and the [Galaxy Proxy](https://github.com/ctrliq/ascender-galaxy-proxy) onto Kubernetes. You do not need an existing cluster or Kubernetes expertise. For every supported platform the installer can provision the cluster on your behalf and write the access file to `~/.kube/config`.

## Requirements

- Control machine on Enterprise Linux 8 or 9, or Ubuntu/Debian 24, `x86_64` only
  - Enterprise Linux covers Rocky, RHEL, Alma, CentOS, and Fedora
  - EL 9 is required when `k8s_platform` is `aks`, `gke`, or `eks`
  - Ubuntu and Debian are not supported for `aks`, `gke`, or `eks`
- `git`: `sudo dnf install git -y` or `sudo apt-get install git -y`
- `ansible-core`: installed by `setup.sh` when missing
- SSH access to `ascender_host` as a user that can `become` root
- An existing `~/.kube/config`, or `kube_install: true` to build the cluster

## Installation

Clone the repository onto the control machine:

```bash
git clone https://github.com/ctrliq/ascender-install.git
cd ascender-install
```

## Using the installer

Generate a configuration file, point the inventory at your target host, then run the installer:

```bash
./config_vars.sh    # interactive; writes custom.config.yml (gitignored)
./setup.sh
```

`setup.sh` reads `custom.config.yml` when present and falls back to `default.config.yml`. To change an existing deployment (switching to SSL, adding Ledger, or moving to a new Ascender version), edit the config and rerun `setup.sh`.

Platform-by-platform walkthroughs, including config and inventory templates for each, are in [docs/README.md](./docs/README.md).

## Configuration

Two files drive every install, both at the repository root:

| File | Purpose |
| ---- | ------- |
| [`default.config.yml`](./default.config.yml) | Every available variable, documented inline by comment |
| [`inventory`](./inventory) | Defines `ascender_host` with `ansible_host`, `ansible_user`, and `ansible_port` |

The variables referenced most often:

- `k8s_platform`: `k3s`, `eks`, `aks`, `gke`, `rke2`, `dkp`, `ocp`, or `tkgi`
- `kube_install`: whether the installer provisions the cluster itself
- `k8s_offline`: use bundled images instead of pulling from the internet
- `k8s_lb_protocol`: `http`, or `https` with certificate and key paths
- `LEDGER_INSTALL`: whether Ledger is deployed alongside Ascender
- `PROXY_INSTALL`: whether the Galaxy Proxy is deployed
- `tmp_dir`: where install artifacts are staged on the control machine

### Offline installation

On k3s, RKE2, and DKP the installer can run without outside internet access, using either the bundled container images or images you have mirrored into an internal registry. A bundled Ascender Operator is included for the same purpose. See the guide for your platform in [docs/installation](./docs/installation).

## Included content

- **8 platform installers**: k3s, EKS, AKS, GKE, RKE2, DKP, OCP, TKGI
- **12 roles**: cluster setup, Ascender, Ledger, Galaxy Proxy, backup, restore, migration
- **AWX migration**: move an existing AWX deployment onto Ascender in place
- **Troubleshooting guides**: DNS, kubeconfig, API startup, namespace deletion

## The Ascender ecosystem

| Repository | Description |
| ---------- | ----------- |
| [ascender](https://github.com/ctrliq/ascender) | The platform itself: web UI, REST API, and task engine |
| [ascender-install](https://github.com/ctrliq/ascender-install) | Installer for Ascender and Ledger, with Galaxy Proxy support |
| [ascender-k8s-install](https://github.com/ctrliq/ascender-k8s-install) | Kubernetes installer for Ascender, Ledger, and React |
| [ascender-pro-install](https://github.com/ctrliq/ascender-pro-install) | Enhanced installer adding Reaqt, Registry, and Galaxy Proxy |
| [ascender-operator](https://github.com/ctrliq/ascender-operator) | Kubernetes operator that deploys and manages Ascender |
| [ascender-ee](https://github.com/ctrliq/ascender-ee) | Default execution environment image for Ascender jobs |
| [ascender-kit](https://github.com/ctrliq/ascender-kit) | The `ascender` command line client and Python API library |
| [ascender-collection](https://github.com/ctrliq/ascender-collection) | The `ctrliq.ascender` Ansible collection for a controller |
| [ascender-ledger](https://github.com/ctrliq/ascender-ledger) | Reporting tool for host facts and playbook changes |
| [ascender-galaxy-proxy](https://github.com/ctrliq/ascender-galaxy-proxy) | Caching proxy for Ansible Galaxy collection downloads |
| [ascender-playbooks](https://github.com/ctrliq/ascender-playbooks) | Example playbooks for use with Ascender |
## Contributing

- See [CONTRIBUTING.md](./CONTRIBUTING.md) for development setup, testing, and pull requests.
- Report bugs and platform requests via [GitHub Issues](https://github.com/ctrliq/ascender-install/issues).
- For security vulnerabilities, follow [SECURITY.md](./SECURITY.md) rather than opening an issue.
- Join the [Ascender forum](https://forum.ascender-automation.org) to discuss development topics.

## License

Licensed under the **Apache License 2.0**. See [LICENSE.md](./LICENSE.md) and [COPYRIGHT.md](./COPYRIGHT.md).

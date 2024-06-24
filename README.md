The Ascender installer is a script that makes for relatively easy
install of Ascender Automation Platform on Kubernetes platforms of
multiple flavors. The installer is being expanded to new Kubernetes
platforms as users/contributors allow, and if you have specific needs
for a platform not yet supported, please submit an issue to this
Github repository.

While Ascender installs on Kubernetes, you don't need to be a guru in
Kubernetes, or even have a Kubernetes cluster up and working!  For
each specified Kubernetes platform, the installer will set up a
Kubernetes cluster on your behalf, and set up the cluster access file
at its default location of `~/.kube/config`.  Windows and Network
admins rejoice!

## Table of Contents

- [General Prerequisites](#general-prerequisites)
- [Optional Components](#optional-components)
- [Configuration File](#configuration-file)
- [Instructions by Kubernetes Platform](#installation-instructions-by-kubernetes-platform)
- [Uninstall](#uninstall)
- [Contributing](#contributing)
- [Reporting Issues](#reporting-issues)

## General Prerequisites

- On the local server (on which the installer script will run), you
  will need the following prerequisites met:
  - The The OS family must be Rocky, Fedora or CentOS and the major version must be 8 or 9.
  - The [ansible inventory file](inventory) file needs to be changed
    to:
    - `ascender_host`
      - `ansible_host` needs to be a set to a server that hosts the [kube-apiserver](https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/) kubernetes cluster access or that you want to eventually host the kube-apiserver.
      - `ansible_user` needs to set to a user that can escalate to
        root with `become` (if different than your logged in user)
      - A port needs to be open for SSH access (typically TCP port
        22). If you choose to have SSH accept connections on a
        different port, you need to specify this port with the
        built-in host variable `ansible_port`.
  - [ansible-core][] will have to be installed, but the setup script
    will install it if it is not already there.
- On `ascender_host`, the following is required:
  - If a Kubernetes cluster is already up, you will need the
    [kubeconfig][] file, located at `~/.kube/config`. The server IP
    address in the [cluster][] section of this file will determine the
    cluster where Ascender will be installed. This cluster must be up
    and running at the time of install.
  - If a kubernetes cluster is to be set up, then the installer script it will create the
    kubeconfig for you automatically.

[ansible-core]: https://github.com/ansible/ansible
[kubeconfig]: https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/
[cluster]: https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/#context

## Optional Components

- An external PostgreSQL server that the Ascender application can
  access. If not specified, the AWX Operator responsible for
  installing Ascender will create a managed PostgreSQL server.

### Offline Installation

For certain Kubernetes platforms (such as k3s, kubeadm, rke2), the Ascender installer supports installation for clusters that do not have outside internet access. In these cases, you can either use:
  - An included bundle of container images (this is the case for k3s)
  - Move the Ascender and Ledger container images into an internal container registry for the installer to consume (this is the case for rke2 and kubeadm)

A bundled AWX operator is also included for the purposes of offline install.

For more detailed instructions, see the section on the corresponding Kubernetes platform.

## Configuration File and Inventory

There is a [default configuration file](default.config.yml) that will
hold all of the options required to set up your installation
properly. While this file is comprehensive, you can find more
platform-specific config file templates in the respective Kubernetes
platform install instructions directory.

Additionally, there is an executable script in this directory called [config_vars.sh](./config_vars.sh) that will generate a config file based on user input, named `custom.config.yml`. `custon.config.yml` is listed in .gitignore, and as such is the suggested/preferred method of setting your install variables.

The Ascender Install script also uses the Ansible inventory file, [inventory](./inventory), located in the top level directory of this repository. 

For both the config file and inventory files, you will find templates for each Kubernetes distribution in its corresponding directory in [docs](./docs/). You can use these templates as guides for how `custom.config.ml` and `inventory` should look for your particular install.

The [**Uninstall**](#uninstall) section of this tutorial references
two of the variables that need to be set:

- `k8s_platform`: The Kubernetes platform Ascender is being installed
  on. This could be K3s, EKS, GKE, or AKS.
- `tmp_dir`: The directory on the server running the install script,
  where temporary artifacts will be stored.

All of the variables and flags in these files have their
description/proper usage directly present in the comments.

## Installation Instructions by Kubernetes Platform

- [K3s](docs/k3s/README.md)
- [Elastic Kubernetes Service](docs/eks/README.md)
- [Azure Kubernetes Service](docs/aks/README.md)
- [RKE Government](docs/rke2/README.md)

## Adding Components/Configuration Changes

Consider a situation where you have already installed Ascender, and wish to change one or more of the attributes of how it is deployed. Some of these changes may include:

- Moving from non-SSL to an SSL connection 
- Installing Ledger when you may have only installed Ascender first
- Changing the version of Ascender and or Ledger that is installed

This can be accomplished by either running `config_vars.sh` again, or editing an existing `custom.config.yml`, in each case, changing the desired install variables. You can then rerun `setup.sh`.`

## Uninstall

After running `setup.sh`, `tmp_dir` will contain timestamped kubernetes manifests for:

- `ascender-deployment-{{ k8s_platform }}.yml`
- `ledger-{{ k8s_platform }}.yml` (if you installed Ledger)
- `kustomization.yml`

Remove the timestamp from the filename and then run the following
commands from within `tmp_dir``:

- `$ kubectl delete -f ascender-deployment-{{ k8s_platform }}.yml`
- `$ kubectl delete -f ledger-{{ k8s_platform }}.yml`
- `$ kubectl delete -k .`

Running the Ascender deletion will remove all related deployments and
statefulsets, however, persistent volumes and secrets will remain. To
enforce secrets also getting removed, you can use
`ascender_garbage_collect_secrets: true` in the `default.config.yml`
file.

## Reporting Issues

If you're experiencing a problem that you feel is a bug in the
installer or have ideas for improving the installer, we encourage you
to open a Github issue and share your feedback.

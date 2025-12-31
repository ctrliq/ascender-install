# Ascender Installation and Updating on K3s

The Ascender installer is a script that makes it relatively easy to install the Ascender Automation
Platform on Kubernetes platforms of multiple flavors. The installer is being expanded to new
Kubernetes platforms as users/contributors allow. If you have specific needs for a platform not yet
supported, please submit an issue to this Github repository.

## Table of Contents

- [General Prerequisites](#general-prerequisites)
- [K3s-specific Prerequisites](#k3s-specific-prerequisites)
- [Install Instructions](#install-instructions)
  - [Offline Installation](#offline-installation)
  - [Offline Ascender Upgrade](#offline-ascender-upgrade)

## General Prerequisites

If you have not done so already, be sure to follow the general prerequisites found in the
[Ascender-Install main README](../../README.md#general-prerequisites).

## K3s-specific Prerequisites

- NOTE: The K3s install of Ascender is not yet meant for production, but rather as a sandbox on
  which to try Ascender. As such, the Installer expects a single-node K3s cluster which will act as
  both master and worker node.
- Operating System
  - If the OS family is Enterprise Linux (Rocky, Fedora, Alma, RHEL, or CentOS) then the major version must be 8 or 9.
  - If the OS family is Ubuntu/Debian then the major version must be 24
- Minimal System Requirements for the k3s server:
  - CPUs: 2
  - Memory: 8GB (if installing both Ascender and Ledger)
  - 20GB of free disk (for Ascender and Ledger Volumes)
- These instructions accommodate an existing K3s cluster, or will set up a new one on your behalf if
  necessary. This behavior is determined by the variable `kube_install`
  - If `kube_install` is set to true, the installer will set up K3s on the `ascender_host`in the
    inventory file. (`ascender_host` can be localhost)
  - If `kube_install` is set to false, the installer will not perform a K3s install
- SSL Certificate and Key
  - To enable HTTPS on your website, you need to provide the Ascender installer with an SSL
    Certificate file, and a Private Key file. While these can be self-signed certificates, it is
    a good practice to use a trusted certificate, issued by a Certificate Authority. A good way to
    generate a trusted Certificate for the purpose of sandboxing, is to use the free Certificate
    Authority, [Let's Encrypt](https://letsencrypt.org/getting-started/).
  - Once you have a Certificate and Private Key file, make sure they are present on the Ascender
    installing server, and specify their locations in the default config file, with the variables
    `tls_crt_path`and `tls_key_path`, respectively. The installer will parse these files for their
    content, and use the content to create a Kubernetes TLS Secret for HTTPS enablement.

## Install and Upgrade Instructions

### Obtain the sources

You can use the `git` command to clone the ascender-install repository or you can download the
zipped archive. (Install `git` with `sudo yum -y install git` if it is not already present.)

```text
$ git clone https://github.com/ctrliq/ascender-install.git
```

This will create a directory named `ascender-install` in your present working directory (PWD).

We will refer to this directory as the \<ASCENDER-INSTALL-SOURCE\> in the remainder of this
instructions.

### Set the configuration variables for a K3s Install

Change directories into the newly created `ascender-install` and run the `config_vars.sh` script.

```text
$ cd ascender-install

$ ./config_vars.sh
```

The script will take you through a series of questions, that will populate the variables file
requires to install Ascender. This variables file will be located at `./custom.config.yml`:

You can edit this file manually if you want to change variable before (re)installing Ascender.

Examples of Configuration files for traditional installation (where resources such as container
images are retrieved from online) and offline installation can be found in this directory as:

- [k3s.default.config.yml](./k3s.default.config.yml)
- [k3s.offline.default.config.yml](./k3s.offline.default.config.yml)

### Run the setup script

Run `./setup.sh` from top level directory in this repository. The setup must run as a user with
Administrative or `sudo` privileges. To begin the setup process, type:

```text
$ sudo ./setup.sh
```

Once the setup is completed successfully, you should see a final output similar to:

```text
[snip...]
PLAY RECAP *************************************************************************************************************************
ascender_host              : ok=14   changed=6    unreachable=0    failed=0    skipped=2    rescued=0    ignored=0
localhost                  : ok=72   changed=27   unreachable=0    failed=0    skipped=4    rescued=0    ignored=0

ASCENDER SUCCESSFULLY SETUP
```

### Offline Installation

In order to perform an offline installation of Ascender on k3s, you must complete the following
steps before running the installation script:

- Run the `playbooks/create_bundle.yml` playbook on a machine that has access to the internet.
- Copy the `offline` folder into your `ascender-install` folder on the machine you would like to
  install from.
- When setting the variables in your `config_vars.sh`, be sure to set `k8s_platform` to `k3s`, and
  `k8s_offline` to `true`. This will instruct the installer to use archived container images rather
  than using a container registry to install Ascender and Ledger.

By doing these steps, the Ascender installer will copy the archived images to the k3s server, import
them into k3s to allow their usage in Pods, and set the `imagePullPolicy` for all k3s images to
`Never`, which will prevent the cluster from attempting to access the internet to retrieve images.

#### Offline Ascender Upgrade

In order to upgrade an offline installation of Ascender on k3s, the process is similar to that of
installation with one key change:

- RE-RUN the `playbooks/create_bundle.yml` playbook on a machine that has access to the internet,
  using the new release/tag of Ascender you wish to move to, indicated by the `ASCENDER_VERSION`
  variable in the `custom.config.yml` or `default.config.yml` file.
  - The list of all releases can be found here: [Ascender
    Releases](https://github.com/ctrliq/ascender/releases).
- Copy the `offline` folder into your `ascender-install` folder on the machine you would like to
  install from.
- When setting the variables in your `config_vars.sh`, be sure to set `k8s_platform` to `k3s`, and
  `k8s_offline` to `true`. This will instruct the installer to use archived container images rather
  than to a container registry to install Ascender and Ledger.

### Connecting to Ascender Web UI

This is a quick and temporary work-around for connecting to your new Ascender installation. By
default the Ascender web service is accessible over its internal CLUSTER IP address. You can use SSH
forwarding from any remote host to connect to the internal CLUSTER IP. Note that it is important to
connect as root to allow privileged port forwarding.

For the example here, you'll use the kubectl utility to query for the CLUSTER IP and store the value
in a variable named "ASCENDER_WEB_INTERNAL_IP".

While still logged on to the server running Ascender (as root), type:

```text
$ export ASCENDER_WEB_INTERNAL_IP=$(kubectl -n ascender get service/ascender-app-service -o jsonpath='{.spec.clusterIP}')
```

To see the value of ASCENDER_WEB_INTERNAL_IP type:

```text
$ echo $ASCENDER_WEB_INTERNAL_IP
```

Now, to use SSH forwarding to connect to your Ascender installation from any workstation you can use
a command like:

```text
$ ssh -L 80:<ASCENDER_WEB_INTERNAL_IP>:80 user@<ASCENDER_SERVER_IP>
```

For example, if your the value of $ASCENDER_WEB_INTERNAL_IP is `10.43.9.224`, and the
ASCENDER_SERVER_IP is `1.2.3.4`, the full command to connect as the root user will be:

```text
$ ssh -L 80:10.43.9.224:80 root@1.2.3.4
```

After port forwarding, you can visit/browse/administer your Ascender instance by pointing your
workstation web browser to:

[https://localhost](https://localhost)

The default username is "admin" and the corresponding password is stored in
`<ASCENDER-INSTALL-SOURCE>/default.config.yml` under the `ASCENDER_ADMIN_PASSWORD` variable.

### Uninstall

After running `setup.sh`, `tmp_dir` (by default `{{ playbook_dir}}/../ascender_install_artifacts`)
will contain timestamped kubernetes manifests for:

- `ascender-deployment-{{ k8s_platform }}.yml`
- `ledger-{{ k8s_platform }}.yml` (if you installed Ledger)
- `kustomization.yml`

Remove the timestamp from the filename and then run the following
commands from within `tmp_dir`:

```text
$ kubectl delete -f ascender-deployment-{{ k8s_platform }}.yml

$ kubectl delete -f ledger-{{ k8s_platform }}.yml # optional if you have installed ledger

$ kubectl delete -k .
```

Running the Ascender deletion steps will remove all related deployments and stateful sets, however,
persistent volumes and secrets will remain. To enforce secrets also getting removed, you can use
`ascender_garbage_collect_secrets: true` in the `default.config.yml` file.

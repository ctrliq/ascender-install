# Ascender Installation and Updating on OpenShift Container Platform (OCP)

The Ascender installer is a script that makes it relatively easy to install the Ascender Automation
Platform on Kubernetes platforms of multiple flavors. The installer is being expanded to new
Kubernetes platforms as users/contributors allow. If you have specific needs for a platform not yet
supported, please submit an issue to this Github repository.

## Table of Contents

- [General Prerequisites](#general-prerequisites)
- [OCP-specific Prerequisites](#ocp-specific-prerequisites)
- [Install Instructions](#install-instructions)

## General Prerequisites

If you have not done so already, be sure to follow the general prerequisites found in the
[Ascender-Install main README](../../README.md#general-prerequisites).

## OCP-specific Prerequisites

- Operating System Requirements:
  - The installer can run from any system with network access to your OCP cluster
  - The OS Family must be the same as Rocky Linux (indicated by the `ansible_os_family` ansible
    fact), and the major version must be 8 or 9.
    - While this includes other Enterprise Linux distributions, the installer is primarily tested
      with Rocky Linux
- Minimal System Requirements for the OCP cluster:
  - CPUs: 2
  - Memory: 8GB (if installing both Ascender and Ledger)
  - 20GB of free disk (for Ascender and Ledger Volumes)
- These instructions require an existing OCP cluster with proper authentication configured
  - The installer will not set up OCP for you - you must have an existing, accessible cluster
  - Ensure you have administrative access to the cluster via `oc` or `kubectl` commands
  - The `kube_install` variable should be set to `false` for OCP installations
- SSL Certificate and TLS Configuration
  - OpenShift Container Platform handles SSL/TLS termination through Routes
  - If you set `k8s_lb_protocol` to `http`, the installer will configure OCP Routes to use edge
    termination, where OpenShift handles the SSL certificate automatically.  Typically, you will need to specify your ASCENDER_HOSTNAME to something like ascender.apps.mycluster.mydomain.com
  - If you set `k8s_lb_protocol` to `https`, you need to provide an SSL
    Certificate file and a Private Key file. While these can be self-signed certificates, it is
    a good practice to use a trusted certificate, issued by a Certificate Authority.
  - Once you have a Certificate and Private Key file, make sure they are present on the Ascender
    installing server, and specify their locations in the config file with the variables
    `tls_crt_path` and `tls_key_path`, respectively. The installer will parse these files for their
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

### Set the configuration variables for an OCP Install

Change directories into the newly created `ascender-install` and run the `config_vars.sh` script.

```text
$ cd ascender-install

$ ./config_vars.sh
```

The script will take you through a series of questions, that will populate the variables file
required to install Ascender. This variables file will be located at `./custom.config.yml`.

You can edit this file manually if you want to change variables before (re)installing Ascender.

**Important:** When configuring for OCP:
- Set `k8s_platform` to `ocp`
- Set `kube_install` to `false` (the installer will not install OCP for you)
- Ensure your `kubeconfig` file is properly configured to access your OCP cluster

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
localhost                  : ok=72   changed=27   unreachable=0    failed=0    skipped=4    rescued=0    ignored=0

ASCENDER SUCCESSFULLY SETUP
```

### Connecting to Ascender Web UI

In OpenShift Container Platform, Ascender is accessed through OCP Routes using the hostnames you
specified during configuration.

You can access the Ascender web interface by navigating to the `ASCENDER_HOSTNAME` value you
configured in your `custom.config.yml` file. For example, if you set `ASCENDER_HOSTNAME` to
`ascender.example.com`, you would access Ascender at:

[https://ascender.example.com](https://ascender.example.com)

If you also installed Ledger, access it using the `LEDGER_HOSTNAME` value from your configuration.

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

Alternatively, you can delete the entire installation by removing the namespaces specified in your
configuration:

```text
$ kubectl delete namespace <ASCENDER_NAMESPACE>

$ kubectl delete namespace <LEDGER_NAMESPACE>  # optional if you have installed ledger
```

Replace `<ASCENDER_NAMESPACE>` and `<LEDGER_NAMESPACE>` with the values you configured (default is
typically `ascender` and `ledger`).



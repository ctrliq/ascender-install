
The Ascender installer is a script that makes for relatively easy install of Ascender Automation Platform on Kubernetes platforms of multiple flavors. The installer is being expanded to new Kubernetes platforms as users/contributors allow, and if you have specific needs for a platform not yet supported, please submit an issue to this Github repository.

# Table of Contents
- [General Prerequisites](#general-prerequisites)
- [Optional Components](#optional-components)
- [Configuration File](#configuration-file)
- [Instructions by Kubernetes Platform](#instructions-by-kubernetes-platform)
- [Contributing](#contributing)
- [Reporting Issues](#reporting-issues)


## General Prerequisites
- On the local server (on which the installer script will run), you will need the following prerequisites met:
  - The [ansible inventory file ](inventory) file needs to be changed to:
    - `ascender_host` and `ledger_host` 
      - `ansible_host` needs to be a set to a server that has kubernetes cluster access
      - `ansible_user` needs to set to a user that can escalate to root with `become`
      - A port needs to be open for SSH access (typically TCP port 22). If you choose to have SSH accept connections on a different port, you need to specify this port with the built-in host variable `ansible_port`.
  - [ansible-core](https://github.com/ansible/ansible) will have to be installed, but the setup script will install it if it is not already there.
- On `ascender_host` and `ledger_host`, the following is required:
  - A [kubeconfig](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/) file, located at `~/.kube/config`. The [current-context](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/#context) in this file will determine the cluster where Ascender will be installed. This cluster must be up and running at the time of install.

## Optional Components
- An external PostgreSQL server that the Ascender application can access. If not specified, the AWX Operator responsible for installing Ascender will create a managed PostgreSQL server.

## Configuration File
There is a [default configuration file](playbooks/default.config.yml) that will hold all of the options required to set up your installation properly. While this file is comprehensive, you can find more platform-specific config file templates in the respective Kubernetes platform install instructions directory.

The **Uninstall** section of this tutorial references two of the variables that need to be set:
- `k8s_platform`: The Kubernetes platform Ascender is being installed on. This could be K3s, EKS, GKE, or AKS.
- `tmp_dir`: The directory on the server running the install script, where temporary artifacts will be stored.



All of the variables and flags in these files have their description/proper usage directly present in the comments.

## Installation Instructions by Kubernetes Platform
- [K3s](ascender-install-instructions/k3s/README.md)

## Uninstall
After running `setup.sh`, `tmp_dir` will contain timestamped kubernetes manifests for:
- `ascender-deployment-{{ k8s_platform }}.yml`
- `ledger-{{ k8s_platform }}.yml` (if you installed Ledger)
- kustomization.yml. 

Remove the timestamp from the filename and then run the following commands from within `tmp_dir``:
- `$ kubectl delete -f ascender-deployment-{{ k8s_platform }}.yml`
- `$ kubectl delete -f ledger-{{ k8s_platform }}.yml`
- `$ kubectl delete -k .`

Running the Ascender deletion will remove all related deployments and statefulsets, however, persistent volumes and secrets will remain. To enforce secrets also getting removed, you can use `ascender_garbage_collect_secrets: true` in the `playbooks/default.config.yml` file.

## Contributing
It is recommended that all contributions be applied upstream first to AWX, to better support collaboration with the community.

## Reporting Issues
If you're experiencing a problem that you feel is a bug in Ascender or have ideas for improving Ascender, we encourage you to open a Github issue and share your feedback.
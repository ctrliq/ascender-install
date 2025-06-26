# Issue: Install Fails Due to Missing Kubeconfig on Target System

## Issue Summary

When running `setup.sh`, the following error is encountered during the `k8s_setup` Ansible role:

```shell
TASK [k8s_setup : Copy kubeconfig file from default location to the ~/.kube directory"]
fatal: [ascender_host]: FAILED! => {"changed": false, "msg": "the remote file does not exist, not transferring, ignored"}
```


### Root Cause

This error occurs because the variable `download_kubeconfig` is set to `true`, which tells the setup process to copy the Kubernetes `kubeconfig` file from the target system. However, the target system does **not** have a Kubernetes installation, so the file does not exist.

This typically happens when:

- The target system is a fresh install and Kubernetes (e.g., k3s) has not been installed yet.
- The variable `kube_install` was not set to `true` during initial setup.

## Resolution Steps

### 1. Ensure Kubernetes Is Installed on the Target System

If this is a new environment, Kubernetes has not yet been installed, and you are wanting to install k3s. Set the `kube_install` variable to `true` in your configuration and ensure `k8s_platform` is set to `k3s`.

For example:

```yaml
k8s_platform: k3s
kube_install: true
```

Then re-run setup.sh. This will trigger the installation of k3s, and the necessary kubeconfig will be generated on the target.

### 2. Alternatively, Disable Kubeconfig Download

If Kubernetes is installed elsewhere, or you don't need to copy the kubeconfig to the local system, set:

```yaml
download_kubeconfig: false
```

This will skip the step that tries to retrieve the kubeconfig from the target system.

## Notes

* This issue is common when running setup.sh against a brand-new host without any Kubernetes installation.
* Ensure that either kube_install is enabled or a valid kubeconfig exists before setting download_kubeconfig: true.
* The installer attempts to copy the config from /etc/rancher/k3s/k3s.yaml. If your config exists elsewhere, you may have to manually copy it over.
* The installer will copy the config to ~/.kube/config

## References

* [Ascender K3S Install Docs](https://github.com/ctrliq/ascender-install/blob/main/docs/k3s/README.md)

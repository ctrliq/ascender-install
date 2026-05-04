# Issue: Install Fails Due to Missing Kubeconfig on Target System

## Issue Summary

When running `setup.sh`, the following error is encountered during the `k8s_setup` Ansible role:

```shell
TASK [k8s_setup : Copy kubeconfig file from default location to the ~/.kube directory"]
fatal: [ascender_host]: FAILED! => {"changed": false, "msg": "the remote file does not exist, not transferring, ignored"}
```


### Root Cause

This error occurs because the target system does **not** have a Kubernetes installation, so the file does not exist.

This typically happens when:

- The target system is a fresh install and Kubernetes (e.g., k3s) has not been installed yet.

## Resolution Steps

### 1. Ensure Kubernetes Is Installed on the Target System

If this is a new environment, Kubernetes has not yet been installed, and you are wanting to install k3s. Use the ascender-k8s-installer to install the kubernetes cluster.


## Notes

* This issue is common when running setup.sh against a brand-new host without any Kubernetes installation.
* Ensure that valid kubeconfig exists.
* The installer attempts to copy the config from /etc/rancher/k3s/k3s.yaml. If your config exists elsewhere, you may have to manually copy it over.
* The installer will copy the config to ~/.kube/config

## References

* [Ascender K3S Install Docs](https://github.com/ctrliq/ascender-install/blob/main/docs/k3s/README.md)

# Upgrade Guide: Ascender

## Overview

Upgrading Ascender is a straightforward process that involves updating the container image version in your configuration and re-running the installation script. This guide walks you through the steps required to safely upgrade Ascender to a new release.

## Prerequisites

- You must already have a running Ascender deployment in a Kubernetes cluster.
- You should have your original `custom.config.yml` (or equivalent) used during the initial installation.

> ⚠️ **Important:** Always back up your current configuration and verify the health of your Ascender deployment before performing an upgrade.

## Steps to Upgrade

### 1. Modify Your Configuration File

Open your `custom.config.yml` file and verify or set the following values:

```yaml
kube_install: false
```

Since your Kubernetes cluster is already set up, you do **not** want to reinstall it.

```yaml
download_kubeconfig: false
```

You already have a working kubeconfig and don't need to re-download it.

```yaml
ASCENDER_VERSION: 25.3.2
```

Replace `25.3.2` with the version you want to upgrade to. The list of available versions is here: 

[Ascender Releases](https://github.com/ctrliq/ascender/releases)

```yaml
image_pull_policy: Always
```

This ensures the latest container image for the specified version is pulled from the registry, even if an older version is cached locally.

### 2. (Optional) Review for Breaking Changes

Check the release notes on the [Ascender Releases](https://github.com/ctrliq/ascender/releases) page for any breaking changes, upgrade steps, or configuration differences required for the target version.

### 3. Re-run the Installer

Run the installation script again using your modified configuration file:

```bash
sudo ./setup.sh
```

This will apply your updated configuration, including the new container image version, while preserving the existing Kubernetes cluster and configuration.

> ✅ The upgrade process is **idempotent** — the installer detects the current state of the cluster and only applies the necessary updates.

Downtime during an upgrade is typically less than a few minutes, as the new containers are brought up and the old containers terminated.

## Post-Upgrade Validation

After the upgrade:

1. Confirm that the new pods are running:

```bash
kubectl get pods -n ascender
```

2. Confirm the new version is deployed by accessing the Ascender web UI and checking the version string at the bottom of the login screen or in the About dialog.

3. Optionally, verify the container image version directly:

```bash
kubectl describe pod <ascender-web-pod-name> -n ascender | grep Image
```

## Other Methods
Utilizing the installer is the recommended method.  It is also recommended that you always set your config to a specific version.

However, if your `ASCENDER_VERSION` is set to `latest` and your `image_pull_policy` is set to `Always`, you can do a Rollout Restart on each deployment to pull the new images.

```bash
kubectl rollout restart deployment/ascender-app-web -n ascender
kubectl rollout restart deployment/ascender-app-task -n ascender
```

## Troubleshooting

- If the image is not updating, double-check that `image_pull_policy` is set to `Always` and that your container runtime is not caching old versions.
- Ensure your kubeconfig is valid and points to the correct cluster context.

## Notes

- Always validate the upgrade in a staging or test environment before applying it to production.
- Additional steps may be required if a newer postgres is required by the new Ascender version.

## Example Configuration Snippet

```bash
kube_install: false  
download_kubeconfig: false  
ASCENDER_VERSION: 25.3.2  
image_pull_policy: Always
```

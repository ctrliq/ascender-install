# Changing the Ascender or Ledger Hostname

## Overview

The hostnames Ascender and Ledger are published under are set by `ASCENDER_HOSTNAME` and `LEDGER_HOSTNAME` in your
configuration file. Both can be changed on a running deployment: update the configuration, re-run `setup.sh`, and the
installer moves the deployment to the new names without a reinstall.

## Prerequisites

- A running Ascender deployment, installed with the same configuration file you are about to edit.
- A DNS record for the new hostname, or `use_etc_hosts: true` if the installer should resolve it locally.
- For `k8s_lb_protocol: https`, a certificate and key whose subject or SAN list covers the new hostname.

> ⚠️ **Important:** Anything that already points at the old hostname keeps pointing at it. Update bookmarks, callback
> URLs registered with an identity provider, execution node configurations, and any automation that calls the API.

## Steps to Change a Hostname

### 1. Update the Hostname in Your Configuration File

Open your `custom.config.yml` file and set the new value:

```yaml
ASCENDER_HOSTNAME: ascender.mycompany.com
```

`LEDGER_HOSTNAME` works the same way, and the two must stay different from each other.

### 2. Confirm the New Hostname Resolves

If you run your own DNS, create the record for the new hostname before re-running the installer, as described in
[Ascender Website Not Loading Due to DNS Resolution Failure](../issues/unresolvable_dns.md).

If you rely on the installer instead, leave `use_etc_hosts: true` and it will maintain `/etc/hosts` on the machine you
run `setup.sh` from:

```yaml
use_etc_hosts: true
```

### 3. Keep the Cluster Settings As They Are

Your cluster already exists, so re-running the installer should not try to build it again:

```yaml
kube_install: false
download_kubeconfig: false
```

### 4. Re-run the Installer

```bash
./setup.sh
```

The run applies the new hostname to the Ascender object, and the operator rewrites the ingress rule and restarts the
web and task pods so that the new hostname is accepted as a trusted origin. The `/etc/hosts` entries the installer
owns are written inside a block marked `ASCENDER INSTALLER MANAGED HOSTS`, which is rewritten on every run, so the
entries of the previous hostname are removed as part of the same step.

### 5. Verify the New Hostname

Check that the ingress rule carries the new hostname:

```bash
kubectl get ingress -n ascender
```

Then confirm the API answers on it:

```bash
curl -sS http://ascender.mycompany.com/api/v2/ping/
```

## Notes

- Installer versions before the managed block wrote one unmarked line per hostname into `/etc/hosts`. The first run
  after upgrading adopts the current hostnames into the block, but a line left behind by an earlier hostname is not
  recognized as installer owned, so remove it by hand if you no longer want the old name to resolve.
- On OpenShift the hostname is published as a route, which has to resolve through the DNS server that serves the
  cluster wildcard record, so `use_etc_hosts` does not apply there.
- Ledger records the URL it uses to reach Ascender, and re-running the installer refreshes it, so change both
  hostnames in the same run when you are moving the whole deployment to a new domain.

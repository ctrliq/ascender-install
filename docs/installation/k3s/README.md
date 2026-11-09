# Ascender Installation and Updating on K3s

The Ascender installer is a script that makes it relatively easy to install the Ascender Automation
Platform on Kubernetes platforms of multiple flavors. The installer is being expanded to new
Kubernetes platforms as users/contributors allow. If you have specific needs for a platform not yet
supported, please submit an issue to this Github repository.

## Table of Contents

- [General Prerequisites](#general-prerequisites)
- [K3s-specific Prerequisites](#k3s-specific-prerequisites)
- [Dual-Stack and IPv6 Clusters](#dual-stack-and-ipv6-clusters)
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
  - If the OS family is Ubuntu/Debian then the major version must be 24 or 26
- Minimal System Requirements for the k3s server:
  - CPUs: 2
  - Memory: 8GB (if installing both Ascender and Ledger)
  - 20GB of free disk (for Ascender and Ledger Volumes)
- These instructions accommodate an existing K3s cluster, or will set up a new one on your behalf if
  necessary. This behavior is determined by the variable `kube_install`
  - If `kube_install` is set to true, the installer will set up K3s on the `ascender_host`in the
    inventory file. (`ascender_host` can be localhost)
  - If `kube_install` is set to false, the installer will not perform a K3s install
- Firewall
  - K3s recommends that `firewalld` is turned off, so the installer stops and disables it by
    default on the k3s server
  - To keep `firewalld` running, set `firewalld_disable: false`. The installer then applies the
    rules K3s [requires](https://docs.k3s.io/installation/requirements): it opens `6443/tcp` for
    the kube-api server, `80/tcp` and `443/tcp` for the ingress that serves Ascender, and adds the
    pod network (`10.42.0.0/16`) and the service network (`10.43.0.0/16`) to the `trusted` zone
  - Both lists can be changed with the `k3s_firewalld_ports` and `k3s_firewalld_trusted_sources`
    variables
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

## Dual-Stack and IPv6 Clusters

k3s supports dual-stack and single-stack IPv6 clusters, but this installer does not set them up and
carries no variables for the k3s options involved. A cluster of that kind is one you install
yourself, with `kube_install` set to `false` so the installer expects your existing cluster. The
subsections below record what such an environment means for an Ascender install. They are grounded
in the behavior verified by the reporter of
[issue #270](https://github.com/ctrliq/ascender-install/issues/270) on k3s v1.36.4+k3s1 and in the
[k3s network options documentation](https://docs.k3s.io/networking/basic-network-options).

### Pod IPv6 traffic and flannel-ipv6-masq

On a dual-stack cluster whose pod CIDR includes an IPv6 unique local address range (a ULA, for
example `fd00:42::/56`), pods send their traffic with the ULA as the source address. k3s applies
masquerade to IPv4 traffic by default, but sets up IPv6 masquerade only when the
`flannel-ipv6-masq` option is enabled. The packets still leave the node and reach the destination
host, but replies to a private ULA have no route back, so the connection hangs until it times
out. In an Ascender install this appears as a job that cannot reach a host which is reachable only
over IPv6, and as a project sync from a git host reachable only over IPv6, both failing with
connection timeouts.

The fix is a k3s drop-in config file on the node. Create
`/etc/rancher/k3s/config.yaml.d/10-flannel-ipv6-masq.yaml` with the single key below, then restart
the service.

```text
flannel-ipv6-masq: true
```

```text
$ sudo mkdir -p /etc/rancher/k3s/config.yaml.d
$ printf 'flannel-ipv6-masq: true\n' | sudo tee /etc/rancher/k3s/config.yaml.d/10-flannel-ipv6-masq.yaml
$ sudo systemctl restart k3s
```

A `systemctl restart k3s` applies it; the reporter measured the restart at 6 to 9 seconds, and
after it the same job and project sync succeeded, because pod traffic then left the node
masqueraded behind the node's own routable IPv6 address. k3s suggests this setting for pod
networks built on unrouted IPv6 space such as the ULA range, and it applies on dual-stack and
IPv6-only clusters with any flannel backend other than `none`.

Two properties of this fix are worth knowing before adopting it. Removing the drop-in and
restarting k3s does not remove the IPv6 masquerade rules. The reporter verified that a full removal
needs `systemctl stop k3s`, then `/usr/local/bin/k3s-killall.sh`, then `systemctl start k3s`, a
sequence that takes k3s, and with it every Ascender workload on this single-node cluster, down for
about 21 seconds. On the other side, the drop-in survives an in-place k3s upgrade (verified by the
reporter across an upgrade from v1.36.4+k3s1 to v1.36.5+k3s1), so it does not need to be reapplied
with each k3s release.

### Configuring a dual-stack cluster

k3s must be configured for dual-stack when the cluster is first created; an existing IPv4-only
cluster cannot gain an IPv6 family later. The installer carries no variables for `cluster-cidr` or
`service-cidr` and passes no such options to k3s, so the supported path today is the k3s config
file `/etc/rancher/k3s/config.yaml` on the node, written before the Ascender install runs. Each of
the two keys takes a list with one IPv4 and one IPv6 CIDR, as in this working example from the
reporter's cluster.

```text
cluster-cidr:
  - 10.42.0.0/16
  - fd00:42::/56
service-cidr:
  - 10.43.0.0/16
  - fd00:43::/112
```

Any valid CIDR pair works, and the k3s documentation recommends these mask sizes, a `/56` pod
network and a `/112` service network alongside the IPv4 defaults, noting that changing the
`cluster-cidr` mask means also changing `node-cidr-mask-size-ipv4` and `node-cidr-mask-size-ipv6`
to match the planned pods per node and node count. With a ULA pod network like `fd00:42::/56`, also
apply the `flannel-ipv6-masq` drop-in from the previous subsection. The firewalld guidance in the
prerequisites needs a matching change too. If you keep `firewalld` running with
`firewalld_disable: false`, the `trusted` zone must hold the IPv6 halves of both networks as well,
because `k3s_firewalld_trusted_sources` defaults to the IPv4 pod and service networks
(`10.42.0.0/16` and `10.43.0.0/16`) only. Add the IPv6 pod and service CIDRs you chose to that
list alongside the IPv4 entries.

### Single-stack IPv6 clusters

k3s also supports clusters with no IPv4, configured the same way with a single IPv6 CIDR for each
of the two keys. The installer variable that matters on such a node is `k3s_master_node_ip`. It
defaults to `127.0.0.1`, an IPv4 loopback address, in `default.config.yml`, in
`playbooks/group_vars/all.yml`, and in the `config_vars.sh` prompt. The installer uses the value
in three places. When it fetches a kubeconfig from a remote node, it replaces the `127.0.0.1` API
endpoint in that kubeconfig with the value. It writes an `/etc/hosts` entry on the machine running
the installer (when `use_etc_hosts` is true, the default), mapping the hostnames of the installed
components, Ascender, Ledger and the Galaxy Proxy among them, to the value. Its final wait for the
Ascender API then polls the Ascender hostname, which resolves through that `/etc/hosts` entry. The
IPv4 loopback default serves a single-node install where the web service answers over IPv4. On a
node with no IPv4, set `k3s_master_node_ip` to the node's global IPv6 address in your
`custom.config.yml`, and the hosts entry and the API wait run against that address. A single-stack
cluster with unrouted pod space, such as a ULA pod CIDR, also needs the `flannel-ipv6-masq` drop-in
and the firewalld trusted-sources change from the two subsections above, which apply unchanged.

### A node with no IPv4 egress

A node can also sit on a network where only IPv6 reaches the outside world. Two separate kinds of
outbound traffic then need a home, the image pulls made by the k3s node's embedded containerd, and
the traffic from the Ascender pods themselves, such as the project sync described above.

For image pulls, k3s documents two mechanisms, and the installer carries no variables for either.
A containerd registry mirror is configured in `/etc/rancher/k3s/registries.yaml` on the node, which
points registries such as `docker.io` and `ghcr.io` at mirror endpoints you control, reachable over
IPv6. k3s reads the file when it starts, so a restart applies changes, and it governs every image
the node pulls, including the execution environment images Ascender jobs fetch on demand. The
alternative is an HTTP proxy configured on the k3s systemd service through its environment file,
`/etc/systemd/system/k3s.service.env`, using `HTTP_PROXY`, `HTTPS_PROXY` and `NO_PROXY` entries.
k3s passes these down to the embedded containerd and kubelet, and adds the cluster's own pod and
service ranges to `NO_PROXY` on its own. The one proxy setting the installer itself carries,
`PROXY_CONFIG`, configures the optional Galaxy Proxy component and does not reach k3s or the image
pulls.

For the pods' own traffic, what covers it is the cluster's stack rather than the node's proxy,
because k3s documents that environment variables from the node are not passed into pods. The
project sync from an IPv6-only git host works on the dual-stack cluster described above once
`flannel-ipv6-masq` is in place. Where a destination exists only on IPv4, the standard answer is
NAT64 with DNS64, both of which live in the site's infrastructure rather than in k3s or this
installer. DNS64 runs on the recursive resolver the node uses, and pods resolve external names
through CoreDNS, which forwards to those same resolvers, so the synthesized IPv6 addresses reach
the pods as well. NAT64 runs on the border router and translates the resulting connections to
IPv4. The [Offline Installation](#offline-installation) section later in this guide takes image
pulls off the network entirely by pre-loading bundled images, which is worth considering alongside
these options.

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

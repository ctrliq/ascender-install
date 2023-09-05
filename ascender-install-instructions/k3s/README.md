The Ascender installer is a script that makes for relatively easy install of Ascender Automation Platform on Kubernetes platforms of multiple flavors. The installer is being expanded to new Kubernetes platforms as users/contributors allow, and if you have specific needs for a platform not yet supported, please submit an issue to this Github repository.

# Table of Contents
- [General Prerequisites](#general-prerequisites)
- [K3s-specific Prerequisites](#k3s-specific-prerequisites)
- [Install Instructions](#install-instructions)


## General Prerequisites
If you have not done so already, be sure to follow the general prerequisites found in the [Ascender-Install main README](../../README.md#general-prerequisites)

## K3s-specific Prerequisites
- NOTE: The K3s install of Ascender is not yet meant for production, but rather as a sandbox on which to try Ascender. As such, the Installer expects a single-node K3s cluster which will act as both master and worker node.
- These instructions assume an already existing K3s cluster. If you need to install K3s on the `ascender_host` and `ledger_host`, please follow the installation instructions:
  - Install k3s on the server on which ascender will run ([Reference](https://docs.k3s.io/quick-start))
    - K3s provides an installation script that is a convenient way to install it as a service on systemd or openrc based systems. This script is available at https://get.k3s.io. To install K3s using this method, just run:
      - `$curl -sfL https://get.k3s.io | sh -`
  - Ensure kubectl access to k3s cluster ([Reference](https://docs.k3s.io/cluster-access))
    - If running the installation script from a remote location
      - Copy the kubeconfig file from its default location on the k3s master node (`/etc/rancher/k3s/k3s.yaml`) and place it on local server at `~/.kube/config`
    - If running the installation script from the k3s master node itself
      - Copy the kubeconfig file from its default location on the k3s master node (`/etc/rancher/k3s/k3s.yaml`) to `~/.kube/config`
- SSL Certificate and Key
  - To enable HTTPS on your website, you need to provide the Ascender installer with an SSL Certificate file, and a Private Key file. While these can be self-signed certificates, it is best practice to use a trusted certificate, issued by a Certificate Authority. A good way to generate a trusted Certificate for the purpose of sandboxing, is to use the free Certificate Authority, [Let's Encrypt](https://letsencrypt.org/getting-started/).
  - Once you have a Certificate and Private Key file, make sure they are present on the Ascender installing server, and specify their locations in the default config file, with the variables `tls_crt_path`and `tls_key_path`, respectively. The installer will parse these files for their content, and use then to create a Kubernetes TLS Secret for HTTPS enablement.

## Install Instructions

### Set the configuration variables for a K3s Install
You can use the README.md in thid directory as a K3s reference, but the file used by the script must be located at the `playbooks/default.config.yml` location.

### Run the setup script
Run `$sudo ./setup` from top level directory in this repository.

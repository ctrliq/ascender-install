The Ascender installer is a script that makes for relatively easy install of Ascender Automation Platform on Kubernetes platforms of multiple flavors. The installer is being expanded to new Kubernetes platforms as users/contributors allow, and if you have specific needs for a platform not yet supported, please submit an issue to this Github repository.

# Table of Contents
- [General Prerequisites](#general-prerequisites)
- [K3s-specific Prerequisites](#k3s-specific-prerequisites)
- [Install Instructions](#install-instructions)


## General Prerequisites
If you have not done so already, be sure to follow the general prerequisites found in the [Ascender-Install main README](../../README.md#general-prerequisites)

## K3s-specific Prerequisites
- NOTE: The K3s install of Ascender is not yet meant for production, but rather as a sandbox on which to try Ascender. As such, the Installer expects a single-node K3s cluster which will act as both master and worker node.
- These instructions accomodate both an existing K3s cluster, and will set one up on your behalf if needed. This behavior is determined by the variable `k8s_install`
  - If `k8s_install` is set to true, the installer will set up K3s on the `ascender_host`in the inventory file. (`ascender_host` can be localhost)
  - If `k8s_install` is set to false, the installer will not perform a K3s install
- SSL Certificate and Key
  - To enable HTTPS on your website, you need to provide the Ascender installer with an SSL Certificate file, and a Private Key file. While these can be self-signed certificates, it is best practice to use a trusted certificate, issued by a Certificate Authority. A good way to generate a trusted Certificate for the purpose of sandboxing, is to use the free Certificate Authority, [Let's Encrypt](https://letsencrypt.org/getting-started/).
  - Once you have a Certificate and Private Key file, make sure they are present on the Ascender installing server, and specify their locations in the default config file, with the variables `tls_crt_path`and `tls_key_path`, respectively. The installer will parse these files for their content, and use the content to create a Kubernetes TLS Secret for HTTPS enablement.

## Install Instructions

### Set the configuration variables for a K3s Install
You can use the README.md in thid directory as a K3s reference, but the file used by the script must be located at the `playbooks/default.config.yml` location.

### Run the setup script
Run `$ ./setup` from top level directory in this repository.

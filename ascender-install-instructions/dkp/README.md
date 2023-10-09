The Ascender installer is a script that makes for relatively easy
install of Ascender Automation Platform on Kubernetes platforms of
multiple flavors. The installer is being expanded to new Kubernetes
platforms as users/contributors allow, and if you have specific needs
for a platform not yet supported, please submit an issue to this
Github repository.

## Table of Contents

- [General Prerequisites](#general-prerequisites)
- [DKP-specific Install Notes](#dkp-specific-install-notes)
- [DKP-specific Prerequisites](#dkp-specific-prerequisites)
- [Ascender Install Instructions](#ascender-install-instructions)

## General Prerequisites

If you have not done so already, be sure to follow the general
prerequisites found in the [Ascender-Install main
README](../../README.md#general-prerequisites)

## DKP-specific Install Notes

- D2iQ Kubernetes Platform (hereafter referred to as DKP) is used by a broad array of government agencies, and as such, there is an installer for it here.
- As DKP can be installed on a number of infrastructure/cloud platforms, this installer will provide general instructions for setting up a DKP cluster. The actual install playbooks assume an **EXISTING** DKP kubernetes cluster.
- The DKP installer has been tested with the following parameters: 
  - [DKP version 2.5](https://docs.d2iq.com/dkp/2.5/day-0-basic-installs-by-infrastructure).
    - Whether you are working with an existing DKP cluster, or have to create a new one, you will have to [download the DKP binary](https://docs.d2iq.com/dkp/2.5/download-dkp) for either MacOS or Linux, whichever you are managing the DKP cluster from.
  - [DKP Essential](https://d2iq.com/products/essential) License, for a single cluster deployment
  - [Traefik Labs ingress controller](https://traefik.io/solutions/kubernetes-ingress/) - this is provided by the [Kommander](https://d2iq.com/products/kommander) Management Plane as part of DKP.
  - vSphere 7.0.3 with appropriate [user permissions](https://docs.d2iq.com/dkp/2.5/vsphere-minimum-user-permissions)
- SSL Certificate and Key
  - To enable HTTPS on your website, you need to provide the Ascender
    installer with an SSL Certificate file, and a Private Key
    file. While these can be self-signed certificates, it is best
    practice to use a trusted certificate, issued by a Certificate
    Authority. A good way to generate a trusted Certificate for the
    purpose of sandboxing, is to use the free Certificate Authority,
    [Let's Encrypt](https://letsencrypt.org/getting-started/).
  - Once you have a Certificate and Private Key file, make sure they
    are present on the Ascender installing server, and specify their
    locations in the default config file, with the variables
    `tls_crt_path`and `tls_key_path`, respectively. The installer will
    parse these files for their content, and use the content to create
    a Kubernetes TLS Secret for HTTPS enablement.

## DKP-specific Prerequisites

### If there is no existing DKP Cluster

Keep in mind that these intructions, while some general, will help primarily with the setup described in the previous section, [DKP-specific Install Notes](#dkp-specific-install-notes).

- Installation instructions for DKP, for every platfom it runs upon, can be found [here](https://docs.d2iq.com/dkp/2.5/day-0-basic-installs-by-infrastructure).
- Make sure you have appropriate permissions for whatever platform. For example, for AWS, you'll need proper IAM Roles/Policies.
- Create a DKP Cluster API compliant image for your DKP cluster nodes:
  - Depending on where you are deploying DKP, this may be done via the [Konvoy Image Builder](https://docs.d2iq.com/dkp/2.5/konvoy-image-builder), or an optimized image provided by D2IQ on the cloud of your choice. 
- Create Bootstrap cluster (required for vSphere, GCP, Azure, and Pre-provisioned deployments)
  - To create Kubernetes clusters, Konvoy uses Cluster API (CAPI) controllers, which run on a Kubernetes cluster. To get started creating your vSphere cluster, you need a bootstrap cluster.
  - [vSphere Bootstrap cluster creation](https://docs.d2iq.com/dkp/2.5/vsphere-bootstrap)
  - NOTE: While the instructions result in a KUBECONFIG file being place at `$HOME/.kube/config`, it would be useful to create another file called `$HOME/.kube/config_bootstrap` and place its contents there as well. The DKP cluster will generate its own KUBECONFIG file, and you can change the contents of `$HOME/.kube/config` to whichever cluster you wish to connect to.
- Create DKP cluster
  - [vSphere DKP cluster creation](https://docs.d2iq.com/dkp/2.5/create-new-vsphere-cluster)
- For on-premise deploymebConfigure MetalLB Loadbalancer address pool
  - [vSphere MetalLB Configuration](https://docs.d2iq.com/dkp/2.5/configure-metallb-for-a-vsphere-managed-cluster)
- Set up Traefik Ingress Controller
  - [vSphere Kommander Install Instructions](https://docs.d2iq.com/dkp/2.5/vsphere-install-kommander)
  - [Kommander Install Customizations](https://docs.d2iq.com/dkp/2.5/dkp-install-configuration) - specifies how to select Traefik to install
  - [DKP 2.5 Components and Applications](https://docs.d2iq.com/dkp/2.5/dkp-2-5-0-components-and-applications)


## Ascender Install Instructions

### Ensure KUBECONFIG file is present

You MUST ensure that the KUBECONFIG file for the DKP cluster is present on the same machine as the Ascender install script, located at `$HOME/.kube/config`.

### Set the configuration variables for a DKP Install

You can use the dkp.default.config.yml in this directory as a DKP reference, but
the file used by the script must be located at the top level directory, with the filename `custom.config.yml`.

### Run the setup script

Run `./setup.sh` from top level directory in this repository.

The setup must run as root, so you may need to utilize `sudo` to
execute it. Example: `sudo ./setup.sh`

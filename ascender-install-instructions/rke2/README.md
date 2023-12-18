The Ascender installer is a script that makes for relatively easy
install of Ascender Automation Platform on Kubernetes platforms of
multiple flavors. The installer is being expanded to new Kubernetes
platforms as users/contributors allow, and if you have specific needs
for a platform not yet supported, please submit an issue to this
Github repository.

## Table of Contents

- [General Prerequisites](#general-prerequisites)
- [RKE2-specific Prerequisites](#rke2-specific-prerequisites)
- [Install Instructions](#install-instructions)

## General Prerequisites

If you have not done so already, be sure to follow the general
prerequisites found in the [Ascender-Install main
README](../../README.md#general-prerequisites)

## RKE2 Preamble

- RKE2, also known as RKE Government, is a Kubernetes distribution from Rancher that is focused on compliance with the U.S. Federal Government Sector. As such, these instructions are primarily focused on installing Ascender into an on-premise environment that may have no public internet access.
  - More details on RKE2 and how it it uniquely suited to Public Sector can be found at Rancher's Introduction website for [RKE2](https://docs.rke2.io/).
- If you do not yet have an RKE2 Cluster, [Labrinth Labs](https://lablabs.io/) has developed together an Ansible role that can be used to set up a cluster of any size that is incredibly well-documented. 
  - The role URL is here: [RKE2 Ansible Role](https://github.com/lablabs/ansible-role-rke2)
  - 
  - The example playbook used by the CIQ team in order to create a cluster with one control plane host, is in [this repository](./deploy-rke2-cluster/deploy-rke2-cluster.yaml), but is copied here for easy access:

      ```
      - name: Deploy RKE2
      hosts: all
      become: yes
      vars:
        # RKE2 version
        # All releases at:
        # https://github.com/rancher/rke2/releases
        rke2_version: v1.28.4+rke2r1
        # RKE2 channel
        rke2_channel: stable
        # Architecture to be downloaded, currently there are releases for amd64 and s390x
        rke2_architecture: amd64
        # Changes the deploy strategy to install based on local artifacts
        rke2_airgap_mode: true
        # Airgap implementation type - download, copy or exists
        # - 'download' will fetch the artifacts on each node,
        # - 'copy' will transfer local files in 'rke2_artifact' to the nodes,
        # - 'exists' assumes 'rke2_artifact' files are already stored in 'rke2_artifact_path'
        rke2_airgap_implementation: download
        # Additional RKE2 server configuration options
        rke2_server_options:
          - "disable-cloud-controller: true"
          - "kubelet-arg:"  
          - "  - \"cloud-provider=external\""
          - "  - \"provider-id=vsphere://$master_node_id\""
        # Additional RKE2 agent configuration options
        rke2_agent_options:
          - "disable-cloud-controller: true"
          - "kubelet-arg:"
          - "  - \"cloud-provider=external\""
          - "  - \"provider-id=vsphere://$worker_id\""
        # Pre-shared secret token that other server or agent nodes will register with when connecting to the cluster
        rke2_token: defaultSecret12345
        # Deploy RKE2 with default CNI canal
        rke2_cni: canal
        # Local source path where artifacts are stored
        rke2_airgap_copy_sourcepath: /tmp/rke2_artifacts
        # Local path to store artifacts
        rke2_artifact_path: /var/tmp/rke2_artifacts
        # Airgap required artifacts
        rke2_artifact: 
          - sha256sum-{{ rke2_architecture }}.txt
          - rke2.linux-{{ rke2_architecture }}.tar.gz
          - rke2-images.linux-{{ rke2_architecture }}.tar.zst
        # Download Kubernetes config file to the Ansible controller
        rke2_download_kubeconf: true
        # Name of the Kubernetes config file will be downloaded to the Ansible controller
        rke2_download_kubeconf_file_name: config
        # Destination directory where the Kubernetes config file will be downloaded to the Ansible controller
        rke2_download_kubeconf_path: ~/.kube
    
      roles:
        - role: lablabs.rke2
  ```
- The installer was run against a vSphere cluster, and if you elect to do the same, you will need to set up the vSphere Container Storage Plug-in in your RKE2 cluster. Detailed instructions from VMWare can be found at this URL: [Installation of vSphere Container Storage Plug-in](https://docs.vmware.com/en/VMware-vSphere-Container-Storage-Plug-in/3.0/vmware-vsphere-csp-getting-started/GUID-0AB6E692-AA47-4B6A-8CEA-38B754E16567.html)


## RKE2-specific Prerequisites

- These instructions assume that you either have an existing RKE2 cluster, and have the `kubeconfig` file necessary to access it, at `~/.kube/config`
- Minimal System Requirements for installing Ascender and Ledger on RKE2:
  - CPUs: 2
  - Memory: 8Gb (if installing both Ascender and Ledger)
  - 20GB of free disk (for Ascender and Ledger Volumes)
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

## Install Instructions

### Obtain the sources

You can use the `git` command to clone the ascender-install repository or you can download the zipped archive. 

To use git to clone the repository run:

```
git clone https://github.com/ctrliq/ascender-install.git
```
This will create a directory named `ascender-install` in your present working directory (PWD).

We will refer to this directory as the <ASCENDER-INSTALL-SOURCE> in the remainder of this instructions.

### Set the configuration variables for a RKE2 Install

#### custom.config.yml file

You can run the bash script at 

```
< ASCENDER-INSTALL-SOURCE >/config_vars.sh
```

The script will take you through a series of questions, that will populate the variables file requires to install Ascender. This variables file will be located at:

```
< ASCENDER-INSTALL-SOURCE >/custom.config.yml
```

Afterward, you can simply edit this file should you not want to run the script again before installing Ascender.

### Run the setup script

Run `./setup.sh` from top level directory in this repository.

The setup must run as a user with Administrative or sudo priviledges.  

To begin the setup process, type:

```
sudo ./setup.sh
```

Once the setup is completed successfully, you should see a final output similar to:

```
...<OUTPUT TRUNCATED>...
PLAY RECAP *************************************************************************************************************************
ascender_host              : ok=14   changed=6    unreachable=0    failed=0    skipped=2    rescued=0    ignored=0
localhost                  : ok=72   changed=27   unreachable=0    failed=0    skipped=4    rescued=0    ignored=0

ASCENDER SUCCESSFULLY SETUP
```


### Connecting to Ascender Web UI

The Ascender and Ledger web UIs are served from the `kubeapi_server_ip` specified in the config file used in the Ascender installer, and together with the Ingress object for Ascender and Legder, will give access to the respective GUIs.

To ensure access to the Ascender and Ledger GUIs, ensure that the `ASCENDER_HOSTNAME` resolves to `kubeapi_server_ip` with a DNS query. If the IP address is not being served by a DNS server, you will have to add that rule locally on the server you are using to connect to the Ascender GUI. For example, on a Mac, the file `/private/etc/hosts` would need the following line added:

```
127.0.0.1	localhost
255.255.255.255	broadcasthost
::1             localhost
`kubeapi_server_ip`     `ASCENDER_HOSTNAME`
```
Afterward, ou can visit/Browse/Administer your Ascender instance by pointing your web browser to:

https://<ASCENDER_HOSTNAME>


The username and the corresponding password are stored in <ASCENDER-INSTALL-SOURCE>/default.config.yml (or <ASCENDER-INSTALL-SOURCE>/custom.config.yml) under the `ASCENDER_ADMIN_USER` and `ASCENDER_ADMIN_PASSWORD` variable, respectively.



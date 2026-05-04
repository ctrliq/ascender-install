The Ascender installer is a script that makes for relatively easy
install of Ascender Automation Platform on Kubernetes platforms of
multiple flavors. The installer is being expanded to new Kubernetes
platforms as users/contributors allow, and if you have specific needs
for a platform not yet supported, please submit an issue to this
Github repository.

## Table of Contents

- [General Prerequisites](#general-prerequisites)
- [EKS-specific Prerequisites](#eks-specific-prerequisites)
- [Install Instructions](#install-instructions)

## General Prerequisites

If you have not done so already, be sure to follow the general
prerequisites found in the [Ascender-Install main
README](../../README.md#general-prerequisites)

## EKS-specific Prerequisites

### AWS User, policy and tool requirements
- Remember that the Enterprise Linux machine used to install Ascender on EKS must be of **major version 9, NOT 8**.
- The unzip rpm package must be installed: `$ sudo dnf install unzip -y` 
- The Ascender installer for EKS requires installation of the [AWS Commmand Line Interface](https://aws.amazon.com/cli/) before it is invoked. Instructions for the Linux installer can be found at [this link](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html#cliv2-linux-install).
  - Be certain to place the `aws` binary at `/usr/local/bin/`, as the Ascender installer will look for it there.
  - Once the AWS Command Line Interface is installed, run the following command to set the active aws user to one with the appropriate permissions to run the Ascender installer on EKS: `$ aws configure`.
    - The AWS CLI requires Programmatic access to AWS: Instructions on setting up Programmatic access can be found here: [AWS security credentials: Programmatic Access](https://docs.aws.amazon.com/IAM/latest/UserGuide/security-creds.html#sec-access-keys-and-secret-access-keys)
    - **Be sure to ensure that the user that will be installing ascender has appropriate access to create an EKS cluster.**
    - An example of setting up these programmatic credentials can be found here:
      - ![aws cli signin](./images/aws_login.png)
- Although not required before install, The Ascender installer for EKS will set up and use the EKS CLI tool, `eksctl`, in order to configure parts of your eks cluster.

## Install Instructions

### Obtain the sources

You can use the `git` command to clone the ascender-install repository or you can download the zipped archive. 

To use git to clone the repository run:

```
git clone https://github.com/ctrliq/ascender-install.git
```
This will create a directory named `ascender-install` in your present working directory (PWD).

We will refer to this directory as the `<repository root>` in the remainder of this instructions.

### Set the configuration variables for an eks Install

#### inventory file

You can copy the contents of [eks.inventory](./eks.inventory) in this directory, to `<repository root>`/inventory.
  - **Be sure to set the ansible_user variable for both the ansible_host and localhost to match the linux user that will be running the installer.**

```
$ cp <repository root>/docs/installation/eks/eks.inventory <repository root>/inventory 
```

#### AWS Certificate Manager

Before configuring the installer, you must create an SSL certificate in [AWS Certificate Manager](https://docs.aws.amazon.com/acm/latest/userguide/acm-overview.html) (ACM) in the same region as your EKS cluster. The certificate should cover the hostnames you plan to use for Ascender (e.g., `ascender.example.com`). If you plan to use the Automation Mesh feature to deploy external execution nodes, the certificate should also include the mesh hostname (e.g., `mesh.ascender.example.com`). Using a wildcard certificate (e.g., `*.example.com`) is recommended to cover all components. The ARN of this certificate will be used for the `EKS_SSL_CERT` variable in the configuration step below.

#### custom.config.yml file

You can run the bash script at 

```
<repository root>/config_vars.sh
```

The script will take you through a series of questions, that will populate the variables file requires to install Ascender. This variables file will be located at:

```
<repository root>/custom.config.yml
```

Afterward, you can simply edit this file should you not want to run the script again before installing Ascender.

The following variables will be present after running the script:

- `k8s_platform`: This variable specificies which Kubernetes platform Ascender and its components will be installed on.
- `k8s_lb_protocol`: For EKS is this ignored, it will always use https for Ascender running on EKS.
- `USE_ROUTE_53`: Determines whether to use Route53's Domain Management, or a third-party service such as Cloudflare, or GoDaddy. If this value is set to false, you will have to manually set a CNAME record for `ASCENDER_HOSTNAME` to point to the AWS Loadbalancers that the installer creates.
- `ASCENDER_HOSTNAME`: The DNS resolvable hostname for Ascender service.
- `ASCENDER_DOMAIN`: The Hosted Zone/Domain for all Ascender components. 
  - this is a SINGLE domain for both Ascender.
- `EKS_CLUSTER_NAME`: The name of the eks cluster on which Ascender will be installed. This can be an existing eks cluster, or the name of the one to create, should the `eksctl` tool not find this name amongst its existing clusters.
- `EKS_CLUSTER_STATUS`: Determines what to do with the EKS cluster Ascender will be installed on. Valid options are:
  - `provision`: Provision a new EKS cluster from scratch.
  - `configure`: Use the cluster specified by `EKS_CLUSTER_NAME`, and configure it with policies for load balancer creation and Elastic Block Store access.
  - `no_action`: Use the cluster specified by `EKS_CLUSTER_NAME`, but make no changes to it before installing Ascender.
- `EKS_CLUSTER_REGION`: The AWS region hosting the eks cluster.
- `EKS_CLUSTER_CIDR`: The EKS cluster subnet in CIDR notation. Only required if `EKS_CLUSTER_STATUS` is set to `provision`.
- `EKS_PUBLIC`: Determines whether cluster nodes are assigned public IPs. If set to true, cluster nodes will be assigned public IPs.
- `EKS_NUM_SUBNETS`: The number of subnets for the EKS cluster. Only required if `EKS_CLUSTER_STATUS` is set to `provision`.
- `EKS_SUBNET_SIZE`: The network size for each of the subnets. Only required if `EKS_CLUSTER_STATUS` is set to `provision`.
- `EKS_SSL_POLICY`: The SSL Policy for the EKS AWS Load Balancer.
- `EKS_INTERNET_GATEWAY`: Whether to set up an Internet Gateway for the VPC. Only required if `EKS_CLUSTER_STATUS` is set to `provision`.
- `EKS_ALB_SECURITY_GROUPS`: The security groups to use for the AWS Load Balancer; this controls who can access the Load Balancer and therefore Ascender. If left blank, the installer will create a security group that allows access from anywhere.
- `EKS_ALB_INBOUND_CIDRS`: The inbound CIDR blocks for the AWS Load Balancer security group; this controls who can access the Load Balancer and therefore Ascender.
- `EKS_K8S_VERSION`: The kubernetes version for the eks cluster; available kubernetes versions can be found [here](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html).
- `EKS_INSTANCE_TYPE`: The worker node instance type.
- `EKS_MIN_WORKER_NODES`: The minimum number of worker nodes that the cluster will run.
- `EKS_MAX_WORKER_NODES`: The maximum number of worker nodes that the cluster will run.
- `EKS_NUM_WORKER_NODES`: The desired number of worker nodes for the eks cluster.
- `EKS_WORKER_VOLUME_SIZE`: The size of the Elastic Block Storage volume for each worker node.
- `EKS_SSL_CERT`: The ARN for the SSL certificate; required when `k8s_lb_protocol` is set to `https`. The same certificate is used for all components (currently Ascender); as such, it is recommended that the certificate is set for a wildcard domain (e.g., `*.example.com`).
- `EKS_EBS_CSI_DRIVER_VERSION`: The version of the Amazon Elastic Block Store Container Storage Interface (CSI) Driver used by the cluster. All releases can be found [here](https://github.com/kubernetes-sigs/aws-ebs-csi-driver/releases).
- `EKS_DEFAULT_STORAGE_CLASS`: The default storage class to use for Ascender PVCs, which determines the type of EBS volume. Valid options are `gp2`, `gp3`, and `io2`. If not set, the installer will not create a default storage class and you will have to set the storage class for the Ascender PVCs manually.
- `tls_crt_path`: For EKS, this is ignored, you must first create a certificate in Certificate Manager.
- `tls_key_path`: For EKS, this is ignored, you must first create a certificate in Certificate Manager.

### Run the setup script

To begin the setup process, from the <repository root> directory in this repository, type:

```
sudo <repository root>/setup.sh
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

You can connect to the Ascender UI at https://`ASCENDER_HOST`

The username is and the corresponding password is stored in `<repository root>`/custom.config.yml under the `ASCENDER_ADMIN_USER` and `ASCENDER_ADMIN_PASSWORD` variables, respectively.


## Uninstall Instructions

After running `setup.sh`, `tmp_dir` will contain timestamped kubernetes manifests for:

- `ascender-deployment-{{ k8s_platform }}.yml`
- `kustomization.yml`

Remove the timestamp from the filename and then run the following
commands from within `tmp_dir``:

- `$ kubectl delete -f ascender-deployment-{{ k8s_platform }}.yml`
- `$ kubectl delete pvc -n {{ ASCENDER_NAMESPACE }} postgres-15-ascender-app-postgres-15-0 (If you used the default postgres database)
- `$ kubectl delete -k .`

**NOTE** A loadbalancer may still be left over, accessible from within the AWS GUI Console, under the EC2 Service page. Its DNS Name will match the CNAME record in either Route53 or whatever DNS resolution service you elected to use. You must manually delete it before destroying the EKS cluster with Terraform.

To delete an EKS cluster created with the Ascender installer, run the following command from within the `tmp_dir`

- `$ terraform -chdir=eks_deploy/ destroy --auto-approve`
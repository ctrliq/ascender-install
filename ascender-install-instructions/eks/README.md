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
- The Ascender installer for EKS requires installation of the [AWS Commmand Line Interface](https://aws.amazon.com/cli/) before it is invoked. Instructions for the Linux installer can be found at [this link](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html#cliv2-linux-install).
  - Be certain to place the `aws` binary at `/usr/local/bin/`, as the Ascender installer will look for it there.
  - Once the AWS Command Line Interface is installed, run the following command to set the active aws user to one with the appropriate permissions to run the Ascender installer on EKS: `$ aws configure`.
- IF INSTALLING ASCENDER ON AN EXISTING EKS CLUSTER, the aws user that will be performing the installation must have appropriate access to the cluster. This can be given by editing the aws-auth ConfigMap, in the kube-system namespace:
  - Use the following command to access the configmap: `$ kubectl edit -n kube-system configmap/aws-auth`
  - An example of the entry to give the {{ EKS_USER }} access to the cluster, is [here](./aws-auth.yml).
- Required IAM user permissions:
  - The Ascender installer for EKS requires minimum IAM AWS policies in order to manipulate EKS. 
  - An AWS administrator can apply these minimum permissions to a user (indicated by the variable `EKS_USER`), via a playbook that can be run from the top level directory of this repository, with the command (and with `k8s_platform` set to `eks`): 
    - `$ ansible-playbook playbooks/apply_cloud_permissions.yml`
  - The following permissions will be applied:
    - (AWS Managed Policy) [AmazonEC2FullAccess](https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AmazonEC2FullAccess.html): Provides full access to Amazon EC2
    - (AWS Managed Policy) [AWSCloudFormationFullAccess](https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AWSCloudFormationFullAccess.html): Provides full access to AWS CloudFormation
    - [ascender_eks_all_access](../../playbooks/roles/apply_permissions/templates/eks/iam_policies/eksallaccess.json): 
      - EKS Full Access
      - Systems Manager: GetParameter, GetParameters
      - KMS: DescribeKey, Create Grant
      - CloudWatch Logs: PutRetentionPolicy
    - [ascender_iam_limited_access](../../playbooks/roles/apply_permissions/templates/eks/iam_policies/iamlimitedaccess.json)
      - IAM: Limited List and Write Permissions
    - [ascender_install_permissions](../../playbooks/roles/apply_permissions/templates/eks/iam_policies/ascenderinstallpermissions.json)
      - IAM: ListPolicies
      - Route53: ChangeResourceRecordSets, ListHostedZones, ListResourceRecordSets
- Required IAM EKS cluster permissions:
  - The Ascender installer for EKS will look for certain Policies to add to the cluster, and create them if they are not present. These Policies are:
    - (AWS Managed Policy) [AmazonEBSCSIDriverPolicy](https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AmazonEBSCSIDriverPolicy.html): Allows the CSI driver service account to make calls to related services such as EC2 on your behalf
    - [AWSLoadBalancerControllerIAMPolicy](../../playbooks/roles/k8s_setup/templates/eks/iam-policy.json): Allows the EKS Cluster to manage all resources required to create Load Balancers for external access.
- Although not required before install, The Ascender installer for EKS will set up and use the EKS CLI tool, `eksctl`, in order to set up and/or manage your eks cluster.

## Install Instructions

### Obtain the sources

You can use the `git` command to clone the ascender-install repository or you can download the zipped archive. 

To use git to clone the repository run:

```
git clone https://github.com/ctrliq/ascender-install.git
```
This will create a directory named `ascender-install` in your present working directory (PWD).

We will refer to this directory as the <ASCENDER-INSTALL-SOURCE> in the remainder of this instructions.

### Set the configuration variables for an eks Install

You can use the eks.custom.config.yml in the ASCENDER-INSTALL-SOURCE directory as an eks reference, but
the file used by the `setup.sh` script must be located at in this path:

```
<ASCENDER-INSTALL-SOURCE>/custom.config.yml
```

The following variables should be changed in the file with your favorite text editor:

- `USE_ROUTE_53`: Determines whether to use Route53's Domain Management (which is automated), or a third-party service (e.g., Cloudflare, GoDaddy, etc.). If this value is set to false, you will have to manually set a CNAME record for {{ASCENDER_HOSTNAME }} and {{ LEDGER_HOSTNAME }} to point to the AWS Loadbalancers that the installer creates.
- `ASCENDER_HOSTNAME`: The DNS resolvable hostname for Ascender service.
- `LEDGER_HOSTNAME`: The DNS resolvable hostname for Ascender service.
- `ASCENDER_DOMAIN`: The Hosted Zone/Domain for all Ascender components. 
  - this must be the domain for both Ascender AND Ledger.
- `EKS_CLUSTER_NAME`: The name of the eks cluster on which Ascender will be installed. This can be an existing eks cluster, or the name of the one to create, should the `eksctl` tool not find this name amongst its existing clusters.
- `EKS_CLUSTER_REGION`: The AWS region hosting the eks cluster
- `EKS_CLUSTER_CIDR`: The eks cluster subnet in CIDR notation
- `EKS_K8S_VERSION`: The kubernetes version for the eks cluster; available kubernetes versions can be found [here](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html)
- `EKS_INSTANCE_TYPE`: The worker node instance type. 
- `EKS_MIN_WORKER_NODES`: The minimum number of worker nodes that the cluster will run
- `EKS_MAX_WORKER_NODES`: The maximum number of worker nodes that the cluster will run
- `EKS_NUM_WORKER_NODES`: The desired number of worker nodes for the eks cluster
- `EKS_WORKER_VOLUME_SIZE`: The size of the Elastic Block Storage volume for each worker node
- `EKS_SSL_CERT`: The ARN for the SSL certificate; required when k8s_lb_protocol is https. The same certificate is used for all components (currently Ascender and Ledger); as such, we recommend that the certificate is set for a wildcard domain, (e.g., *.example.com).
- `EKS_EBS_CSI_DRIVER_VERSION`: Amazon Elastic Block Store Container Storage Interface (CSI) Driver release

### Run the setup script

Run `./setup.sh` from top level directory in this repository.

The setup must run as a user with Administrative or sudo privileges.  

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

You can connect to the Ascender UI at https://{{ASCENDER_HOST }}"


The username is and the corresponding password is stored in <ASCENDER-INSTALL-SOURCE>/default.config.yml under the `ASCENDER_ADMIN_USER` and `ASCENDER_ADMIN_PASSWORD` variables, respectively.



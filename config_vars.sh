#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# Copyright (c) 2023-2025, Ctrl IQ, Inc. All rights reserved.
#
# This optional script will create a custom.config.yml file to direct the
# installer to create your customer Ascender install.
#
# Our installer currently supports multiple K8S platforms including:
#
# More Popular
# - K3S  - Kubernetes Lite Service
# - EKS  - Elastic Kubernetes Service (Amazon)
# - AKS  - Azure Kubernetes Service (Azure)
# - GKE  - Google Kubernetes Engine (Google)
#
# Less Popular
# - DKP  - D2iQ Kubernetes Platform (Nutanix)
# - RKE2 - Rancher Kubernetes Engine (SUSE)
#
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Include the core functions for the script
# -----------------------------------------------------------------------------
if [ -f lib/functions.sh ]; then
  source lib/functions.sh
else
  echo "Error: Unable to find the core functions.sh file"
  exit 1
fi

# -----------------------------------------------------------------------------
# Remove the custom.config.yml script if it already exists
# -----------------------------------------------------------------------------
if [ -f "./custom.config.yml" ]; then
  rm ./custom.config.yml
fi

clear
echo "--------------------------------------------------------------------"
echo "Custom Config Creation Program"
echo "--------------------------------------------------------------------"
echo "This script will prompt you for variables value that will generate"
echo "an installer script.  Once done, you will be able to then run the"
echo "setup.sh binary using the custom.config.yml file generated from"
echo "this script running to it's end."
echo ""
echo "If at any time you wish to cancel the process, press Ctrl+C"
echo ""

# -----------------------------------------------------------------------------
# LEDGER_INSTALL
# -----------------------------------------------------------------------------
echo "Do you wish to install Ledger along with Ascender?"
options=(true false)
prompt="Select true or false: "
ledger_install=$(prompt_for_input "$prompt" "${options[@]}")

# -----------------------------------------------------------------------------
# Ledger Install Type - Open Source or Pro
# -----------------------------------------------------------------------------
if [ $ledger_install == "true" ]; then
    echo "Do you wish to install Ledger or Ledger Pro?"
    options=("LedgerPro" "Ledger")
    prompt="Select an option: "
    ledger_install_type=$(prompt_for_input "$prompt" "${options[@]}")
fi

# -----------------------------------------------------------------------------
# k8s_platform
# -----------------------------------------------------------------------------
echo "Select the number of the Kubernetes platform you are using to install Ascender."
options=(k3s eks aks gke rke2 dkp)
prompt="Select a Platform option: "
k8s_platform=$(prompt_for_input "$prompt" "${options[@]}")

echo "---"$'\n'"    # This variable specificies which Kubernetes platform Ascender and its components will be installed on." >> custom.config.yml
echo "k8s_platform: "$k8s_platform >> custom.config.yml

# -----------------------------------------------------------------------------
# kube_install
# -----------------------------------------------------------------------------
if [ $k8s_platform == "k3s" ]; then
    echo "Do you wish the installer install k3s/k8s now and create a on-premise cluster (true) or use an existing k3s/k8s on premise cluster (false)"
    
    options=(true false)
    prompt="Select true or false: "
	kube_install=$(prompt_for_input "$prompt" "${options[@]}")

    echo "    # Boolean indicating whether to set up a new k3s cluster (true) or use an existing k3s cluster (false)" >> custom.config.yml
    echo "kube_install: "$kube_install >> custom.config.yml
fi

# -----------------------------------------------------------------------------
# k8s_offline
# -----------------------------------------------------------------------------
if [[ ( $k8s_platform == "k3s" || $k8s_platform == "rke2") ]]; then
    echo "Do you wish to use local assets to complete an OFFLINE install (true) or perform a traditional install using internet resources (false)"
    options=(true false)
    prompt="Select true or false: "
	k8s_offline=$(prompt_for_input "$prompt" "${options[@]}")

    echo "" >> custom.config.yml
    echo "    # Offline Install - Whether to use local assets to complete the install" >> custom.config.yml
    echo "k8s_offline: "$k8s_offline >> custom.config.yml

    if [ $k8s_offline == "true" ]; then
        echo "" >> custom.config.yml
        echo "    # Offline Install - Whether to use local assets to complete the install" >> custom.config.yml
        echo "ANSIBLE_OPERATOR_OFFLINE_VERSION: 2.9.0" >> custom.config.yml
    fi

    # -------------------------------------------------------------------------
    # If offline is selected and platform is rke2, choose an alternate registry
    # -------------------------------------------------------------------------
    if [[ ( $k8s_offline == "true" && $k8s_platform == "rke2") ]]; then
        # ----------------------------------------------------------------------
        # k8s_container_registry
        # ----------------------------------------------------------------------
        read -p "Specify an INTERNAL container registry and namespace where the k8s cluster can access Ascender images [format: registry.io/namespace]: " k_container_registry
        k8s_container_registry=${k_container_registry:-registry.io/namespace}

        echo "" >> custom.config.yml
        echo "    # Specify an INTERNAL container registry and namespace where the k8s cluster can access Ascender images" >> custom.config.yml
        echo "k8s_container_registry: "$k8s_container_registry >> custom.config.yml

        # ----------------------------------------------------------------------
        # k8s_image_pull_secret
        # ----------------------------------------------------------------------
        read -p "Kubernetes secret containing the login credentials required for the INTERNAL registry holding the ASCENDER images. If no login credentials are required, leave as [None]: " k_image_pull_secret
        k8s_image_pull_secret=${k_image_pull_secret:-None}

        if [ $k8s_image_pull_secret != "None" ]; then
            echo "" >> custom.config.yml
            echo "    # Kubernetes secret containing the login credentials required for the INTERNAL registry holding the ASCENDER images." >> custom.config.yml
            echo "k8s_image_pull_secret: "$k8s_image_pull_secret >> custom.config.yml
        fi

        # ----------------------------------------------------------------------
        # k8s_ee_pull_credentials_secret
        # ----------------------------------------------------------------------
        read -p "Kubernetes secret containing the login credentials required for the INTERNAL registry holding the EXECUTION ENVIRONMENT images. If no login credentials are required, leave as [None]: " k_ee_pull_credentials_secret
        k8s_ee_pull_credentials_secret=${k_ee_pull_credentials_secret:-None}

        if [ $k8s_ee_pull_credentials_secret != "None" ]; then
            echo "" >> custom.config.yml
            echo "    # Kubernetes secret containing the login credentials required for the INTERNAL registry holding the EXECUTION ENVIRONMENT images." >> custom.config.yml
            echo "k8s_ee_pull_credentials_secret: "$k8s_ee_pull_credentials_secret >> custom.config.yml
        fi
    fi
fi

# -----------------------------------------------------------------------------
# ee_images
# -----------------------------------------------------------------------------
echo "Do you wish to pull container images to serve as additional Execution Environments to run your playbooks? If unsure, choose false"
options=(true false)
prompt="Select true or false: "
use_ee_images=$(prompt_for_input "$prompt" "${options[@]}")

if [ $use_ee_images == "true" ]; then
    echo "ee_images:" >> custom.config.yml
    while true; do
        echo "Enter the informal image name, and the formal registry-address/namespace/image:tag (the tag is optional):"
        read -p "Informal image name (format: my-custom-ascender-ee): " informal_image_name
        read -p "Formal image path: (format: registry-address/namespace/my-custom-ascender-ee:tag): " formal_image_path
        echo "  - name: "$informal_image_name >> custom.config.yml
        echo "    image: "$formal_image_path >> custom.config.yml
        echo "Do you have another image to enter? Yes = 1, No = 2"
        read next_image

        if [[ $next_image -eq 2 ]]; then
            break
        fi
    done
fi

# -----------------------------------------------------------------------------
# download_kubeconfig
# -----------------------------------------------------------------------------
echo "Boolean indicating whether or not the kubeconfig file needs to be downloaded to the Ansible controller"
options=(true false)
prompt="Select true or false: "
download_kubeconfig=$(prompt_for_input "$prompt" "${options[@]}")

echo "" >> custom.config.yml
echo "    # Boolean indicating whether or not the kubeconfig file needs to be downloaded to the Ansible controller" >> custom.config.yml
echo "download_kubeconfig: "$download_kubeconfig >> custom.config.yml

# -----------------------------------------------------------------------------
# k8s_lb_protocol
# -----------------------------------------------------------------------------
echo "Select the number of the prototol you want to support. Selecting 'https' requires the SSL certificate being present"
options=(http https)
prompt="Select a protocol: "
k8s_lb_protocol=$(prompt_for_input "$prompt" "${options[@]}")

echo "" >> custom.config.yml
echo "    # Determines whether to use HTTP or HTTPS for Ascender and Ledger." >> custom.config.yml
echo "    # If set to https, you MUST provide certificate/key options for the Installer to use." >> custom.config.yml
echo "k8s_lb_protocol: "$k8s_lb_protocol >> custom.config.yml

# -----------------------------------------------------------------------------
# k3s_master_node_ip
# -----------------------------------------------------------------------------
if [ $k8s_platform == "k3s" ]; then
    read -p "Routable IP address for the K3s Master/Worker node [127.0.0.1]: " k3s_m_node_ip
    k3s_master_node_ip=${k3s_m_node_ip:-127.0.0.1}

    echo "" >> custom.config.yml
    echo "    # Routable IP address for the K3s Master/Worker node" >> custom.config.yml
    echo "    # required for DNS and k3s install" >> custom.config.yml
    echo "k3s_master_node_ip: "\"$k3s_master_node_ip\" >> custom.config.yml
fi

# -----------------------------------------------------------------------------
# kubeapi_server_ip
# -----------------------------------------------------------------------------
if [ $k8s_platform == "rke2" ]; then
    read -p "Routable IP address for the K8s API Server (This could be a Load Balancer if using 3 K8s control nodes) [127.0.0.1]: " k8s_api_srvr_ip
    kubeapi_server_ip=${k8s_api_srvr_ip:-127.0.0.1}

    echo "" >> custom.config.yml
    echo "    # Routable IP address for the K8s API Server" >> custom.config.yml
    echo "    # (This could be a Load Balancer if using 3 K8s control nodes)" >> custom.config.yml
    echo "kubeapi_server_ip: "\"$kubeapi_server_ip\" >> custom.config.yml
fi

# -----------------------------------------------------------------------------
# Platform: eks
# -----------------------------------------------------------------------------
if [ "$k8s_platform" == "eks" ]; then
    # -------------------------------------------------------------------------
    # USE_ROUTE_53
    # -------------------------------------------------------------------------
    echo "Boolean indicating Determines whether to use Route53 Domain Management (true) "
    echo "or a third-party service such as Cloudflare or GoDaddy (false). If this value"
    echo "is set to false, you will have to manually set a CNAME record for Ascender/Ledger"
    echo "to point to their respective AWS Load Balancers."

    options=(true false)
    prompt="Select true or false: "
    use_route_53=$(prompt_for_input "$prompt" "${options[@]}")

    echo "" >> custom.config.yml
    echo "    # Determines whether to use Route53's Domain Management (which is automated)" >> custom.config.yml
    echo "    # Or a third-party service (e.g., Cloudflare, GoDaddy, etc.)" >> custom.config.yml
    echo "    # If this value is set to false, you will have to manually set a CNAME record for" >> custom.config.yml
    echo "    # {{ASCENDER_HOSTNAME }} and {{ LEDGER_HOSTNAME }} to point to the AWS" >> custom.config.yml
    echo "    # Loadbalancers" >> custom.config.yml
    echo "USE_ROUTE_53: "$use_route_53 >> custom.config.yml

    # -------------------------------------------------------------------------
    # EKS_CLUSTER_NAME
    # -------------------------------------------------------------------------
    read -p "The name of the eks cluster to install Ascender on - if it does not already exist, the installer can set it up [ascender-eks-cluster]: " e_cluster_name
    eks_cluster_name=${e_cluster_name:-ascender-eks-cluster}

    echo "" >> custom.config.yml
    echo "    # The name of the eks cluster to install Ascender on - if it does not already exist, the installer can set it up" >> custom.config.yml
    echo "EKS_CLUSTER_NAME: "$eks_cluster_name >> custom.config.yml

    # -------------------------------------------------------------------------
    # EKS_CLUSTER_STATUS:
    # -------------------------------------------------------------------------
    echo "Specifies whether the EKS cluster needs to be provisioned (provision), exists but needs to be configured to support Ascender (configure), or exists and needs nothing done before installing Ascender (no_action)"
    options=(provision configure no_action)
    prompt="Select an option: "
    eks_cluster_status=$(prompt_for_input "$prompt" "${options[@]}")

    echo "" >> custom.config.yml
    echo "    # Specifies whether the EKS cluster needs to be provisioned (provision), exists but needs to be configured to support Ascender (configure), or exists and needs nothing done before installing Ascender (no_action)" >> custom.config.yml
    echo "EKS_CLUSTER_STATUS: "$eks_cluster_status >> custom.config.yml

    # -------------------------------------------------------------------------
    # EKS_CLUSTER_REGION
    # -------------------------------------------------------------------------
    read -p "The AWS region hosting the eks cluster [us-east-1]: " e_cluster_region
    eks_cluster_region=${e_cluster_region:-us-east-1}

    echo "" >> custom.config.yml
    echo "    # The AWS region hosting the eks cluster" >> custom.config.yml
    echo "EKS_CLUSTER_REGION: "$eks_cluster_region >> custom.config.yml

    if [ $eks_cluster_status == "provision" ]; then
        # ----------------------------------------------------------------------
        # EKS_K8S_VERSION
        # ----------------------------------------------------------------------
        read -p "The kubernetes version for the eks cluster; available kubernetes versions can be found here: https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html [1.28]:" e_k8s_version
        eks_k8s_version=${e_k8s_version:-1.28}

        echo "" >> custom.config.yml
        echo "    # The kubernetes version for the eks cluster; available kubernetes versions can be found here:" >> custom.config.yml
        echo "EKS_K8S_VERSION: "\"$eks_k8s_version\" >> custom.config.yml
 
        # ----------------------------------------------------------------------
        # EKS_INSTANCE_TYPE
        # ----------------------------------------------------------------------
        read -p "The eks worker node instance types [t3.large]:" e_instance_type
        eks_instance_type=${e_instance_type:-t3.large}

        echo "" >> custom.config.yml
        echo "    # The eks worker node instance types" >> custom.config.yml
        echo "EKS_INSTANCE_TYPE: "\"$eks_instance_type\" >> custom.config.yml

        # ----------------------------------------------------------------------
        # EKS_MIN_WORKER_NODES
        # ----------------------------------------------------------------------
        read -p "The minimum number of eks worker nodes [2]:" e_min_worker_nodes
        eks_min_worker_nodes=${e_min_worker_nodes:-2}

        echo "" >> custom.config.yml
        echo "    # The minimum number of eks worker nodes" >> custom.config.yml
        echo "EKS_MIN_WORKER_NODES: "$eks_min_worker_nodes >> custom.config.yml

        # ----------------------------------------------------------------------
        # EKS_MAX_WORKER_NODES: 6
        # ----------------------------------------------------------------------
        read -p "The maximum number of eks worker nodes [6]:" e_max_worker_nodes
        eks_max_worker_nodes=${e_max_worker_nodes:-6}

        echo "" >> custom.config.yml
        echo "    # The maximum number of eks worker nodes" >> custom.config.yml
        echo "EKS_MAX_WORKER_NODES: "$eks_max_worker_nodes >> custom.config.yml

        # ----------------------------------------------------------------------
        # EKS_NUM_WORKER_NODES: 3
        # ----------------------------------------------------------------------
        read -p "The desired number of eks worker nodes [3]:" e_num_worker_nodes
        eks_num_worker_nodes=${e_num_worker_nodes:-3}

        echo "" >> custom.config.yml
        echo "    # The desired number of eks worker nodes" >> custom.config.yml
        echo "EKS_NUM_WORKER_NODES: "$eks_num_worker_nodes >> custom.config.yml

        # ----------------------------------------------------------------------
        # EKS_WORKER_VOLUME_SIZE
        # ----------------------------------------------------------------------
        read -p "The volume size of eks worker nodes in GB [100]:" e_worker_volume_size
        eks_worker_volume_size=${e_worker_volume_size:-100}

        echo "" >> custom.config.yml
        echo "    # The volume size of eks worker nodes in GB" >> custom.config.yml
        echo "EKS_WORKER_VOLUME_SIZE: "$eks_worker_volume_size >> custom.config.yml
    fi 
fi

# -----------------------------------------------------------------------------
# Platform: aks
# -----------------------------------------------------------------------------
if [ $k8s_platform == "aks" ]; then
    # -------------------------------------------------------------------------
    # USE_AZURE_DNS
    # -------------------------------------------------------------------------
    echo "Boolean indicating Determines whether to use Azure DNS Domain Management (true)"
    echo "or a third-party service such as Cloudflare or GoDaddy (false). If this value"
    echo "is set to false, you will have to manually set an A record for Ascender/Ledger"
    echo "to point to their respective Azure Load Balancers"

    options=(true false)
    prompt="Select true or false: "
    use_azuredns=$(prompt_for_input "$prompt" "${options[@]}")

    echo "" >> custom.config.yml
    echo "    # Determines whether to use Azure DNS Domain Management (which is automated)" >> custom.config.yml
    echo "    # Or a third-party service (e.g., Cloudflare, GoDaddy, etc.)" >> custom.config.yml
    echo "    # If this value is set to false, you will have to manually set an A record for" >> custom.config.yml
    echo "    # {{ASCENDER_HOSTNAME }} and {{ LEDGER_HOSTNAME }} to point to the Azure" >> custom.config.yml
    echo "    # Loadbalancers" >> custom.config.yml
    echo "USE_AZURE_DNS: "$use_azuredns >> custom.config.yml
 
    # -------------------------------------------------------------------------
    # AKS_CLUSTER_NAME
    # -------------------------------------------------------------------------
    read -p "The name of the aks cluster to install Ascender on - if it does not already exist, the installer can set it up [ascender-aks-cluster]: " a_cluster_name
    aks_cluster_name=${a_cluster_name:-ascender-aks-cluster}

    echo "" >> custom.config.yml
    echo "    # The name of the eks cluster to install Ascender on - if it does not already exist, the installer can set it up" >> custom.config.yml
    echo "AKS_CLUSTER_NAME: "$aks_cluster_name >> custom.config.yml

    # -------------------------------------------------------------------------
    # AKS_CLUSTER_STATUS:
    # -------------------------------------------------------------------------
    echo "Specifies whether the AKS cluster needs to be provisioned (provision), exists but needs to be configured to support Ascender (configure), or exists and needs nothing done before installing Ascender (no_action)"

    options=(provision configure no_action)
    prompt="Select an option: "
    aks_cluster_status=$(prompt_for_input "$prompt" "${options[@]}")

    echo "" >> custom.config.yml
    echo "    # Specifies whether the AKS cluster needs to be provisioned (provision), exists but needs to be configured to support Ascender (configure), or exists and needs nothing done before installing Ascender (no_action)" >> custom.config.yml
    echo "AKS_CLUSTER_STATUS: "$aks_cluster_status >> custom.config.yml

    # -------------------------------------------------------------------------
    # AKS_CLUSTER_REGION
    # -------------------------------------------------------------------------
    read -p "The Azure region hosting the aks cluster [eastus]: " a_cluster_region
    aks_cluster_region=${a_cluster_region:-eastus}

    echo "" >> custom.config.yml
    echo "    # The Azure region hosting the aks cluster" >> custom.config.yml
    echo "AKS_CLUSTER_REGION: "$aks_cluster_region >> custom.config.yml

    if [ $aks_cluster_status == "provision" ]; then
        # ----------------------------------------------------------------------
        # AKS_K8S_VERSION
        # ----------------------------------------------------------------------
        read -p "The kubernetes version for the aks cluster; available kubernetes versions can be found here: https://learn.microsoft.com/en-us/azure/aks/supported-kubernetes-versions?tabs=azure-cli [1.29]:" a_k8s_version
        aks_k8s_version=${a_k8s_version:-1.29}

        echo "" >> custom.config.yml
        echo "    # The kubernetes version for the aks cluster; available kubernetes versions can be found here:" >> custom.config.yml
        echo "AKS_K8S_VERSION: "\"$aks_k8s_version\" >> custom.config.yml
 
        # ----------------------------------------------------------------------
        # AKS_INSTANCE_TYPE
        # ----------------------------------------------------------------------
        read -p "The aks worker node instance types [Standard_D2_v2]:" a_instance_type
        aks_instance_type=${a_instance_type:-Standard_D2_v2}

        echo "" >> custom.config.yml
        echo "    # The aks worker node instance types" >> custom.config.yml
        echo "AKS_INSTANCE_TYPE: "\"$aks_instance_type\" >> custom.config.yml

        # ----------------------------------------------------------------------
        # AKS_NUM_WORKER_NODES: 3
        # ----------------------------------------------------------------------
        read -p "The desired number of aks worker nodes [3]:" a_num_worker_nodes
        aks_num_worker_nodes=${a_num_worker_nodes:-3}

        echo "" >> custom.config.yml
        echo "    # The desired number of aks worker nodes" >> custom.config.yml
        echo "AKS_NUM_WORKER_NODES: "$aks_num_worker_nodes >> custom.config.yml

        # ----------------------------------------------------------------------
        # AKS_WORKER_VOLUME_SIZE
        # ----------------------------------------------------------------------
        read -p "The volume size of aks worker nodes in GB [100]:" a_worker_volume_size
        aks_worker_volume_size=${a_worker_volume_size:-100}

        echo "" >> custom.config.yml
        echo "    # The volume size of aks worker nodes in GB" >> custom.config.yml
        echo "AKS_WORKER_VOLUME_SIZE: "$aks_worker_volume_size >> custom.config.yml
    fi 
fi

# -----------------------------------------------------------------------------
# Platform: gke
# -----------------------------------------------------------------------------
if [ $k8s_platform == "gke" ]; then
    # -------------------------------------------------------------------------
    # GKE_PROJECT_ID
    # -------------------------------------------------------------------------
    read -p "The name of the Google Cloud Project ID where the gke cluster should live [ascender-gke-project]: " g_project
    google_project=${g_project:-ascender-gke-project}

    echo "" >> custom.config.yml
    echo "    # The name of the Google Cloud Project ID where the gke cluster should live" >> custom.config.yml
    echo "GKE_PROJECT_ID: "$google_project >> custom.config.yml

    # -------------------------------------------------------------------------
    # USE_GOOGLE_DNS
    # -------------------------------------------------------------------------
    echo "Boolean indicating Determines whether to use Google Cloud DNS Domain Management (true) Or a third-party service such as Cloudflare or GoDaddy (false). If this value is set to false, you will have to manually set an A record for Ascender/Ledger to point to their respective Google Cloud Load Balancers"

    options=(true false)
    prompt="Select true or false: "
    use_googledns=$(prompt_for_input "$prompt" "${options[@]}")

    echo "" >> custom.config.yml
    echo "    # Determines whether to use Google Cloud DNS Domain Management (which is automated)" >> custom.config.yml
    echo "    # Or a third-party service (e.g., Cloudflare, GoDaddy, etc.)" >> custom.config.yml
    echo "    # If this value is set to false, you will have to manually set an A record for" >> custom.config.yml
    echo "    # {{ASCENDER_HOSTNAME }} and {{ LEDGER_HOSTNAME }} to point to the Google Cloud" >> custom.config.yml
    echo "    # Loadbalancers" >> custom.config.yml
    echo "USE_GOOGLE_DNS: "$use_googledns >> custom.config.yml

    # -------------------------------------------------------------------------
    # GKE_CLUSTER_NAME
    # -------------------------------------------------------------------------
    read -p "The name of the gke cluster to install Ascender on - if it does not already exist, the installer can set it up [ascender-gke-cluster]: " g_cluster_name
    gke_cluster_name=${g_cluster_name:-ascender-gke-cluster}

    echo "" >> custom.config.yml
    echo "    # The name of the gke cluster to install Ascender on - if it does not already exist, the installer can set it up" >> custom.config.yml
    echo "GKE_CLUSTER_NAME: "$gke_cluster_name >> custom.config.yml

    # -------------------------------------------------------------------------
    # GKE_CLUSTER_STATUS:
    # -------------------------------------------------------------------------
    echo "Specifies whether the GKE cluster needs to be provisioned (provision), exists but needs to be configured to support Ascender (configure), or exists and needs nothing done before installing Ascender (no_action)"
    options=(provision configure no_action)
    prompt="Select an option: "
    gke_cluster_status=$(prompt_for_input "$prompt" "${options[@]}")

    echo "" >> custom.config.yml
    echo "    # Specifies whether the GKE cluster needs to be provisioned (provision), exists but needs to be configured to support Ascender (configure), or exists and needs nothing done before installing Ascender (no_action)" >> custom.config.yml
    echo "GKE_CLUSTER_STATUS: "$gke_cluster_status >> custom.config.yml

    # -------------------------------------------------------------------------
    # GKE_CLUSTER_ZONE
    # -------------------------------------------------------------------------
    read -p "The Google Cloud zone hosting the gke cluster. To see a list of all available zones in your Google Cloud project, you can type the following command into your terminal: $ gcloud compute zones list --project <your-project-id> [us-central1-a]: " g_cluster_zone
    gke_cluster_zone=${g_cluster_zone:-us-central1-a}

    echo "" >> custom.config.yml
    echo "    # The Google Cloud zone hosting the gke cluster" >> custom.config.yml
    echo "GKE_CLUSTER_ZONE: "$gke_cluster_zone >> custom.config.yml

    if [ $gke_cluster_status == "provision" ]; then
        # ----------------------------------------------------------------------
        # GKE_K8S_VERSION
        # ----------------------------------------------------------------------
        read -p "The kubernetes version for the gke cluster; available kubernetes versions can be determined by typing the following command into your terminal: &gcloud container get-server-config --zone < zone > [1.29.4-gke.1043002]:" a_k8s_version
        gke_k8s_version=${g_k8s_version:-1.29.4-gke.1043002}

        echo "" >> custom.config.yml
        echo "    # The kubernetes version for the gke cluster" >> custom.config.yml
        echo "GKE_K8S_VERSION: "\"$gke_k8s_version\" >> custom.config.yml
 
        # ----------------------------------------------------------------------
        # GKE_INSTANCE_TYPE
        # ----------------------------------------------------------------------
        read -p "The gke worker node instance types [e2-medium]:" g_instance_type
        gke_instance_type=${g_instance_type:-e2-medium}

        echo "" >> custom.config.yml
        echo "    # The gke worker node instance types" >> custom.config.yml
        echo "GKE_INSTANCE_TYPE: "\"$gke_instance_type\" >> custom.config.yml

        # ----------------------------------------------------------------------
        # GKE_NUM_WORKER_NODES: 3
        # ----------------------------------------------------------------------
        read -p "The desired number of gke worker nodes [3]:" g_num_worker_nodes
        gke_num_worker_nodes=${g_num_worker_nodes:-3}

        echo "" >> custom.config.yml
        echo "    # The desired number of gke worker nodes" >> custom.config.yml
        echo "GKE_NUM_WORKER_NODES: "$gke_num_worker_nodes >> custom.config.yml

        # ----------------------------------------------------------------------
        # GKE_WORKER_VOLUME_SIZE
        # ----------------------------------------------------------------------
        read -p "The volume size of gke worker nodes in GB [100]:" g_worker_volume_size
        gke_worker_volume_size=${g_worker_volume_size:-100}

        echo "" >> custom.config.yml
        echo "    # The volume size of gke worker nodes in GB" >> custom.config.yml
        echo "GKE_WORKER_VOLUME_SIZE: "$gke_worker_volume_size >> custom.config.yml
    fi 
fi

# -----------------------------------------------------------------------------
# Platform: dkp
# -----------------------------------------------------------------------------
if [ $k8s_platform == "dkp" ]; then
    # -------------------------------------------------------------------------
    # DKP_CLUSTER_NAME
    # -------------------------------------------------------------------------
    read -p "The name of the dkp cluster you wish to deploy Ascender to and/or create [dkp-cluster]:" d_cluster_name
    dkp_cluster_name=${d_cluster_name:-dkp-cluster} 

    echo "" >> custom.config.yml
    echo "    # The name of the dkp cluster you wish to deploy Ascender to and/or create" >> custom.config.yml
    echo "DKP_CLUSTER_NAME: "$dkp_cluster_name >> custom.config.yml
fi

# -----------------------------------------------------------------------------
# Update /etc/hosts for local resolution
# -----------------------------------------------------------------------------
if [[ ( $k8s_platform == "k3s" || $k8s_platform == "dkp" || $k8s_platform == "rke2") ]]; then
    echo "Do you want the installer to update your /etc/hosts to resolved Ascender and Ledger Hosts (true) or leave it as is (false)"
    options=(true false)
    prompt="Select true or false: "
    use_etc_hosts=$(prompt_for_input "$prompt" "${options[@]}")

    echo "" >> custom.config.yml
    echo "    # Boolean indicating whether to use the local /etc/hosts file for DNS resolution to access Ascender" >> custom.config.yml
    echo "use_etc_hosts: "$use_etc_hosts >> custom.config.yml
fi

# -----------------------------------------------------------------------------
# Certificate location for installing or updating a certificate
# -----------------------------------------------------------------------------
if [[ ( $k8s_platform == "k3s" || $k8s_platform == "dkp" || $k8s_platform == "rke2" || $k8s_platform == "aks" || $k8s_platform == "gke" || $k8s_platform == "eks" ) && $k8s_lb_protocol == "https" ]]; then
    # -------------------------------------------------------------------------
    # tls_crt_path
    # -------------------------------------------------------------------------
    read -p "TLS Certificate file location on the local installing machine [~/ascender.crt]:" t_cert_path
    tls_cert_path=${t_cert_path:-~/ascender.crt} 

    echo "" >> custom.config.yml
    echo "    # TLS Certificate file location on the local installing machine" >> custom.config.yml
    echo "tls_crt_path: "\"$tls_cert_path\" >> custom.config.yml

    # -------------------------------------------------------------------------
    # tls_key_path
    # -------------------------------------------------------------------------
    read -p "TLS Private Key file location on the local installing machine [~/ascender.key]:" t_key_path
    tls_key_path=${t_key_path:-~/ascender.key} 

    echo "" >> custom.config.yml
    echo "    # TLS Private Key file location on the local installing machine" >> custom.config.yml
    echo "tls_key_path: "\"$tls_key_path\" >> custom.config.yml
fi

# -----------------------------------------------------------------------------
# Location of the tmp_dir to be used for uninstall
# -----------------------------------------------------------------------------
read -p "Where will install artifacts be stored [{{ playbook_dir }}/../ascender_install_artifacts]? " dir
tmp_dir=${dir:-"{{ playbook_dir }}/../ascender_install_artifacts"}

echo "" >> custom.config.yml
echo "    # A directory in which to place both temporary artifacts" >> custom.config.yml
echo "    # and timestamped Kubernetes Manifests to make Ascender/Ledger easy" >> custom.config.yml
echo "    # to uninstall" >> custom.config.yml
echo "tmp_dir: \""$tmp_dir\" >> custom.config.yml

# -----------------------------------------------------------------------------
# DNS for the Ascender Install - ASCENDER_HOSTNAME
# -----------------------------------------------------------------------------
read -p "DNS resolvable hostname for Ascender service [ascender.example.com]: " a_hostname
ascender_hostname=${a_hostname:-ascender.example.com}

echo "" >> custom.config.yml
echo "    # The REQUIRED DNS resolvable hostname for Ascender service." >> custom.config.yml
echo "ASCENDER_HOSTNAME: "$ascender_hostname >> custom.config.yml

# -----------------------------------------------------------------------------
# Cloud Domain - ASCENDER_DOMAIN 
# -----------------------------------------------------------------------------
if [[ $k8s_platform == "eks" || $k8s_platform == "aks" || $k8s_platform == "gke" ]]; then
    # -------------------------------------------------------------------------
    # ASCENDER_DOMAIN
    # -------------------------------------------------------------------------
    read -p "DNS domain for Ascender service.  Required for cloud services [example.com]: " a_domain
    ascender_domain=${a_domain:-example.com}

    echo "" >> custom.config.yml
    echo "    # The DNS domain for Ascender service.  Required for cloud services." >> custom.config.yml
    echo "ASCENDER_DOMAIN: "$ascender_domain >> custom.config.yml
fi

# -----------------------------------------------------------------------------
# Google Managed Zone
# -----------------------------------------------------------------------------
if [[ ( $k8s_platform == "gke" ) && $use_googledns == "true" ]]; then
    # -------------------------------------------------------------------------
    # GOOGLE_DNS_MANAGED_ZONE
    # -------------------------------------------------------------------------
    read -p "If using Google Cloud DNS, provide the name of an existing hosted DNS zone for your DNS record. [example-com]:" g_hosted_zone
    google_hosted_zone=${g_hosted_zone:-example-com} 

    echo "" >> custom.config.yml
    echo "    # In Google Cloud DNS the name of an existing hosted DNS zone for your DNS record." >> custom.config.yml
    echo "GOOGLE_DNS_MANAGED_ZONE: "\"$google_hosted_zone\" >> custom.config.yml
fi

# -----------------------------------------------------------------------------
# ASCENDER_IMAGE - If only going with Ascender and not ledger
# -----------------------------------------------------------------------------
if [ $ledger_install != "true" -o $ledger_install_type == "Ledger" ]; then
    # Define ASCENDER_IMAGE variable
    read -p "The OCI container image for Ascender [ghcr.io/ctrliq/ascender]: " a_image
    ascender_image=${a_image:-ghcr.io/ctrliq/ascender}

    echo "" >> custom.config.yml
    echo "    # The OCI container image for Ascender" >> custom.config.yml
    echo "ASCENDER_IMAGE: "$ascender_image >> custom.config.yml
fi

# -----------------------------------------------------------------------------
# ASCENDER_NAMESPACE
# -----------------------------------------------------------------------------
read -p "Namespace for Ascender Kubernetes objects [ascender]: " a_namespace
ascender_namespace=${a_namespace:-ascender}

echo "" >> custom.config.yml
echo "    # Namespace for Ascender Kubernetes objects" >> custom.config.yml
echo "ASCENDER_NAMESPACE: "$ascender_namespace >> custom.config.yml

# -----------------------------------------------------------------------------
# ASCENDER_ADMIN_USER
# -----------------------------------------------------------------------------
read -p "Administrator username for Ascender [admin]: " a_admin_user
ascender_admin_user=${a_admin_user:-admin}

echo "" >> custom.config.yml
echo "    # Administrator username for Ascender" >> custom.config.yml
echo "ASCENDER_ADMIN_USER: "$ascender_admin_user >> custom.config.yml

# -----------------------------------------------------------------------------
# ASCENDER_ADMIN_PASSWORD variable
# -----------------------------------------------------------------------------
read -p "Administrator password for Ascender [myadminpassword]: " a_admin_password
ascender_admin_password=${a_admin_password:-myadminpassword}

echo "" >> custom.config.yml
echo "    # Administrator password for Ascender" >> custom.config.yml
echo "ASCENDER_ADMIN_PASSWORD: "\"$ascender_admin_password\" >> custom.config.yml

# -----------------------------------------------------------------------------
# ASCENDER_VERSION
# -----------------------------------------------------------------------------
read -p "The image tag indicating the version of Ascender you wish to install [25.1.0]: " a_version
ascender_version=${a_version:-25.1.0}

echo "" >> custom.config.yml
echo "    # The image tag indicating the version of Ascender you wish to install" >> custom.config.yml
echo "ASCENDER_VERSION: "$ascender_version >> custom.config.yml

# -----------------------------------------------------------------------------
# ANSIBLE_OPERATOR_VERSION
# -----------------------------------------------------------------------------
read -p "The version of the AWX Operator used to install Ascender and its components [2.19.0]: " a_operator_version
ascender_operator_version=${a_operator_version:-2.19.0}

echo "" >> custom.config.yml
echo "    # The version of the AWX Operator used to install Ascender and its components" >> custom.config.yml
echo "ANSIBLE_OPERATOR_VERSION: "$ascender_operator_version >> custom.config.yml

# -----------------------------------------------------------------------------
# ascender_garbage_collect_secrets
# -----------------------------------------------------------------------------
echo "Do you wish to keep secrets required to encrypt within Ascender (important when backing up)?"
options=(true false)
prompt="Select true or false: "
a_garbage_collect_secrets=$(prompt_for_input "$prompt" "${options[@]}")

echo "" >> custom.config.yml
echo "    # Determines whether to keep the secrets required to encrypt within Ascender (important when backing up)" >> custom.config.yml
echo "ascender_garbage_collect_secrets: "$a_garbage_collect_secrets >> custom.config.yml

# -----------------------------------------------------------------------------
# ASCENDER_PGSQL_HOST
# -----------------------------------------------------------------------------
read -p "If using an external PostgreSQL Server, specify it's IP Address or URL. Otherwise, hit enter and the installer will create one. [None]: " a_pgsql_host
ascender_pgsql_host=${a_pgsql_host:-None}

if [ $ascender_pgsql_host != "None" ]; then
    echo "" >> custom.config.yml
    echo "    # External PostgreSQL ip or url resolvable by the cluster" >> custom.config.yml
    echo "ASCENDER_PGSQL_HOST: "$ascender_pgsql_host >> custom.config.yml

    # -------------------------------------------------------------------------
    # ASCENDER_PGSQL_PORT
    # -------------------------------------------------------------------------
    read -p "External PostgreSQL port [5432]: " a_pgsql_port
    ascender_pgsql_port=${a_pgsql_port:-5432}

    echo "" >> custom.config.yml
    echo "    # External PostgreSQL port, this usually defaults to 5432" >> custom.config.yml
    echo "ASCENDER_PGSQL_PORT: "$ascender_pgsql_port >> custom.config.yml

    # -------------------------------------------------------------------------
    # ASCENDER_PGSQL_USER
    # -------------------------------------------------------------------------
    read -p "External PostgreSQL username [ascender]: " a_pgsql_user
    ascender_pgsql_user=${a_pgsql_user:-ascender}

    echo "" >> custom.config.yml
    echo "    # External PostgreSQL username" >> custom.config.yml
    echo "ASCENDER_PGSQL_USER: "$ascender_pgsql_user >> custom.config.yml

    # -------------------------------------------------------------------------
    # ASCENDER_PGSQL_PWD
    # -------------------------------------------------------------------------
    read -p "External PostgreSQL password. NOTE: Do NOT use special characters in the postgres password (Django requirement) [mypgadminpassword]: " a_pgsql_pwd
    ascender_pgsql_pwd=${a_pgsql_pwd:-ascender}

    echo "" >> custom.config.yml
    echo "    # External PostgreSQL password" >> custom.config.yml
    echo "ASCENDER_PGSQL_PWD: "$ascender_pgsql_pwd >> custom.config.yml

    # -------------------------------------------------------------------------
    # ASCENDER_PGSQL_DB
    # -------------------------------------------------------------------------
    read -p "External PostgreSQL database name used for Ascender (this DB must exist) [ascenderdb]: " a_pgsql_db
    ascender_pgsql_db=${a_pgsql_db:-ascenderdb}

    echo "" >> custom.config.yml
    echo "    # External PostgreSQL database name used for Ascender (this DB must exist)" >> custom.config.yml
    echo "ASCENDER_PGSQL_DB: "$ascender_pgsql_db >> custom.config.yml
fi

# -----------------------------------------------------------------------------
# ascender_replicas
# -----------------------------------------------------------------------------
read -p "Number of replicas for the Ascender web container [1]: " a_replicas
ascender_replicas=${a_replicas:-1}

echo "" >> custom.config.yml
echo "    # External PostgreSQL database name used for Ascender (this DB must exist)" >> custom.config.yml
echo "ascender_replicas: "$ascender_replicas >> custom.config.yml

# -----------------------------------------------------------------------------
# ascender_image_pull_policy
# -----------------------------------------------------------------------------
if [ "$k8s_offline" == "false" ]; then
    echo "Select the Ascender web container image pull policy (If unsure, choose IfNotPresent)"
    options=(IfNotPresent Always Never)
    prompt="Select an option: "
    image_pull_policy=$(prompt_for_input "$prompt" "${options[@]}")

    echo "" >> custom.config.yml
    echo "    # The Ascender web container image pull policy (If unsure, choose IfNotPresent)" >> custom.config.yml
    echo "image_pull_policy: "$image_pull_policy >> custom.config.yml
fi

# -----------------------------------------------------------------------------
# ascender_setup_playbooks
# -----------------------------------------------------------------------------
echo "Do you wish to install standard playbooks into Ascender after installation"
options=(true false)
prompt="Select true or false: "
ascender_setup_playbooks=$(prompt_for_input "$prompt" "${options[@]}")

echo "" >> custom.config.yml
echo "    # Boolean indicating whether to add standard playbooks into Ascender after installation" >> custom.config.yml
echo "ascender_setup_playbooks: "$ascender_setup_playbooks >> custom.config.yml

# -----------------------------------------------------------------------------
# We've already prompted for the ledger install
# -----------------------------------------------------------------------------
echo "" >> custom.config.yml
echo "    # Determines whether or not Ledger will be installed" >> custom.config.yml
echo "LEDGER_INSTALL: "$ledger_install >> custom.config.yml

# -----------------------------------------------------------------------------
# Ledger Install Details
# -----------------------------------------------------------------------------
if [ $ledger_install == "true" ]; then
    # -------------------------------------------------------------------------
    # LEDGER_HOSTNAME
    # -------------------------------------------------------------------------
    read -p "DNS resolvable hostname for Ledger service. This is required for install [ledger.example.com]: " l_hostname
    ledger_hostname=${l_hostname:-ledger.example.com}

    echo "" >> custom.config.yml
    echo "    # DNS resolvable hostname for Ledger service. This is required for install" >> custom.config.yml
    echo "LEDGER_HOSTNAME: "$ledger_hostname >> custom.config.yml

    if [ $ledger_install_type == "Ledger" ]; then
        # ----------------------------------------------------------------------
        # LEDGER_WEB_IMAGE
        # ----------------------------------------------------------------------
        read -p "The OCI container image for Ledger [ghcr.io/ctrliq/ascender-ledger/ledger-web]: " l_web_image
        ledger_web_image=${l_web_image:-ghcr.io/ctrliq/ascender-ledger/ledger-web}

        echo "" >> custom.config.yml
        echo "    # The OCI container image for Ledger" >> custom.config.yml
        echo "LEDGER_WEB_IMAGE: "$ledger_web_image >> custom.config.yml

        # ----------------------------------------------------------------------
        # LEDGER_PARSER_IMAGE
        # ----------------------------------------------------------------------
        read -p "The OCI container image for Ledger Parser [ghcr.io/ctrliq/ascender-ledger/ledger-parser]: " l_parser_image
        ledger_parser_image=${l_parser_image:-ghcr.io/ctrliq/ascender-ledger/ledger-parser}

        echo "" >> custom.config.yml
        echo "    # The OCI container image for Ledger Parser" >> custom.config.yml
        echo "LEDGER_PARSER_IMAGE: "$ledger_parser_image >> custom.config.yml

        # ----------------------------------------------------------------------
        # LEDGER_DB_IMAGE
        # ----------------------------------------------------------------------
        read -p "The OCI container image for Ledger DB [ghcr.io/ctrliq/ascender-ledger/ledger-db]: " l_db_image
        ledger_db_image=${l_db_image:-ghcr.io/ctrliq/ascender-ledger/ledger-db}

        echo "" >> custom.config.yml
        echo "    # The OCI container image for Ledger DB" >> custom.config.yml
        echo "LEDGER_DB_IMAGE: "$ledger_db_image >> custom.config.yml
    else
        # ----------------------------------------------------------------------
        # Depot Credentials
        # ----------------------------------------------------------------------
        echo "" >> custom.config.yml
        echo "    # We are installing Ledger Pro Depot Credentials below" >> custom.config.yml
		echo "LEDGER_REGISTRY:" >> custom.config.yml

        # ----------------------------------------------------------------------
        # Depot Base
        # ----------------------------------------------------------------------
        read -p "Enter your Depot Server address and port if not using https [depot.ciq.com]: " l_depot_server
        depot_server=${l_depot_serve:-depot.ciq.com}

        echo "    BASE: $depot_server" >> custom.config.yml

        # ----------------------------------------------------------------------
        # Depot Username
        # ----------------------------------------------------------------------
        read -p "Enter your Depot Server username [username]: " l_depot_username
        depot_username=${l_depot_username:-username}

        echo "    USERNAME: $depot_username" >> custom.config.yml

        # ----------------------------------------------------------------------
        # Depot Password
        # ----------------------------------------------------------------------
        read -p "Enter your Depot Server user token [yourtoken]: " l_depot_token
        depot_token=${l_depot_token:-youttoken}

        echo "    PASSWORD: $depot_token" >> custom.config.yml
    fi

    # -------------------------------------------------------------------------
    # ledger_web_replicas
    # -------------------------------------------------------------------------
    read -p "Number of replicas for the Ledger web container [1]: " l_web_replicas
    ledger_web_replicas=${l_web_replicas:-1}

    echo "" >> custom.config.yml
    echo "    # Number of replicas for the Ledger web container" >> custom.config.yml
    echo "ledger_web_replicas: "$ledger_web_replicas >> custom.config.yml

    # -------------------------------------------------------------------------
    # ledger_parser_replicas
    # -------------------------------------------------------------------------
    read -p "Number of replicas for the Ledger Parser container [1]: " l_parser_replicas
    ledger_parser_replicas=${l_parser_replicas:-1}

    echo "" >> custom.config.yml
    echo "    # Number of replicas for the Ledger Parser container" >> custom.config.yml
    echo "ledger_parser_replicas: "$ledger_parser_replicas >> custom.config.yml

    # -------------------------------------------------------------------------
    # LEDGER_VERSION
    # -------------------------------------------------------------------------
    read -p "The image tag indicating the version of Ledger you wish to install [latest]: " l_version
    ledger_version=${l_version:-latest}

    echo "" >> custom.config.yml
    echo "    # The image tag indicating the version of Ledger you wish to install" >> custom.config.yml
    echo "LEDGER_VERSION: "$ledger_version >> custom.config.yml

    # -------------------------------------------------------------------------
    # LEDGER_NAMESPACE
    # -------------------------------------------------------------------------
    read -p "The Kubernetes namespace in which Ledger objects will live [ledger]: " l_namespace
    ledger_namespace=${l_namespace:-ledger}

    echo "" >> custom.config.yml
    echo "    # The Kubernetes namespace in which Ledger objects will live" >> custom.config.yml
    echo "LEDGER_NAMESPACE: "$ledger_namespace >> custom.config.yml

    # -------------------------------------------------------------------------
    # LEDGER_ADMIN_PASSWORD
    # -------------------------------------------------------------------------
    read -p "Admin password for Ledger [myadminpassword]: " l_admin_password
    ledger_admin_password=${l_admin_password:-myadminpassword}

    echo "" >> custom.config.yml
    echo "    # Admin password for Ledger (the username is admin by default)" >> custom.config.yml
    echo "LEDGER_ADMIN_PASSWORD: "$ledger_admin_password >> custom.config.yml

    # -------------------------------------------------------------------------
    # LEDGER_DB_PASSWORD
    # -------------------------------------------------------------------------
    read -p "Password for Ledger database [mydbpassword]: " l_db_password
    ledger_db_password=${l_db_password:-mydbpassword}

    echo "" >> custom.config.yml
    echo "    # Password for Ledger database" >> custom.config.yml
    echo "LEDGER_DB_PASSWORD: "$ledger_db_password >> custom.config.yml
fi

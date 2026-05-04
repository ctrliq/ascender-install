#!/bin/bash

rm ./custom.config.yml

# k8s_platform
echo $'\n'
platforms=(k3s eks aks gke rke2 dkp ocp)
selected=()
PS3='Select the number of the Kubernetes platform you are using to install Ascender: '
select name in "${platforms[@]}" ; do
    for reply in $REPLY ; do
        selected+=(${platforms[reply - 1]})
    done
    [[ $selected ]] && break
done

k8s_platform=${selected[@]}

echo "---"$'\n'"# This variable specificies which Kubernetes platform Ascender and its components will be installed on." >> custom.config.yml
echo "k8s_platform: "$k8s_platform >> custom.config.yml

# k8s_offline
if [[ ( $k8s_platform == "k3s" || $k8s_platform == "rke2") ]]; then
    echo $'\n'
    k_offline=(true false)
    selected=()
    PS3='Boolean indicating whether to use local assets to complete an OFFLINE install (true) or perform a traditional install using internet resources (false): '
    select name in "${k_offline[@]}" ; do
        for reply in $REPLY ; do
            selected+=(${k_offline[reply - 1]})
        done
        [[ $selected ]] && break
    done

    k8s_offline=${selected[@]}
    echo "# Offline Install - Whether to use local assets to complete the install" >> custom.config.yml
    echo "k8s_offline: "$k8s_offline >> custom.config.yml

    if [ $k8s_offline == "true" ]; then
        echo $'\n'
        echo "# Offline Install - Whether to use local assets to complete the install" >> custom.config.yml
        echo "ANSIBLE_OPERATOR_OFFLINE_VERSION: 2.9.0" >> custom.config.yml
    fi

    # If offline is selected and platform is rke2, choose an alternate registry
    # k8s_container_registry
    if [[ ( $k8s_offline == "true" && $k8s_platform == "rke2") ]]; then
        echo $'\n'
        read -p "Specify an INTERNAL container registry and namespace where the k8s cluster can access Ascender images [format: registry.io/namespace]: " k_container_registry
        k8s_container_registry=${k_container_registry:-registry.io/namespace}
        echo "# Specify an INTERNAL container registry and namespace where the k8s cluster can access Ascender images" >> custom.config.yml
        echo "k8s_container_registry: "$k8s_container_registry >> custom.config.yml

        # k8s_image_pull_secret
        echo $'\n'
        read -p "Kubernetes secret containing the login credentials required for the INTERNAL registry holding the ASCENDER images. If no login credentials are required, leave as [None]: " k_image_pull_secret
        k8s_image_pull_secret=${k_image_pull_secret:-None}

        if [ $k8s_image_pull_secret != "None" ]; then
            echo $'\n'
            echo "# Kubernetes secret containing the login credentials required for the INTERNAL registry holding the ASCENDER images." >> custom.config.yml
            echo "k8s_image_pull_secret: "$k8s_image_pull_secret >> custom.config.yml
        fi

        # k8s_ee_pull_credentials_secret
        echo $'\n'
        read -p "Kubernetes secret containing the login credentials required for the INTERNAL registry holding the EXECUTION ENVIRONMENT images. If no login credentials are required, leave as [None]: " k_ee_pull_credentials_secret
        k8s_ee_pull_credentials_secret=${k_ee_pull_credentials_secret:-None}

        if [ $k8s_ee_pull_credentials_secret != "None" ]; then
            echo $'\n'
            echo "# Kubernetes secret containing the login credentials required for the INTERNAL registry holding the EXECUTION ENVIRONMENT images." >> custom.config.yml
            echo "k8s_ee_pull_credentials_secret: "$k8s_ee_pull_credentials_secret >> custom.config.yml
        fi

    fi
fi

# ee_images
echo $'\n'
u_ee_images=(true false)
selected=()
PS3='Do you wish to pull container images to serve as additional Execution Environments to run your playbooks? If unsure, choose false: '
select name in "${u_ee_images[@]}" ; do
    for reply in $REPLY ; do
        selected+=(${u_ee_images[reply - 1]})
    done
    [[ $selected ]] && break
done
use_ee_images=${selected[@]}

if [ $use_ee_images == "true" ]; then
    echo "ee_images:" >> custom.config.yml
    while true
    do
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

# k8s_lb_protocol
echo $'\n'
ssl=(http https)
selected=()
PS3='Select the number of the prototol you want to support. Selecting 'https' requires the SSL certificate being present: '
select name in "${ssl[@]}" ; do
    for reply in $REPLY ; do
        selected+=(${ssl[reply - 1]})
    done
    [[ $selected ]] && break
done
k8s_lb_protocol=${selected[@]}
echo "# Determines whether to use HTTP or HTTPS for Ascender." >> custom.config.yml
echo "# If set to https, you MUST provide certificate/key options for the Installer to use." >> custom.config.yml
echo "k8s_lb_protocol: "$k8s_lb_protocol >> custom.config.yml

# k3s_master_node_ip
echo $'\n'
if [ $k8s_platform == "k3s" ]; then
   echo $'\n'
   read -p "Routable IP address for the K3s Master/Worker node [127.0.0.1]: " k3s_m_node_ip
   k3s_master_node_ip=${k3s_m_node_ip:-127.0.0.1}
   echo "# Routable IP address for the K3s Master/Worker node" >> custom.config.yml
   echo "# required for DNS and k3s install" >> custom.config.yml
   echo "k3s_master_node_ip: "\"$k3s_master_node_ip\" >> custom.config.yml
fi

# kubeapi_server_ip
if [ $k8s_platform == "rke2" ]; then
   echo $'\n'
   read -p "Routable IP address for the K8s API Server (This could be a Load Balancer if using 3 K8s control nodes) [127.0.0.1]: " k8s_api_srvr_ip
   kubeapi_server_ip=${k8s_api_srvr_ip:-127.0.0.1}
   echo "# Routable IP address for the K8s API Server" >> custom.config.yml
   echo "# (This could be a Load Balancer if using 3 K8s control nodes)" >> custom.config.yml
   echo "kubeapi_server_ip: "\"$kubeapi_server_ip\" >> custom.config.yml
fi

if [ $k8s_platform == "eks" ]; then
   
   # USE_ROUTE_53
   echo $'\n'
   use_r53=(true false)
   selected=()
   PS3='Boolean indicating Determines whether to use Route53 Domain Management (true) Or a third-party service such as Cloudflare or GoDaddy (false). If this value is set to false, you will have to manually set a CNAME record for Ascender to point to their respective AWS Load Balancers: '
   select name in "${use_r53[@]}" ; do
       for reply in $REPLY ; do
           selected+=(${use_r53[reply - 1]})
       done
       [[ $selected ]] && break
   done

   use_route_53=${selected[@]}
   echo "# Determines whether to use Route53's Domain Management (which is automated)" >> custom.config.yml
   echo "# Or a third-party service (e.g., Cloudflare, GoDaddy, etc.)" >> custom.config.yml
   echo "# If this value is set to false, you will have to manually set a CNAME record for" >> custom.config.yml
   echo "# {{ASCENDER_HOSTNAME }} to point to the AWS" >> custom.config.yml
   echo "# Loadbalancers" >> custom.config.yml
   echo "USE_ROUTE_53: "$use_route_53 >> custom.config.yml

fi

if [ $k8s_platform == "aks" ]; then
   
   # USE_AZURE_DNS
   echo $'\n'
   use_azuredns=(true false)
   selected=()
   PS3='Boolean indicating Determines whether to use Azure DNS Domain Management (true) Or a third-party service such as Cloudflare or GoDaddy (false). If this value is set to false, you will have to manually set an A record for Ascender to point to their respective Azure Load Balancers: '
   select name in "${use_azuredns[@]}" ; do
       for reply in $REPLY ; do
           selected+=(${use_azuredns[reply - 1]})
       done
       [[ $selected ]] && break
   done

   use_azuredns=${selected[@]}
   echo "# Determines whether to use Azure DNS Domain Management (which is automated)" >> custom.config.yml
   echo "# Or a third-party service (e.g., Cloudflare, GoDaddy, etc.)" >> custom.config.yml
   echo "# If this value is set to false, you will have to manually set an A record for" >> custom.config.yml
   echo "# {{ASCENDER_HOSTNAME }} to point to the Azure" >> custom.config.yml
   echo "# Loadbalancers" >> custom.config.yml
   echo "USE_AZURE_DNS: "$use_azuredns >> custom.config.yml
fi

if [ $k8s_platform == "gke" ]; then

   # USE_GOOGLE_DNS
   echo $'\n'
   use_googledns=(true false)
   selected=()
   PS3='Boolean indicating Determines whether to use Google Cloud DNS Domain Management (true) Or a third-party service such as Cloudflare or GoDaddy (false). If this value is set to false, you will have to manually set an A record for Ascender to point to their respective Google Cloud Load Balancers: '
   select name in "${use_googledns[@]}" ; do
       for reply in $REPLY ; do
           selected+=(${use_googledns[reply - 1]})
       done
       [[ $selected ]] && break
   done

   use_googledns=${selected[@]}
   echo "# Determines whether to use Google Cloud DNS Domain Management (which is automated)" >> custom.config.yml
   echo "# Or a third-party service (e.g., Cloudflare, GoDaddy, etc.)" >> custom.config.yml
   echo "# If this value is set to false, you will have to manually set an A record for" >> custom.config.yml
   echo "# {{ASCENDER_HOSTNAME }} to point to the Google Cloud" >> custom.config.yml
   echo "# Loadbalancers" >> custom.config.yml
   echo "USE_GOOGLE_DNS: "$use_googledns >> custom.config.yml
fi
if [[ ( $k8s_platform == "k3s" || $k8s_platform == "dkp" || $k8s_platform == "rke2") ]]; then
   echo $'\n'
   u_etc_hosts=(true false)
   selected=()
   PS3='Boolean indicating whether to use the local /etc/hosts file for DNS resolution to access Ascender: '
   select name in "${u_etc_hosts[@]}" ; do
       for reply in $REPLY ; do
           selected+=(${u_etc_hosts[reply - 1]})
       done
       [[ $selected ]] && break
   done
   use_etc_hosts=${selected[@]}
   echo "# Boolean indicating whether to use the local /etc/hosts file for DNS resolution to access Ascender" >> custom.config.yml
   echo "use_etc_hosts: "$use_etc_hosts >> custom.config.yml
fi

if [[ ( $k8s_platform == "k3s" || $k8s_platform == "dkp" || $k8s_platform == "rke2" || $k8s_platform == "aks" || $k8s_platform == "gke" || $k8s_platform == "eks" ) && $k8s_lb_protocol == "https" ]]; then
   #tls_crt_path
   echo $'\n'
   read -p "TLS Certificate file location on the local installing machine [~/ascender.crt]:" t_cert_path
   tls_cert_path=${t_cert_path:-~/ascender.crt} 
   echo "# TLS Certificate file location on the local installing machine" >> custom.config.yml
   echo "tls_crt_path: "\"$tls_cert_path\" >> custom.config.yml

   #tls_key_path
   echo $'\n'
   read -p "TLS Private Key file location on the local installing machine [~/ascender.key]:" t_key_path
   tls_key_path=${t_key_path:-~/ascender.key} 
   echo "# TLS Private Key file location on the local installing machine" >> custom.config.yml
   echo "tls_key_path: "\"$tls_key_path\" >> custom.config.yml
fi

# tmp_dir
echo $'\n'
echo "# A directory in which to place both temporary artifacts" >> custom.config.yml
echo "# and timestamped Kubernetes Manifests to make Ascender easy" >> custom.config.yml
echo "# to uninstall" >> custom.config.yml
read -p "Where will install artifacts be stored [{{ playbook_dir}}/../ascender_install_artifacts]? " dir
tmp_dir=${dir:-"{{ playbook_dir}}/../ascender_install_artifacts"}
echo "tmp_dir: \""$tmp_dir\" >> custom.config.yml

# ASCENDER_HOSTNAME
echo $'\n'
echo "# DNS resolvable hostname for Ascender service. This is required for install." >> custom.config.yml
read -p "DNS resolvable hostname for Ascender service [ascender.example.com]: " a_hostname
ascender_hostname=${a_hostname:-ascender.example.com}
echo "ASCENDER_HOSTNAME: "$ascender_hostname >> custom.config.yml

if [[ $k8s_platform == "eks" || $k8s_platform == "aks" || $k8s_platform == "gke" ]]; then
   # ASCENDER_DOMAIN
   echo $'\n'
   echo "# DNS domain for Ascender service. This is required when hosting on cloud services." >> custom.config.yml
   read -p "DNS domain for Ascender service. This is required when hosting on cloud services [example.com]: " a_domain
   ascender_domain=${a_domain:-example.com}
   echo "ASCENDER_DOMAIN: "$ascender_domain >> custom.config.yml
fi

if [[ (  $k8s_platform == "gke" ) && $use_googledns == "true" ]]; then
   #GOOGLE_DNS_MANAGED_ZONE
   echo $'\n'
   read -p "If using Google Cloud DNS, provide the name of an existing hosted DNS zone for your DNS record. [example-com]:" g_hosted_zone
   google_hosted_zone=${g_hosted_zone:-example-com} 
   echo "# In Google Cloud DNS the name of an existing hosted DNS zone for your DNS record." >> custom.config.yml
   echo "GOOGLE_DNS_MANAGED_ZONE: "\"$google_hosted_zone\" >> custom.config.yml
fi

# ASCENDER_NAMESPACE
echo $'\n'
read -p "Namespace for Ascender Kubernetes objects [ascender]: " a_namespace
ascender_namespace=${a_namespace:-ascender}
echo "# Namespace for Ascender Kubernetes objects" >> custom.config.yml
echo "ASCENDER_NAMESPACE: "$ascender_namespace >> custom.config.yml

# ASCENDER_ADMIN_USER
echo $'\n'
echo "# Administrator username for Ascender" >> custom.config.yml
read -p "Administrator username for Ascender [admin]: " a_admin_user
ascender_admin_user=${a_admin_user:-admin}
echo "ASCENDER_ADMIN_USER: "$ascender_admin_user >> custom.config.yml

# Define ASCENDER_ADMIN_PASSWORD variable
echo $'\n'
echo "# Administrator password for Ascender" >> custom.config.yml
read -p "Administrator password for Ascender [myadminpassword]: " a_admin_password
ascender_admin_password=${a_admin_password:-myadminpassword}
echo "ASCENDER_ADMIN_PASSWORD: "\"$ascender_admin_password\" >> custom.config.yml

# Define ASCENDER_IMAGE variable
# echo $'\n'
# echo "# The OCI container image for Ascender" >> custom.config.yml
# read -p "The OCI container image for Ascender [ghcr.io/ctrliq/ascender]: " a_image
# ascender_image=${a_image:-ghcr.io/ctrliq/ascender}
# echo "ASCENDER_IMAGE: "$ascender_image >> custom.config.yml

# ASCENDER_VERSION
echo $'\n'
echo "# The image tag indicating the version of Ascender you wish to install" >> custom.config.yml
read -p "The image tag indicating the version of Ascender you wish to install [25.3.6]: " a_version
ascender_version=${a_version:-25.3.6}
echo "ASCENDER_VERSION: "$ascender_version >> custom.config.yml

# ASCENDER_OPERATOR_VERSION
echo $'\n'
echo "# The version of the AWX Operator used to install Ascender and its components" >> custom.config.yml
read -p "The version of the AWX Operator used to install Ascender and its components [2.19.5]: " a_operator_version
ascender_operator_version=${a_operator_version:-2.19.5}
echo "ASCENDER_OPERATOR_VERSION: "$ascender_operator_version >> custom.config.yml

# ascender_garbage_collect_secrets
echo $'\n'
garbage_collect_secrets=(true false)
selected=()
PS3='Boolean indicating whether to keep the secrets required to encrypt within Ascender (important when backing up): '
select name in "${garbage_collect_secrets[@]}" ; do
    for reply in $REPLY ; do
        selected+=(${garbage_collect_secrets[reply - 1]})
    done
    [[ $selected ]] && break
done
a_garbage_collect_secrets=${selected[@]}
echo "# Determines whether to keep the secrets required to encrypt within Ascender (important when backing up)" >> custom.config.yml
echo "ascender_garbage_collect_secrets: "$a_garbage_collect_secrets >> custom.config.yml

# ASCENDER_PGSQL_HOST
echo $'\n'
read -p "External PostgreSQL ip or url resolvable by the cluster. If you prefer to have Ascender create and manage a PostgreSQL DB, leave as [None]: " a_pgsql_host
ascender_pgsql_host=${a_pgsql_host:-None}

if [ $ascender_pgsql_host != "None" ]; then
   echo $'\n'
   echo "# External PostgreSQL ip or url resolvable by the cluster" >> custom.config.yml
   echo "ASCENDER_PGSQL_HOST: "$ascender_pgsql_host >> custom.config.yml

   # ASCENDER_PGSQL_PORT
   echo $'\n'
   read -p "External PostgreSQL port [5432]: " a_pgsql_port
   ascender_pgsql_port=${a_pgsql_port:-5432}
   echo "# External PostgreSQL port, this usually defaults to 5432" >> custom.config.yml
   echo "ASCENDER_PGSQL_PORT: "$ascender_pgsql_port >> custom.config.yml

   # ASCENDER_PGSQL_USER
   echo $'\n'
   read -p "External PostgreSQL username [ascender]: " a_pgsql_user
   ascender_pgsql_user=${a_pgsql_user:-ascender}
   echo "# External PostgreSQL username" >> custom.config.yml
   echo "ASCENDER_PGSQL_USER: "$ascender_pgsql_user >> custom.config.yml

   # ASCENDER_PGSQL_PWD
   echo $'\n'
   read -p "External PostgreSQL password. NOTE: Do NOT use special characters in the postgres password (Django requirement) [mypgadminpassword]: " a_pgsql_pwd
   ascender_pgsql_pwd=${a_pgsql_pwd:-ascender}
   echo "# External PostgreSQL password" >> custom.config.yml
   echo "ASCENDER_PGSQL_PWD: "$ascender_pgsql_pwd >> custom.config.yml

   # ASCENDER_PGSQL_DB
   echo $'\n'
   read -p "External PostgreSQL database name used for Ascender (this DB must exist) [ascenderdb]: " a_pgsql_db
   ascender_pgsql_db=${a_pgsql_db:-ascenderdb}
   echo "# External PostgreSQL database name used for Ascender (this DB must exist)" >> custom.config.yml
   echo "ASCENDER_PGSQL_DB: "$ascender_pgsql_db >> custom.config.yml
fi

# ascender_replicas
echo $'\n'
read -p "Number of replicas for the Ascender web container [1]: " a_replicas
ascender_replicas=${a_replicas:-1}
echo "# External PostgreSQL database name used for Ascender (this DB must exist)" >> custom.config.yml
echo "ascender_replicas: "$ascender_replicas >> custom.config.yml


# ascender_image_pull_policy
if [ "$k8s_offline" == "false" ]; then
    echo $'\n'
    pull_policy=(IfNotPresent Always Never)
    selected=()
    PS3='Select the Ascender web container image pull policy (If unsure, choose IfNotPresent): '
    select name in "${pull_policy[@]}" ; do
        for reply in $REPLY ; do
            selected+=(${pull_policy[reply - 1]})
        done
        [[ $selected ]] && break
    done
    image_pull_policy=${selected[@]}
    echo "# The Ascender web container image pull policy (If unsure, choose IfNotPresent)" >> custom.config.yml
    echo "image_pull_policy: "$image_pull_policy >> custom.config.yml
fi

# ascender_setup_playbooks
echo $'\n'
a_setup_playbooks=(true false)
selected=()
PS3='Boolean indicating whether to add standard playbooks into Ascender after installation: '
select name in "${a_setup_playbooks[@]}" ; do
    for reply in $REPLY ; do
        selected+=(${a_setup_playbooks[reply - 1]})
    done
    [[ $selected ]] && break
done
ascender_setup_playbooks=${selected[@]}
echo "# Boolean indicating whether to add standard playbooks into Ascender after installation" >> custom.config.yml
echo "ascender_setup_playbooks: "$ascender_setup_playbooks >> custom.config.yml

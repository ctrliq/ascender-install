#!/bin/bash
# Ask the user for their name
# echo Hello, who am I talking to?
# read varname
# echo It\'s nice to meet you $varname
rm ./custom.config.yml 

platforms=(k3s eks dkp)
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
echo "# Determines whether to use HTTP or HTTPS for Ascender and Ledger." >> custom.config.yml
echo "# If set to https, you MUST provide certificate/key options for the Installer to use." >> custom.config.yml
echo "k8s_lb_protocol: "$k8s_lb_protocol >> custom.config.yml

# Define tmp_dir variable
echo "# A directory in which to place both temporary artifacts" >> custom.config.yml
echo "# and timestamped Kubernetes Manifests to make Ascender/Ledger easy" >> custom.config.yml
echo "# to uninstall" >> custom.config.yml
read -p "Where will install artifacts be stored [/tmp/ascender_install_artifacts]? " dir
tmp_dir=${dir:-/tmp/ascender_install_artifacts}
echo "tmp_dir: \""$tmp_dir\" >> custom.config.yml

# Define ASCENDER_HOSTNAME variable
echo "# DNS resolvable hostname for Ascender service. This is required for install." >> custom.config.yml
read -p "DNS resolvable hostname for Ascender service [ascender.example.com]: " a_hostname
ascender_hostname=${a_hostname:-ascender.example.com}
echo "ASCENDER_HOSTNAME: "$ascender_hostname >> custom.config.yml

# Define ASCENDER_DOMAIN variable
if [ $k8s_platform="eks" ]; then
   echo "# DNS domain for Ascender service. This is required when hosting on cloud services." >> custom.config.yml
   read -p "DNS domain for Ascender service. This is required when hosting on cloud services [example.com]: " a_domain
   ascender_domain=${a_domain:-ascender.example.com}
   echo "ASCENDER_DOMAIN: "$ascender_domain >> custom.config.yml
fi

# Define ASCENDER_NAMESPACE variable
echo "Namespace for Ascender Kubernetes objects" >> custom.config.yml
read -p "Namespace for Ascender Kubernetes objects [ascender]: " a_namespace
ascender_namespace=${a_namespace:-ascender.example.com}
echo "ASCENDER_NAMESPACE: "$ascender_namespace >> custom.config.yml

# Define ASCENDER_ADMIN_USER variable
echo "# Administrator username for Ascender" >> custom.config.yml
read -p "Administrator username for Ascender [admin]: " a_admin_user
ascender_admin_user=${a_admin_user:-admin}
echo "ASCENDER_ADMIN_USER: "$ascender_admin_user >> custom.config.yml

# Define ASCENDER_ADMIN_PASSWORD variable
echo "# Administrator password for Ascender" >> custom.config.yml
read -p "Administrator password for Ascender [myadminpassword]: " a_admin_password
ascender_admin_password=${a_admin_password:-myadminpassword}
echo "ASCENDER_ADMIN_PASSWORD: "\"$ascender_admin_password\" >> custom.config.yml

# Define ASCENDER_IMAGE variable
echo "# The OCI container image for Ascender" >> custom.config.yml
read -p "The OCI container image for Ascender [ghcr.io/ctrliq/ascender]: " a_image
ascender_image=${a_image:-ghcr.io/ctrliq/ascender}
echo "ASCENDER_IMAGE: "$ascender_image >> custom.config.yml

# ASCENDER_VERSION

# ANSIBLE_OPERATOR_VERSION

# ascender_garbage_collect_secrets

# ASCENDER_PGSQL_HOST

# ASCENDER_PGSQL_PORT

# ASCENDER_PGSQL_USER

# ASCENDER_PGSQL_PWD

# ASCENDER_PGSQL_DB

# ascender_replicas

# ascender_image_pull_policy

# LEDGER_INSTALL

# LEDGER_HOSTNAME

# LEDGER_WEB_IMAGE

# ledger_web_replicas

# LEDGER_PARSER_IMAGE

# ledger_parser_replicas

# LEDGER_DB_IMAGE

# LEDGER_VERSION

# LEDGER_NAMESPACE

# LEDGER_ADMIN_PASSWORD

# LEDGER_DB_PASSWORD
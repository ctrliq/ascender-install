#!/bin/bash

# -----------------------------------------------------------------------------
# Copyright (c) 2023-2025, Ctrl IQ, Inc. All rights reserved.
#
# Core functions for the Ascender Installer.
# -----------------------------------------------------------------------------

prompt_for_input() {
  local prompt="$1"
  shift
  local variables=("$@")
  local selected=()
  local upper=${#variables[@]}

  PS3="$prompt"
  select name in $@; do
    if [ -n "$REPLY" ] && [[ $REPLY =~ ^[0-9]+$ ]] && [ "$REPLY" -gt 0 ] && [ "$REPLY" -le "$upper" ]; then
      for reply in $REPLY ; do
        selected+=("${variables[reply - 1]}")
      done
      [[ $selected ]] && break
    fi
  done

  echo $selected
}

check_for_errors() {
  # -----------------------------------------------------------------------------
  # Read the k8s_platform value from the configuration file
  # -----------------------------------------------------------------------------
  k8s_platform=$(grep '^k8s_platform:' "$config_file" | awk '{print $2}')

  # -----------------------------------------------------------------------------
  # Check if the k8s_platform is either "eks", "gke" or "aks"
  # -----------------------------------------------------------------------------
  if [[ "$k8s_platform" == "eks" || "$k8s_platform" == "gke" || "$k8s_platform" == "aks" ]]; then
    # Check if the script is run as root or with sudo
    if [ "$(id -u)" -eq 0 ]; then
      echo "Error: This script must not be run as root or with sudo when k8s_platform is $k8s_platform."
      exit 1
    fi

    # Check if the system is RHEL or Rocky Linux version 9 or higher
    os_family=$(grep -oP '(?<=^ID_LIKE=).+' /etc/os-release | tr -d '"')
    os_version=$(grep '^VERSION_ID=' /etc/os-release | cut -d'=' -f2 | tr -d '"' | cut -d. -f1)

    if [[ "$os_family" == *"rhel"* || "$os_family" == *"fedora"* || "$os_family" == *"centos"* ]]; then
      if [ "$os_version" -lt 9 ]; then
        echo "Error: This script must be run on RHEL or Rocky Linux version 9 or higher when k8s_platform is $k8s_platform."
        exit 1
      fi
    else
      echo "Error: Unsupported OS family $os_family. This script must be run on RHEL or Rocky Linux when k8s_platform is $k8s_platform."
      exit 1
    fi
  fi

  # -----------------------------------------------------------------------------
  # Verify that the CPU architecture of the local machine is x86_64
  # -----------------------------------------------------------------------------
  LINUX_ARCH=$(arch)
  if [[ $LINUX_ARCH != "x86_64" ]]; then
    echo "CPU architecture must be x86_64.";
    exit 1
  fi

  # -----------------------------------------------------------------------------
  # Verify that the Operating system of the local machine is in the centos/rocky family
  # -----------------------------------------------------------------------------
  OS_FAMILY=$(grep -oP '(?<=^ID_LIKE=).+' /etc/os-release)
  if !([[ "$OS_FAMILY" =~ "rhel" || "$OS_FAMILY" =~ "fedora" || "$OS_FAMILY" =~ "centos" ]]); then
    echo "Error: The OS family must be Rocky, RHEL, Fedora or CentOS";
    exit 1
  fi

  # -----------------------------------------------------------------------------
  # Verify that the Operating System major version of the local machine is either 8 or 9
  # -----------------------------------------------------------------------------
  LINUX_VERSION=$(grep -oP '(?<=^VERSION_ID=).+' /etc/os-release | tr -d '"' | cut -d. -f1)
  if [[ $LINUX_VERSION != "9" && $LINUX_VERSION != "8" ]]; then
    echo "Linux major version must be 8 or 9.";
    exit 1
  fi
}

check_ansible() {
  type -p ansible-playbook > /dev/null
}

check_collections() {
  ansible-doc -t module -l | grep ansible.posix.selinux > /dev/null
  if [ $? -ne 0 ]; then
    return 0
  fi
  ansible-doc -t module -l | grep awx.awx.settings > /dev/null
  if [ $? -ne 0 ]; then
    return 0
  fi
  ansible-doc -t module -l | grep kubernetes.core.k8s > /dev/null
  if [ $? -ne 0 ]; then
    return 0
  fi
  ansible-doc -t module -l | grep amazon.aws.ec2_instance > /dev/null
  if [ $? -ne 0 ]; then
    return 0
  fi

  return 1 
}


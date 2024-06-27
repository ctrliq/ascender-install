#!/bin/bash

# Copyright (c) 2023, Ctrl IQ, Inc. All rights reserved.

# Verify that the CPU architecture of the local machine is x86_64
LINUX_ARCH=$(arch)
if [[ $LINUX_ARCH != "x86_64" ]]; then
  echo "CPU architecture must be x86_64."; exit $ERRCODE;
fi 

# Verify that the Operating system of the local machine is in the centos/rocky family
OS_FAMILY=$(grep -oP '(?<=^ID_LIKE=).+' /etc/os-release)
if !([[ "$OS_FAMILY" =~ "rhel" || "$OS_FAMILY" =~ "fedora" || "$OS_FAMILY" =~ "centos" ]]); then
  echo "The OS family must be rocky, rhel, fedora or centos"; exit $ERRCODE;
fi

# Verify that the Operating System major version of the local machine is either 8 or 9
LINUX_VERSION=$(grep -oP '(?<=^VERSION_ID=).+' /etc/os-release | tr -d '"' | cut -d. -f1)
if [[ $LINUX_VERSION != "9" && $LINUX_VERSION != "8" ]]; then
  echo "Linux major version must be 8 or 9."; exit $ERRCODE;
fi 

# COLORIZE THE ANSIBLE SHELL
if [ -t "0" ]; then
  ANSIBLE_FORCE_COLORS=True
fi

if [ -f "$(dirname $0)/inventory.yml" ]; then
  INVENTORY_FILE="$(dirname $0)/inventory.yml"
else
  INVENTORY_FILE="$(dirname $0)/inventory"
fi

echo "Using Inventory File: ${INVENTORY_FILE}"

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

# ------------------------- #

check_ansible
if [ $? -ne 0 ]; then
  echo "#### INSTALLING ANSIBLE ####"
  sudo dnf install -y ansible-core
fi

check_collections
if [ $? -ne 1 ]; then
  echo "#### INSTALLING COLLECTIONS ####"
  if [ -f "$(dirname $0)/offline/collections/ansible-posix-1.5.4.tar.gz" ]; then
    ansible-galaxy collection install $(dirname $0)/offline/collections/ansible-posix-1.5.4.tar.gz
    ansible-galaxy collection install $(dirname $0)/offline/collections/awx-awx-22.3.0.tar.gz
    ansible-galaxy collection install $(dirname $0)/offline/collections/kubernetes-core-2.4.0.tar.gz
    ansible-galaxy collection install $(dirname $0)/offline/collections/amazon-aws-6.5.0.tar.gz
  else
    ansible-galaxy install -r collections/requirements.yml
  fi
fi

PASSED_ARG=$@
if [[ ${#PASSED_ARG} -ne 0 ]]
then
  while getopts "pbr" ARG; do

    case $ARG in

      p)
      
        printf "\nCREATE CLOUD PERMISSIONS ARTIFACTS\n"

        ansible-playbook -i "${INVENTORY_FILE}" playbooks/apply_cloud_permissions.yml

        printf "\n\nNOTE: Check the ./ascender_install_artifacts directory for cloud permissions files.\n\n"
        ;;
      b)
      
        printf "\nBACKUP\n"

        ansible-playbook -i "${INVENTORY_FILE}" playbooks/backup.yml
        ;;
      r)

        echo "RESTORE"

        ansible-playbook -i "${INVENTORY_FILE}" playbooks/restore.yml
        ;;
      \?) 

        exit
        ;;
    esac
  done
else
  ansible-playbook -i "${INVENTORY_FILE}" playbooks/setup.yml

  RC=$?
  if [ ${RC} -ne 0 ]; then
    echo "ERROR OCCURRED DURING SETUP"
  else
    echo "ASCENDER SUCCESSFULLY SETUP"
  fi
fi
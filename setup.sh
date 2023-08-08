#!/bin/bash

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
  ansible-doc -t module -l | grep awx.awx.settings > /dev/null
  if [ $? -ne 0 ]; then
    return 0
  fi
  ansible-doc -t module -l | grep kubernetes.core.k8s > /dev/null
  if [ $? -ne 0 ]; then
    return 0
  fi
  ansible-doc -t module -l | grep ansible.posix.selinux > /dev/null
  if [ $? -ne 0 ]; then
    return 0
  fi
  return 1 
}

# ------------------------- #

check_ansible
if [ $? -ne 0 ]; then
  echo "#### INSTALLING ANSIBLE ####"
  dnf install ansible-core
fi

check_collections
if [ $? -ne 1 ]; then
  echo "#### INSTALLING COLLECTIONS ####"
  ansible-galaxy install -r collections/requirements.yml
fi

ansible-playbook -i "${INVENTORY_FILE}" playbooks/setup.yml

RC=$?
if [ ${RC} -ne 0 ]; then
  echo "ERROR OCCURRED DURING SETUP"
else
  echo "ASCENDER SUCCESSFULLY SETUP"
fi
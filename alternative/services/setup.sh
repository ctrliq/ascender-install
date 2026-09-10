#!/bin/bash

# Copyright (c) 2026, Ctrl IQ, Inc. All rights reserved.

# Installs Ascender as host services on the Rocky 9 host(s) in the inventory:
# makes sure Ansible and the required collections are present, checks the
# inventory, then runs install.yml. Extra arguments are passed to
# ansible-playbook (for example: ./setup.sh --check, ./setup.sh -e ascender_version=25.6.2).

cd "$(dirname "$0")" || exit 1

OS_FAMILY=$(grep -oP '(?<=^ID_LIKE=).+' /etc/os-release | tr -d '"')
if [ "$OS_FAMILY" == "" ]; then
  OS_FAMILY=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"')
fi
OS=""

if [[ "$OS_FAMILY" == *"rhel"* || "$OS_FAMILY" == *"fedora"* || "$OS_FAMILY" == *"centos"* ]]; then
  OS="rhel"
elif [[ "$OS_FAMILY" == *"debian"* || "$OS_FAMILY" == *"ubuntu"* ]]; then
  OS="debian"
fi

# COLORIZE THE ANSIBLE SHELL
if [ -t "0" ]; then
  export ANSIBLE_FORCE_COLOR=True
fi

if [ -f "inventory.yml" ]; then
  INVENTORY_FILE="inventory.yml"
else
  INVENTORY_FILE="inventory"
fi

check_ansible() {
  type -p ansible-playbook > /dev/null
}

check_collections() {
  # Returns 1 when everything is present, 0 when something is missing.
  ansible-doc -t module -l 2>/dev/null | grep -q community.postgresql.postgresql_db || return 0
  ansible-doc -t module -l 2>/dev/null | grep -q ansible.posix.seboolean || return 0
  ansible-doc -t module -l 2>/dev/null | grep -q community.general.sefcontext || return 0
  ansible-doc -t lookup -l 2>/dev/null | grep -q community.general.random_string || return 0
  return 1
}

check_inventory() {
  if [ ! -f "${INVENTORY_FILE}" ]; then
    echo "Error: inventory file '${INVENTORY_FILE}' not found."
    echo "       Copy inventory.example to inventory and set the host, ascender_hostname and ascender_version."
    return 1
  fi

  local hosts
  hosts=$(ansible-inventory -i "${INVENTORY_FILE}" --list 2>/dev/null | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except ValueError:
    sys.exit(0)
print(" ".join(data.get("ascender", {}).get("hosts", [])))')
  if [ -z "${hosts}" ]; then
    echo "Error: inventory '${INVENTORY_FILE}' has no hosts in the [ascender] group."
    return 1
  fi
  echo "Ascender host(s): ${hosts}"
  return 0
}

# ------------------------- #

check_ansible
if [ $? -ne 0 ]; then
  echo "#### INSTALLING ANSIBLE ####"
  if [[ "$OS" == "debian" ]]; then
    sudo apt-get update -y && sudo apt-get install -y ansible-core
  elif [[ "$OS" == "rhel" ]]; then
    sudo dnf install -y ansible-core
  else
    echo "Error: Unsupported OS family $OS_FAMILY. Unable to install Ansible automatically."
    exit 1
  fi

  check_ansible
  if [ $? -ne 0 ]; then
    echo "Error: Ansible installation failed. Please install ansible-core and re-run this script."
    exit 1
  fi
fi

check_collections
if [ $? -ne 1 ]; then
  echo "#### INSTALLING COLLECTIONS ####"
  ansible-galaxy collection install -r requirements.yml
  if [ $? -ne 0 ]; then
    echo "Error: collection installation failed. Install them with: ansible-galaxy collection install -r requirements.yml"
    exit 1
  fi

  check_collections
  if [ $? -ne 1 ]; then
    echo "Error: required collections are still missing after installation."
    exit 1
  fi
fi

echo "Using Inventory File: ${INVENTORY_FILE}"
check_inventory || exit 1

ansible-playbook -i "${INVENTORY_FILE}" install.yml "$@"

RC=$?
if [ ${RC} -ne 0 ]; then
  echo "ERROR OCCURRED DURING SETUP"
else
  echo "ASCENDER SUCCESSFULLY SETUP"
fi

exit "${RC}"

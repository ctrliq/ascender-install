#!/bin/bash

# Copyright (c) 2026, Ctrl IQ, Inc. All rights reserved.

# Determine the OS family so we know which package manager to use
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

check_ansible() {
  type -p ansible-playbook > /dev/null
}

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

ANSIBLE_STDOUT_CALLBACK=minimum_text ansible-playbook -i 'localhost,' playbooks/config_vars.yml

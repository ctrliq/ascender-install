#!/bin/bash

# COLORIZE THE ANSIBLE SHELL
if [ -t "0" ]; then
  ANSIBLE_FORCE_COLORS=True
fi
INVENTORY_FILE="$(dirname $0)/inventory"

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

PASSED_ARG=$@
if [[ ${#PASSED_ARG} -ne 0 ]]
then
  while getopts "br" ARG; do

    case $ARG in

      b)
      
        echo "BACKUP"

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
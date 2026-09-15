#!/bin/bash

# Copyright (c) 2026, Ctrl IQ, Inc. All rights reserved.

# Determine the configuration file to use
config_file=""

if [ -f "custom.config.yml" ]; then
  config_file="custom.config.yml"
elif [ -f "default.config.yml" ]; then
  config_file="default.config.yml"
else
  echo "Error: Neither custom.config.yml nor default.config.yml found."
  exit 1
fi

# Read the k8s_platform value from the configuration file
k8s_platform=$(grep '^k8s_platform:' "$config_file" | awk '{print $2}')
OS_FAMILY=$(grep -oP '(?<=^ID_LIKE=).+' /etc/os-release | tr -d '"')
if [ "$OS_FAMILY" == "" ]; then
  OS_FAMILY=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"')
fi
LINUX_VERSION=$(grep -oP '(?<=^VERSION_ID=).+' /etc/os-release | tr -d '"' | cut -d. -f1)
LINUX_ARCH=$(arch)
OS=""

if [ "$OS_FAMILY" == "" ] || [ "$LINUX_VERSION" == "" ]; then
  echo "Error: Unable to determine OS_FAMILY or LINUX_VERSION from /etc/os-release."
  exit 1
fi

if [[ "$OS_FAMILY" == *"rhel"* || "$OS_FAMILY" == *"fedora"* || "$OS_FAMILY" == *"centos"* ]]; then
  OS="rhel"
else
  if [[ "$OS_FAMILY" == *"debian"* || "$OS_FAMILY" == *"ubuntu"* ]]; then
    OS="debian"
  else
    echo "Error: Unsupported OS family $OS_FAMILY. This script must be run on a supported RHEL or Debian family distribution."
    exit 1
  fi
fi

# Check if the k8s_platform is either "eks", "gke" or "aks"
if [[ "$k8s_platform" == "eks" || "$k8s_platform" == "gke" || "$k8s_platform" == "aks" ]]; then
  # Check if the script is run as root or with sudo
  # if [ "$(id -u)" -eq 0 ]; then
  #   echo "Error: This script must not be run as root or with sudo when k8s_platform is $k8s_platform."
  #   exit 1
  # fi

  # Check if the system is using a supported Linux family for this platform
  if [[ "$OS" == "rhel" ]]; then
    if [ "$LINUX_VERSION" -lt 9 ]; then
      echo "Error: This script must be run on RHEL or Rocky Linux version 9 or higher when k8s_platform is $k8s_platform."
      exit 1
    fi
  else
    echo "Error: Unsupported OS family $OS_FAMILY. This script must be run on a supported RHEL family distribution when k8s_platform is $k8s_platform."
    exit 1
  fi
fi

# Verify that the CPU architecture of the local machine is x86_64
if [[ $LINUX_ARCH != "x86_64" ]]; then
  echo "CPU architecture must be x86_64.";
  exit 1;
fi

if [[ "$OS" == "rhel" ]]; then
  # Verify that the Operating System major version of the local machine is either 8 or 9
  if [[ $LINUX_VERSION != "9" && $LINUX_VERSION != "8" ]]; then
    echo "Linux major version must be 8 or 9.";
    exit 1;
  fi
fi

# COLORIZE THE ANSIBLE SHELL
if [ -t "0" ]; then
  ANSIBLE_FORCE_COLORS=True
fi

if [ -f "$(dirname "$0")/inventory.yml" ]; then
  INVENTORY_FILE="$(dirname "$0")/inventory.yml"
else
  INVENTORY_FILE="$(dirname "$0")/inventory"
fi

echo "Using Inventory File: ${INVENTORY_FILE}"

check_ansible() {
  type -p ansible-playbook > /dev/null
}

check_python_kubernetes() {
  python3 -c "import kubernetes" > /dev/null 2>&1
}

# Being on PATH does not mean ansible-playbook can actually run, so fail here
# rather than at the first playbook.
preflight() {
  type -p ansible-playbook > /dev/null || {
    echo "Error: ansible-playbook is not on PATH."
    exit 1
  }

  if diag=$(ansible-playbook --version 2>&1); then
    return 0
  fi

  echo "Error: ansible-playbook on PATH cannot run:"
  printf '%s\n' "$diag" | sed 's/^/       /'
  echo "       ansible-playbook: $(type -p ansible-playbook)"
  echo "       python3:          $(type -p python3)"
  if [ -n "${SUDO_USER:-}" ]; then
    echo
    echo "  You are running under sudo. sudo resets PATH, so an activated"
    echo "  virtualenv is not visible here. Either run the installer as an"
    echo "  unprivileged user with passwordless sudo (recommended - every task"
    echo "  that needs root escalates on its own):"
    echo
    echo "      source /path/to/venv/bin/activate && ./setup.sh"
    echo
    echo "  or keep the environment when escalating:"
    echo
    echo "      sudo -E env \"PATH=\$PATH\" ./setup.sh"
  fi
  exit 1
}

check_collections() {
  ansible-doc -t module -l | grep ansible.posix.selinux > /dev/null
  if [ $? -ne 0 ]; then
    return 0
  fi
  ansible-doc -t module -l | grep ctrliq.ascender.settings > /dev/null
  if [ $? -ne 0 ]; then
    return 0
  fi
  ansible-doc -t module -l | grep kubernetes.core.k8s > /dev/null
  if [ $? -ne 0 ]; then
    return 0
  fi
  ansible-doc -t lookup -l | grep community.general.collection_version > /dev/null
  if [ $? -ne 0 ]; then
    return 0
  fi

  return 1
}

# ------------------------- #

check_ansible
if [ $? -ne 0 ]; then
  echo "#### INSTALLING ANSIBLE ####"
  if [[ "$OS" == "debian" ]]; then
    sudo apt-get update -y && sudo apt-get install -y ansible-core
  fi
  if [[ "$OS" == "rhel" ]]; then
    sudo dnf install -y ansible-core
  fi
fi

preflight

check_collections
if [ $? -ne 1 ]; then
  echo "#### INSTALLING COLLECTIONS ####"
  if [ -f "$(dirname "$0")/offline/collections/ansible-posix-1.5.4.tar.gz" ]; then
    ansible-galaxy collection install "$(dirname "$0")/offline/collections/ansible-posix-1.5.4.tar.gz"
    ansible-galaxy collection install "$(dirname "$0")/offline/collections/ctrliq-ascender-25.6.2.tar.gz"
    ansible-galaxy collection install "$(dirname "$0")/offline/collections/community-general-8.3.0.tar.gz"
    ansible-galaxy collection install "$(dirname "$0")/offline/collections/kubernetes-core-2.4.0.tar.gz"
  else
    ansible-galaxy install -r collections/requirements.yml
  fi
fi

check_python_kubernetes
if [ $? -ne 0 ]; then
  echo "#### INSTALLING PYTHON KUBERNETES CLIENT ####"
  # We are going to attempt to install the kubernetes client
  # but we don't want this failing to stop us if we are in offline mode

  # prefer the distro package. Debian marks its Python
  # install as externally managed (PEP 668), so the old
  # "python3 -m pip install --user" line below is rejected outright, and
  # "--user" is additionally invalid inside a virtualenv. Try apt/dnf first,
  # then fall back to pip with the right flags for whichever env we are in.
  if [[ "$OS" == "debian" ]]; then
    sudo apt-get update -y && sudo apt-get install -y python3-kubernetes || true
  fi
  if [[ "$OS" == "rhel" ]]; then
    sudo dnf install -y python3-kubernetes || true
  fi

  if ! check_python_kubernetes; then
    if ! python3 -m pip --version > /dev/null 2>&1; then
      if [[ "$OS" == "debian" ]]; then
        sudo apt-get update -y && sudo apt-get install -y python3-pip || true
      fi
      if [[ "$OS" == "rhel" ]]; then
        sudo dnf install -y python3-pip || true
      fi
    fi

    if [ -n "${VIRTUAL_ENV:-}" ]; then
      # Inside a venv: no --user, and PEP 668 does not apply.
      python3 -m pip install -U kubernetes || true
    else
      python3 -m pip install --user -U kubernetes 2>/dev/null \
        || python3 -m pip install --user --break-system-packages -U kubernetes \
        || true
    fi
  fi

  if ! check_python_kubernetes; then
    echo "WARNING: the python kubernetes client is still not importable by $(type -p python3)."
    echo "         The playbooks install python3-kubernetes on the target as well, so this"
    echo "         is only fatal if it is still missing when kubernetes.core tasks run."
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

  exit "${RC}"
fi

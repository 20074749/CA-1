#!/bin/bash
set -euo pipefail

# Run from WSL. This script:
# - checks ansible is available
# - ensures the community.docker collection is installed
# - runs a syntax check
# - checks that DOCKERHUB_USERNAME and DOCKERHUB_TOKEN are set in the environment
# - runs the playbook using those env vars

if ! command -v ansible-playbook >/dev/null 2>&1; then
  echo "Ansible not found in WSL. Please install Ansible (sudo) or run this script after installing it."
  echo "To install on Ubuntu WSL:"
  echo "  sudo apt update && sudo apt install -y software-properties-common"
  echo "  sudo apt-add-repository --yes --update ppa:ansible/ansible"
  echo "  sudo apt update && sudo apt install -y ansible python3-pip"
  exit 1
fi

echo "Ansible version:"
ansible-playbook --version

# Ensure collection
if ! ansible-galaxy collection list | grep -q "community.docker"; then
  echo "Installing community.docker collection..."
  ansible-galaxy collection install community.docker
fi

# Syntax check
echo "Running playbook syntax-check..."
ansible-playbook -i ansible/inventory.ini ansible/deploy_docker.yml --syntax-check

# Check credentials
if [ -z "${DOCKERHUB_USERNAME:-}" ] || [ -z "${DOCKERHUB_TOKEN:-}" ]; then
  echo "ERROR: DOCKERHUB_USERNAME or DOCKERHUB_TOKEN not set in WSL environment."
  echo "Set them and rerun, e.g. (in WSL):"
  echo "  export DOCKERHUB_USERNAME=myuser"
  echo "  export DOCKERHUB_TOKEN=mytoken"
  echo "Then run: bash ansible/run_playbook_wsl.sh"
  exit 2
fi

# Run the playbook (this is destructive: it will remove previous container and recreate it)
ansible-playbook -i ansible/inventory.ini ansible/deploy_docker.yml -e "dockerhub_username=$DOCKERHUB_USERNAME dockerhub_token=$DOCKERHUB_TOKEN"

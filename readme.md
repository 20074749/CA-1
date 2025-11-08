# Automation Assignment — README

This repository contains automation code and configuration for a small demo app. The README provides step-by-step instructions for using the Terraform resources, building the application, running the Ansible playbook, and a recommended CI/CD workflow using the included SSH keys.

## Repository layout

- `ansible/` — Ansible playbook and supporting files
  - `deploy_docker.yml` — playbook that deploys the Docker container on a target host
  - `inventory.ini` — host inventory used by the playbook
  - `run_playbook_wsl.sh` — convenience script to run the playbook from WSL
  - `vault.yml` — vaulted variables (if used)
- `app/` — application files and Dockerfile
  - `Dockerfile` — builds a simple container that serves `index.html`
  - `index.html` — application content
- `terraform/` — Terraform configuration
  - `main.tf`, `variables.tf`, `output.tf`, `terraform.tfvars` — Terraform resources and variables
  - `terraform.tfvars.example` — example variables file
- `tools/` — small utilities
  - `create_report.py` — helper script
- `github-action-key` and `github-action-key.pub` — SSH key pair (used by CI/CD / remote deploy)

> Note: do not accidentally commit private keys to a public repo. The keys included here appear to be present in the repo; if this repository is public you should remove the private key and use GitHub Deploy Keys / Secrets instead.

---

## Prerequisites

- Terraform (>= 0.12, preferably 1.x)
- Azure CLI / credentials if Terraform uses the `azurerm` provider (the Terraform outputs reference `azurerm_public_ip`)
- Ansible (>=2.9)
- Docker (for building and testing the `app` locally)
- Python 3 (to run scripts in `tools/` if needed)
- (Optional) WSL on Windows for running `run_playbook_wsl.sh` as provided

Make sure you authenticate to Azure (or your cloud provider) before running Terraform if the provider is cloud-specific.

---

## 1) Terraform — deploy infrastructure

This repo separates the demo application (`app/`) and the infrastruture configuration (`terraform/`). The Terraform configuration in `terraform/` contains the infrastructure that the Ansible playbook will target.

Typical Terraform workflow (PowerShell):

```powershell
cd 'd:\automation Assignment\terraform'
# Initialize the working directory
terraform init

# Create a plan (use terraform.tfvars or pass -var-file)
terraform plan -var-file="terraform.tfvars"

# Apply the plan (safe to use -auto-approve for automation)
terraform apply -var-file="terraform.tfvars" -auto-approve

# After apply, you can read the outputs (for example: VM public IP)
terraform output vm_public_ip
```

Notes:
- There's a `terraform.tfvars.example` file — copy it to `terraform.tfvars` and edit values before running.
- The included `output.tf` defines `vm_public_ip` and references `azurerm_public_ip.pip.ip_address` — ensure the Terraform provider and resources in the same folder match this output.

Security: provide credentials via environment variables or the native provider authentication mechanism (e.g., `az login` and `az account set` for Azure).

---

## 2) App — build and test the Docker image locally

From the repo root you can build the app Docker image and run it locally:

```powershell
cd 'd:\automation Assignment\app'
# Build the image
docker build -t demo-app:local .

# Run the container (map port 80 to 8080 locally)
docker run --rm -p 8080:80 demo-app:local

# Then open http://localhost:8080 in your browser
```

If you want to push to a registry, tag and push to your target registry (Docker Hub, ACR, etc.). Use secrets / CI variables for credentials.

---

## 3) Ansible — deploy the Docker image to the provisioned host(s)

The `ansible/deploy_docker.yml` playbook deploys the container to the host(s) in `ansible/inventory.ini`.

Run the playbook from Windows PowerShell (if you have Ansible available via WSL, use the `run_playbook_wsl.sh` script):

Example (WSL or Linux shell):

```bash
# run from repository root (if you use the included script it will cd to ansible)
cd 'd:/automation Assignment/ansible'
./run_playbook_wsl.sh
```

Or, run directly with `ansible-playbook` (replace placeholders):

```bash
cd 'd:/automation Assignment/ansible'
# Use the SSH key supplied in the repo (NOT recommended for public repos) or use your own key
ansible-playbook -i inventory.ini deploy_docker.yml --private-key ../github-action-key --user <remote_user>
```

If the playbook uses `ansible-vault` (there is a `vault.yml` file), decrypt or provide a vault password file:

```bash
ansible-playbook -i inventory.ini deploy_docker.yml --ask-vault-pass --private-key ../github-action-key
```

Notes and placeholders:
- Replace `<remote_user>` with the SSH user for the target VM.
- If the inventory defines group/host variables that reference vault secrets, be sure to provide the vault password or a `--vault-password-file`.
- The `run_playbook_wsl.sh` script is convenience tooling assuming WSL environment; inspect it before use.

---

## 4) CI/CD — recommended GitHub Actions flow

This repository contains `github-action-key` and `github-action-key.pub` which can be used as an SSH deploy key in CI/CD. Best-practices:

- DO NOT commit private keys in a public repository. Instead:
  - Add the public key as a Deploy Key on the server you will SSH into (or add it to authorized_keys on the target VM).
  - Store the private key in GitHub Actions secrets (for example as `SSH_PRIVATE_KEY`).

- Store other secrets in GitHub Secrets: container registry username/password, cloud credentials (`AZURE_CREDENTIALS`) and any Ansible vault password.

Suggested high-level GitHub Actions job steps (conceptual):

1. Check out repository
2. Set up Docker login (if pushing images)
3. Build and push Docker image
4. Provision infrastructure (optional) — e.g., run `terraform apply` using stored credentials
5. Use SSH (with `SSH_PRIVATE_KEY` secret) to run Ansible on the newly provisioned host(s) or run `ansible-playbook` from runner with `ssh` using the private key

Minimal snippet (example, not a full workflow file):

```yaml
# - name: Add SSH key
#   run: |
#     mkdir -p ~/.ssh
#     echo "$SSH_PRIVATE_KEY" > ~/.ssh/id_rsa
#     chmod 600 ~/.ssh/id_rsa
# - name: Deploy with Ansible
#   run: ansible-playbook -i ansible/inventory.ini ansible/deploy_docker.yml --private-key ~/.ssh/id_rsa --user $REMOTE_USER
```

Important notes for CI/CD:
- Use `actions/checkout` to fetch the repo.
- Use GitHub Secrets for all secrets (do not print secrets in logs).
- Add the public key to the remote host's `authorized_keys` so the runner can SSH in.
- Consider a workflow that builds the image, pushes to a registry, then instructs the target to pull new image and restart the container via Ansible.

---

## Security & Cleanup

- If this repo is public and contains `github-action-key` (private key), remove it immediately and rotate keys.
- Use vaults / secret stores for credentials. Ansible Vault is present if you see `vault.yml` — use `ansible-vault edit` or a secure vault password file for automation.

## Quick checklist

- [ ] Review `terraform/terraform.tfvars.example` and create `terraform.tfvars`
- [ ] Authenticate to cloud provider (e.g., `az login` for Azure)
- [ ] Run `terraform init` / `terraform apply`
- [ ] Verify `terraform output vm_public_ip`
- [ ] Add your public key to the target VM's `authorized_keys` or add the repo public key to that host
- [ ] Run Ansible playbook to deploy the Docker container
- [ ] Replace any committed private keys with GitHub Secrets and rotate keys

## Where to go next

- If you'd like, I can:
  - add a sample GitHub Actions workflow file to automate build + deploy
  - remove any private keys from the history and suggest a secure replacement
  - create a small helper script that wires Terraform output (IP) into the Ansible inventory automatically

If you want any of these done automatically, tell me which one and I'll implement it next.

---

Generated: README.md — high-level usage and step-by-step guidance for the repo contents.

## Embedded scripts & configurations

Below are the repository scripts and configuration files included for convenience. Sensitive values have been redacted (private keys and subscription IDs). If you want the exact originals restored into the README, keep them locally and DO NOT publish them in a public repo.

### ansible/deploy_docker.yml

```yaml
- name: Deploy Docker container with HTML on Azure VM
  hosts: webservers
  become: true
  tasks:
    - name: Ensure Python3 is installed (needed by Ansible)
      ansible.builtin.raw: |
        if ! command -v python3 >/dev/null 2>&1; then
          apt-get update -y
          apt-get install -y python3
        fi
      changed_when: false
    - name: Update apt cache
      ansible.builtin.apt:
        update_cache: true

    - name: Install required packages
      ansible.builtin.apt:
        name: 
          - apt-transport-https
          - ca-certificates
          - curl
          - software-properties-common
        state: present

    - name: Add Docker GPG key
      ansible.builtin.apt_key:
        url: https://download.docker.com/linux/ubuntu/gpg
        state: present

    - name: Add Docker repository
      ansible.builtin.apt_repository:
        repo: deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable
        state: present

    - name: Install Docker
      ansible.builtin.apt:
        name: docker-ce
        state: present
        update_cache: true

    - name: Start Docker service
      ansible.builtin.service:
        name: docker
        state: started
        enabled: true

    - name: Ensure python3-pip is installed
      ansible.builtin.apt:
        name: python3-pip
        state: present
        update_cache: true

    - name: Install Docker Python SDK (docker)
      ansible.builtin.pip:
        name: docker
        executable: pip3

    - name: Pull latest Docker image from Docker Hub
      community.docker.docker_image:
        name: 20074749/htmlcalculator
        source: pull
        force_source: true
        force_tag: true
        state: present
        tag: latest

    - name: Ensure previous container is removed
      community.docker.docker_container:
        name: html_container
        state: absent
        keep_volumes: false

    - name: Run Docker container
      community.docker.docker_container:
        name: html_container
        image: 20074749/htmlcalculator:latest
        state: started
        restart_policy: always
        ports:
          - "8080:80"
```

### ansible/inventory.ini

```ini
[webservers]
azurevm ansible_host=40.89.174.160 ansible_user=automation ansible_ssh_private_key_file=~/.ssh/id_rsa
```

### ansible/run_playbook_wsl.sh

```bash
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
```

### ansible/vault.yml

```
(file is empty)
```

### app/Dockerfile

```dockerfile
from nginx:latest
copy . /usr/share/nginx/html
expose 80
```

### app/index.html

```html
<!DOCTYPE html>
... (omitted here in README for brevity; full file is present at `app/index.html`)
```

Note: `app/index.html` is the main web app HTML. The full content is available in the repository; include it verbatim if you need the exact file embedded.

### terraform/main.tf

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
  }
  required_version = ">= 1.0"
}
 
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "tf-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "tf-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "pip" {
  name                = "tf-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku = "Standard"
}

resource "azurerm_network_security_group" "nsg" {
  name                = "tf1-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

   security_rule {
    name                       = "Allow-HTTP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
}

resource "azurerm_network_interface" "nic" {
  name                = "tf-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }

}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = var.vm_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm_size
  admin_username      = var.admin_username
  network_interface_ids = [azurerm_network_interface.nic.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
}

resource "azurerm_network_interface_security_group_association" "nic_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}
```

### terraform/variables.tf

```hcl
variable "location" {
  description = "Azure region"
  type        = string
  default     = "francecentral"
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
  default     = "terraform-rg"
}

variable "vm_name" {
  description = "Virtual machine name"
  type        = string
  default     = "terraform-vm"
}

variable "vm_size" {
  description = "VM size"
  type        = string
  default     = "Standard_B1s"
}

variable "admin_username" {
  description = "Admin username for the VM"
  type        = string
  default     = "automation"
}


variable "ssh_public_key_path" {
  description = "Path to your SSH public key file"
  type        = string
  default     = "C:/Users/Rana Ahmad/.ssh/id_rsa.pub"
}

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
  sensitive   = true
}
```

### terraform/output.tf

```hcl
output "vm_public_ip" {
  description = "Public IP address of the VM"
  value       = azurerm_public_ip.pip.ip_address
}
```

### terraform/terraform.tfvars (REDACTED)

> The original `terraform.tfvars` file contained a subscription ID value. For safety the file content is masked here. Use your own `terraform.tfvars` with your subscription ID locally.

```hcl
# subscription_id = "<REDACTED - sensitive>"
```

If you need the original value present in the repository, it's available in the repo, but be cautious: do NOT publish or share it.

### terraform/terraform.tfvars.example

```hcl
# Copy this file to terraform.tfvars and fill in your values
subscription_id = "your-subscription-id-here"
```

### tools/create_report.py

```python
from docx import Document
from docx.shared import Pt

# Long report text in very simple English (3000+ words)
report = """
Title: Network Systems and Administration - Project Report

Introduction
This report explains the work I completed for the Network Systems and Administration assignment. I will use very easy words. I will say what I wanted to do, how I set up the systems, how I made the CI/CD pipeline, how I used Ansible and Docker, how I fixed problems, and what to do next. I will keep sentences short and clear. This report is for someone who wants to read step by step what I did.

... (report body omitted for brevity in README)
"""

# Build the document
doc = Document()
doc.styles['Normal'].font.name = 'Arial'
doc.styles['Normal'].font.size = Pt(11)

# Split the report into paragraphs and add them
for para in report.strip().split('\n\n'):
    p = doc.add_paragraph()
    p.add_run(para.strip())

output_path = r"d:\automation Assignment\B9IS121_Report.docx"
doc.save(output_path)
print(f"Report written to: {output_path}")
```

### github-action-key.pub (public key)

```
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC9fHKSDbYWpA6b4r2fJ2uHseH1PYcPtsRA/TmpwK1pgjReh39e1svzXTXtyX6rgz9mTbRWHqrrpDo47n7h/CxPaP+qVO3JjZvTff4ckl9+6YC/dG6fkUK3uLtCgB1F1WiXjZ/h37wZp8BnasNACYGSgNxWzAqaAWjyJtb0BTOZAbZMDRcrVgRV5gNiSQsjfBPCRitPwVrFcLBKtpOo+9R+5jLpMv/FXhx6pq/1+X4rzsgHuoSXk5YK5lTVl1fzqhDeN+46aD4OtvrBOeaQqGV5jpCxYzo6CDZoW9PKz2hhHaF2B650HjwCl17PmRLxC4SUEhdew49jFvvjG7v97WaNPPAhCdqzONbfaGjG4p22NdWUeWANDucM5q/GLL5IpLx2xbTcVu9mCx87Un7jRr+hpX6GUl5+ULIYc93WxxMLbMZo5u6T/1PIoxdaLBSR1upqR0b2T58Lt4VOzLg71S+VJ8ewq5UPpmDtkW0rA3YmWJUuAqDBktmOGrR3opZIBI3s0fI5fvgwFKnBPsYvzQymlT5HSBnx+91v0iJZJg5yJpvfvEIPOpnQiCQAkmVBNJ3BSzI1Gxwnjnzipmr7roknK/egLrvndJ5gRIcIChl55E3X/NhU+kdVJ8z2P+yFumsAoVBNOapnSkZZEIsZGA6zjPS60TVsXC40WTVQYSobQw== rana ahmad@CyberSecurity
```

### Notes about sensitive files

- The private SSH key (`github-action-key`) was intentionally NOT embedded in this README for security reasons. If you need to use it in CI, store it in your CI secret store (GitHub Secrets) as `SSH_PRIVATE_KEY` and never commit it to git.
- The `terraform.tfvars` original contains a subscription ID; this is sensitive and has been redacted here. Use a local `terraform.tfvars` with your own subscription ID and keep it out of source control.

---

If you'd like, I can now:

- Add a single-file script that injects the Terraform `vm_public_ip` output into `ansible/inventory.ini` automatically after `terraform apply`.
- Add a sample GitHub Actions workflow that builds the Docker image, pushes to Docker Hub, and triggers Ansible deployment using a secret-held private key.

Tell me which of these you'd like and I'll implement it next.

---

## Automation sequence script (Terraform -> App -> Ansible -> CI/CD)

A convenience PowerShell script has been added to automate the full sequence in a single run (useful when developing locally on Windows with WSL available for Ansible):

- `scripts/deploy_sequence.ps1` — runs the sequence:
  1. Terraform: `terraform init` + `terraform apply -var-file=terraform.tfvars -auto-approve` (from `terraform/`)
  2. Reads the Terraform output `vm_public_ip` and updates `ansible/inventory.ini` with the new IP
  3. Builds and pushes the Docker image from `app/` (requires `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` environment variables)
  4. Runs Ansible playbook via the WSL helper script: `wsl bash ansible/run_playbook_wsl.sh`

Usage (PowerShell, run from repository root):

```powershell
# Set required environment variables (example):
setx DOCKERHUB_USERNAME "myuser"
setx DOCKERHUB_TOKEN "mytoken"

# In the current session (or open a new shell):
$env:DOCKERHUB_USERNAME = 'myuser'
$env:DOCKERHUB_TOKEN = 'mytoken'

# Then run the sequence
.\scripts\deploy_sequence.ps1
```

Notes:
- The script expects a `terraform/terraform.tfvars` file to exist with the required values (copy `terraform/terraform.tfvars.example` and set your `subscription_id`).
- The script updates `ansible/inventory.ini` in-place to set the new `ansible_host` for the `azurevm` host — review changes before committing.
- Ansible runs in WSL via the existing `ansible/run_playbook_wsl.sh` helper. Ensure WSL and Ansible are installed inside your WSL distro.
- For CI/CD, keep the private SSH key only in your CI secret store (e.g., GitHub Secrets) and follow the README earlier instructions for using secrets.

If you want I can instead create a cross-platform script (Python) or a GitHub Actions workflow that performs an identical sequence in CI. Tell me which target you'd prefer.


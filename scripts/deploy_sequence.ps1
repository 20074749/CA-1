<#
deploy_sequence.ps1

Performs the full sequence:
  1. Terraform: init / apply (uses terraform/terraform.tfvars)
  2. App: build and push Docker image (uses DOCKERHUB_USERNAME & DOCKERHUB_TOKEN env vars)
  3. Update Ansible inventory with VM public IP
  4. Ansible: run the playbook via WSL helper script

Run from PowerShell (Windows):
  Set the required environment variables first (Docker credentials). Then run in repo root:
    .\scripts\deploy_sequence.ps1

Security: do NOT commit private keys; keep secrets in environment or CI secret store.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Helper: check env var
function Require-EnvVar([string]$name) {
    if (-not $env:$name) {
        Write-Error "Environment variable $name is required but not set."
        exit 2
    }
}

Write-Host "Starting full deployment sequence: Terraform -> App -> Ansible -> CI/CD" -ForegroundColor Cyan

# 1) Terraform
Push-Location -Path (Join-Path $PSScriptRoot '..\terraform')
try {
    Write-Host "Initializing Terraform..."
    terraform init

    Write-Host "Applying Terraform (using terraform.tfvars)..."
    if (-not (Test-Path -Path 'terraform.tfvars')) {
        Write-Warning "terraform.tfvars not found in terraform/. Create it (copy terraform.tfvars.example) before running."
        throw "Missing terraform.tfvars"
    }

    terraform apply -var-file="terraform.tfvars" -auto-approve

    Write-Host "Reading Terraform output: vm_public_ip"
    $vmIp = terraform output -raw vm_public_ip
    if (-not $vmIp) { throw "Failed to read vm_public_ip from Terraform outputs" }
    Write-Host "VM public IP: $vmIp"
} finally {
    Pop-Location
}

# 2) Update Ansible inventory with the new IP
$inventoryPath = Join-Path $PSScriptRoot '..\ansible\inventory.ini'
if (-not (Test-Path $inventoryPath)) { throw "Inventory file not found at $inventoryPath" }

$inventory = Get-Content $inventoryPath -Raw
# Replace any existing ansible_host=... occurrence on the azurevm line
$newInventory = $inventory -replace '(azurevm\s+ansible_host=)[0-9\.]+', "`$1$vmIp"

if ($newInventory -ne $inventory) {
    Write-Host "Updating ansible inventory with new VM IP..."
    Set-Content -Path $inventoryPath -Value $newInventory -Encoding UTF8
} else {
    Write-Host "No IP placeholder replaced — ensure inventory format matches 'azurevm ansible_host=<ip>'" -ForegroundColor Yellow
}

# 3) App: build and push Docker image
Push-Location -Path (Join-Path $PSScriptRoot '..\app')
try {
    Require-EnvVar 'DOCKERHUB_USERNAME'
    Require-EnvVar 'DOCKERHUB_TOKEN'

    $imageName = '20074749/htmlcalculator'
    $tag = 'latest'
    $fullImage = "$imageName:$tag"

    Write-Host "Logging into Docker Hub as $env:DOCKERHUB_USERNAME..."
    docker login --username $env:DOCKERHUB_USERNAME --password-stdin <<< $env:DOCKERHUB_TOKEN

    Write-Host "Building Docker image $fullImage..."
    docker build -t $fullImage .

    Write-Host "Pushing Docker image $fullImage..."
    docker push $fullImage
} finally {
    Pop-Location
}

# 4) Ansible: call the WSL helper script which runs ansible-playbook
Write-Host "Running Ansible playbook via WSL helper script..."
if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) {
    Write-Warning "WSL not available. Please run the Ansible step manually or enable WSL."
    exit 0
}

# Execute the WSL script (it expects DOCKERHUB_USERNAME/DOCKERHUB_TOKEN in WSL environment)
Write-Host "Invoking: wsl bash ansible/run_playbook_wsl.sh"
wsl bash ansible/run_playbook_wsl.sh

Write-Host "Full deployment sequence complete." -ForegroundColor Green

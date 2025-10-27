
# ==========================================
# FILE: scripts/deploy-azure.ps1
# ==========================================
# Deploy CDC pipeline to Azure
# Usage: .\scripts\deploy-azure.ps1

param(
    [string]$ImageTag = "latest"
)

$ErrorActionPreference = "Stop"

Write-Host @"
╔════════════════════════════════════════╗
║   Deploying to Azure Container Apps   ║
╚════════════════════════════════════════╝
"@ -ForegroundColor Blue

# Step 1: Check prerequisites
Write-Host "`nStep 1/4: Checking prerequisites..." -ForegroundColor Yellow

$missingTools = @()
if (-not (Get-Command az -ErrorAction SilentlyContinue)) { $missingTools += "Azure CLI" }
if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) { $missingTools += "Terraform" }
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { $missingTools += "Docker" }

if ($missingTools.Count -gt 0) {
    Write-Host "Error: Missing tools: $($missingTools -join ', ')" -ForegroundColor Red
    exit 1
}

try {
    az account show 2>$null | Out-Null
} catch {
    Write-Host "Error: Not logged in to Azure. Run: az login" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path "terraform\azure\terraform.tfvars")) {
    Write-Host "Error: terraform.tfvars not found. Copy from terraform.tfvars.example" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Prerequisites OK" -ForegroundColor Green

# Step 2: Initialize Terraform
Write-Host "`nStep 2/4: Initializing Terraform..." -ForegroundColor Yellow
Push-Location "terraform\azure"
try {
    terraform init
    Write-Host "✓ Terraform initialized" -ForegroundColor Green
    
    # Step 3: Build and push container
    Write-Host "`nStep 3/4: Building and pushing container..." -ForegroundColor Yellow
    Pop-Location
    & ".\scripts\build_and_push.ps1" -Cloud azure -Tag $ImageTag
    Push-Location "terraform\azure"
    
    # Step 4: Deploy infrastructure
    Write-Host "`nStep 4/4: Deploying infrastructure..." -ForegroundColor Yellow
    terraform apply -var="image_tag=$ImageTag" -auto-approve
    
    Write-Host @"

╔════════════════════════════════════════╗
║  ✓ Deployment Complete!               ║
╚════════════════════════════════════════╝
"@ -ForegroundColor Green
    
    Write-Host "`nContainer App URL:" -ForegroundColor Blue
    terraform output container_app_url
    
    Write-Host "`nStorage Account:" -ForegroundColor Blue
    terraform output storage_account_name
    
    Write-Host "`nNext steps:" -ForegroundColor Yellow
    Write-Host "  1. Check health: curl `$(terraform output -raw container_app_url)/health"
    Write-Host "  2. Configure Databricks with the storage account URL"
    Write-Host "  3. Monitor logs: az containerapp logs show --name cdc-app --resource-group <rg-name> --follow"
    
} finally {
    Pop-Location
}
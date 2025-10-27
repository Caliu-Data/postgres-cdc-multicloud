# ==========================================
# FILE: scripts/quick_setup.ps1
# ==========================================
# Quick setup script for PostgreSQL CDC Pipeline (PowerShell version)
# Usage: .\scripts\quick_setup.ps1

$ErrorActionPreference = "Stop"

# Colors
function Write-Step { Write-Host "==> $args" -ForegroundColor Blue }
function Write-Success { Write-Host "✓ $args" -ForegroundColor Green }
function Write-Error { Write-Host "✗ $args" -ForegroundColor Red }
function Write-Warning { Write-Host "⚠ $args" -ForegroundColor Yellow }

Write-Host @"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   PostgreSQL CDC Multi-Cloud Pipeline - Quick Setup          ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Blue

# Function to check if command exists
function Test-CommandExists {
    param($Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

# Step 1: Check Prerequisites
Write-Step "Checking prerequisites..."

$missingDeps = @()

if (-not (Test-CommandExists docker)) { $missingDeps += "docker" }
if (-not (Test-CommandExists terraform)) { $missingDeps += "terraform" }
if (-not (Test-CommandExists git)) { $missingDeps += "git" }

if ($missingDeps.Count -gt 0) {
    Write-Error "Missing dependencies: $($missingDeps -join ', ')"
    Write-Host "Please install the missing dependencies and try again."
    exit 1
}

Write-Success "All prerequisites installed"

# Step 2: Select Cloud Provider
Write-Step "Select your cloud provider"
Write-Host "1) Azure"
Write-Host "2) AWS"
Write-Host "3) GCP"
$cloudChoice = Read-Host "Enter choice [1-3]"

switch ($cloudChoice) {
    "1" {
        $cloud = "azure"
        if (-not (Test-CommandExists az)) {
            Write-Error "Azure CLI not found. Please install: https://aka.ms/install-azure-cli"
            exit 1
        }
        Write-Success "Azure selected"
    }
    "2" {
        $cloud = "aws"
        if (-not (Test-CommandExists aws)) {
            Write-Error "AWS CLI not found. Please install: https://aws.amazon.com/cli/"
            exit 1
        }
        Write-Success "AWS selected"
    }
    "3" {
        $cloud = "gcp"
        if (-not (Test-CommandExists gcloud)) {
            Write-Error "gcloud CLI not found. Please install: https://cloud.google.com/sdk/docs/install"
            exit 1
        }
        Write-Success "GCP selected"
    }
    default {
        Write-Error "Invalid choice"
        exit 1
    }
}

# Step 3: Check Cloud Authentication
Write-Step "Checking cloud authentication..."

switch ($cloud) {
    "azure" {
        try {
            az account show 2>$null | Out-Null
            Write-Success "Azure authentication OK"
        } catch {
            Write-Warning "Not logged in to Azure"
            $login = Read-Host "Login now? (y/n)"
            if ($login -eq "y") {
                az login
            } else {
                Write-Error "Please run 'az login' and try again"
                exit 1
            }
        }
    }
    "aws" {
        try {
            aws sts get-caller-identity 2>$null | Out-Null
            Write-Success "AWS authentication OK"
        } catch {
            Write-Error "AWS credentials not configured"
            Write-Host "Please run 'aws configure' and try again"
            exit 1
        }
    }
    "gcp" {
        try {
            gcloud auth print-access-token 2>$null | Out-Null
            Write-Success "GCP authentication OK"
        } catch {
            Write-Warning "Not logged in to GCP"
            $login = Read-Host "Login now? (y/n)"
            if ($login -eq "y") {
                gcloud auth login
            } else {
                Write-Error "Please run 'gcloud auth login' and try again"
                exit 1
            }
        }
    }
}

# Step 4: Configure Terraform
Write-Step "Configuring Terraform variables..."

$tfvarsDir = "terraform\$cloud"
$tfvarsFile = "$tfvarsDir\terraform.tfvars"
$exampleFile = "$tfvarsDir\terraform.tfvars.example"

if (Test-Path $tfvarsFile) {
    Write-Warning "terraform.tfvars already exists"
    $overwrite = Read-Host "Overwrite? (y/n)"
    if ($overwrite -eq "y") {
        Copy-Item $exampleFile $tfvarsFile -Force
        Write-Success "Created terraform.tfvars from example"
    } else {
        Write-Warning "Skipping configuration"
    }
} else {
    Copy-Item $exampleFile $tfvarsFile
    Write-Success "Created terraform.tfvars from example"
}

# Step 5: Prompt for PostgreSQL details
Write-Step "PostgreSQL Configuration"
Write-Host "Please provide your PostgreSQL connection details:"
Write-Host ""

$pgHost = Read-Host "PostgreSQL Host"
$pgDatabase = Read-Host "PostgreSQL Database"
$pgUser = Read-Host "PostgreSQL User"
$pgPassword = Read-Host "PostgreSQL Password" -AsSecureString
$pgPasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($pgPassword))
$tableInclude = Read-Host "Tables to capture (comma-separated, e.g., schema.table1,schema.table2)"

# Update terraform.tfvars
$content = Get-Content $tfvarsFile
$content = $content -replace 'pg_host\s*=.*', "pg_host = `"$pgHost`""
$content = $content -replace 'pg_database\s*=.*', "pg_database = `"$pgDatabase`""
$content = $content -replace 'pg_user\s*=.*', "pg_user = `"$pgUser`""
$content = $content -replace 'pg_password\s*=.*', "pg_password = `"$pgPasswordPlain`""
$content = $content -replace 'table_include\s*=.*', "table_include = `"$tableInclude`""
$content | Set-Content $tfvarsFile

Write-Success "PostgreSQL configuration saved"

# Step 6: Cloud-specific configuration
Write-Step "Cloud-specific configuration"

switch ($cloud) {
    "azure" {
        $rgName = Read-Host "Resource Group Name"
        $location = Read-Host "Azure Region (e.g., eastus)"
        $acrName = Read-Host "Container Registry Name (globally unique)"
        $storageName = Read-Host "Storage Account Name (globally unique, lowercase)"
        
        $content = Get-Content $tfvarsFile
        $content = $content -replace 'resource_group_name\s*=.*', "resource_group_name = `"$rgName`""
        $content = $content -replace 'location\s*=.*', "location = `"$location`""
        $content = $content -replace 'acr_name\s*=.*', "acr_name = `"$acrName`""
        $content = $content -replace 'storage_account_name\s*=.*', "storage_account_name = `"$storageName`""
        $content | Set-Content $tfvarsFile
    }
    "aws" {
        $awsRegion = Read-Host "AWS Region (e.g., us-east-1)"
        $s3Bucket = Read-Host "S3 Bucket Name (globally unique)"
        
        $content = Get-Content $tfvarsFile
        $content = $content -replace 'aws_region\s*=.*', "aws_region = `"$awsRegion`""
        $content = $content -replace 's3_bucket_name\s*=.*', "s3_bucket_name = `"$s3Bucket`""
        $content | Set-Content $tfvarsFile
    }
    "gcp" {
        $projectId = Read-Host "GCP Project ID"
        $gcpRegion = Read-Host "GCP Region (e.g., us-central1)"
        $gcsBucket = Read-Host "GCS Bucket Name (globally unique)"
        
        $content = Get-Content $tfvarsFile
        $content = $content -replace 'project_id\s*=.*', "project_id = `"$projectId`""
        $content = $content -replace 'region\s*=.*', "region = `"$gcpRegion`""
        $content = $content -replace 'gcs_bucket_name\s*=.*', "gcs_bucket_name = `"$gcsBucket`""
        $content | Set-Content $tfvarsFile
    }
}

Write-Success "Configuration complete"

# Step 7: PostgreSQL Setup Instructions
Write-Step "PostgreSQL Setup Required"
Write-Host ""
Write-Warning "IMPORTANT: Before deploying, you must prepare your PostgreSQL database:"
Write-Host ""
Write-Host "1. Enable logical replication (requires restart):"
Write-Host "   Add to postgresql.conf:"
Write-Host "   wal_level = logical"
Write-Host "   max_replication_slots = 10"
Write-Host "   max_wal_senders = 10"
Write-Host ""
Write-Host "2. Run the setup script on your PostgreSQL server:"
Write-Host "   psql -h $pgHost -U postgres -d $pgDatabase -f scripts\setup_postgres.sql"
Write-Host ""
$pgSetup = Read-Host "Have you completed the PostgreSQL setup? (y/n)"

if ($pgSetup -ne "y") {
    Write-Warning "Please complete PostgreSQL setup first"
    Write-Host "Setup script saved in: scripts\setup_postgres.sql"
    exit 0
}

# Step 8: Ready to Deploy
Write-Step "Ready to Deploy!"
Write-Host ""
Write-Host "Configuration saved to: $tfvarsFile"
Write-Host ""
Write-Host "To deploy, run:"
Write-Host ".\scripts\deploy-$cloud.ps1" -ForegroundColor Green
Write-Host ""
$deployNow = Read-Host "Deploy now? (y/n)"

if ($deployNow -eq "y") {
    & ".\scripts\deploy-$cloud.ps1"
} else {
    Write-Host ""
    Write-Success "Setup complete!"
    Write-Host ""
    Write-Host "When ready to deploy, run:"
    Write-Host ".\scripts\deploy-$cloud.ps1" -ForegroundColor Green
    Write-Host ""
}

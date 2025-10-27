

# ==========================================
# FILE: scripts/deploy-gcp.ps1
# ==========================================
# Deploy CDC pipeline to GCP
# Usage: .\scripts\deploy-gcp.ps1 [-ImageTag <tag>]

param(
    [string]$ImageTag = "latest"
)

$ErrorActionPreference = "Stop"

Write-Host @"
╔════════════════════════════════════════╗
║   Deploying to GCP Cloud Run           ║
╚════════════════════════════════════════╝
"@ -ForegroundColor Blue

# Step 1: Check prerequisites
Write-Host "`nStep 1/4: Checking prerequisites..." -ForegroundColor Yellow

$missingTools = @()
if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) { $missingTools += "gcloud CLI" }
if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) { $missingTools += "Terraform" }
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { $missingTools += "Docker" }

if ($missingTools.Count -gt 0) {
    Write-Host "Error: Missing tools: $($missingTools -join ', ')" -ForegroundColor Red
    Write-Host "Please install:" -ForegroundColor Yellow
    if ($missingTools -contains "gcloud CLI") {
        Write-Host "  - gcloud CLI: https://cloud.google.com/sdk/docs/install" -ForegroundColor Yellow
    }
    if ($missingTools -contains "Terraform") {
        Write-Host "  - Terraform: https://www.terraform.io/downloads" -ForegroundColor Yellow
    }
    if ($missingTools -contains "Docker") {
        Write-Host "  - Docker Desktop: https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
    }
    exit 1
}

# Check GCP authentication
try {
    $gcpAccount = gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>$null
    if (-not $gcpAccount) {
        throw "Not authenticated"
    }
    $gcpProject = gcloud config get-value project 2>$null
    Write-Host "✓ Authenticated as: $gcpAccount" -ForegroundColor Green
    if ($gcpProject) {
        Write-Host "  Project: $gcpProject" -ForegroundColor Gray
    }
} catch {
    Write-Host "Error: Not logged in to GCP" -ForegroundColor Red
    Write-Host "Please run: gcloud auth login" -ForegroundColor Yellow
    Write-Host "Then set project: gcloud config set project YOUR_PROJECT_ID" -ForegroundColor Yellow
    exit 1
}

# Check terraform.tfvars exists
if (-not (Test-Path "terraform\gcp\terraform.tfvars")) {
    Write-Host "Error: terraform.tfvars not found" -ForegroundColor Red
    Write-Host "Please copy from terraform.tfvars.example and configure:" -ForegroundColor Yellow
    Write-Host "  Copy-Item terraform\gcp\terraform.tfvars.example terraform\gcp\terraform.tfvars" -ForegroundColor Gray
    exit 1
}

Write-Host "✓ Prerequisites OK" -ForegroundColor Green

# Step 2: Initialize Terraform
Write-Host "`nStep 2/4: Initializing Terraform..." -ForegroundColor Yellow
Push-Location "terraform\gcp"
try {
    Write-Host "Running: terraform init..." -ForegroundColor Gray
    terraform init
    if ($LASTEXITCODE -ne 0) {
        throw "Terraform init failed"
    }
    Write-Host "✓ Terraform initialized" -ForegroundColor Green
    
    # Step 3: Build and push container
    Write-Host "`nStep 3/4: Building and pushing container..." -ForegroundColor Yellow
    Pop-Location
    
    Write-Host "Building Docker image..." -ForegroundColor Gray
    & ".\scripts\build_and_push.ps1" -Cloud gcp -Tag $ImageTag
    if ($LASTEXITCODE -ne 0) {
        throw "Docker build/push failed"
    }
    
    Push-Location "terraform\gcp"
    
    # Step 4: Deploy infrastructure
    Write-Host "`nStep 4/4: Deploying infrastructure..." -ForegroundColor Yellow
    Write-Host "Running: terraform apply..." -ForegroundColor Gray
    Write-Host "This may take 5-10 minutes..." -ForegroundColor Gray
    
    terraform apply -var="image_tag=$ImageTag" -auto-approve
    if ($LASTEXITCODE -ne 0) {
        throw "Terraform apply failed"
    }
    
    Write-Host @"

╔════════════════════════════════════════╗
║  ✓ Deployment Complete!               ║
╚════════════════════════════════════════╝
"@ -ForegroundColor Green
    
    Write-Host "`n📋 Deployment Information:" -ForegroundColor Blue
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    
    Write-Host "`n🏗️  Infrastructure:" -ForegroundColor Cyan
    $cloudRunUrl = terraform output -raw cloud_run_url 2>$null
    $gcsBucket = terraform output -raw gcs_bucket_name 2>$null
    $projectId = terraform output -raw project_id 2>$null
    $region = terraform output -raw region 2>$null
    $artifactRepo = terraform output -raw artifact_registry_repository 2>$null
    
    if ($cloudRunUrl) { Write-Host "  Cloud Run URL: $cloudRunUrl" -ForegroundColor White }
    if ($gcsBucket) { Write-Host "  GCS Bucket: gs://$gcsBucket" -ForegroundColor White }
    if ($projectId) { Write-Host "  Project ID: $projectId" -ForegroundColor White }
    if ($region) { Write-Host "  Region: $region" -ForegroundColor White }
    if ($artifactRepo) { Write-Host "  Artifact Registry: $artifactRepo" -ForegroundColor White }
    
    Write-Host "`n🔍 Next Steps:" -ForegroundColor Yellow
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    
    Write-Host "`n1️⃣  Check service status:" -ForegroundColor Cyan
    Write-Host "   gcloud run services describe cdc-pipeline --region $region" -ForegroundColor Gray
    
    Write-Host "`n2️⃣  View logs:" -ForegroundColor Cyan
    Write-Host "   gcloud logging read 'resource.type=cloud_run_revision' --limit 50" -ForegroundColor Gray
    Write-Host "   # Or stream logs:" -ForegroundColor Gray
    Write-Host "   gcloud logging tail 'resource.type=cloud_run_revision'" -ForegroundColor Gray
    
    Write-Host "`n3️⃣  Check health:" -ForegroundColor Cyan
    Write-Host "   .\scripts\health_check.ps1 gcp" -ForegroundColor Gray
    Write-Host "   # Or directly:" -ForegroundColor Gray
    Write-Host "   curl $cloudRunUrl/health" -ForegroundColor Gray
    
    Write-Host "`n4️⃣  Configure Databricks:" -ForegroundColor Cyan
    Write-Host "   - Storage path: gs://$gcsBucket/landing" -ForegroundColor Gray
    Write-Host "   - Run notebooks in databricks/ folder" -ForegroundColor Gray
    
    Write-Host "`n5️⃣  Monitor the pipeline:" -ForegroundColor Cyan
    Write-Host "   - Cloud Run Console: https://console.cloud.google.com/run" -ForegroundColor Gray
    Write-Host "   - Logging: https://console.cloud.google.com/logs" -ForegroundColor Gray
    Write-Host "   - Cloud Storage: https://console.cloud.google.com/storage/browser/$gcsBucket" -ForegroundColor Gray
    
    Write-Host "`n💡 Tip: Cloud Run services start instantly, but allow 30s for initial cold start" -ForegroundColor Yellow
    Write-Host ""
    
} catch {
    Write-Host "`n✗ Deployment failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`nTroubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Check GCP authentication: gcloud auth list" -ForegroundColor Gray
    Write-Host "  2. Verify project is set: gcloud config get-value project" -ForegroundColor Gray
    Write-Host "  3. Check terraform.tfvars is configured correctly" -ForegroundColor Gray
    Write-Host "  4. Ensure required APIs are enabled:" -ForegroundColor Gray
    Write-Host "     - Cloud Run API" -ForegroundColor Gray
    Write-Host "     - Artifact Registry API" -ForegroundColor Gray
    Write-Host "     - Cloud Storage API" -ForegroundColor Gray
    Write-Host "  5. Run: terraform plan (in terraform\gcp directory)" -ForegroundColor Gray
    exit 1
} finally {
    Pop-Location
}


# ==========================================
# FILE: scripts/destroy-azure.ps1
# ==========================================
# Destroy Azure infrastructure
# Usage: .\scripts\destroy-azure.ps1

param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host @"
╔════════════════════════════════════════╗
║   Destroying Azure Infrastructure      ║
╚════════════════════════════════════════╝
"@ -ForegroundColor Red

if (-not $Force) {
    Write-Host "`n⚠️  WARNING: This will destroy all resources in Azure!" -ForegroundColor Yellow
    Write-Host "This includes:" -ForegroundColor Yellow
    Write-Host "  - Container App" -ForegroundColor Gray
    Write-Host "  - Storage Account (and all data!)" -ForegroundColor Gray
    Write-Host "  - Container Registry" -ForegroundColor Gray
    Write-Host "  - Log Analytics Workspace" -ForegroundColor Gray
    Write-Host ""
    
    $confirm = Read-Host "Type 'yes' to confirm destruction"
    if ($confirm -ne "yes") {
        Write-Host "Cancelled" -ForegroundColor Yellow
        exit 0
    }
}

Push-Location "terraform\azure"
try {
    terraform destroy -auto-approve
    Write-Host "`n✓ Infrastructure destroyed" -ForegroundColor Green
} catch {
    Write-Host "`n✗ Destroy failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Pop-Location
}


# ==========================================
# FILE: scripts/destroy-aws.ps1
# ==========================================
# Destroy AWS infrastructure
# Usage: .\scripts\destroy-aws.ps1

param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host @"
╔════════════════════════════════════════╗
║   Destroying AWS Infrastructure        ║
╚════════════════════════════════════════╝
"@ -ForegroundColor Red

if (-not $Force) {
    Write-Host "`n⚠️  WARNING: This will destroy all resources in AWS!" -ForegroundColor Yellow
    Write-Host "This includes:" -ForegroundColor Yellow
    Write-Host "  - ECS Service and Task Definition" -ForegroundColor Gray
    Write-Host "  - S3 Bucket (and all data!)" -ForegroundColor Gray
    Write-Host "  - ECR Repository" -ForegroundColor Gray
    Write-Host "  - CloudWatch Logs" -ForegroundColor Gray
    Write-Host ""
    
    $confirm = Read-Host "Type 'yes' to confirm destruction"
    if ($confirm -ne "yes") {
        Write-Host "Cancelled" -ForegroundColor Yellow
        exit 0
    }
}

Push-Location "terraform\aws"
try {
    terraform destroy -auto-approve
    Write-Host "`n✓ Infrastructure destroyed" -ForegroundColor Green
} catch {
    Write-Host "`n✗ Destroy failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Pop-Location
}


# ==========================================
# FILE: scripts/destroy-gcp.ps1
# ==========================================
# Destroy GCP infrastructure
# Usage: .\scripts\destroy-gcp.ps1

param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host @"
╔════════════════════════════════════════╗
║   Destroying GCP Infrastructure        ║
╚════════════════════════════════════════╝
"@ -ForegroundColor Red

if (-not $Force) {
    Write-Host "`n⚠️  WARNING: This will destroy all resources in GCP!" -ForegroundColor Yellow
    Write-Host "This includes:" -ForegroundColor Yellow
    Write-Host "  - Cloud Run Service" -ForegroundColor Gray
    Write-Host "  - GCS Bucket (and all data!)" -ForegroundColor Gray
    Write-Host "  - Artifact Registry Repository" -ForegroundColor Gray
    Write-Host "  - Service Account" -ForegroundColor Gray
    Write-Host ""
    
    $confirm = Read-Host "Type 'yes' to confirm destruction"
    if ($confirm -ne "yes") {
        Write-Host "Cancelled" -ForegroundColor Yellow
        exit 0
    }
}

Push-Location "terraform\gcp"
try {
    terraform destroy -auto-approve
    Write-Host "`n✓ Infrastructure destroyed" -ForegroundColor Green
} catch {
    Write-Host "`n✗ Destroy failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Pop-Location
}
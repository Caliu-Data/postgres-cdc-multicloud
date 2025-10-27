# ==========================================
# FILE: scripts/deploy-aws.ps1
# ==========================================
# Deploy CDC pipeline to AWS
# Usage: .\scripts\deploy-aws.ps1 [-ImageTag <tag>]

param(
    [string]$ImageTag = "latest"
)

$ErrorActionPreference = "Stop"

Write-Host @"
╔════════════════════════════════════════╗
║   Deploying to AWS Fargate             ║
╚════════════════════════════════════════╝
"@ -ForegroundColor Blue

# Step 1: Check prerequisites
Write-Host "`nStep 1/4: Checking prerequisites..." -ForegroundColor Yellow

$missingTools = @()
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) { $missingTools += "AWS CLI" }
if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) { $missingTools += "Terraform" }
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { $missingTools += "Docker" }

if ($missingTools.Count -gt 0) {
    Write-Host "Error: Missing tools: $($missingTools -join ', ')" -ForegroundColor Red
    Write-Host "Please install:" -ForegroundColor Yellow
    if ($missingTools -contains "AWS CLI") {
        Write-Host "  - AWS CLI: https://aws.amazon.com/cli/" -ForegroundColor Yellow
    }
    if ($missingTools -contains "Terraform") {
        Write-Host "  - Terraform: https://www.terraform.io/downloads" -ForegroundColor Yellow
    }
    if ($missingTools -contains "Docker") {
        Write-Host "  - Docker Desktop: https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
    }
    exit 1
}

# Check AWS authentication
try {
    aws sts get-caller-identity 2>$null | Out-Null
    $awsAccount = aws sts get-caller-identity --query Account --output text
    $awsUser = aws sts get-caller-identity --query Arn --output text
    Write-Host "✓ Authenticated as: $awsUser" -ForegroundColor Green
    Write-Host "  Account: $awsAccount" -ForegroundColor Gray
} catch {
    Write-Host "Error: Not logged in to AWS" -ForegroundColor Red
    Write-Host "Please run: aws configure" -ForegroundColor Yellow
    exit 1
}

# Check terraform.tfvars exists
if (-not (Test-Path "terraform\aws\terraform.tfvars")) {
    Write-Host "Error: terraform.tfvars not found" -ForegroundColor Red
    Write-Host "Please copy from terraform.tfvars.example and configure:" -ForegroundColor Yellow
    Write-Host "  Copy-Item terraform\aws\terraform.tfvars.example terraform\aws\terraform.tfvars" -ForegroundColor Gray
    exit 1
}

Write-Host "✓ Prerequisites OK" -ForegroundColor Green

# Step 2: Initialize Terraform
Write-Host "`nStep 2/4: Initializing Terraform..." -ForegroundColor Yellow
Push-Location "terraform\aws"
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
    & ".\scripts\build_and_push.ps1" -Cloud aws -Tag $ImageTag
    if ($LASTEXITCODE -ne 0) {
        throw "Docker build/push failed"
    }
    
    Push-Location "terraform\aws"
    
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
    $ecrUrl = terraform output -raw ecr_repository_url 2>$null
    $s3Bucket = terraform output -raw s3_bucket_name 2>$null
    $ecsCluster = terraform output -raw ecs_cluster_name 2>$null
    $ecsService = terraform output -raw ecs_service_name 2>$null
    $region = terraform output -raw aws_region 2>$null
    
    if ($ecrUrl) { Write-Host "  ECR Repository: $ecrUrl" -ForegroundColor White }
    if ($s3Bucket) { Write-Host "  S3 Bucket: s3://$s3Bucket" -ForegroundColor White }
    if ($ecsCluster) { Write-Host "  ECS Cluster: $ecsCluster" -ForegroundColor White }
    if ($ecsService) { Write-Host "  ECS Service: $ecsService" -ForegroundColor White }
    if ($region) { Write-Host "  Region: $region" -ForegroundColor White }
    
    Write-Host "`n🔍 Next Steps:" -ForegroundColor Yellow
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    
    Write-Host "`n1️⃣  Check service status:" -ForegroundColor Cyan
    Write-Host "   aws ecs describe-services --cluster $ecsCluster --services $ecsService --region $region" -ForegroundColor Gray
    
    Write-Host "`n2️⃣  View logs:" -ForegroundColor Cyan
    Write-Host "   aws logs tail /ecs/cdc-pipeline --follow --region $region" -ForegroundColor Gray
    
    Write-Host "`n3️⃣  Check health:" -ForegroundColor Cyan
    Write-Host "   .\scripts\health_check.ps1 aws" -ForegroundColor Gray
    
    Write-Host "`n4️⃣  Configure Databricks:" -ForegroundColor Cyan
    Write-Host "   - Storage path: s3://$s3Bucket/landing" -ForegroundColor Gray
    Write-Host "   - Run notebooks in databricks/ folder" -ForegroundColor Gray
    
    Write-Host "`n5️⃣  Monitor the pipeline:" -ForegroundColor Cyan
    Write-Host "   - CloudWatch: https://console.aws.amazon.com/cloudwatch" -ForegroundColor Gray
    Write-Host "   - ECS Console: https://console.aws.amazon.com/ecs" -ForegroundColor Gray
    
    Write-Host "`n💡 Tip: Wait 2-3 minutes for the service to fully start" -ForegroundColor Yellow
    Write-Host ""
    
} catch {
    Write-Host "`n✗ Deployment failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`nTroubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Check AWS credentials: aws sts get-caller-identity" -ForegroundColor Gray
    Write-Host "  2. Verify terraform.tfvars is configured correctly" -ForegroundColor Gray
    Write-Host "  3. Check Terraform logs above for specific errors" -ForegroundColor Gray
    Write-Host "  4. Run: terraform plan (in terraform\aws directory)" -ForegroundColor Gray
    exit 1
} finally {
    Pop-Location
}
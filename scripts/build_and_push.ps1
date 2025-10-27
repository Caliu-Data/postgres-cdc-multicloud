
# ==========================================
# FILE: scripts/build_and_push.ps1
# ==========================================
# Build and push Docker image to cloud registry
# Usage: .\scripts\build_and_push.ps1 [azure|aws|gcp] [tag]

param(
    [Parameter(Position=0)]
    [ValidateSet("azure", "aws", "gcp")]
    [string]$Cloud = "azure",
    
    [Parameter(Position=1)]
    [string]$Tag = "latest"
)

$ErrorActionPreference = "Stop"

# Try to get git tag if not specified
if ($Tag -eq "latest") {
    try {
        $gitTag = git describe --tags --always --dirty 2>$null
        if ($gitTag) { $Tag = $gitTag }
    } catch {
        # Keep "latest" if git command fails
    }
}

Write-Host "Building Docker image with tag: $Tag" -ForegroundColor Blue
docker build -t cdc-pipeline:$Tag .

switch ($Cloud) {
    "azure" {
        Write-Host "Pushing to Azure Container Registry..." -ForegroundColor Blue
        
        Push-Location "terraform\azure"
        try {
            $acrName = terraform output -raw acr_login_server 2>$null
            if (-not $acrName) {
                Write-Host "Error: ACR not found. Run deploy-azure.ps1 first" -ForegroundColor Red
                exit 1
            }
            
            $acrShortName = $acrName.Split('.')[0]
            az acr login --name $acrShortName
            
            docker tag cdc-pipeline:$Tag "$acrName/cdc-pipeline:$Tag"
            docker push "$acrName/cdc-pipeline:$Tag"
            
            Write-Host "✓ Pushed to $acrName/cdc-pipeline:$Tag" -ForegroundColor Green
        } finally {
            Pop-Location
        }
    }
    
    "aws" {
        Write-Host "Pushing to AWS ECR..." -ForegroundColor Blue
        
        $awsAccount = aws sts get-caller-identity --query Account --output text
        
        Push-Location "terraform\aws"
        try {
            $awsRegion = terraform output -raw aws_region 2>$null
            if (-not $awsRegion) { $awsRegion = "us-east-1" }
            
            $ecrUrl = "$awsAccount.dkr.ecr.$awsRegion.amazonaws.com"
            
            aws ecr get-login-password --region $awsRegion | docker login --username AWS --password-stdin $ecrUrl
            
            docker tag cdc-pipeline:$Tag "$ecrUrl/cdc-pipeline:$Tag"
            docker push "$ecrUrl/cdc-pipeline:$Tag"
            
            Write-Host "✓ Pushed to $ecrUrl/cdc-pipeline:$Tag" -ForegroundColor Green
        } finally {
            Pop-Location
        }
    }
    
    "gcp" {
        Write-Host "Pushing to GCP Artifact Registry..." -ForegroundColor Blue
        
        Push-Location "terraform\gcp"
        try {
            $gcpProject = terraform output -raw project_id 2>$null
            $gcpRegion = terraform output -raw region 2>$null
            
            if (-not $gcpProject) {
                Write-Host "Error: GCP project not found" -ForegroundColor Red
                exit 1
            }
            if (-not $gcpRegion) { $gcpRegion = "us-central1" }
            
            $garUrl = "$gcpRegion-docker.pkg.dev/$gcpProject/cdc-pipeline"
            
            gcloud auth configure-docker "$gcpRegion-docker.pkg.dev"
            
            docker tag cdc-pipeline:$Tag "$garUrl/cdc-pipeline:$Tag"
            docker push "$garUrl/cdc-pipeline:$Tag"
            
            Write-Host "✓ Pushed to $garUrl/cdc-pipeline:$Tag" -ForegroundColor Green
        } finally {
            Pop-Location
        }
    }
}

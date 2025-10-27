

# ==========================================
# FILE: scripts/health_check.ps1
# ==========================================
# Health check script for deployed CDC pipeline
# Usage: .\scripts\health_check.ps1 [azure|aws|gcp]

param(
    [Parameter(Position=0)]
    [ValidateSet("azure", "aws", "gcp")]
    [string]$Cloud = "azure"
)

$ErrorActionPreference = "Stop"

function Test-HealthEndpoint {
    param([string]$Url)
    
    Write-Host "Checking health at: $Url" -ForegroundColor Blue
    
    try {
        $response = Invoke-WebRequest -Uri "$Url/health" -UseBasicParsing
        
        if ($response.StatusCode -eq 200) {
            Write-Host "✓ Health check passed" -ForegroundColor Green
            $response.Content | ConvertFrom-Json | ConvertTo-Json -Depth 10
            return $true
        } else {
            Write-Host "✗ Health check failed (HTTP $($response.StatusCode))" -ForegroundColor Red
            Write-Host $response.Content
            return $false
        }
    } catch {
        Write-Host "✗ Health check failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

switch ($Cloud) {
    "azure" {
        Write-Host "Checking Azure Container App..." -ForegroundColor Blue
        Push-Location "terraform\azure"
        try {
            $appUrl = terraform output -raw container_app_url 2>$null
            if (-not $appUrl) {
                Write-Host "Error: Container App URL not found" -ForegroundColor Red
                exit 1
            }
            Test-HealthEndpoint -Url $appUrl
        } finally {
            Pop-Location
        }
    }
    
    "aws" {
        Write-Host "Checking AWS ECS Service..." -ForegroundColor Blue
        Push-Location "terraform\aws"
        try {
            $cluster = terraform output -raw ecs_cluster_name
            $service = terraform output -raw ecs_service_name
            $region = terraform output -raw aws_region
            
            $taskArn = aws ecs list-tasks --cluster $cluster --service-name $service --region $region --query 'taskArns[0]' --output text
            
            if (-not $taskArn -or $taskArn -eq "None") {
                Write-Host "✗ No running tasks found" -ForegroundColor Red
                exit 1
            }
            
            Write-Host "✓ ECS service is running" -ForegroundColor Green
            Write-Host "Task ARN: $taskArn"
            Write-Host "Check logs: aws logs tail /ecs/cdc-pipeline --follow --region $region"
        } finally {
            Pop-Location
        }
    }
    
    "gcp" {
        Write-Host "Checking GCP Cloud Run..." -ForegroundColor Blue
        Push-Location "terraform\gcp"
        try {
            $runUrl = terraform output -raw cloud_run_url 2>$null
            if (-not $runUrl) {
                Write-Host "Error: Cloud Run URL not found" -ForegroundColor Red
                exit 1
            }
            Test-HealthEndpoint -Url $runUrl
        } finally {
            Pop-Location
        }
    }
}

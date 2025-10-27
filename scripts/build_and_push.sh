#!/bin/bash
# ==========================================
# FILE: scripts/build_and_push.sh
# ==========================================
# Build and push Docker image to cloud registry
# Usage: ./scripts/build_and_push.sh [azure|aws|gcp] [tag]

set -e

CLOUD=${1:-azure}
TAG=${2:-$(git describe --tags --always --dirty 2>/dev/null || echo "latest")}

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}Building Docker image with tag: ${TAG}${NC}"
docker build -t cdc-pipeline:${TAG} .

case $CLOUD in
  azure)
    echo -e "${BLUE}Pushing to Azure Container Registry...${NC}"
    
    cd terraform/azure
    ACR_NAME=$(terraform output -raw acr_login_server 2>/dev/null || echo "")
    cd ../..
    
    if [ -z "$ACR_NAME" ]; then
      echo -e "${RED}Error: ACR not found. Run 'make azure-setup' first${NC}"
      exit 1
    fi
    
    ACR_SHORT_NAME=$(echo $ACR_NAME | cut -d'.' -f1)
    az acr login --name $ACR_SHORT_NAME
    
    docker tag cdc-pipeline:${TAG} ${ACR_NAME}/cdc-pipeline:${TAG}
    docker push ${ACR_NAME}/cdc-pipeline:${TAG}
    
    echo -e "${GREEN}✓ Pushed to ${ACR_NAME}/cdc-pipeline:${TAG}${NC}"
    ;;
    
  aws)
    echo -e "${BLUE}Pushing to AWS ECR...${NC}"
    
    AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    
    cd terraform/aws
    AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-east-1")
    cd ../..
    
    ECR_URL="${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    
    aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_URL}
    
    docker tag cdc-pipeline:${TAG} ${ECR_URL}/cdc-pipeline:${TAG}
    docker push ${ECR_URL}/cdc-pipeline:${TAG}
    
    echo -e "${GREEN}✓ Pushed to ${ECR_URL}/cdc-pipeline:${TAG}${NC}"
    ;;
    
  gcp)
    echo -e "${BLUE}Pushing to GCP Artifact Registry...${NC}"
    
    cd terraform/gcp
    GCP_PROJECT=$(terraform output -raw project_id 2>/dev/null || echo "")
    GCP_REGION=$(terraform output -raw region 2>/dev/null || echo "us-central1")
    cd ../..
    
    if [ -z "$GCP_PROJECT" ]; then
      echo -e "${RED}Error: GCP project not found${NC}"
      exit 1
    fi
    
    GAR_URL="${GCP_REGION}-docker.pkg.dev/${GCP_PROJECT}/cdc-pipeline"
    
    gcloud auth configure-docker ${GCP_REGION}-docker.pkg.dev
    
    docker tag cdc-pipeline:${TAG} ${GAR_URL}/cdc-pipeline:${TAG}
    docker push ${GAR_URL}/cdc-pipeline:${TAG}
    
    echo -e "${GREEN}✓ Pushed to ${GAR_URL}/cdc-pipeline:${TAG}${NC}"
    ;;
    
  *)
    echo -e "${RED}Error: Unsupported cloud provider: ${CLOUD}${NC}"
    echo "Usage: $0 [azure|aws|gcp] [tag]"
    exit 1
    ;;
esac


#!/bin/bash
# ==========================================
# FILE: scripts/deploy-azure.sh
# ==========================================
# Deploy CDC pipeline to Azure (Bash version)
# Usage: ./scripts/deploy-azure.sh [tag]

set -e

IMAGE_TAG=${1:-latest}

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
cat << "EOF"
╔════════════════════════════════════════╗
║   Deploying to Azure Container Apps   ║
╚════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check prerequisites
echo -e "\n${YELLOW}Step 1/4: Checking prerequisites...${NC}"

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

if ! command_exists az || ! command_exists terraform || ! command_exists docker; then
    echo -e "${RED}Error: Missing required tools${NC}"
    exit 1
fi

if ! az account show >/dev/null 2>&1; then
    echo -e "${RED}Error: Not logged in to Azure${NC}"
    exit 1
fi

if [ ! -f "terraform/azure/terraform.tfvars" ]; then
    echo -e "${RED}Error: terraform.tfvars not found${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites OK${NC}"

# Initialize Terraform
echo -e "\n${YELLOW}Step 2/4: Initializing Terraform...${NC}"
cd terraform/azure
terraform init
echo -e "${GREEN}✓ Terraform initialized${NC}"
cd ../..

# Build and push
echo -e "\n${YELLOW}Step 3/4: Building and pushing container...${NC}"
./scripts/build_and_push.sh azure ${IMAGE_TAG}

# Deploy
echo -e "\n${YELLOW}Step 4/4: Deploying infrastructure...${NC}"
cd terraform/azure
terraform apply -var="image_tag=${IMAGE_TAG}" -auto-approve

echo -e "\n${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✓ Deployment Complete!               ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"

# Output info
echo -e "\n${BLUE}Container App URL:${NC}"
terraform output container_app_url

echo -e "\n${BLUE}Storage Account:${NC}"
terraform output storage_account_name

cd ../..


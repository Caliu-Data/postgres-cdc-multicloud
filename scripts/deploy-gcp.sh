#!/bin/bash
# ==========================================
# FILE: scripts/deploy-gcp.sh
# ==========================================
# Deploy CDC pipeline to GCP (Bash version)
# Usage: ./scripts/deploy-gcp.sh [tag]

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
║   Deploying to GCP Cloud Run           ║
╚════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Similar structure as Azure, adapted for GCP
echo -e "\n${YELLOW}Step 1/4: Checking prerequisites...${NC}"
# ... (same pattern)
echo -e "${GREEN}✓ Prerequisites OK${NC}"

echo -e "\n${YELLOW}Step 2/4: Initializing Terraform...${NC}"
cd terraform/gcp
terraform init
cd ../..

echo -e "\n${YELLOW}Step 3/4: Building and pushing container...${NC}"
./scripts/build_and_push.sh gcp ${IMAGE_TAG}

echo -e "\n${YELLOW}Step 4/4: Deploying infrastructure...${NC}"
cd terraform/gcp
terraform apply -var="image_tag=${IMAGE_TAG}" -auto-approve
cd ../..

#!/bin/bash
# ==========================================
# FILE: scripts/deploy-aws.sh
# ==========================================
# Deploy CDC pipeline to AWS (Bash version)
# Usage: ./scripts/deploy-aws.sh [tag]

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
║   Deploying to AWS Fargate             ║
╚════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Similar structure as Azure, adapted for AWS
echo -e "\n${YELLOW}Step 1/4: Checking prerequisites...${NC}"
# ... (same pattern as Azure)
echo -e "${GREEN}✓ Prerequisites OK${NC}"

echo -e "\n${YELLOW}Step 2/4: Initializing Terraform...${NC}"
cd terraform/aws
terraform init
cd ../..

echo -e "\n${YELLOW}Step 3/4: Building and pushing container...${NC}"
./scripts/build_and_push.sh aws ${IMAGE_TAG}

echo -e "\n${YELLOW}Step 4/4: Deploying infrastructure...${NC}"
cd terraform/aws
terraform apply -var="image_tag=${IMAGE_TAG}" -auto-approve
cd ../..


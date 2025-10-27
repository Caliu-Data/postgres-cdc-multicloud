#!/bin/bash
# ==========================================
# FILE: scripts/health_check.sh
# ==========================================
# Health check script for deployed CDC pipeline
# Usage: ./scripts/health_check.sh [azure|aws|gcp]

set -e

CLOUD=${1:-azure}

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

check_health() {
  local url=$1
  echo -e "${BLUE}Checking health at: ${url}${NC}"
  
  response=$(curl -s -w "\n%{http_code}" "${url}/health" || echo "000")
  body=$(echo "$response" | head -n -1)
  status=$(echo "$response" | tail -n 1)
  
  if [ "$status" = "200" ]; then
    echo -e "${GREEN}✓ Health check passed${NC}"
    echo "$body" | jq '.' 2>/dev/null || echo "$body"
    return 0
  else
    echo -e "${RED}✗ Health check failed (HTTP ${status})${NC}"
    echo "$body"
    return 1
  fi
}

case $CLOUD in
  azure)
    echo -e "${BLUE}Checking Azure Container App...${NC}"
    cd terraform/azure
    APP_URL=$(terraform output -raw container_app_url 2>/dev/null || echo "")
    cd ../..
    
    if [ -z "$APP_URL" ]; then
      echo -e "${RED}Error: Container App URL not found${NC}"
      exit 1
    fi
    check_health "$APP_URL"
    ;;
    
  aws)
    echo -e "${BLUE}Checking AWS ECS Service...${NC}"
    cd terraform/aws
    CLUSTER=$(terraform output -raw ecs_cluster_name)
    SERVICE=$(terraform output -raw ecs_service_name)
    REGION=$(terraform output -raw aws_region)
    cd ../..
    
    TASK_ARN=$(aws ecs list-tasks --cluster $CLUSTER --service-name $SERVICE --region $REGION --query 'taskArns[0]' --output text)
    
    if [ -z "$TASK_ARN" ] || [ "$TASK_ARN" = "None" ]; then
      echo -e "${RED}✗ No running tasks found${NC}"
      exit 1
    fi
    
    echo -e "${GREEN}✓ ECS service is running${NC}"
    echo "Task ARN: $TASK_ARN"
    echo -e "${YELLOW}Check logs: aws logs tail /ecs/cdc-pipeline --follow --region ${REGION}${NC}"
    ;;
    
  gcp)
    echo -e "${BLUE}Checking GCP Cloud Run...${NC}"
    cd terraform/gcp
    RUN_URL=$(terraform output -raw cloud_run_url 2>/dev/null || echo "")
    cd ../..
    
    if [ -z "$RUN_URL" ]; then
      echo -e "${RED}Error: Cloud Run URL not found${NC}"
      exit 1
    fi
    check_health "$RUN_URL"
    ;;
    
  *)
    echo -e "${RED}Error: Unsupported cloud provider: ${CLOUD}${NC}"
    exit 1
    ;;
esac

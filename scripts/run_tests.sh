#!/bin/bash
# ==========================================
# FILE: scripts/run_tests.sh
# ==========================================
# Run tests for CDC Pipeline
# Usage: ./scripts/run_tests.sh

set -e

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}Running CDC Pipeline Tests...${NC}\n"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
  echo -e "${RED}✗ Docker is not running${NC}"
  echo "Please start Docker and try again"
  exit 1
fi

# Build the project
echo -e "${BLUE}Building project...${NC}"
docker build -t cdc-pipeline:test .
echo -e "${GREEN}✓ Build successful${NC}\n"

# Run Maven tests
echo -e "${BLUE}Running unit tests...${NC}"
docker run --rm cdc-pipeline:test mvn test

if [ $? -eq 0 ]; then
  echo -e "${GREEN}✓ All tests passed${NC}"
else
  echo -e "${RED}✗ Tests failed${NC}"
  exit 1
fi

# Optional: Run integration tests if they exist
if [ -f "src/test/java/integration" ]; then
  echo -e "\n${BLUE}Running integration tests...${NC}"
  docker run --rm cdc-pipeline:test mvn integration-test
  
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Integration tests passed${NC}"
  else
    echo -e "${RED}✗ Integration tests failed${NC}"
    exit 1
  fi
fi

echo -e "\n${GREEN}╔════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✓ All Tests Passed Successfully  ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════╝${NC}"


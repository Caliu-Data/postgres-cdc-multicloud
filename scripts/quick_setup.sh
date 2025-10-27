#!/bin/bash
# ==========================================
# FILE: scripts/quick_setup.sh
# ==========================================
# Quick setup script for PostgreSQL CDC Pipeline
# Usage: ./scripts/quick_setup.sh

set -e

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   PostgreSQL CDC Multi-Cloud Pipeline - Quick Setup          ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Step 1: Check Prerequisites
echo -e "\n${BLUE}==>${NC} Checking prerequisites..."

MISSING_DEPS=()

if ! command_exists docker; then
    MISSING_DEPS+=("docker")
fi

if ! command_exists terraform; then
    MISSING_DEPS+=("terraform")
fi

if ! command_exists git; then
    MISSING_DEPS+=("git")
fi

if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
    echo -e "${RED}✗${NC} Missing dependencies: ${MISSING_DEPS[*]}"
    echo "Please install the missing dependencies and try again."
    exit 1
fi

echo -e "${GREEN}✓${NC} All prerequisites installed"

# Step 2: Select Cloud Provider
echo -e "\n${BLUE}==>${NC} Select your cloud provider"
echo "1) Azure"
echo "2) AWS"
echo "3) GCP"
read -p "Enter choice [1-3]: " cloud_choice

case $cloud_choice in
    1)
        CLOUD="azure"
        if ! command_exists az; then
            echo -e "${RED}✗${NC} Azure CLI not found. Please install: https://aka.ms/install-azure-cli"
            exit 1
        fi
        echo -e "${GREEN}✓${NC} Azure selected"
        ;;
    2)
        CLOUD="aws"
        if ! command_exists aws; then
            echo -e "${RED}✗${NC} AWS CLI not found. Please install: https://aws.amazon.com/cli/"
            exit 1
        fi
        echo -e "${GREEN}✓${NC} AWS selected"
        ;;
    3)
        CLOUD="gcp"
        if ! command_exists gcloud; then
            echo -e "${RED}✗${NC} gcloud CLI not found. Please install: https://cloud.google.com/sdk/docs/install"
            exit 1
        fi
        echo -e "${GREEN}✓${NC} GCP selected"
        ;;
    *)
        echo -e "${RED}✗${NC} Invalid choice"
        exit 1
        ;;
esac

# Step 3: Check Cloud Authentication
echo -e "\n${BLUE}==>${NC} Checking cloud authentication..."

case $CLOUD in
    azure)
        if ! az account show >/dev/null 2>&1; then
            echo -e "${YELLOW}⚠${NC} Not logged in to Azure"
            read -p "Login now? (y/n): " login_choice
            if [ "$login_choice" = "y" ]; then
                az login
            else
                echo -e "${RED}✗${NC} Please run 'az login' and try again"
                exit 1
            fi
        fi
        echo -e "${GREEN}✓${NC} Azure authentication OK"
        ;;
    aws)
        if ! aws sts get-caller-identity >/dev/null 2>&1; then
            echo -e "${RED}✗${NC} AWS credentials not configured"
            echo "Please run 'aws configure' and try again"
            exit 1
        fi
        echo -e "${GREEN}✓${NC} AWS authentication OK"
        ;;
    gcp)
        if ! gcloud auth print-access-token >/dev/null 2>&1; then
            echo -e "${YELLOW}⚠${NC} Not logged in to GCP"
            read -p "Login now? (y/n): " login_choice
            if [ "$login_choice" = "y" ]; then
                gcloud auth login
            else
                echo -e "${RED}✗${NC} Please run 'gcloud auth login' and try again"
                exit 1
            fi
        fi
        echo -e "${GREEN}✓${NC} GCP authentication OK"
        ;;
esac

# Step 4: Configure Terraform
echo -e "\n${BLUE}==>${NC} Configuring Terraform variables..."

TFVARS_DIR="terraform/${CLOUD}"
TFVARS_FILE="${TFVARS_DIR}/terraform.tfvars"
EXAMPLE_FILE="${TFVARS_DIR}/terraform.tfvars.example"

if [ -f "$TFVARS_FILE" ]; then
    echo -e "${YELLOW}⚠${NC} terraform.tfvars already exists"
    read -p "Overwrite? (y/n): " overwrite
    if [ "$overwrite" = "y" ]; then
        cp "$EXAMPLE_FILE" "$TFVARS_FILE"
        echo -e "${GREEN}✓${NC} Created terraform.tfvars from example"
    else
        echo -e "${YELLOW}⚠${NC} Skipping configuration"
    fi
else
    cp "$EXAMPLE_FILE" "$TFVARS_FILE"
    echo -e "${GREEN}✓${NC} Created terraform.tfvars from example"
fi

# Step 5: Prompt for PostgreSQL details
echo -e "\n${BLUE}==>${NC} PostgreSQL Configuration"
echo "Please provide your PostgreSQL connection details:"
echo ""

read -p "PostgreSQL Host: " pg_host
read -p "PostgreSQL Database: " pg_database
read -p "PostgreSQL User: " pg_user
read -sp "PostgreSQL Password: " pg_password
echo ""
read -p "Tables to capture (comma-separated, e.g., schema.table1,schema.table2): " table_include

# Update terraform.tfvars with PostgreSQL details
sed -i.bak "s|pg_host.*=.*|pg_host = \"$pg_host\"|" "$TFVARS_FILE"
sed -i.bak "s|pg_database.*=.*|pg_database = \"$pg_database\"|" "$TFVARS_FILE"
sed -i.bak "s|pg_user.*=.*|pg_user = \"$pg_user\"|" "$TFVARS_FILE"
sed -i.bak "s|pg_password.*=.*|pg_password = \"$pg_password\"|" "$TFVARS_FILE"
sed -i.bak "s|table_include.*=.*|table_include = \"$table_include\"|" "$TFVARS_FILE"

rm -f "${TFVARS_FILE}.bak"

echo -e "${GREEN}✓${NC} PostgreSQL configuration saved"

# Step 6: Cloud-specific configuration
echo -e "\n${BLUE}==>${NC} Cloud-specific configuration"

case $CLOUD in
    azure)
        read -p "Resource Group Name: " rg_name
        read -p "Azure Region (e.g., eastus): " location
        read -p "Container Registry Name (globally unique): " acr_name
        read -p "Storage Account Name (globally unique, lowercase): " storage_name
        
        sed -i.bak "s|resource_group_name.*=.*|resource_group_name = \"$rg_name\"|" "$TFVARS_FILE"
        sed -i.bak "s|location.*=.*|location = \"$location\"|" "$TFVARS_FILE"
        sed -i.bak "s|acr_name.*=.*|acr_name = \"$acr_name\"|" "$TFVARS_FILE"
        sed -i.bak "s|storage_account_name.*=.*|storage_account_name = \"$storage_name\"|" "$TFVARS_FILE"
        rm -f "${TFVARS_FILE}.bak"
        ;;
    aws)
        read -p "AWS Region (e.g., us-east-1): " aws_region
        read -p "S3 Bucket Name (globally unique): " s3_bucket
        
        sed -i.bak "s|aws_region.*=.*|aws_region = \"$aws_region\"|" "$TFVARS_FILE"
        sed -i.bak "s|s3_bucket_name.*=.*|s3_bucket_name = \"$s3_bucket\"|" "$TFVARS_FILE"
        rm -f "${TFVARS_FILE}.bak"
        ;;
    gcp)
        read -p "GCP Project ID: " project_id
        read -p "GCP Region (e.g., us-central1): " gcp_region
        read -p "GCS Bucket Name (globally unique): " gcs_bucket
        
        sed -i.bak "s|project_id.*=.*|project_id = \"$project_id\"|" "$TFVARS_FILE"
        sed -i.bak "s|region.*=.*|region = \"$gcp_region\"|" "$TFVARS_FILE"
        sed -i.bak "s|gcs_bucket_name.*=.*|gcs_bucket_name = \"$gcs_bucket\"|" "$TFVARS_FILE"
        rm -f "${TFVARS_FILE}.bak"
        ;;
esac

echo -e "${GREEN}✓${NC} Configuration complete"

# Step 7: PostgreSQL Setup Instructions
echo -e "\n${BLUE}==>${NC} PostgreSQL Setup Required"
echo ""
echo -e "${YELLOW}IMPORTANT:${NC} Before deploying, you must prepare your PostgreSQL database:"
echo ""
echo "1. Enable logical replication (requires restart):"
echo "   Add to postgresql.conf:"
echo "   wal_level = logical"
echo "   max_replication_slots = 10"
echo "   max_wal_senders = 10"
echo ""
echo "2. Run the setup script on your PostgreSQL server:"
echo "   psql -h $pg_host -U postgres -d $pg_database -f scripts/setup_postgres.sql"
echo ""
read -p "Have you completed the PostgreSQL setup? (y/n): " pg_setup

if [ "$pg_setup" != "y" ]; then
    echo -e "${YELLOW}⚠${NC} Please complete PostgreSQL setup first"
    echo "Setup script saved in: scripts/setup_postgres.sql"
    exit 0
fi

# Step 8: Ready to Deploy
echo -e "\n${BLUE}==>${NC} Ready to Deploy!"
echo ""
echo "Configuration saved to: $TFVARS_FILE"
echo ""
echo "To deploy, run:"
echo -e "${GREEN}make deploy-${CLOUD}${NC}"
echo ""
read -p "Deploy now? (y/n): " deploy_now

if [ "$deploy_now" = "y" ]; then
    make "deploy-${CLOUD}"
else
    echo ""
    echo -e "${GREEN}✓${NC} Setup complete!"
    echo ""
    echo "When ready to deploy, run:"
    echo -e "${GREEN}make deploy-${CLOUD}${NC}"
    echo ""
fi
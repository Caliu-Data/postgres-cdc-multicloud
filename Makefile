.PHONY: help build push deploy-azure deploy-aws deploy-gcp test clean

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m # No Color

# Configuration
IMAGE_NAME := postgres-cdc-pipeline
VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
DOCKERFILE := Dockerfile

# Azure Configuration
AZURE_REGISTRY := $(shell terraform -chdir=terraform/azure output -raw acr_login_server 2>/dev/null || echo "notset")
AZURE_IMAGE := $(AZURE_REGISTRY)/$(IMAGE_NAME):$(VERSION)

# AWS Configuration
AWS_ACCOUNT := $(shell aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "notset")
AWS_REGION := $(shell terraform -chdir=terraform/aws output -raw aws_region 2>/dev/null || echo "us-east-1")
AWS_REGISTRY := $(AWS_ACCOUNT).dkr.ecr.$(AWS_REGION).amazonaws.com
AWS_IMAGE := $(AWS_REGISTRY)/$(IMAGE_NAME):$(VERSION)

# GCP Configuration
GCP_PROJECT := $(shell terraform -chdir=terraform/gcp output -raw project_id 2>/dev/null || echo "notset")
GCP_REGION := $(shell terraform -chdir=terraform/gcp output -raw region 2>/dev/null || echo "us-central1")
GCP_REGISTRY := $(GCP_REGION)-docker.pkg.dev/$(GCP_PROJECT)/cdc-pipeline
GCP_IMAGE := $(GCP_REGISTRY)/$(IMAGE_NAME):$(VERSION)

help: ## Show this help message
	@echo "$(BLUE)PostgreSQL CDC Multi-Cloud Pipeline$(NC)"
	@echo ""
	@echo "$(GREEN)Available targets:$(NC)"
	@awk 'BEGIN {FS = ":.*##"; printf "\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

build: ## Build the Docker image locally
	@echo "$(BLUE)Building Docker image...$(NC)"
	docker build -t $(IMAGE_NAME):$(VERSION) -f $(DOCKERFILE) .
	@echo "$(GREEN)✓ Build complete: $(IMAGE_NAME):$(VERSION)$(NC)"

test: build ## Run integration tests
	@echo "$(BLUE)Running tests...$(NC)"
	./scripts/run_tests.sh
	@echo "$(GREEN)✓ All tests passed$(NC)"

# ===== AZURE =====

azure-setup: ## Setup Azure prerequisites (Resource Group, ACR)
	@echo "$(BLUE)Setting up Azure prerequisites...$(NC)"
	@cd terraform/azure && terraform init
	@cd terraform/azure && terraform apply -target=azurerm_resource_group.main -target=azurerm_container_registry.acr -auto-approve
	@echo "$(GREEN)✓ Azure setup complete$(NC)"

azure-build: ## Build and push Docker image to Azure ACR
	@echo "$(BLUE)Building and pushing to Azure Container Registry...$(NC)"
	@if [ "$(AZURE_REGISTRY)" = "notset" ]; then \
		echo "$(RED)Error: ACR not found. Run 'make azure-setup' first$(NC)"; \
		exit 1; \
	fi
	az acr login --name $(shell echo $(AZURE_REGISTRY) | cut -d'.' -f1)
	docker build -t $(AZURE_IMAGE) -f $(DOCKERFILE) .
	docker push $(AZURE_IMAGE)
	@echo "$(GREEN)✓ Image pushed: $(AZURE_IMAGE)$(NC)"

deploy-azure: ## 🚀 Deploy complete pipeline to Azure (ONE COMMAND!)
	@echo "$(BLUE)╔════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║   Deploying to Azure Container Apps   ║$(NC)"
	@echo "$(BLUE)╚════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(YELLOW)Step 1/4: Checking prerequisites...$(NC)"
	@command -v az >/dev/null 2>&1 || { echo "$(RED)Error: Azure CLI not installed$(NC)"; exit 1; }
	@command -v terraform >/dev/null 2>&1 || { echo "$(RED)Error: Terraform not installed$(NC)"; exit 1; }
	@command -v docker >/dev/null 2>&1 || { echo "$(RED)Error: Docker not installed$(NC)"; exit 1; }
	@az account show >/dev/null 2>&1 || { echo "$(RED)Error: Not logged in to Azure. Run: az login$(NC)"; exit 1; }
	@test -f terraform/azure/terraform.tfvars || { echo "$(RED)Error: terraform.tfvars not found. Copy from terraform.tfvars.example$(NC)"; exit 1; }
	@echo "$(GREEN)✓ Prerequisites OK$(NC)"
	@echo ""
	@echo "$(YELLOW)Step 2/4: Initializing Terraform...$(NC)"
	@cd terraform/azure && terraform init
	@echo "$(GREEN)✓ Terraform initialized$(NC)"
	@echo ""
	@echo "$(YELLOW)Step 3/4: Building and pushing container...$(NC)"
	@$(MAKE) azure-build VERSION=$(VERSION)
	@echo ""
	@echo "$(YELLOW)Step 4/4: Deploying infrastructure...$(NC)"
	@cd terraform/azure && terraform apply -var="image_tag=$(VERSION)" -auto-approve
	@echo ""
	@echo "$(GREEN)╔════════════════════════════════════════╗$(NC)"
	@echo "$(GREEN)║  ✓ Deployment Complete!               ║$(NC)"
	@echo "$(GREEN)╚════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(BLUE)Container App URL:$(NC)"
	@cd terraform/azure && terraform output container_app_url
	@echo ""
	@echo "$(BLUE)Storage Account:$(NC)"
	@cd terraform/azure && terraform output storage_account_name
	@echo ""
	@echo "$(YELLOW)Next steps:$(NC)"
	@echo "  1. Check health: curl \$$(cd terraform/azure && terraform output -raw container_app_url)/health"
	@echo "  2. Configure Databricks with the storage account URL"
	@echo "  3. Monitor logs: az containerapp logs show --name cdc-app --resource-group <rg-name> --follow"

destroy-azure: ## Destroy Azure infrastructure
	@echo "$(RED)Destroying Azure infrastructure...$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		cd terraform/azure && terraform destroy -auto-approve; \
		echo "$(GREEN)✓ Infrastructure destroyed$(NC)"; \
	else \
		echo "Cancelled"; \
	fi

# ===== AWS =====

aws-setup: ## Setup AWS prerequisites (ECR)
	@echo "$(BLUE)Setting up AWS prerequisites...$(NC)"
	@cd terraform/aws && terraform init
	@cd terraform/aws && terraform apply -target=aws_ecr_repository.cdc -auto-approve
	@echo "$(GREEN)✓ AWS setup complete$(NC)"

aws-build: ## Build and push Docker image to AWS ECR
	@echo "$(BLUE)Building and pushing to AWS ECR...$(NC)"
	@if [ "$(AWS_ACCOUNT)" = "notset" ]; then \
		echo "$(RED)Error: AWS credentials not configured$(NC)"; \
		exit 1; \
	fi
	aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(AWS_REGISTRY)
	docker build -t $(AWS_IMAGE) -f $(DOCKERFILE) .
	docker push $(AWS_IMAGE)
	@echo "$(GREEN)✓ Image pushed: $(AWS_IMAGE)$(NC)"

deploy-aws: ## 🚀 Deploy complete pipeline to AWS (ONE COMMAND!)
	@echo "$(BLUE)╔════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║   Deploying to AWS Fargate             ║$(NC)"
	@echo "$(BLUE)╚════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(YELLOW)Step 1/4: Checking prerequisites...$(NC)"
	@command -v aws >/dev/null 2>&1 || { echo "$(RED)Error: AWS CLI not installed$(NC)"; exit 1; }
	@command -v terraform >/dev/null 2>&1 || { echo "$(RED)Error: Terraform not installed$(NC)"; exit 1; }
	@command -v docker >/dev/null 2>&1 || { echo "$(RED)Error: Docker not installed$(NC)"; exit 1; }
	@aws sts get-caller-identity >/dev/null 2>&1 || { echo "$(RED)Error: Not logged in to AWS. Configure credentials$(NC)"; exit 1; }
	@test -f terraform/aws/terraform.tfvars || { echo "$(RED)Error: terraform.tfvars not found$(NC)"; exit 1; }
	@echo "$(GREEN)✓ Prerequisites OK$(NC)"
	@echo ""
	@echo "$(YELLOW)Step 2/4: Initializing Terraform...$(NC)"
	@cd terraform/aws && terraform init
	@echo "$(GREEN)✓ Terraform initialized$(NC)"
	@echo ""
	@echo "$(YELLOW)Step 3/4: Building and pushing container...$(NC)"
	@$(MAKE) aws-build VERSION=$(VERSION)
	@echo ""
	@echo "$(YELLOW)Step 4/4: Deploying infrastructure...$(NC)"
	@cd terraform/aws && terraform apply -var="image_tag=$(VERSION)" -auto-approve
	@echo ""
	@echo "$(GREEN)╔════════════════════════════════════════╗$(NC)"
	@echo "$(GREEN)║  ✓ Deployment Complete!               ║$(NC)"
	@echo "$(GREEN)╚════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(BLUE)ECS Service:$(NC)"
	@cd terraform/aws && terraform output ecs_service_name
	@echo ""
	@echo "$(BLUE)S3 Bucket:$(NC)"
	@cd terraform/aws && terraform output s3_bucket_name

destroy-aws: ## Destroy AWS infrastructure
	@echo "$(RED)Destroying AWS infrastructure...$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		cd terraform/aws && terraform destroy -auto-approve; \
		echo "$(GREEN)✓ Infrastructure destroyed$(NC)"; \
	fi

# ===== GCP =====

gcp-setup: ## Setup GCP prerequisites (Artifact Registry)
	@echo "$(BLUE)Setting up GCP prerequisites...$(NC)"
	@cd terraform/gcp && terraform init
	@cd terraform/gcp && terraform apply -target=google_artifact_registry_repository.cdc -auto-approve
	@echo "$(GREEN)✓ GCP setup complete$(NC)"

gcp-build: ## Build and push Docker image to GCP Artifact Registry
	@echo "$(BLUE)Building and pushing to GCP Artifact Registry...$(NC)"
	@if [ "$(GCP_PROJECT)" = "notset" ]; then \
		echo "$(RED)Error: GCP project not configured$(NC)"; \
		exit 1; \
	fi
	gcloud auth configure-docker $(GCP_REGION)-docker.pkg.dev
	docker build -t $(GCP_IMAGE) -f $(DOCKERFILE) .
	docker push $(GCP_IMAGE)
	@echo "$(GREEN)✓ Image pushed: $(GCP_IMAGE)$(NC)"

deploy-gcp: ## 🚀 Deploy complete pipeline to GCP (ONE COMMAND!)
	@echo "$(BLUE)╔════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║   Deploying to GCP Cloud Run          ║$(NC)"
	@echo "$(BLUE)╚════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(YELLOW)Step 1/4: Checking prerequisites...$(NC)"
	@command -v gcloud >/dev/null 2>&1 || { echo "$(RED)Error: gcloud CLI not installed$(NC)"; exit 1; }
	@command -v terraform >/dev/null 2>&1 || { echo "$(RED)Error: Terraform not installed$(NC)"; exit 1; }
	@command -v docker >/dev/null 2>&1 || { echo "$(RED)Error: Docker not installed$(NC)"; exit 1; }
	@gcloud auth print-access-token >/dev/null 2>&1 || { echo "$(RED)Error: Not logged in to GCP. Run: gcloud auth login$(NC)"; exit 1; }
	@test -f terraform/gcp/terraform.tfvars || { echo "$(RED)Error: terraform.tfvars not found$(NC)"; exit 1; }
	@echo "$(GREEN)✓ Prerequisites OK$(NC)"
	@echo ""
	@echo "$(YELLOW)Step 2/4: Initializing Terraform...$(NC)"
	@cd terraform/gcp && terraform init
	@echo "$(GREEN)✓ Terraform initialized$(NC)"
	@echo ""
	@echo "$(YELLOW)Step 3/4: Building and pushing container...$(NC)"
	@$(MAKE) gcp-build VERSION=$(VERSION)
	@echo ""
	@echo "$(YELLOW)Step 4/4: Deploying infrastructure...$(NC)"
	@cd terraform/gcp && terraform apply -var="image_tag=$(VERSION)" -auto-approve
	@echo ""
	@echo "$(GREEN)╔════════════════════════════════════════╗$(NC)"
	@echo "$(GREEN)║  ✓ Deployment Complete!               ║$(NC)"
	@echo "$(GREEN)╚════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(BLUE)Cloud Run URL:$(NC)"
	@cd terraform/gcp && terraform output cloud_run_url
	@echo ""
	@echo "$(BLUE)GCS Bucket:$(NC)"
	@cd terraform/gcp && terraform output gcs_bucket_name

destroy-gcp: ## Destroy GCP infrastructure
	@echo "$(RED)Destroying GCP infrastructure...$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		cd terraform/gcp && terraform destroy -auto-approve; \
		echo "$(GREEN)✓ Infrastructure destroyed$(NC)"; \
	fi

# ===== UTILITIES =====

clean: ## Clean local build artifacts
	@echo "$(BLUE)Cleaning build artifacts...$(NC)"
	rm -rf target/
	rm -rf .terraform/
	docker image prune -f
	@echo "$(GREEN)✓ Clean complete$(NC)"

logs-azure: ## Tail Azure Container App logs
	@echo "$(BLUE)Tailing Azure logs (Ctrl+C to exit)...$(NC)"
	@RG=$$(cd terraform/azure && terraform output -raw resource_group_name); \
	APP=$$(cd terraform/azure && terraform output -raw container_app_name); \
	az containerapp logs show --name $$APP --resource-group $$RG --follow

logs-aws: ## Tail AWS ECS logs
	@echo "$(BLUE)Tailing AWS logs (Ctrl+C to exit)...$(NC)"
	@CLUSTER=$$(cd terraform/aws && terraform output -raw ecs_cluster_name); \
	SERVICE=$$(cd terraform/aws && terraform output -raw ecs_service_name); \
	aws ecs describe-tasks --cluster $$CLUSTER --tasks $$(aws ecs list-tasks --cluster $$CLUSTER --service
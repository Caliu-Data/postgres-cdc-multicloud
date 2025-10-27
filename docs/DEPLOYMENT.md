Detailed Deployment Guide
This guide covers advanced deployment scenarios and production best practices.
Prerequisites
Azure Deployment

Azure subscription
Azure CLI installed and authenticated
Contributor role on subscription
Terraform 1.5+

AWS Deployment

AWS account
AWS CLI configured
IAM permissions for ECS, ECR, S3
Terraform 1.5+

GCP Deployment

GCP project
gcloud CLI authenticated
Project Editor role
Terraform 1.5+

Step-by-Step Deployment
1. Prepare PostgreSQL
sql-- Enable logical replication (requires restart)
-- In postgresql.conf:
wal_level = logical
max_replication_slots = 10
max_wal_senders = 10

-- Restart PostgreSQL

-- Create CDC user
CREATE USER cdcuser WITH REPLICATION PASSWORD 'strong_password';

-- Grant permissions
GRANT CONNECT ON DATABASE warehouse TO cdcuser;
GRANT USAGE ON SCHEMA warehouse TO cdcuser;
GRANT SELECT ON ALL TABLES IN SCHEMA warehouse TO cdcuser;

-- Create publication
CREATE PUBLICATION cdc_pub FOR TABLE
    warehouse.stock_item,
    warehouse.stock_movement;
2. Configure Terraform
bash# Navigate to cloud-specific directory
cd terraform/azure  # or aws/gcp

# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars
3. Deploy Infrastructure
bash# Initialize Terraform
terraform init

# Review plan
terraform plan

# Apply (confirm with 'yes')
terraform apply

# Save outputs
terraform output > outputs.txt
4. Build and Push Container
bash# Using Makefile (recommended)
make deploy-azure

# Or manually
./scripts/build_and_push.sh azure
5. Configure Databricks

Create compute cluster
Install required libraries (none needed for Autoloader)
Import notebooks from databricks/ directory
Update storage paths in 01_bronze_ingestion.py
Run bronze ingestion notebook
Run silver merge notebook (schedule as job)
Run gold aggregation notebook (schedule as job)

6. Verify Deployment
bash# Check health
./scripts/health_check.sh azure

# View logs (Azure)
az containerapp logs show \
  --name cdc-pipeline \
  --resource-group rg-cdc-pipeline \
  --follow

# View logs (AWS)
aws logs tail /ecs/cdc-pipeline --follow

# View logs (GCP)
gcloud logging read "resource.type=cloud_run_revision" --limit 50
Production Checklist
Security

 Use Azure Key Vault / AWS Secrets Manager / GCP Secret Manager
 Enable private endpoints for PostgreSQL
 Configure VNet/VPC injection
 Rotate credentials regularly
 Enable audit logging
 Set up IAM policies with least privilege

Reliability

 Configure auto-restart policies
 Set up health check alerts
 Enable container instance redundancy (if needed)
 Test disaster recovery procedures
 Document rollback procedures

Monitoring

 Set up CloudWatch/Azure Monitor/Cloud Logging
 Create dashboards for key metrics
 Configure alerts for lag > 60s
 Monitor storage growth
 Set up on-call rotation

Performance

 Tune batch size based on workload
 Monitor network latency
 Optimize table includes list
 Consider table-level parallelism for high volume
 Benchmark end-to-end latency

Cost Management

 Set up budget alerts
 Review monthly costs
 Optimize container size if over-provisioned
 Implement storage lifecycle policies
 Use spot instances (AWS) if applicable
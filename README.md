# 🚀 PostgreSQL CDC Multi-Cloud Pipeline

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/docker-ready-blue.svg)](https://www.docker.com/)
[![Terraform](https://img.shields.io/badge/terraform-1.5+-purple.svg)](https://www.terraform.io/)

> **True Change Data Capture from PostgreSQL to Databricks**  
> Multi-Cloud Ready • Deploy in 5 Minutes • ~$7/month

A production-ready, vendor-neutral CDC pipeline that captures PostgreSQL changes and streams them to Databricks via object storage. **No Kafka, no complex infrastructure**—just one container and object storage.

---

## 📋 Table of Contents

- [What This Solves](#-what-this-solves)
- [Quick Start](#-quick-start)
- [Architecture](#-architecture)
- [Project Structure](#-project-structure)
- [Detailed Setup](#-detailed-setup)
- [Databricks Configuration](#-databricks-configuration)
- [Monitoring](#-monitoring)
- [Cost Breakdown](#-cost-breakdown)
- [FAQ](#-faq)

---

## 🎯 What This Solves

✅ **Real-time CDC** from PostgreSQL using logical replication  
✅ **Cost-optimized** infrastructure (~$5-10/month on Azure)  
✅ **Multi-cloud portable** - Same code runs on Azure, AWS, or GCP  
✅ **Infrastructure as Code** - Full Terraform automation  
✅ **Production-ready** - Monitoring, health checks, and auto-restart

**Perfect for:**
- Real-time inventory tracking
- Order fulfillment monitoring
- Customer 360 views
- Audit logging
- Data lake synchronization

---

## 🚀 Quick Start

### Choose Your Platform

<details open>
<summary><b>🪟 Windows (PowerShell)</b></summary>

```powershell
# 1. Clone repository
git clone https://github.com/yourusername/postgres-cdc-multicloud.git
Set-Location postgres-cdc-multicloud

# 2. Run interactive setup (recommended)
.\scripts\quick_setup.ps1

# The script will:
# ✓ Check prerequisites
# ✓ Configure your cloud provider
# ✓ Set up PostgreSQL connection
# ✓ Create terraform.tfvars
# ✓ Deploy everything automatically
```

**Manual deployment (if you prefer):**
```powershell
# Prepare PostgreSQL first (IMPORTANT!)
# See scripts\setup_postgres.sql

# Configure Terraform
Copy-Item terraform\azure\terraform.tfvars.example terraform\azure\terraform.tfvars
# Edit terraform\azure\terraform.tfvars with your values

# Deploy
.\scripts\deploy-azure.ps1
# Or for AWS/GCP:
.\scripts\deploy-aws.ps1
.\scripts\deploy-gcp.ps1
```

</details>

<details>
<summary><b>🐧 Linux / 🍎 Mac (Bash)</b></summary>

```bash
# 1. Clone repository
git clone https://github.com/yourusername/postgres-cdc-multicloud.git
cd postgres-cdc-multicloud

# 2. Make scripts executable
chmod +x scripts/*.sh

# 3. Run interactive setup (recommended)
./scripts/quick_setup.sh

# The script will:
# ✓ Check prerequisites
# ✓ Configure your cloud provider
# ✓ Set up PostgreSQL connection
# ✓ Create terraform.tfvars
# ✓ Deploy everything automatically
```

**Manual deployment with Makefile:**
```bash
# Prepare PostgreSQL first (IMPORTANT!)
# See scripts/setup_postgres.sql

# Configure Terraform
cp terraform/azure/terraform.tfvars.example terraform/azure/terraform.tfvars
# Edit terraform/azure/terraform.tfvars

# Deploy using Makefile
make deploy-azure
# Or for AWS/GCP:
make deploy-aws
make deploy-gcp
```

</details>

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     PostgreSQL Database                     │
│                   (Logical Replication)                     │
└──────────────────────┬──────────────────────────────────────┘
                       │ Logical decoding (pgoutput)
                       ↓
┌─────────────────────────────────────────────────────────────┐
│              CDC Container (Debezium Embedded)              │
│                   Java 17 + Event Batching                  │
└──────────────────────┬──────────────────────────────────────┘
                       │ Batched writes (NDJSON)
                       ↓
┌─────────────────────────────────────────────────────────────┐
│         Object Storage (ADLS Gen2 / S3 / GCS)              │
│          Partitioned by date=YYYY-MM-DD/hour=HH            │
└──────────────────────┬──────────────────────────────────────┘
                       │ Auto-discovery
                       ↓
┌─────────────────────────────────────────────────────────────┐
│              Databricks Autoloader                          │
│            (Structured Streaming + Checkpoints)            │
└──────────────────────┬──────────────────────────────────────┘
                       │ Delta Lake MERGE
                       ↓
┌─────────────────────────────────────────────────────────────┐
│                   Delta Lake Tables                         │
│         Bronze → Silver → Gold (Medallion)                  │
└─────────────────────────────────────────────────────────────┘
```

**Why This Design?**
- ✅ No Kafka/Event Hubs overhead
- ✅ Minimal infrastructure (1 container + storage)
- ✅ Cloud-agnostic (same container everywhere)
- ✅ Cost-optimized (object storage is pennies)
- ✅ Databricks-native ingestion

---

## 📁 Project Structure

```
postgres-cdc-multicloud/
│
├── 📄 Core Files
│   ├── Dockerfile                  # Multi-stage Docker build
│   ├── pom.xml                     # Maven configuration
│   ├── README.md                   # This file
│   └── LICENSE                     # MIT License
│
├── 💻 Source Code
│   └── src/main/java/com/cdc/
│       ├── Main.java              # Debezium Embedded engine
│       ├── EventBatcher.java      # Batching logic
│       ├── StorageSink.java       # Storage interface
│       └── storage/
│           ├── AzureStorageSink.java   # Azure implementation
│           ├── S3StorageSink.java      # AWS implementation
│           └── GcsStorageSink.java     # GCP implementation
│
├── ☁️ Infrastructure (Terraform)
│   ├── terraform/azure/           # Azure deployment
│   ├── terraform/aws/             # AWS deployment
│   └── terraform/gcp/             # GCP deployment
│
├── 📊 Databricks Notebooks
│   ├── 01_bronze_ingestion.py     # Autoloader setup
│   ├── 02_silver_merge.py         # CDC MERGE logic
│   └── 03_gold_aggregation.sql    # Business metrics
│
├── 🔧 Scripts
│   ├── Windows (PowerShell)
│   │   ├── quick_setup.ps1        # Interactive setup
│   │   ├── deploy-azure.ps1       # Azure deployment
│   │   ├── deploy-aws.ps1         # AWS deployment
│   │   ├── deploy-gcp.ps1         # GCP deployment
│   │   ├── build_and_push.ps1     # Docker build/push
│   │   └── health_check.ps1       # Health monitoring
│   │
│   └── Linux/Mac (Bash)
│       ├── quick_setup.sh         # Interactive setup
│       ├── deploy-azure.sh        # Azure deployment
│       ├── deploy-aws.sh          # AWS deployment
│       ├── deploy-gcp.sh          # GCP deployment
│       ├── build_and_push.sh      # Docker build/push
│       ├── health_check.sh        # Health monitoring
│       └── run_tests.sh           # Unit tests
│
├── 📚 Documentation
│   ├── ARCHITECTURE.md            # System design details
│   ├── DEPLOYMENT.md              # Advanced deployment
│   ├── TROUBLESHOOTING.md         # Common issues
│   └── CONTRIBUTING.md            # Contribution guide
│
└── 🤖 CI/CD
    └── .github/workflows/
        ├── deploy.yml             # Auto-deployment
        └── pr-check.yml           # PR validation
```

---

## 🔧 Detailed Setup

### Step 1: Prerequisites

**Required Tools:**
- ✅ Docker Desktop
- ✅ Terraform 1.5+
- ✅ Git
- ✅ Cloud CLI (choose one):
  - Azure: `az` CLI
  - AWS: `aws` CLI
  - GCP: `gcloud` CLI

**Check Installation:**

<details>
<summary><b>🪟 Windows</b></summary>

```powershell
# Check versions
docker --version
terraform --version
git --version
az --version     # or aws --version, or gcloud --version

# If missing, install:
# Docker: https://www.docker.com/products/docker-desktop
# Terraform: https://www.terraform.io/downloads
# Azure CLI: https://aka.ms/install-azure-cli
# AWS CLI: https://aws.amazon.com/cli/
# GCloud: https://cloud.google.com/sdk/docs/install
```

</details>

<details>
<summary><b>🐧 Linux / 🍎 Mac</b></summary>

```bash
# Check versions
docker --version
terraform --version
git --version
az --version     # or aws --version, or gcloud --version

# Install missing tools (example for Ubuntu):
# Docker: https://docs.docker.com/engine/install/ubuntu/
# Terraform: https://www.terraform.io/downloads
# Cloud CLIs: See official documentation
```

</details>

---

### Step 2: PostgreSQL Setup (CRITICAL!)

**Enable logical replication on your PostgreSQL server:**

```sql
-- 1. Edit postgresql.conf (requires restart)
wal_level = logical
max_replication_slots = 10
max_wal_senders = 10

-- 2. Restart PostgreSQL

-- 3. Create CDC user
CREATE USER cdcuser WITH REPLICATION PASSWORD 'YourSecurePassword123!';

-- 4. Grant permissions
GRANT CONNECT ON DATABASE warehouse TO cdcuser;
GRANT USAGE ON SCHEMA warehouse TO cdcuser;
GRANT SELECT ON ALL TABLES IN SCHEMA warehouse TO cdcuser;

-- 5. Create publication
CREATE PUBLICATION cdc_pub FOR TABLE
  warehouse.stock_item,
  warehouse.stock_movement;

-- 6. Verify setup
SELECT * FROM pg_publication WHERE pubname = 'cdc_pub';
SELECT * FROM pg_publication_tables WHERE pubname = 'cdc_pub';
```

**Full script available at:** `scripts/setup_postgres.sql`

---

### Step 3: Cloud Authentication

<details>
<summary><b>☁️ Azure</b></summary>

```powershell
# Login
az login

# Select subscription (if multiple)
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Verify
az account show
```

</details>

<details>
<summary><b>☁️ AWS</b></summary>

```bash
# Configure credentials
aws configure
# Enter: Access Key ID, Secret Access Key, Region, Output format

# Verify
aws sts get-caller-identity
```

</details>

<details>
<summary><b>☁️ GCP</b></summary>

```bash
# Login
gcloud auth login

# Set project
gcloud config set project YOUR_PROJECT_ID

# Verify
gcloud config list
```

</details>

---

### Step 4: Configure Terraform

**Choose your cloud and configure:**

<details>
<summary><b>☁️ Azure Configuration</b></summary>

**Windows:**
```powershell
Copy-Item terraform\azure\terraform.tfvars.example terraform\azure\terraform.tfvars
code terraform\azure\terraform.tfvars  # or notepad
```

**Linux/Mac:**
```bash
cp terraform/azure/terraform.tfvars.example terraform/azure/terraform.tfvars
nano terraform/azure/terraform.tfvars  # or vi, vim, etc.
```

**Edit these values:**
```hcl
# Resource configuration
resource_group_name   = "rg-cdc-pipeline-prod"
location              = "eastus"
acr_name              = "cdcpipelineacr123"      # Must be globally unique
storage_account_name  = "cdclandingsa123"        # Must be globally unique, lowercase

# PostgreSQL connection
pg_host       = "your-postgres.postgres.database.azure.com"
pg_port       = "5432"
pg_database   = "warehouse"
pg_user       = "cdcuser"
pg_password   = "YourSecurePassword123!"
pg_publication = "cdc_pub"
pg_slot       = "cdc_slot"

# Tables to capture
table_include = "warehouse.stock_item,warehouse.stock_movement"
```

</details>

<details>
<summary><b>☁️ AWS Configuration</b></summary>

**Windows:**
```powershell
Copy-Item terraform\aws\terraform.tfvars.example terraform\aws\terraform.tfvars
code terraform\aws\terraform.tfvars
```

**Linux/Mac:**
```bash
cp terraform/aws/terraform.tfvars.example terraform/aws/terraform.tfvars
nano terraform/aws/terraform.tfvars
```

**Edit these values:**
```hcl
aws_region       = "us-east-1"
s3_bucket_name   = "cdc-landing-bucket-123"  # Must be globally unique

# PostgreSQL connection
pg_host       = "your-postgres.rds.amazonaws.com"
pg_port       = "5432"
pg_database   = "warehouse"
pg_user       = "cdcuser"
pg_password   = "YourSecurePassword123!"
table_include = "warehouse.stock_item,warehouse.stock_movement"
```

</details>

<details>
<summary><b>☁️ GCP Configuration</b></summary>

**Windows:**
```powershell
Copy-Item terraform\gcp\terraform.tfvars.example terraform\gcp\terraform.tfvars
code terraform\gcp\terraform.tfvars
```

**Linux/Mac:**
```bash
cp terraform/gcp/terraform.tfvars.example terraform/gcp/terraform.tfvars
nano terraform/gcp/terraform.tfvars
```

**Edit these values:**
```hcl
project_id        = "your-gcp-project-id"
region            = "us-central1"
gcs_bucket_name   = "cdc-landing-bucket-123"  # Must be globally unique

# PostgreSQL connection
pg_host       = "your-postgres.googleapis.com"
pg_port       = "5432"
pg_database   = "warehouse"
pg_user       = "cdcuser"
pg_password   = "YourSecurePassword123!"
table_include = "warehouse.stock_item,warehouse.stock_movement"
```

</details>

---

### Step 5: Deploy

**Choose your platform and cloud:**

<details>
<summary><b>🪟 Windows Deployment</b></summary>

```powershell
# Azure
.\scripts\deploy-azure.ps1

# AWS
.\scripts\deploy-aws.ps1

# GCP
.\scripts\deploy-gcp.ps1

# With specific image tag
.\scripts\deploy-azure.ps1 -ImageTag v1.0.0
```

**What happens:**
1. ✅ Checks prerequisites
2. ✅ Initializes Terraform
3. ✅ Builds Docker image
4. ✅ Pushes to cloud registry
5. ✅ Deploys infrastructure
6. ✅ Outputs connection details

</details>

<details>
<summary><b>🐧 Linux / 🍎 Mac Deployment</b></summary>

```bash
# Using Makefile (recommended)
make deploy-azure
make deploy-aws
make deploy-gcp

# Or directly with scripts
./scripts/deploy-azure.sh
./scripts/deploy-aws.sh
./scripts/deploy-gcp.sh

# With specific image tag
./scripts/deploy-azure.sh v1.0.0
```

**What happens:**
1. ✅ Checks prerequisites
2. ✅ Initializes Terraform
3. ✅ Builds Docker image
4. ✅ Pushes to cloud registry
5. ✅ Deploys infrastructure
6. ✅ Outputs connection details

</details>

---

## 📊 Databricks Configuration

### Step 1: Bronze Layer (Autoloader)

Create a Databricks notebook and run:

```python
# Configure storage path based on your cloud
# Azure:
source = "abfss://landing@<your-storage-account>.dfs.core.windows.net/landing"
# AWS:
# source = "s3://your-bucket-name/landing"
# GCP:
# source = "gs://your-bucket-name/landing"

# Create databases
spark.sql("CREATE DATABASE IF NOT EXISTS bronze")
spark.sql("CREATE DATABASE IF NOT EXISTS silver")
spark.sql("CREATE DATABASE IF NOT EXISTS gold")

# Ingest stock items
(spark.readStream
    .format("cloudFiles")
    .option("cloudFiles.format", "json")
    .option("cloudFiles.schemaLocation", "dbfs:/checkpoints/bronze/stock_item_schema")
    .load(f"{source}/cdc.warehouse.stock_item")
    .writeStream
    .format("delta")
    .option("checkpointLocation", "dbfs:/checkpoints/bronze/stock_item")
    .table("bronze.stock_item"))

# Ingest stock movements
(spark.readStream
    .format("cloudFiles")
    .option("cloudFiles.format", "json")
    .option("cloudFiles.schemaLocation", "dbfs:/checkpoints/bronze/stock_movement_schema")
    .load(f"{source}/cdc.warehouse.stock_movement")
    .writeStream
    .format("delta")
    .option("checkpointLocation", "dbfs:/checkpoints/bronze/stock_movement")
    .table("bronze.stock_movement"))
```

**Full notebook:** `databricks/01_bronze_ingestion.py`

---

### Step 2: Silver Layer (MERGE)

```python
from delta.tables import DeltaTable

# Get latest changes
latest_changes = spark.sql("""
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY item_id ORDER BY ingestion_timestamp DESC) as rn
    FROM bronze.stock_item
""").filter("rn = 1").drop("rn")

# Create/update silver table
spark.sql("""
    CREATE TABLE IF NOT EXISTS silver.stock_item (
        item_id INT NOT NULL,
        sku STRING,
        name STRING,
        location_id INT,
        initial_qty INT,
        updated_at TIMESTAMP,
        _last_updated TIMESTAMP,
        CONSTRAINT pk_item PRIMARY KEY (item_id)
    ) USING DELTA
""")

# Perform MERGE
silver_table = DeltaTable.forName(spark, "silver.stock_item")

(silver_table.alias("target")
    .merge(latest_changes.alias("source"), "target.item_id = source.item_id")
    .whenMatchedDelete(condition="source.__deleted = 'true' OR source.__op = 'd'")
    .whenMatchedUpdate(set={
        "sku": "source.sku",
        "name": "source.name",
        "location_id": "source.location_id",
        "initial_qty": "source.initial_qty",
        "updated_at": "source.updated_at",
        "_last_updated": "source.ingestion_timestamp"
    })
    .whenNotMatchedInsert(
        condition="source.__deleted != 'true' AND source.__op != 'd'",
        values={
            "item_id": "source.item_id",
            "sku": "source.sku",
            "name": "source.name",
            "location_id": "source.location_id",
            "initial_qty": "source.initial_qty",
            "updated_at": "source.updated_at",
            "_last_updated": "source.ingestion_timestamp"
        }
    )
    .execute())
```

**Full notebook:** `databricks/02_silver_merge.py`

---

### Step 3: Gold Layer (Analytics)

```sql
-- Calculate remaining stock
CREATE OR REPLACE TABLE gold.remaining_stock AS
SELECT 
    i.item_id,
    i.sku,
    i.name,
    i.location_id,
    i.initial_qty,
    COALESCE(m.qty_in, 0) AS total_in,
    COALESCE(m.qty_out, 0) AS total_out,
    i.initial_qty + COALESCE(m.qty_in, 0) - COALESCE(m.qty_out, 0) AS remaining_qty,
    CURRENT_TIMESTAMP() AS computed_at
FROM silver.stock_item i
LEFT JOIN (
    SELECT 
        item_id,
        SUM(CASE WHEN type = 'IN' THEN qty ELSE 0 END) AS qty_in,
        SUM(CASE WHEN type = 'OUT' THEN qty ELSE 0 END) AS qty_out
    FROM silver.stock_movement
    GROUP BY item_id
) m ON i.item_id = m.item_id;
```

**Full notebook:** `databricks/03_gold_aggregation.sql`

---

## 🔍 Monitoring

### Health Checks

<details>
<summary><b>🪟 Windows</b></summary>

```powershell
# Check health
.\scripts\health_check.ps1 azure
.\scripts\health_check.ps1 aws
.\scripts\health_check.ps1 gcp

# View logs - Azure
az containerapp logs show --name cdc-app --resource-group <rg-name> --follow

# View logs - AWS
aws logs tail /ecs/cdc-pipeline --follow --region us-east-1

# View logs - GCP
gcloud logging tail "resource.type=cloud_run_revision"
```

</details>

<details>
<summary><b>🐧 Linux / 🍎 Mac</b></summary>

```bash
# Check health
./scripts/health_check.sh azure
./scripts/health_check.sh aws
./scripts/health_check.sh gcp

# View logs - Azure
az containerapp logs show --name cdc-app --resource-group <rg-name> --follow

# View logs - AWS
aws logs tail /ecs/cdc-pipeline --follow --region us-east-1

# View logs - GCP
gcloud logging tail "resource.type=cloud_run_revision"
```

</details>

---

## 💰 Cost Breakdown

| Cloud | Resources | Monthly Cost |
|-------|-----------|--------------|
| **Azure** | Container App (0.25 vCPU, 0.5 GB)<br>Storage Account (Standard LRS) | **~$7-8** |
| **AWS** | ECS Fargate (0.25 vCPU, 0.5 GB)<br>S3 (Standard) | **~$10-13** |
| **GCP** | Cloud Run (min instances)<br>Cloud Storage (Standard) | **~$12-15** |

*Excludes Databricks compute costs*

**Cost Savings:** ~86% cheaper than traditional CDC solutions ($7 vs $200+/month)

---

## 🙋 FAQ

<details>
<summary><b>Q: Can I use this with other databases?</b></summary>

Yes! Debezium supports MySQL, SQL Server, MongoDB, Oracle, and more. Just swap the connector in `pom.xml` and update the configuration.

</details>

<details>
<summary><b>Q: What about DELETE operations?</b></summary>

Fully supported! Debezium captures DELETE operations with the complete row state before deletion.

</details>

<details>
<summary><b>Q: How do I handle schema changes?</b></summary>

Debezium automatically captures schema changes. Enable `mergeSchema` option in Databricks Autoloader to handle schema evolution.

</details>

<details>
<summary><b>Q: Can I use this without Databricks?</b></summary>

Absolutely! The container writes standard NDJSON files to object storage. Any system that reads from storage works (Spark, Flink, custom apps).

</details>

<details>
<summary><b>Q: How do I scale for high-volume databases?</b></summary>

For high-volume:
- Run multiple containers (one per table or table group)
- Use separate replication slots
- Increase container resources
- Optimize batch size settings

</details>

<details>
<summary><b>Q: Which cloud provider should I choose?</b></summary>

- **Azure**: Cheapest (~$7/month), best for Microsoft shops
- **AWS**: Good ecosystem integration, ~$10-13/month
- **GCP**: Instant scaling with Cloud Run, ~$12-15/month

All three use identical code!

</details>

---

## 🤝 Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

## 📝 License

This project is licensed under the MIT License - see [LICENSE](LICENSE) for details.

---

## 🌟 Star This Project

If this helps you, please ⭐ star the repository on GitHub!

---

## 📧 Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/postgres-cdc-multicloud/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/postgres-cdc-multicloud/discussions)
- **Documentation**: See `docs/` folder

---

**Built with ❤️ for the data engineering community**
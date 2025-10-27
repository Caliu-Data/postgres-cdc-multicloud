Troubleshooting Guide
Common Issues and Solutions
PostgreSQL Connection Issues
Problem: Container can't connect to PostgreSQL
Solutions:

Verify network connectivity
Check firewall rules
Verify credentials
Ensure logical replication is enabled
Check replication slot exists

sql-- Verify replication settings
SHOW wal_level;  -- Should be 'logical'

-- Check replication slots
SELECT * FROM pg_replication_slots;
Replication Lag
Problem: Lag increasing over time
Possible Causes:

Container undersized
Network bandwidth limited
PostgreSQL under load
Batch size too small

Solutions:

Increase container resources
Tune batch size: BATCH_MAX_SIZE environment variable
Check PostgreSQL slow queries
Consider table-level parallelism

Storage Write Failures
Problem: Failed to write to object storage
Azure:
bash# Verify managed identity has permissions
az role assignment list --assignee <identity-id>
AWS:
bash# Verify IAM role
aws iam get-role-policy --role-name cdc-task-role --policy-name s3-access
GCP:
bash# Verify service account
gcloud projects get-iam-policy <project-id>
Databricks Ingestion Issues
Problem: Autoloader not picking up files
Checks:

Verify storage path is correct
Check access permissions
Ensure checkpoint location is writable
Review streaming query logs

python# Check what files Autoloader sees
display(spark.read.format("cloudFiles")
  .option("cloudFiles.format", "json")
  .load("your-path"))
Container Crashes
Problem: Container repeatedly restarting
Debug Steps:

Check logs for exceptions
Verify environment variables
Check resource limits
Review health check endpoint

bash# Azure
az containerapp logs show --name cdc-pipeline --resource-group rg-cdc

# AWS
aws ecs describe-tasks --cluster cdc-cluster --tasks <task-arn>

# GCP
gcloud logging read "resource.type=cloud_run_revision" --limit 100
Schema Evolution
Problem: New columns not appearing in Delta tables
Solution:
python# Enable schema merging in Autoloader
.option("mergeSchema", "true")
.option("cloudFiles.schemaEvolutionMode", "addNewColumns")
Performance Tuning
Optimize Batch Size
bash# Increase for high-volume workloads
BATCH_MAX_SIZE=10000000  # 10MB
BATCH_MAX_SECONDS=5

# Decrease for low-latency requirements
BATCH_MAX_SIZE=1000000   # 1MB
BATCH_MAX_SECONDS=1
Optimize Autoloader
python# Tune Autoloader performance
(spark.readStream
  .format("cloudFiles")
  .option("cloudFiles.maxFilesPerTrigger", "1000")  # Batch size
  .option("cloudFiles.maxBytesPerTrigger", "1g")    # Data per batch
  .load(path))
Getting Help
If you're still stuck:

Check Issues for similar problems
Review Debezium logs for detailed error messages
Enable debug logging: Set SLF4J_LEVEL=DEBUG
Create a new issue with:

Cloud provider
Error logs
Steps to reproduce
Environment details
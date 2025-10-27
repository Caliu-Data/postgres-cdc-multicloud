Architecture Overview
System Design
The PostgreSQL CDC Multi-Cloud Pipeline is designed around these core principles:

Simplicity: No complex brokers or streaming platforms
Cost-efficiency: Minimal infrastructure footprint
Portability: Same code runs on any cloud
Reliability: Durable buffering with object storage

Components
1. CDC Microservice
Technology: Java 17 + Debezium Embedded Engine
Responsibilities:

Connects to PostgreSQL replication slot
Reads change events via logical decoding (pgoutput)
Batches events for efficient storage
Writes NDJSON files to object storage

Key Classes:

Main.java: Engine initialization and lifecycle
EventBatcher.java: Time/size-based batching
StorageSink.java: Cloud-agnostic storage interface
storage/*: Cloud-specific implementations

2. Object Storage Layer
Options: Azure ADLS Gen2, AWS S3, Google Cloud Storage
Structure:
landing/
  {table_name}/
    date=YYYY-MM-DD/
      hour=HH/
        part-{timestamp}.ndjson
Why This Structure?:

Partitioned by date/hour for efficient querying
Hive-style partitions work with Databricks Autoloader
Immutable files prevent consistency issues
Easy to replay/reprocess specific time ranges

3. Databricks Ingestion
Technology: Autoloader (Structured Streaming)
Process:

Bronze Layer: Raw CDC events as Delta tables
Silver Layer: MERGE operations for current state
Gold Layer: Business metrics and aggregations

Benefits:

Exactly-once processing semantics
Automatic schema evolution
Scalable to billions of events

Data Flow
PostgreSQL WAL
    ↓ (logical decoding)
CDC Container
    ↓ (batched writes)
Object Storage
    ↓ (Autoloader)
Bronze Delta Tables
    ↓ (MERGE/transform)
Silver Delta Tables
    ↓ (aggregate)
Gold Delta Tables
Failure Handling
Container Restarts

Debezium maintains offset files
Resumes from last committed LSN
No data loss

Network Interruptions

Exponential backoff retries
Object storage buffers data
PostgreSQL replication slot holds WAL

Schema Changes

Autoloader detects schema evolution
Can be configured to merge or fail
Databricks supports schema migration

Scalability
Horizontal Scaling
For high-volume databases:

Run multiple containers (one per table/group)
Use separate replication slots
Partition landing zone by table

Vertical Scaling
Single container can handle:

~10K events/second
~100 tables
~1GB/hour of changes

Security
Authentication

Azure: Managed Identity
AWS: IAM Roles
GCP: Service Accounts

Encryption

TLS for PostgreSQL connection
Encryption at rest for storage
In-transit encryption (HTTPS)

Network

VNet/VPC injection supported
Private endpoints recommended
No public IP required

Monitoring
Metrics

Events processed count
Replication lag (seconds)
Last processed LSN
Batch write latency

Health Check
Exposed at http://container:8080/health:
json{
  "status": "healthy",
  "eventsProcessed": 12345,
  "lastLsn": "0/1A2B3C4D",
  "lagSeconds": 2
}
Alerting Recommendations

Alert if lag > 60 seconds
Alert on container restarts
Monitor storage growth rate

Cost Optimization
Compute

Single small container: ~$5-10/month
Auto-scale for batch processing
Stop during maintenance windows

Storage

Object storage: ~$0.02/GB/month
Use lifecycle policies for old data
Compress landing files (future)

Data Transfer

Minimize cross-region transfers
Use cloud-native endpoints
Batch writes to reduce API calls
# ==========================================
# FILE: databricks/01_bronze_ingestion.py
# ==========================================
# Databricks notebook source
# MAGIC %md
# MAGIC # Bronze Layer: Autoloader Ingestion
# MAGIC 
# MAGIC This notebook sets up Autoloader to ingest CDC events from object storage into Delta Lake bronze tables.

# COMMAND ----------

# Configuration
# Change these based on your cloud provider

# Azure
storage_path = "abfss://landing@<your-storage-account>.dfs.core.windows.net/landing"

# AWS
# storage_path = "s3://your-bucket/landing"

# GCP
# storage_path = "gs://your-bucket/landing"

checkpoint_base = "dbfs:/checkpoints/bronze"

# COMMAND ----------

# MAGIC %md
# MAGIC ## Setup Database

# COMMAND ----------

spark.sql("CREATE DATABASE IF NOT EXISTS bronze")
spark.sql("CREATE DATABASE IF NOT EXISTS silver")
spark.sql("CREATE DATABASE IF NOT EXISTS gold")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Ingest Stock Items

# COMMAND ----------

from pyspark.sql.functions import *
from pyspark.sql.types import *

# Define schema (optional - Autoloader can infer)
stock_item_schema = StructType([
    StructField("item_id", IntegerType(), False),
    StructField("sku", StringType(), True),
    StructField("name", StringType(), True),
    StructField("location_id", IntegerType(), True),
    StructField("initial_qty", IntegerType(), True),
    StructField("updated_at", TimestampType(), True),
    StructField("__op", StringType(), True),  # CDC operation: c (create), u (update), d (delete)
    StructField("__source_ts_ms", LongType(), True),
    StructField("__deleted", StringType(), True)
])

# Start streaming from Autoloader
stock_item_stream = (
    spark.readStream
    .format("cloudFiles")
    .option("cloudFiles.format", "json")
    .option("cloudFiles.schemaLocation", f"{checkpoint_base}/stock_item_schema")
    .option("cloudFiles.inferColumnTypes", "true")
    .option("cloudFiles.schemaEvolutionMode", "addNewColumns")
    .load(f"{storage_path}/cdc.warehouse.stock_item")
    .withColumn("ingestion_timestamp", current_timestamp())
)

# Write to Delta table
(
    stock_item_stream.writeStream
    .format("delta")
    .outputMode("append")
    .option("checkpointLocation", f"{checkpoint_base}/stock_item")
    .option("mergeSchema", "true")
    .table("bronze.stock_item")
)

# COMMAND ----------

# MAGIC %md
# MAGIC ## Ingest Stock Movements

# COMMAND ----------

stock_movement_schema = StructType([
    StructField("movement_id", IntegerType(), False),
    StructField("item_id", IntegerType(), False),
    StructField("type", StringType(), True),  # IN or OUT
    StructField("qty", IntegerType(), True),
    StructField("ts", TimestampType(), True),
    StructField("__op", StringType(), True),
    StructField("__source_ts_ms", LongType(), True),
    StructField("__deleted", StringType(), True)
])

stock_movement_stream = (
    spark.readStream
    .format("cloudFiles")
    .option("cloudFiles.format", "json")
    .option("cloudFiles.schemaLocation", f"{checkpoint_base}/stock_movement_schema")
    .option("cloudFiles.inferColumnTypes", "true")
    .option("cloudFiles.schemaEvolutionMode", "addNewColumns")
    .load(f"{storage_path}/cdc.warehouse.stock_movement")
    .withColumn("ingestion_timestamp", current_timestamp())
)

(
    stock_movement_stream.writeStream
    .format("delta")
    .outputMode("append")
    .option("checkpointLocation", f"{checkpoint_base}/stock_movement")
    .option("mergeSchema", "true")
    .table("bronze.stock_movement")
)

# COMMAND ----------

# MAGIC %md
# MAGIC ## Verify Ingestion

# COMMAND ----------

# Check record counts
display(spark.sql("SELECT COUNT(*) as count FROM bronze.stock_item"))
display(spark.sql("SELECT COUNT(*) as count FROM bronze.stock_movement"))

# Sample data
display(spark.sql("SELECT * FROM bronze.stock_item LIMIT 10"))
display(spark.sql("SELECT * FROM bronze.stock_movement LIMIT 10"))
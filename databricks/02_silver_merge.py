
# ==========================================
# FILE: databricks/02_silver_merge.py
# ==========================================
# Databricks notebook source
# MAGIC %md
# MAGIC # Silver Layer: CDC MERGE Operations
# MAGIC 
# MAGIC Apply CDC changes to maintain current state in silver tables.

# COMMAND ----------

# MAGIC %md
# MAGIC ## Process Stock Items

# COMMAND ----------

# MAGIC %sql
# MAGIC CREATE TABLE IF NOT EXISTS silver.stock_item (
# MAGIC   item_id INT NOT NULL,
# MAGIC   sku STRING,
# MAGIC   name STRING,
# MAGIC   location_id INT,
# MAGIC   initial_qty INT,
# MAGIC   updated_at TIMESTAMP,
# MAGIC   _last_updated TIMESTAMP,
# MAGIC   CONSTRAINT pk_item PRIMARY KEY (item_id)
# MAGIC ) USING DELTA;

# COMMAND ----------

from delta.tables import DeltaTable

# Get latest changes from bronze
latest_changes = spark.sql("""
    SELECT 
        item_id,
        sku,
        name,
        location_id,
        initial_qty,
        updated_at,
        __op,
        __deleted,
        ingestion_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY item_id 
            ORDER BY ingestion_timestamp DESC
        ) as rn
    FROM bronze.stock_item
""").filter("rn = 1").drop("rn")

# Perform MERGE
silver_table = DeltaTable.forName(spark, "silver.stock_item")

(
    silver_table.alias("target")
    .merge(
        latest_changes.alias("source"),
        "target.item_id = source.item_id"
    )
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
    .execute()
)

print(f"Merged {latest_changes.count()} changes into silver.stock_item")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Process Stock Movements (Append-Only)

# COMMAND ----------

# MAGIC %sql
# MAGIC CREATE TABLE IF NOT EXISTS silver.stock_movement (
# MAGIC   movement_id INT NOT NULL,
# MAGIC   item_id INT NOT NULL,
# MAGIC   type STRING,
# MAGIC   qty INT,
# MAGIC   ts TIMESTAMP,
# MAGIC   _ingested_at TIMESTAMP,
# MAGIC   CONSTRAINT pk_movement PRIMARY KEY (movement_id)
# MAGIC ) USING DELTA;

# COMMAND ----------

# For movements, we typically append only (they're immutable events)
# But we handle duplicates with MERGE

movements = spark.sql("""
    SELECT DISTINCT
        movement_id,
        item_id,
        type,
        qty,
        ts,
        ingestion_timestamp as _ingested_at
    FROM bronze.stock_movement
    WHERE __deleted != 'true' AND __op != 'd'
""")

movement_table = DeltaTable.forName(spark, "silver.stock_movement")

(
    movement_table.alias("target")
    .merge(
        movements.alias("source"),
        "target.movement_id = source.movement_id"
    )
    .whenNotMatchedInsertAll()
    .execute()
)

print(f"Inserted {movements.count()} new movements into silver.stock_movement")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Verify Silver Layer

# COMMAND ----------

display(spark.sql("SELECT * FROM silver.stock_item LIMIT 10"))
display(spark.sql("SELECT * FROM silver.stock_movement LIMIT 10"))


# ==========================================
# FILE: databricks/03_gold_aggregation.sql
# ==========================================
-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Gold Layer: Business Metrics
-- MAGIC 
-- MAGIC Calculate remaining stock and other business KPIs.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Calculate Remaining Stock

-- COMMAND ----------

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
    CURRENT_TIMESTAMP() AS computed_at,
    i._last_updated AS last_item_update
FROM silver.stock_item i
LEFT JOIN (
    SELECT 
        item_id,
        SUM(CASE WHEN type = 'IN' THEN qty ELSE 0 END) AS qty_in,
        SUM(CASE WHEN type = 'OUT' THEN qty ELSE 0 END) AS qty_out
    FROM silver.stock_movement
    GROUP BY item_id
) m ON i.item_id = m.item_id;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Verify Results

-- COMMAND ----------

SELECT * FROM gold.remaining_stock ORDER BY remaining_qty ASC LIMIT 20;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Stock Summary by Location

-- COMMAND ----------

CREATE OR REPLACE TABLE gold.stock_summary_by_location AS
SELECT 
    location_id,
    COUNT(DISTINCT item_id) AS total_items,
    SUM(initial_qty) AS total_initial_qty,
    SUM(remaining_qty) AS total_remaining_qty,
    AVG(remaining_qty) AS avg_remaining_qty,
    computed_at
FROM gold.remaining_stock
GROUP BY location_id, computed_at;

-- COMMAND ----------

SELECT * FROM gold.stock_summary_by_location ORDER BY location_id;
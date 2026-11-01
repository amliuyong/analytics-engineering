-- Input contract checks return failing rows; adapt fields and quality policy before use.

SELECT dt, sku_id, COUNT(*) AS row_cnt
FROM dim.dim_sku_full
WHERE dt = CAST('${bizdate}' AS DATE)
GROUP BY dt, sku_id
HAVING COUNT(*) > 1;

SELECT dt, category_id, COUNT(*) AS row_cnt
FROM dim.dim_category_full
WHERE dt = CAST('${bizdate}' AS DATE)
GROUP BY dt, category_id
HAVING COUNT(*) > 1;

-- Flag repeated key/version pairs for inspection; remove identical duplicates in the cleaning layer.
SELECT order_id, order_item_id, source_version, COUNT(*) AS row_cnt
FROM ods.ods_trade_order_detail_slice
WHERE dt = CAST('${bizdate}' AS DATE)
GROUP BY order_id, order_item_id, source_version
HAVING COUNT(*) > 1;

SELECT order_id, order_item_id
FROM ods.ods_trade_order_detail_slice
WHERE dt = CAST('${bizdate}' AS DATE)
  AND (
      order_id IS NULL OR order_id < 0
      OR order_item_id IS NULL OR source_version IS NULL
      OR is_deleted IS NULL OR is_deleted NOT IN (0, 1)
      OR (is_deleted = 0 AND (
          user_id IS NULL OR user_id < 0 OR sku_id IS NULL
          OR quantity IS NULL OR item_order_amount IS NULL OR item_pay_amount IS NULL
          OR create_time IS NULL OR update_time IS NULL
      ))
  );

-- Check partition existence and ranges before writes; inspect output manually or with project tooling.
SHOW PARTITIONS FROM dwd.dwd_trade_order_detail_di;
SHOW PARTITIONS FROM dws.dws_trade_category_1d;
SHOW PARTITIONS FROM ads.ads_trade_category_1d;

-- DWD grain check; Duplicate storage does not enforce uniqueness.
SELECT dt, order_id, order_item_id, COUNT(*) AS row_cnt
FROM dwd.dwd_trade_order_detail_di
WHERE dt = CAST('${bizdate}' AS DATE)
GROUP BY dt, order_id, order_item_id
HAVING COUNT(*) > 1;

-- DWD-to-ADS reconciliation: amounts and exact order/user counts by category.
-- Return categories missing from either side; an inner join would hide them.
WITH expected AS (
    SELECT
        category_id,
        COUNT(DISTINCT order_id) AS order_cnt,
        COUNT(DISTINCT user_id) AS buyer_cnt,
        SUM(pay_amount) AS pay_amount
    FROM dwd.dwd_trade_order_detail_di
    WHERE dt = CAST('${bizdate}' AS DATE)
    GROUP BY category_id
), actual AS (
    SELECT category_id, order_cnt, buyer_cnt, pay_amount
    FROM ads.ads_trade_category_1d
    WHERE dt = CAST('${bizdate}' AS DATE)
)
SELECT e.category_id AS expected_category, a.category_id AS actual_category
FROM expected e
FULL OUTER JOIN actual a ON e.category_id = a.category_id
WHERE e.category_id IS NULL OR a.category_id IS NULL
   OR e.order_cnt <> a.order_cnt
   OR e.buyer_cnt <> a.buyer_cnt
   OR e.pay_amount <> a.pay_amount;

-- Add source-to-DWD reconciliation, unmatched rates, late/deleted records, empty-day and replay checks
-- for actual inputs and batches; the queries above do not establish those properties.

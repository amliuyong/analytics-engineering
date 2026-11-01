-- Read references/doris.md for the complete-slice, version, amount, and dimension contracts.
-- partition_name is an actual partition name verified with SHOW PARTITIONS.
-- Run input checks first. Confirm empty input means a legitimate empty day before replacing.
-- Serialize writes for a business day. Statements commit separately, without a cross-layer transaction.

INSERT OVERWRITE TABLE dwd.dwd_trade_order_detail_di
PARTITION (${partition_name})
(dt, order_id, order_item_id, user_id, sku_id, category_id,
 quantity, order_amount, pay_amount, create_time, update_time, source_version, etl_time)
SELECT
    CAST('${bizdate}' AS DATE),
    o.order_id,
    o.order_item_id,
    o.user_id,
    o.sku_id,
    COALESCE(s.category_id, -1),
    o.quantity,
    o.item_order_amount,
    o.item_pay_amount,
    o.create_time,
    o.update_time,
    o.source_version,
    CURRENT_TIMESTAMP
FROM (
    SELECT
        order_id, order_item_id, user_id, sku_id, quantity,
        item_order_amount, item_pay_amount, create_time, update_time,
        source_version, is_deleted,
        ROW_NUMBER() OVER (
            PARTITION BY order_id, order_item_id
            ORDER BY source_version DESC
        ) AS rn
    FROM ods.ods_trade_order_detail_slice
    WHERE dt = CAST('${bizdate}' AS DATE)
) o
LEFT JOIN (
    SELECT sku_id, category_id
    FROM dim.dim_sku_full
    WHERE dt = CAST('${bizdate}' AS DATE)
) s ON o.sku_id = s.sku_id
WHERE o.rn = 1 AND o.is_deleted = 0;

INSERT OVERWRITE TABLE dws.dws_trade_category_1d
PARTITION (${partition_name})
(dt, category_id, order_ids, buyer_ids, pay_amount, etl_time)
SELECT
    dt,
    category_id,
    BITMAP_UNION(TO_BITMAP(order_id)),
    BITMAP_UNION(TO_BITMAP(user_id)),
    SUM(pay_amount),
    CURRENT_TIMESTAMP
FROM dwd.dwd_trade_order_detail_di
WHERE dt = CAST('${bizdate}' AS DATE)
GROUP BY dt, category_id;

INSERT OVERWRITE TABLE ads.ads_trade_category_1d
PARTITION (${partition_name})
(dt, category_id, category_name, order_cnt, buyer_cnt, pay_amount, etl_time)
SELECT
    w.dt,
    w.category_id,
    COALESCE(c.category_name, 'Unknown category'),
    BITMAP_COUNT(w.order_ids),
    BITMAP_COUNT(w.buyer_ids),
    w.pay_amount,
    CURRENT_TIMESTAMP
FROM dws.dws_trade_category_1d w
LEFT JOIN (
    SELECT category_id, category_name
    FROM dim.dim_category_full
    WHERE dt = CAST('${bizdate}' AS DATE)
) c ON w.category_id = c.category_id
WHERE w.dt = CAST('${bizdate}' AS DATE);

-- Union DWS sets for distinct rollups across dates/categories; do not SUM ADS distinct counts.
-- Independent query example below, scoped to the selected business day.
SELECT
    BITMAP_UNION_COUNT(order_ids) AS distinct_order_cnt,
    BITMAP_UNION_COUNT(buyer_ids) AS distinct_buyer_cnt,
    SUM(pay_amount) AS pay_amount
FROM dws.dws_trade_category_1d
WHERE dt = CAST('${bizdate}' AS DATE);

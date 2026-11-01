-- Doris 3.x documentation-based syntax template; native execution has not been validated.
-- Parameters and input contracts: references/doris.md. The project has created dwd/dws/ads databases.
-- Dynamic retention deletes old data. Confirm the retention contract before applying.

CREATE TABLE dwd.dwd_trade_order_detail_di (
    dt DATE NOT NULL COMMENT 'Order business date; time zone defined in the contract',
    order_id BIGINT NOT NULL COMMENT 'Order ID, nonnegative integer',
    order_item_id BIGINT NOT NULL COMMENT 'Order line ID; combined with order_id identifies the line',
    user_id BIGINT NOT NULL COMMENT 'Ordering user ID, nonnegative integer',
    sku_id BIGINT NOT NULL COMMENT 'Product SKU ID',
    category_id BIGINT NOT NULL COMMENT 'Category ID; -1 identifies an unmatched dimension',
    quantity BIGINT NOT NULL COMMENT 'Order line quantity',
    order_amount DECIMAL(18,2) NOT NULL COMMENT 'Allocated order line amount due, common currency',
    pay_amount DECIMAL(18,2) NOT NULL COMMENT 'Allocated order line amount paid, common currency',
    create_time DATETIME NOT NULL COMMENT 'Order creation time',
    update_time DATETIME NOT NULL COMMENT 'Source update time',
    source_version BIGINT NOT NULL COMMENT 'Ordered source version',
    etl_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Transformation time'
)
ENGINE=OLAP
DUPLICATE KEY(dt, order_id, order_item_id)
COMMENT 'Complete order-line slice for an order business day; partition replacement supports replay'
PARTITION BY RANGE(dt) ()
DISTRIBUTED BY HASH(order_id) BUCKETS ${dwd_buckets}
PROPERTIES (
    "replication_num" = "${replication_num}",
    "light_schema_change" = "true",
    "dynamic_partition.enable" = "true",
    "dynamic_partition.time_unit" = "DAY",
    "dynamic_partition.time_zone" = "${business_timezone}",
    "dynamic_partition.start" = "${dwd_start}",
    "dynamic_partition.end" = "${future_days}",
    "dynamic_partition.prefix" = "p",
    "dynamic_partition.buckets" = "${dwd_buckets}",
    "dynamic_partition.create_history_partition" = "true"
);

-- Independent example: date-scoped current order state; dt is stable creation date, not update date.
-- sequence_col orders versions; retain tombstones and filter is_deleted=0 in consumer views.
CREATE TABLE dwd.dwd_trade_order_state_di (
    dt DATE NOT NULL COMMENT 'Stable order creation business date',
    order_id BIGINT NOT NULL COMMENT 'Order ID',
    user_id BIGINT NOT NULL COMMENT 'Ordering user ID',
    order_status VARCHAR(32) NOT NULL COMMENT 'Controlled order status code',
    pay_amount DECIMAL(18,2) NOT NULL COMMENT 'Order amount paid, common currency',
    create_time DATETIME NOT NULL COMMENT 'Order creation time',
    update_time DATETIME NOT NULL COMMENT 'Source update time',
    source_version BIGINT NOT NULL COMMENT 'Strictly ordered source version',
    is_deleted TINYINT NOT NULL DEFAULT "0" COMMENT 'Source tombstone: 0 active, 1 deleted',
    etl_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Transformation time'
)
ENGINE=OLAP
UNIQUE KEY(dt, order_id)
COMMENT 'Latest order state per creation date; uniqueness is date-scoped, not global order_id'
PARTITION BY RANGE(dt) ()
DISTRIBUTED BY HASH(order_id) BUCKETS ${dwd_buckets}
PROPERTIES (
    "replication_num" = "${replication_num}",
    "enable_unique_key_merge_on_write" = "true",
    "function_column.sequence_col" = "source_version",
    "light_schema_change" = "true",
    "dynamic_partition.enable" = "true",
    "dynamic_partition.time_unit" = "DAY",
    "dynamic_partition.time_zone" = "${business_timezone}",
    "dynamic_partition.start" = "${dwd_start}",
    "dynamic_partition.end" = "${future_days}",
    "dynamic_partition.prefix" = "p",
    "dynamic_partition.buckets" = "${dwd_buckets}",
    "dynamic_partition.create_history_partition" = "true"
);

CREATE TABLE dws.dws_trade_category_1d (
    dt DATE NOT NULL COMMENT 'Order business date',
    category_id BIGINT NOT NULL COMMENT 'Category ID; -1 identifies an unmatched dimension',
    order_ids BITMAP BITMAP_UNION NOT NULL COMMENT 'Nonnegative order ID set for exact distinct counts',
    buyer_ids BITMAP BITMAP_UNION NOT NULL COMMENT 'Nonnegative ordering user ID set for exact distinct counts',
    pay_amount DECIMAL(38,2) SUM NOT NULL COMMENT 'Sum of allocated line payments, common currency',
    etl_time DATETIME MAX NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Latest transformation time'
)
ENGINE=OLAP
AGGREGATE KEY(dt, category_id)
COMMENT 'Business-day category state; replace completely on replay; sets merge, amounts must not replay as increments'
PARTITION BY RANGE(dt) ()
DISTRIBUTED BY HASH(category_id) BUCKETS ${rollup_buckets}
PROPERTIES (
    "replication_num" = "${replication_num}",
    "light_schema_change" = "true",
    "dynamic_partition.enable" = "true",
    "dynamic_partition.time_unit" = "DAY",
    "dynamic_partition.time_zone" = "${business_timezone}",
    "dynamic_partition.start" = "${rollup_start}",
    "dynamic_partition.end" = "${future_days}",
    "dynamic_partition.prefix" = "p",
    "dynamic_partition.buckets" = "${rollup_buckets}",
    "dynamic_partition.create_history_partition" = "true"
);

CREATE TABLE ads.ads_trade_category_1d (
    dt DATE NOT NULL COMMENT 'Order business date',
    category_id BIGINT NOT NULL COMMENT 'Category ID; -1 identifies an unmatched dimension',
    category_name VARCHAR(128) NOT NULL COMMENT 'Category name in the business-day dimension snapshot',
    order_cnt BIGINT NOT NULL COMMENT 'Distinct orders within category; non-additive across categories',
    buyer_cnt BIGINT NOT NULL COMMENT 'Distinct ordering users within category; non-additive across dates/categories',
    pay_amount DECIMAL(38,2) NOT NULL COMMENT 'Sum of allocated line payments, common currency',
    etl_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Transformation time'
)
ENGINE=OLAP
UNIQUE KEY(dt, category_id)
COMMENT 'Complete order-business-day category report; partition replacement, not payment-event-day reporting'
PARTITION BY RANGE(dt) ()
DISTRIBUTED BY HASH(category_id) BUCKETS ${rollup_buckets}
PROPERTIES (
    "replication_num" = "${replication_num}",
    "enable_unique_key_merge_on_write" = "true",
    "light_schema_change" = "true",
    "dynamic_partition.enable" = "true",
    "dynamic_partition.time_unit" = "DAY",
    "dynamic_partition.time_zone" = "${business_timezone}",
    "dynamic_partition.start" = "${rollup_start}",
    "dynamic_partition.end" = "${future_days}",
    "dynamic_partition.prefix" = "p",
    "dynamic_partition.buckets" = "${rollup_buckets}",
    "dynamic_partition.create_history_partition" = "true"
);

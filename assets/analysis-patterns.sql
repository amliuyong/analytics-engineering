-- Generic SQL patterns: adapt dialect, relations, fields, types, and contracts before use.
-- Amounts share a currency; key columns are non-NULL. Statements are independent examples.

-- 1. Avoid fact-to-fact multiplication: aggregate orders/refunds to order grain first.
-- order_lines contains allocated line amounts; refund_events contains individual refunds.
WITH orders AS (
    SELECT order_id, SUM(amount) AS order_amount
    FROM order_lines
    GROUP BY order_id
), refunds AS (
    SELECT order_id, SUM(refund_amount) AS refund_amount
    FROM refund_events
    GROUP BY order_id
)
SELECT
    o.order_id,
    o.order_amount,
    COALESCE(r.refund_amount, 0) AS refund_amount
FROM orders o
LEFT JOIN refunds r ON o.order_id = r.order_id;

-- 2. Weighted rollup: aggregate numerators and denominators rather than averaging ratios.
-- REQUIRED: both counts describe additive observations at the declared grain, with compatible
-- eligibility/conversion rules. Repeated users across days produce a user-day ratio.
-- For period-unique/cohort conversion, retain entity IDs/events and deduplicate at that scope.
-- Zero denominator returns NULL; choose decimal precision for the actual engine/value range.
SELECT
    segment,
    CAST(SUM(converted_cnt) AS DECIMAL(38, 6))
        / NULLIF(SUM(eligible_cnt), 0) AS conversion_rate
FROM daily_segment_metrics
GROUP BY segment;

-- 3. Event-time Type 2 attribution: half-open validity; NULL marks an open current interval.
-- REQUIRED: intervals do not overlap per customer_id, with at most one open interval.
SELECT f.event_id, d.region
FROM fact_events f
LEFT JOIN dim_customer_history d
    ON f.customer_id = d.customer_id
   AND f.event_time >= d.valid_from
   AND (f.event_time < d.valid_to OR d.valid_to IS NULL);

-- 4. Grain check: returns failing keys. Select the actual model's business key.
SELECT event_id, COUNT(*) AS row_cnt
FROM fact_events
GROUP BY event_id
HAVING COUNT(*) > 1;

-- 5. Type 2 overlap check: history_id identifies a version; returns conflicting version pairs.
SELECT a.customer_id, a.history_id, b.history_id
FROM dim_customer_history a
JOIN dim_customer_history b
    ON a.customer_id = b.customer_id
   AND a.history_id < b.history_id
   AND (b.valid_to IS NULL OR a.valid_from < b.valid_to)
   AND (a.valid_to IS NULL OR b.valid_from < a.valid_to);

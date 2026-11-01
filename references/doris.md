# Doris implementation reference

## Scope and version boundary

The source article discusses 2.1.x/3.x. The syntax reference for this skill is reviewed official
3.x documentation. Confirm the actual patch version and deployment mode. Archived 2.1 or 4.x
requires matching documentation and validation; "2.1 and above" does not imply future compatibility.
The templates have not been executed against a Doris instance: native validation starts at `NOT_RUN`.

## Models and keys

| Input/use | Candidate model | Decision basis |
|---|---|---|
| Immutable detail or fully reconstructible partition slice | Duplicate | Key is a sort key, not a uniqueness constraint |
| CDC current state, latest value at fixed grain, replacement reports | Unique | Same-key replacement; declare the full logical key |
| Mergeable preaggregation state | Aggregate | Every Value has an aggregation function; raw detail is not retained |

Templates place Key columns first in the field list, in the declared Key order.
For Unique/Aggregate, partition and hash bucket columns belong to Key.
The date-partitioned Duplicate template also places `dt` in the sort Key as a consistent modeling
choice; do not promote the article's statement into an engine restriction for all Duplicate tables.

`UNIQUE KEY(dt, order_id)` means one order per date, not one order globally. If current orders are
partitioned by creation date, that date must remain stable; using an update date leaves stale rows
in old partitions. An unpartitioned current-state table can use `UNIQUE KEY(order_id)` with business
and update dates as Values.

Unique templates explicitly set `"enable_unique_key_merge_on_write" = "true"`.
Official CREATE TABLE documentation records the default as enabled from 2.1; inspect actual
existing table properties. Full-row upsert may replace omitted columns with NULL/defaults;
partial updates require version-specific configuration. Out-of-order CDC can map an ordered
source version through `"function_column.sequence_col"`, with policies for ties and deletions.
MOW alone does not mean the latest source version wins.

Aggregate SUM accumulates duplicate writes. Fixed reports can use Unique for complete results,
or Aggregate with complete partition replacement. Direct incremental SUM appends require an
exactly-once increment contract. Audit Values also need aggregation; `etl_time` uses MAX here.

## Partitioning and bucketing

Examples use `DATE dt`, daily RANGE partitions, and an explicit business time zone. Choose
hourly/monthly/non-date partitioning only when workload and volume justify it. A negative dynamic
partition `start` deletes old partitions: it is a retention policy. `create_history_partition`
defaults to false; setting `start` alone does not precreate all historical partitions.

Templates use `PARTITION BY RANGE(dt) ()` plus dynamic partitioning. Confirm actual partitions
exist before writing. Backfills need bounded historical creation and compatible deletion rules;
do not precreate daily partitions spanning 2026 through 2070. `start=-90` specifies a boundary
90 days before today; including today does not mean exactly 90 partitions.

Select Hash keys from filters/joins, cardinality, and skew. Random fits scan-oriented Duplicate
tables, not Unique/Aggregate. Bucket count depends on compressed partition size, BE/disks, and
concurrency. The article's approximately 1GB/tablet and 200-bucket cap are heuristics, not engine
limits; current 3.x guidance differs. Use version-specific guidance and actual tablet sizes.
If choosing AUTO, verify version/dynamic-partition compatibility and remove fixed bucket settings
that would override it.

Choose `replication_num` for available BEs and deployment mode. A traditional production cluster
may use three replicas; a single-BE test needs a compatible single replica. Replicas alone do not
establish backup or disaster recovery. `light_schema_change` accelerates supported Value-column
additions/removals, not every schema operation.

## Write syntax

```sql
INSERT OVERWRITE TABLE dwd.some_table
PARTITION (p20261101)
(dt, entity_id, amount, etl_time)
SELECT CAST('2026-11-01' AS DATE), entity_id, amount, CURRENT_TIMESTAMP
FROM some_source
WHERE dt = CAST('2026-11-01' AS DATE);
```

Use actual partition names, not Hive's `PARTITION(dt='...')`. Explicit target columns match SELECT
expressions, including `dt`. Confirm names with `SHOW PARTITIONS`; dynamic names commonly use
`pYYYYMMDD`, but do not infer names solely from dates. The 3.x documentation records `PARTITION (*)`
auto-detection from 2.1.3. An empty result cannot identify the stale partition to clear, so use
explicit partitions for empty-day recomputation. Omitting PARTITION replaces the whole table;
reserve it for a declared full-table rebuild.

## Templates and input contract

Copy and adapt only what is needed:

- [DDL](../assets/doris/ddl.sql): complete daily DWD slices, date-scoped DWD current state,
  mergeable DWS sets, and complete-result ADS reports.
- [Daily transformations](../assets/doris/daily-etl.sql): latest-version selection, dimension joins,
  DWS bitmap state, and ADS partition replacement.
- [Checks](../assets/doris/checks.sql): grain, dimensions, exact distinct counts, and amount reconciliation.

The calling project's scheduler/template system substitutes parameters; no specific templating
engine is required.

| Parameter | Meaning/constraint |
|---|---|
| `bizdate` | Business day in `YYYY-MM-DD` form |
| `partition_name` | Verified existing partition with a valid identifier |
| `replication_num` | Positive integer compatible with the deployment |
| `dwd_buckets` / `rollup_buckets` | Positive integers selected for the workload |
| `dwd_start` / `rollup_start` | Negative dynamic-retention boundaries |
| `future_days` | Positive number of future days to precreate |
| `business_timezone` | Same zone used to derive business dates |

ODS must be a **complete reconstructible slice for the specified business day**, including each
order line's latest source version. An ordinary CDC partition organized by ingestion day does
not meet this precondition. `source_version` strictly orders different versions per order line;
identical repeats can be removed, while conflicting equal-version payloads require quarantine.
`is_deleted` is 0/1. Business keys and versions are validated; active records also have validated
IDs, dates, quantities, and amounts. Tombstones may omit non-key payload fields.

`item_order_amount`/`item_pay_amount` are allocated line amounts, not repeated order totals.
Payment amounts in this template are attributed to the **order business date and current line
state**. Buyers are placing users in that slice, not paying users grouped by payment event date.
The latter requires a payment fact and its own time contract. SKU/category snapshots are unique
on `(dt, id)`; daily snapshots cannot express intraday Type 2 precision. Exact bitmap templates
require nonnegative BIGINT IDs; strings or larger IDs need a different representation.
The templates execute DWD, DWS, then ADS with separate commits, not a cross-layer transaction.

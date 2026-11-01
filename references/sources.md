# Sources, scope, and corrections

Prepared on 2026-11-01. These sources inform modeling decisions and syntax review.
Reading documentation does not establish native SQL execution, performance, or production acceptance.

## Primary method references

- Kimball Group, [Fact Tables](https://www.kimballgroup.com/2008/11/fact-tables/):
  declare business grain before dimensions/facts; transaction, periodic, and accumulating snapshots;
  metric additivity.
- dbt, [Incremental models](https://docs.getdbt.com/docs/build/incremental-models):
  incremental filters and keys, late/updated records, and schema changes that do not backfill history.
- dbt, [Data tests](https://docs.getdbt.com/docs/build/data-tests):
  unique, not-null, relationship, and domain assertions expressed as failing-row queries.
- dbt, [Snapshots](https://docs.getdbt.com/docs/build/snapshots):
  Type 2 validity and deletion handling; capture snapshots versus complete change history.
- dbt, [Metrics](https://docs.getdbt.com/docs/build/metrics-overview):
  shared atomic/derived definitions and ratio/cumulative/conversion semantics.

These methods do not require those products. The skill's contracts and SQL templates are newly written.

## Official Doris syntax references

- [CREATE TABLE (3.x)](https://doris.apache.org/docs/3.x/sql-manual/sql-statements/table-and-view/table/CREATE-TABLE/):
  Key prefixes, bucket columns, properties, and MOW defaults.
- [INSERT OVERWRITE (3.x)](https://doris.apache.org/docs/3.x/sql-manual/sql-statements/data-modification/DML/INSERT-OVERWRITE/):
  explicit partition names, target columns, whole-table replacement, and auto-detection version boundaries.
- [Dynamic partitioning (3.x)](https://doris.apache.org/docs/3.x/table-design/data-partitioning/dynamic-partitioning/):
  history creation, retention, buckets, and time zones.
- [Data bucketing (3.x)](https://doris.apache.org/docs/3.x/table-design/data-partitioning/data-bucketing/):
  Hash/Random applicability and tablet sizing guidance.
- [Unique model (3.x)](https://doris.apache.org/docs/3.x/table-design/data-model/unique/)
  and [Aggregate model (3.x)](https://doris.apache.org/docs/3.x/table-design/data-model/aggregate/):
  upserts, date-scoped uniqueness, and aggregated Value state.
- [TO_BITMAP (3.x)](https://doris.apache.org/docs/3.x/sql-manual/sql-functions/scalar-functions/bitmap-functions/to-bitmap/):
  integer input range; the templates further constrain inputs to nonnegative BIGINT.

Online documentation can change. Use documentation for the actual version and runtime evidence.

## WeChat starting point and corrections

The starting point is [DWD-to-ADS Table Standards and Example SQL for Apache Doris](https://mp.weixin.qq.com/s/2wyCcuF9IG6BgbbZMiZ6lg),
from the WeChat account Dongbai Mumaren. The skill reuses its layering, naming, and table-design
themes without distributing the full article or illustrations. Text extraction lost code spacing
and table formatting; the corrections below address structure and semantics, not extraction artifacts.

| Article example/recommendation | Treatment in this skill |
|---|---|
| Key refers to `dt` outside the field-list Key prefix | Reorder fields and structurally validate the prefix |
| Hive-style partition overwrite; SELECT omits `dt` | Actual partition names, explicit target columns, and date expressions |
| Date overwrite on an unpartitioned user table; undefined fields | Separate current state from historical snapshots and keep template fields consistent |
| Distinct buyers stored as additive SUM counts | Retain mergeable ID sets in DWS; complete daily results in ADS |
| GROUP BY inconsistent with nonaggregated SELECT fields | Deduplicate/join at declared grain, then aggregate separately |
| MAX of category names in place of unique attribution | Verify dimension uniqueness and join the correct snapshot |
| All-time totals based on expired detail | Require complete history or a separate cumulative/recovery design |
| Uniform numeric IDs, decimal precision, tablet/bucket thresholds | Preserve ID meaning and select precision/physical settings for the workload |
| Extremely long daily partition ranges and uniform models | Bounded dynamic partitions and models selected by update/additivity semantics |

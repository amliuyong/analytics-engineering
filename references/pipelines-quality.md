# Pipelines, quality, and publication

## Source contracts

Identify full snapshots, append-only events, CDC changes, or complete business-day slices.
A daily CDC partition usually means "changes received today," not "all facts belonging to an
event day." Record keys, ordered versions, tombstones, replay retention, and change detection.
Full replacement requires complete input. A change batch needs upsert or reconstruction of the
complete affected slice before replacement.

### Deduplication and deletion

Select the latest version per actual business key. Prefer ordered source versions, LSNs, or
explicit event sequences; timestamps alone may tie. Identical duplicates can be removed, but
conflicting versions need an explicit policy. Select the latest version before interpreting its
tombstone: filtering deletions first can resurrect old rows. Hard deletion, soft deletion,
business reversal, and privacy erasure are different contracts.

### Late data and recomputation

Use event time for business attribution and ingestion/update watermarks for change detection.
Reading only `event_time > MAX(target.event_time)` misses old events arriving late and historical
updates. Use a reliable change watermark plus affected-key/partition recomputation, or a justified
lookback window with a recovery or exception path for events beyond it.

Recomputation covers updates, refunds, historical dimension corrections, and dependent cumulative
metrics. Moving an entity across partitions requires removing the old attribution and writing
the new one. Source retention must cover lookback, failure recovery, and promised historical scope.
Ninety days of detail cannot establish an all-time cumulative metric.

## Idempotency and concurrency

| Write strategy | Preconditions | What to validate |
|---|---|---|
| Complete partition replacement | Full reconstruction of the selected partition | Replay does not accumulate; an empty result clears stale data |
| Key-based upsert | Deterministic current value and version | Unique keys, out-of-order handling, deletion propagation |
| Append-only events | Immutable events with duplicate prevention | Stable event/batch identity; retries do not append twice |
| Aggregate increments | Additive increments delivered exactly once | Retry, reversal, duplicate, and correction handling |

Make task scope, batch identity, and parameters traceable. Replaying identical inputs preserves
business records and metrics; audit timestamps may change. Serialize same-partition replacement
or use locks/publication versions so older runs cannot replace newer results.
Atomic replacement of one partition does not make DWD/DWS/ADS publication a multi-table transaction.
Consumers requiring a consistent batch need an existing publication pointer, batch barrier, or
controlled serving view.

Definition changes and incompatible schemas specify migration scope, historical recomputation,
consumer compatibility, and recovery. A schema-change property alone does not make destructive
renames or removals safe for consumers.

## Data quality and evidence

Prioritize properties relevant to the current deliverable. Use queries returning failing records
so errors can be traced to entities/dates. Existing testing frameworks may run these assertions.

| Property | Check | Interpretation |
|---|---|---|
| Completeness | Required NULLs, conversion failures, partition gaps | Acceptable missingness has a business explanation |
| Unique grain | GROUP BY business key; find COUNT > 1 | Check input and output; storage merging alone is insufficient |
| Join integrity | Unmatched and duplicate dimension keys | Unknown rate and expected join cardinality |
| Temporal validity | Non-overlapping SCD intervals, at most one match per event | Check open intervals and time zones together |
| Domain validity | Enums, bounds, units/currency, precision | Refunds and negative inventory follow business contracts |
| Reconciliation | Amounts/counts against source with the same grain/window/filters | Separate explained exclusions from unexplained differences |
| Replayability | Run identical inputs twice and compare business results | Compare business amounts/keys; treat audit fields separately |
| Freshness | Completed batches, watermarks, expected partitions, event/ingestion lag | MAX(etl_time) alone does not prove complete arrival |
| Stability | Volumes, NULL rates, distinctness, distributions versus history | Seasonal thresholds; an anomaly is not automatically an error |

Classify severity: critical money, grain, historical attribution, and recoverability errors
usually block publication. Noncritical label gaps may follow documented degraded-service policy.
Set thresholds from business requirements or observed baselines; example percentages or latency
numbers are not universal commitments.

Use relevant boundary cases: duplicate events, out-of-order versions, latest tombstones,
missing/duplicate dimensions, empty days, time-zone/day boundaries, late corrections, and replay.
Exact amounts usually require exact reconciliation; approximate metrics use their declared error
contract. Sample checks cannot establish full-data uniqueness or all-history consistency.

## Performance and operation

Establish correctness before optimizing from representative plans and measurements.

- Prune partitions using query filters; reduce inputs early and avoid unused columns or unnecessary
  full-history recomputation.
- Inspect join cardinality, skew, bytes scanned, spill, latency, and concurrency.
- Materialize or cache repeated expensive work when justified, with refresh and metric consistency.
- Choose partitioning, bucketing, sorting, indexes, and compression for the target engine and
  measured workload; a table-size threshold is not a cross-engine standard.
- Record execution scope, input/output counts, failures, batch identity, and code/metric version;
  keep credentials and unnecessary personal detail out of logs.

Reuse existing scheduling and observability tools. This skill does not automatically introduce
dbt, an orchestrator, or a data catalog.

# Metrics and analytical reasoning

## Metric contracts

Reusable metrics specify the business definition, counted entity, source fact, filters, time
field/zone, window, dimensions, aggregation rule, NULL/zero behavior, units/currency, precision,
owner, and definition version. Centralize atomic definitions; derived metrics reference them.
Definition changes state whether historical recomputation is required. Use existing metric
management tools; a particular semantic layer or dbt installation is not required.

Example: `paid_buyer_cnt` counts distinct paying users by payment date, excluding test orders.
It is not interchangeable with buyers counted by order date merely because field names match.

## Retain sufficient state for rollups

| Metric | Useful intermediate state | Rollup rule and limitations |
|---|---|---|
| Line-level amounts/quantities | SUM | Correct grain, consistent filters/units, no duplication |
| Distinct people/orders | IDs or mergeable sets | Union sets before counting; daily/category distinct counts generally cannot be added |
| Mean | Sum and valid observation count | `SUM(value_sum) / NULLIF(SUM(value_cnt), 0)`; do not average group means |
| Ratio | Numerator and denominator state | Aggregate each separately; compatible populations/windows and additive counts, or retained entity sets |
| Balances/inventory | Snapshot at a defined instant | Sum across entities at that instant; use agreed closing/average semantics over time |
| Maximum/minimum | MAX/MIN | Continue MAX/MIN only over compatible definitions and windows |
| Percentiles such as P95 | Raw observations or mergeable distribution state | Averages or maxima of group P95s are not the overall P95 |

Exact distinct counts can retain IDs or use collision-free integer mappings with bitmap state.
Ordinary hashes of strings cannot be advertised as collision-free. HLL and similar approximations
must declare error and suitability. Whether net amounts may be negative is a business rule,
not a universal quality constraint.

A ratio of summed daily counts needs additive observations at a declared grain. Repeated users
across days produce a user-day ratio, not a period-unique conversion rate. For period-unique or
cohort conversion, retain eligible/converted entity IDs or qualifying events and apply the
agreed entity/window rules before counting. Weighted rollup alone does not solve entity overlap.

## SQL semantics

- `COUNT(*)` counts rows, `COUNT(column)` excludes NULL, and `COUNT(DISTINCT entity_id)` counts
  unique entities only within the query's scope.
- After an outer join, `COUNT(*)` can count one activity for an entity with none; count the
  right-side event key instead.
- Use `COALESCE` for an explicit default policy. Missing quality data, no activity, and unknown
  state are not all zero.
- Return NULL or an explicit unavailable result for a zero denominator. Choose numeric types
  for the engine to avoid integer division, overflow, and premature rounding; round for display.
- `SUM(DISTINCT amount)` merges equal-valued independent events and cannot repair join duplication.
- Deduplicate by business event key and deterministic source version. Quarantine conflicting
  records with the same version rather than choosing randomly, using MAX of a status, or relying
  on the latest transformation time.
- Define rank ties. Give window functions explicit partitioning, ordering, and frames when needed
  so timestamp peers or default cumulative frames do not change the intended calculation.

## Time, funnels, and retention

Use explicit half-open time windows `[start, end)`. Derive calendar days in the business time
zone and track ingestion dates separately. Comparisons account for working days, complete
windows, seasonality, and data that has not finished arriving.

Funnels declare the entity, step order, maximum conversion window, cross-device identity rules,
and attribution for repeated entries. Having performed A and B is not proof of A then B within
the window. Multiple-event joins need deduplication at the final entity grain; event combinations
are not converted people.

Retention uses a consistent cohort denominator and states whether the anchor is registration,
first activity, or first payment. Day-N and rolling retention differ. Mark cohorts whose
observation windows are not complete as immature rather than churned. A date spine can expose
missing periods; fill zero only where complete data makes zero a valid business interpretation.

## Interpreting results

Check coverage, freshness, missingness, outliers, denominator, and population composition before
explaining a trend. For samples, state sample size, sampling method, and potential bias; do not
present estimates as exact full-population facts. Inspect group sizes and within-group changes
to detect composition effects and Simpson's paradox. Correlation supports association;
causal claims need an experiment or an appropriate identification design.

Ad hoc analyses retain reproducible SQL, parameters, and a data-as-of timestamp. Follow existing
access and masking policies for sensitive detail and existing small-cell disclosure rules for aggregates.

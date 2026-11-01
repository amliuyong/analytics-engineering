# Dataset and metric contract

Fill the relevant fields and remove inapplicable sections. Examples are not business defaults.

## Dataset

| Field | Definition |
|---|---|
| Name / owner / consumers | |
| Business decision supported | |
| Engine, version, deployment mode | |
| Meaning of one row | |
| Business key / physical Key | |
| Fact type: event / periodic snapshot / accumulating snapshot / current state | |
| Sources, completeness, change detection, deletion semantics | |
| Business time, time zone, date attribution | |
| Dimension keys, expected cardinality, historical attribution | |
| Refresh strategy, late/update/delete handling | |
| Coverage, retention, recomputation capability | |
| Freshness, quality thresholds, exception owner | |
| Access scope and sensitive fields | |
| Publication batch, compatibility, recovery | |

## Metric

Complete separately for each reusable metric.

| Field | Definition |
|---|---|
| Name / business definition / version | |
| Counted entity and source fact | |
| Filters, reversals/refunds, test-data exclusions | |
| Time field, window, time zone | |
| Dimensions and population | |
| Expression / numerator / denominator | |
| Additivity and state needed for rollup | |
| NULL, zero, zero denominator, empty-day semantics | |
| Unit, currency, precision, exact/approximate | |
| Data-as-of time and immature windows | |

## Validation record

| Property | Check | Status | Evidence / scope |
|---|---|---|---|
| Unique grain | | NOT_RUN | |
| No join amplification / correct historical attribution | | NOT_RUN | |
| Amount and count reconciliation | | NOT_RUN | |
| Replay, late records, deletion | | NOT_RUN | |
| Time boundaries / completeness / freshness | | NOT_RUN | |

Statuses: `PASS` / `FAIL` / `NOT_RUN` / `UNKNOWN`.

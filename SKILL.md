---
name: analytics-engineering
description: Design or review analytical data models, metric definitions, and analysis SQL; handle fact grain, dimensional joins, incremental recomputation, and data quality across warehouse layers, with Doris-specific templates.
---

# Analytics Engineering

Turn a business question into analytical data with explicit grain, explainable metrics,
repeatable transformations, and reconcilable results. Use the project's existing database,
layering, and tools. Doris is a concrete implementation reference.

## Workflow

### 1. Establish the analysis contract

Inspect existing models, data dictionaries, metric definitions, and representative queries.
Record:

- The business decision and consumers; whether the output is an ad hoc analysis,
  reusable metric, or production dataset.
- Sources, fact grain, entity keys, and whether records describe events, current state,
  or historical snapshots.
- Metric population, filters, time basis, dimensions, units, and precision.
- Database and version, update semantics, volume, available history, and freshness needs.

Write checkable assumptions when information is missing. Clarify ambiguity that changes
money, distinct entities, historical attribution, or replacement scope. Continue independent
work. For a one-off query, apply the relevant rules without building a full warehouse.

### 2. Read the relevant references

| Task | Reference |
|---|---|
| New models, layering, facts/dimensions, domain adaptation | [Modeling](references/modeling.md) |
| KPIs, distinct counts, ratios, retention, funnels, interpretation | [Metrics and analysis](references/metrics.md) |
| Transformations, replay, CDC, late data, quality, publication | [Pipelines and quality](references/pipelines-quality.md) |
| Doris DDL, partitioning, bucketing, models, and write syntax | [Doris implementation](references/doris.md) |
| Method provenance, version boundaries, or article corrections | [Sources and corrections](references/sources.md) |

Load references for the current task. Preserve unrelated tools and layer organization.

### 3. Fix the grain before writing SQL

Describe what one row represents in business terms, then list its business key. Declare the
expected cardinality of every JOIN. Give filtering, deduplication, dimensional attribution,
and aggregation explicit semantics. Aggregate separate facts to a common grain before joining.

Check that:

- Joins do not multiply amounts or records through many-to-many relationships.
- Time filters, time zones, and historical attributes match the metric contract.
- Distinct counts, ratios, means, percentiles, and balances retain the state needed to roll up.
- Updates, deletions, and repeated batches produce the agreed result; recomputation has complete inputs.

For a design deliverable, adapt the [dataset and metric contract](assets/dataset-contract.md).
For analysis SQL, adapt the [query patterns](assets/analysis-patterns.sql) to the target dialect.
For Doris, follow the template links in its implementation reference.

### 4. Validate and deliver

Validate business properties: unique grain, no join amplification, source-to-target
reconciliation, stable metrics on replay, correct time boundaries, and effective late updates
and deletions. See the pipeline reference for quality checks and release severity.

Scale the deliverable to the task:

- **Design:** grain, model and metric contracts, consequential choices, and assumptions.
- **Implementation:** target-dialect SQL, parameters and input contracts, recomputation and
  publication scope, and validation queries.
- **Review:** issue, impact, file and line evidence, and correction; distinguish business
  errors from optional optimization.
- **Analysis:** results, denominators/windows/coverage, quality limitations, and supported conclusions.

Report `PASS`, `FAIL`, `NOT_RUN`, or `UNKNOWN` for each check, with evidence.
Separate static review, database compilation, sample validation, and full-data validation.
Generating a template does not establish successful execution. Database writes follow the
current task's authorization; invoking this skill does not grant additional write authority.

## Completion criteria

Each delivered model explains its grain, keys, time basis, and update semantics. Each metric
traces to a consistent definition. Referenced fields exist with compatible types. Critical
properties have a validation method and an honest status. Record demonstrated domain differences
in the current project's contract rather than promoting them into universal rules.

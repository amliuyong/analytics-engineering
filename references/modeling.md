# Modeling standards

## Declare the grain first

Grain defines a business measurement event; the business key implements that definition.
Write "one row represents an order line" or "one row represents an account's end-of-day balance"
before choosing keys and metrics. Keep one grain per fact table. Copying an order total to every
line and then summing it overcounts. If allocation is needed, document the rule and reconcile
allocated line amounts to the original order total.

| Fact type | Meaning of one row | Common uses | Update and aggregation concerns |
|---|---|---|---|
| Transaction | An indivisible business event | Payments, clicks, shipments, billing | Deduplicate by event key; define reversals/refunds |
| Periodic snapshot | Entity state or activity for a fixed period | Inventory, balances, daily subscription state | Missing records differ from zero activity; state is usually non-additive over time |
| Accumulating snapshot | One business process and its milestones | Fulfillment, ticket lifecycle | Updated as the process advances; preserve separate event history when transition analysis needs it |

A current-state table answers "what is true now?" A historical snapshot answers "what was true
then?" Sharing an entity ID does not make them interchangeable.

## Layers express responsibilities

Use the project's existing terminology. `ODS / DWD / DWS / ADS` and
`source/staging / intermediate / marts` are alternative organizations, not mandatory extra steps.

| Responsibility | Common layer | Modeling focus |
|---|---|---|
| Replayable source | ODS/source | Source keys, change versions, event/ingestion times, deletion semantics |
| Clean business facts | DWD/staging | Types, grain, deterministic deduplication, quarantine, dimension keys |
| Reusable computation | DWS/intermediate | Shared expensive work, common grain, mergeable metric state |
| Consumer datasets | ADS/marts | Metric contracts, serving grain, access scope, query performance |
| Consistent attributes | DIM/dimensions | Conformed keys, business meaning, historical validity |

Small datasets or one-off queries may aggregate trusted detail directly. Materialize intermediate
work when reuse, scan cost, or serving needs justify it. Support authorized detail drill-down
where useful; retaining only aggregates can make results impossible to explain.

## Dimensions and joins

- Use conformed entity definitions across facts. Preserve source business keys; introduce
  surrogate keys when integrating sources or representing multiple historical versions.
- Fact-to-dimension joins are usually many-to-one. Investigate duplicate dimension keys rather
  than hiding them with `MAX(name)` or arbitrary row selection. Represent legitimate many-to-many
  relationships with a bridge, existence filter, or explicit weighting.
- Direct fact-to-fact joins can create a Cartesian multiplication within each entity. Aggregate
  each fact to the common entity/period first, or choose a driving grain and define allocation.
- A left join preserves facts only until subsequent filters exclude unmatched rows.
  Confirm whether `WHERE dimension.attr = ...` is intended to change the population.
- Keep an identifiable unknown member or NULL and measure unmatched rates. Unknown does not mean
  the entity is known not to exist.

### Historical attributes

| Strategy | Business question | Explicit contract |
|---|---|---|
| Type 1 overwrite | View historical activity using today's region/name | History is reclassified |
| Type 2 versions | Attribute activity to the region valid at event time | Business key, validity interval, and matching time |
| Periodic snapshot | Existing daily organization/product snapshots are sufficient | Unique key within period; acceptable loss of intraday precision |

Type 2 joins normally use `event_time >= valid_from AND event_time < valid_to`, with explicit
handling of NULL open ends. Validate non-overlapping intervals, one current version per business
key, and at most one match per fact. Detection time is not necessarily actual business-effective
time. Periodic snapshots can miss changes between captures and do not replace complete CDC history.

## Fields and contracts

For new projects, use these starting points; preserve existing contracts. Keep logical choices
separate from engine-specific types.

| Content | Principle |
|---|---|
| Names | Lowercase snake_case; `_id` for keys, `_time` for instants, `_amount` for money, `_cnt` for counts |
| IDs | Preserve meaning; use integers for numeric IDs, strings for leading zeros, letters, or external codes |
| Money | Fixed-point decimal sized for currency and maximum cumulative value; missing differs from legitimate zero |
| Counts | Size for expected maxima; cumulative counts usually need 64-bit integers |
| Enums | Controlled codes and definitions with traceable unknown values |
| Time | Record time zone; distinguish event, source update, ingestion, and transformation times |
| Dates | Declare business-day attribution and derivation time zone; a date is not a precise instant |
| Audit | Choose `etl_time`, `batch_id`, source version, and source identity according to traceability needs |
| Comments | Explain meaning, units, and NULL semantics; table comments declare grain and time basis |

To follow the source article's naming style: `{layer}_{domain}_{process}_{description}_{period}`.
`_di`/`_hi` denote daily/hourly increments, `_df` daily full snapshots, `_1d` daily grain,
and `_td` may denote temporal history. A suffix does not replace an actual grain/refresh contract;
temporal history requires validity intervals. Conformed join keys have compatible meanings and
types. Keep currency as a dimension or declare an exchange-rate conversion policy before combining amounts.

## Adapting across domains

Reuse the reasoning method; replace the measurement event and metric contract.

| Domain | Typical atomic grain | Reusable patterns | Main traps |
|---|---|---|---|
| Commerce | Order line, payment event, refund event | Amount reconciliation, distinct orders, fulfillment snapshots | Order/line mixing; payment date versus order date |
| Product behavior | Event with a stable event key | Activity, funnels, cohort retention | Duplicate tracking, identity resolution, step ordering |
| Subscriptions | Change event or subscription-day snapshot | MRR movements and period-end state | Trials/refunds; summing balances over days |
| Inventory | SKU-location movement or closing snapshot | Separate flows from stock; opening/closing reconciliation | Permitted negative stock; filling missing snapshots with zero |
| Operations/service | Request, ticket, or lifecycle | Success rates, latency, handling duration | Whether retries count as requests; incorrect percentile rollups |

Build only the models required by the current problem.

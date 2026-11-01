# analytics-engineering

A reusable skill for analytical models, consistent metrics, reliable SQL transformations,
and data quality. Compatible with Codex and Claude Code. The skill and its references are in English.

It starts from a Doris DWD-to-ADS article and adds primary-source methods from Kimball and dbt.
Use it across commerce, product behavior, subscriptions, inventory, and operations while
preserving the project's existing database and tools.

## Capabilities

- Design and review fact grain, dimensions, historical attribution, and warehouse layers.
- Define metrics and correct rollups of distinct counts, ratios, means, balances, and percentiles.
- Handle join amplification, late records, deletions, replay, and historical recomputation.
- Generate quality checks, reconciliations, and evidence-based analytical conclusions.
- Provide Doris DDL, partition-replacement transformations, and validation query templates.

## Installation

Keep the entire repository: references and SQL assets are part of the skill.
The link commands below are for a new installation. Inspect any existing destination first.

```bash
git clone https://github.com/amliuyong/analytics-engineering.git \
  ~/my/analytics-engineering

# Codex
mkdir -p ~/.codex/skills
ln -s ~/my/analytics-engineering ~/.codex/skills/analytics-engineering

# Claude Code (optional)
mkdir -p ~/.claude/skills
ln -s ~/my/analytics-engineering ~/.claude/skills/analytics-engineering
```

Start a new session after installation so the tool can discover the skill.
The entrypoint is [SKILL.md](SKILL.md).

## Example requests

```text
$analytics-engineering
Design order-line facts, category daily reports, and metric contracts on Doris 3.x.
Support business-day replay, and specify payment-date semantics, late updates, and quality checks.
```

```text
Use analytics-engineering to review a subscription report:
Are period-end MRR, churn, and renewal rates using consistent grain, denominators,
windows, and historical state? Provide corrected SQL and reconciliation methods.
```

```text
Use analytics-engineering to inspect this analysis SQL:
Why do amounts increase after joining order lines to multiple refunds?
Correct the query and explain which conclusions the results support.
```

## Package contents

| File | Purpose |
|---|---|
| [SKILL.md](SKILL.md) | Invocation, workflow, and completion criteria |
| [references/modeling.md](references/modeling.md) | Grain, facts/dimensions, layering, domain adaptation |
| [references/metrics.md](references/metrics.md) | Metric contracts, rollups, windows, interpretation |
| [references/pipelines-quality.md](references/pipelines-quality.md) | Incremental work, deletion, replay, quality, publication |
| [references/doris.md](references/doris.md) | Doris version boundary, syntax, and parameters |
| [references/sources.md](references/sources.md) | Primary sources and article corrections |
| [assets/dataset-contract.md](assets/dataset-contract.md) | Fillable dataset and metric contract |
| [assets/analysis-patterns.sql](assets/analysis-patterns.sql) | Common analysis SQL patterns |
| [assets/doris/ddl.sql](assets/doris/ddl.sql) | Doris table definitions |
| [assets/doris/daily-etl.sql](assets/doris/daily-etl.sql) | Complete business-day slice transformations |
| [assets/doris/checks.sql](assets/doris/checks.sql) | Input and result checks |

## Validation

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-dev.txt
.venv/bin/python scripts/validate_skill.py
.venv/bin/python -m unittest discover -s tests -v
```

GitHub Actions runs these checks. Static validation covers metadata, internal links, template
Key prefixes, and target columns. In-memory DuckDB fixtures check generic SQL join, rollup,
and temporal-attribution semantics. **These checks do not establish native Doris compatibility.**
Doris templates follow reviewed official 3.x documentation. Substitute parameters, verify the
input contract and actual version, then perform compilation, sample, and full-data validation.

The Doris example requires a complete reconstructible business-day slice; a day's CDC changes
alone are insufficient. Select production settings, retention, and metric definitions for the project.

License: [MIT](LICENSE). Referenced materials remain subject to their respective terms.

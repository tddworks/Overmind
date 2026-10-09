---
description: How each case works in Edge Meter. Covers the closed sums a service or plan file can use (how a limit is read, allowances, prices, breakdowns, periods), the JSON shapes, Cloudflare's datasets and endpoints as verified, and what is still unverified. Read before adding a service, a plan or a case.
---

# Edge Meter — the engine

> **#5 of 5** in [the design](ARCHITECTURE.md) · **Answers:** how each case
> works · **Builds on:** [MODULAR_DESIGN.md](MODULAR_DESIGN.md)
>
> A new Cloudflare product is a service file; a price change is a plan file.
> A new **case** below is a design change: write it here first, confirmed
> before code.

---

## 1 · The one idea

A **service file** says what is counted and where the number is.
A **plan file** says how much is included and what the rest costs.
One `ReadPlan` turns every limit into one GraphQL query; one `AnswerReader`
reads the answer back by the paths the files name. No Swift knows D1.

## 2 · `Read` — how a limit's number is found

| Case | Means | Example |
|---|---|---|
| `sum` | add up a field over the period | D1 rows read: `d1AnalyticsAdaptiveGroups` · `sum.rowsRead` |
| `max` | the largest value in the period | D1 storage: `databaseSizeBytes` |
| `quantile` | a percentile over the period, plus a count of the invocations that failed the allowance | CPU: `quantiles.cpuTimeP99`, failures where `status = exceededResources` |

Every `Read` names:

- `dataset` and `field` (a path in the group, e.g. `sum.rowsRead`);
- `time`: the filter the dataset takes, `date` (`date_geq`/`date_leq`, D1) or
  `datetime` (`datetime_geq`/`datetime_leq`, Workers);
- `focus`: the dimension a breakdown narrows by (`scriptName`, `databaseId`).
  `ReadPlan` uses it **for breakdowns only** (model law 1);
- `scale`, when the answer's unit isn't the limit's: CPU comes in microseconds,
  so `0.001` turns it into milliseconds;
- `failures`, for a `quantile`: the dimension value that marks an invocation
  that went past the allowance (`status = exceededResources`).

`ReadPlan` writes each limit as an aliased field of one `viewer.accounts`
query filtered by `accountTag`, so a refresh is one request whatever the
number of limits.

## 3 · `Allowance` and `Price` — in the plan

| `Allowance` | Period | Pace | Example |
|---|---|---|---|
| `perDay(Quantity)` | the UTC day | yes | 5M rows read |
| `perMonth(Quantity)` | the billing month (from the subscription's `current_period_end`) | yes | 25B rows read |
| `perInvocation(Quantity)` | the UTC day, for the p99 and the failure count | no | 10 ms CPU |
| `total(Quantity)` | none: it never resets | no | 5 GB storage |

| `Price` | Means |
|---|---|
| absent | the plan **stops** past the allowance (Free) |
| `beyond(Money, per: Quantity)` | each unit past the allowance costs this (*$0.001 per 1M rows*) |
| `perMonthOver(Money, per: Quantity)` | storage: billed on the month's average past the allowance (*$0.75 per GB-month*) |

A plan also carries `subscription` (`$5` a month) and `matches`: the
`rate_plan` ids from `/accounts/{id}/subscriptions` that mean this plan.
No match means Free.

**A plan without an allowance for a limit doesn't show that limit.** Free caps
CPU per invocation (`workers.cpu`); Workers Paid bills CPU time by the month
(`workers.cpuTime`, `sum.cpuTimeUs`). Each plan file names only its own.

## 4 · `Breakdown` — on a service tab

| Case | Draws | Example |
|---|---|---|
| `series(limit, by: hour \| day, last:)` | bars, with deployment pins | rows read, last 7 days |
| `top(dataset, dimension, measure, count)` | a ranked list | queries by rows read (`d1QueriesAdaptiveGroups`, `dimensions.query`, `sum.rowsRead`) |
| `split(dataset, dimension, measure)` | a list per value | invocations by `status` |
| `figures([Read])` | a row of numbers | CPU p50 · p99, errors |

## 5 · The files

```jsonc
// Services/Resources/Services/d1.json
{
  "id": "d1", "name": "D1", "look": { "glyph": "⛁", "color": "butter" },
  "limits": [
    { "id": "d1.rowsRead", "name": "D1 rows read", "short": "D1", "unit": "rows",
      "read": { "sum": { "dataset": "d1AnalyticsAdaptiveGroups", "field": "sum.rowsRead",
                         "time": "date", "focus": "databaseId" } } },
    { "id": "d1.rowsWritten", "name": "D1 rows written", "short": "D1 writes", "unit": "rows",
      "read": { "sum": { "dataset": "d1AnalyticsAdaptiveGroups", "field": "sum.rowsWritten",
                         "time": "date", "focus": "databaseId" } } }
  ],
  "breakdowns": [
    { "title": "Rows read · last 7 days", "series": { "limit": "d1.rowsRead", "by": "day", "last": 7 } },
    { "title": "Top queries by rows read",
      "top": { "dataset": "d1QueriesAdaptiveGroups", "dimension": "query",
               "measure": "sum.rowsRead", "count": 5, "time": "datetimeHour" } }
  ]
}

// Plans/Resources/Plans/free.json
{
  "id": "free", "name": "Free", "subscription": "0 USD", "matches": [],
  "allowances": {
    "d1.rowsRead":     { "perDay": "5M rows" },
    "d1.rowsWritten":  { "perDay": "100k rows" },
    "d1.storage":      { "total": "5 GB" },
    "workers.requests":{ "perDay": "100k requests" },
    "workers.cpu":     { "perInvocation": "10 ms" }
  }
}
```

## 6 · Cloudflare, as verified (2026-10-09)

| Need | Where | Status |
|---|---|---|
| Workers requests, errors, CPU p50/p99, by `scriptName`, `status` | GraphQL `workersInvocationsAdaptive` | verified |
| D1 reads, writes | GraphQL `d1AnalyticsAdaptiveGroups` (`accountTag`, `date`) | verified |
| D1 queries by rows read | GraphQL `d1QueriesAdaptiveGroups` (`datetimeHour`) | from Wrangler's source |
| D1 storage `databaseSizeBytes` | GraphQL `d1StorageAdaptiveGroups` · `max.databaseSizeBytes` | verified by a read |
| Workers by hour | `datetimeHour` (also `datetimeFifteenMinutes`, `datetimeSixHours`) | verified by introspection |
| CPU time unit | `cpuTimeP50` · `cpuTimeP99` are **microseconds** | verified by a read |
| Cron runs | GraphQL `workersInvocationsScheduled`: `cron` · `status` · `cpuTimeUs` · `scheduledDatetime` | verified by introspection |
| Rate Limiting bindings | none exists | out of scope ([journeys §5](USER_JOURNEYS.md#5--out-of-scope-for-now)) |
| GraphQL budget | 300 queries / 5 min / user; 31 days retention on adaptive datasets | verified |
| Plan | `GET /accounts/{id}/subscriptions`: one entry per rate plan (an account can have *R2 Paid* without *Workers Paid*) | verified |
| Workers Paid's `rate_plan` id | `workers_paid` in `workers-paid.json` | **unverified**: no Paid account to read yet |
| Workers CPU time total | `workersInvocationsAdaptive` · `sum.cpuTimeUs` | verified by introspection |
| Invoices | `GET /accounts/{id}/billing/history` (`/user/billing/history` is deprecated) | verified |
| Billable usage | `/accounts/{id}/billable-usage`, alpha | not used in v1: the bill is an estimate |
| Deployments | `GET /accounts/{id}/workers/scripts/{name}/deployments` (Workers Scripts Read) | verified |
| Token check | `GET /user/tokens/verify`; `/accounts/{id}/tokens/verify` for account-owned tokens | verified |
| The `cf` CLI (1.0.0-beta.12) | no GraphQL command; `cf analytics sql get` has D1 datasets but no Workers invocations; its OAuth login reads analytics and subscriptions but not invoices (403) | checked 2026-10-09; not used in v1 ([status](../status.md#decisions)) |
| Free limits | Workers 100k req/day, 10 ms CPU; D1 5M read, 100k written per day, 5 GB; reset 00:00 UTC | verified |
| Paid ($5/mo) | 10M req, 30M CPU ms; D1 25B read, 50M written, 5 GB per month; overage $0.30/M req, $0.02/M CPU ms, $0.001/M rows read, $1.00/M rows written, $0.75/GB-month | verified |

Sources: Cloudflare's [GraphQL limits](https://developers.cloudflare.com/analytics/graphql-api/limits/),
[Workers metrics](https://developers.cloudflare.com/analytics/graphql-api/tutorials/querying-workers-metrics/),
[D1 metrics](https://developers.cloudflare.com/d1/observability/metrics-analytics/),
[Workers pricing](https://developers.cloudflare.com/workers/platform/pricing/),
[D1 pricing](https://developers.cloudflare.com/d1/platform/pricing/),
[API permissions](https://developers.cloudflare.com/fundamentals/api/reference/permissions/).

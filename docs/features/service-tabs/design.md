---
description: How a service tab is built from data — BreakdownDefinition cases, ReadPlan.breakdowns and the focus — and what each Cloudflare dataset gives. Read before adding a chart.
---

# Service tabs — design

- A tab is a `ServiceDefinition`'s `breakdowns` ([ENGINE §4](../../architecture/ENGINE_DESIGN.md#4--breakdown--on-a-service-tab)): `series`, `top`, `split`. A new chart is JSON; a new kind of chart is a case.
- `ReadPlan.breakdowns(service, focus:, at:)` writes one query per tab; the focus filters only sources that name a `focus` dimension.
- `split` with `measure: "rows"` counts a raw dataset's rows (`workersInvocationsScheduled` has no groups).
- Deployments come from `BillingAPI.deployments` for the focused Worker and are pinned on the bar whose step holds them.

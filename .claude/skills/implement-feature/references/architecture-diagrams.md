# Architecture Diagram Patterns

Use the words of [CANONICAL_MODEL.md](../../../../docs/architecture/CANONICAL_MODEL.md):
Account, Connection, Plan, Service, Limit, Allowance, Usage, Pace, Level, Alerts,
Warning, Breakdown, Deployment, Focus, Bill.

## The modules

```text
                     Overmind (App)
                          │
                       Monitor ─────────────── Storage (implements its ports)
     ┌──────────┬─────────┼─────────┬──────────┐
 Analytics   Billing    Alerts    Limits
     │          │          │         │
  Services    Plans ───────┴─────────┤
     └──────────┴──── Measures ──────┘
```

## Pattern: a new Cloudflare product

```text
┌──────────────┐    ┌───────────────────────────────┐
│ <id>.json    │───▶│ Services (definition test)    │
│ + allowances │───▶│ Plans    (definition test)    │──▶ ReadPlan picks it up; no Swift
└──────────────┘    └───────────────────────────────┘
```

## Pattern: the refresh

```text
Refresher ──▶ Account.refresh(at:)
               │ plan.period(for:at:)            (Plans)
               │ ReadPlan → Analytics.read       (Analytics, one POST)
               │ AnswerReader → [Usage]
               │ limit.record(usage)             (Limits, law 7)
               │ alerts.check(limits, at:)       (Alerts, laws 9–10) ──▶ Notifier
               ▼
             views redraw
```

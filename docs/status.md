---
description: Where Edge Meter stands — what is built per module with test counts, the decisions taken, open questions, and the slices in order. Read before picking up work.
---

# Status

> As of **2026-10-09** · **0 tests**. The design is approved;
> the app builds as an empty menu bar item. This file is the one home for
> "what's built and what's next". Update it when a slice lands.

## What is built

| Piece | State |
|---|---|
| Design: the five docs, the mockup | proposed |
| `EdgeMeter` app target | builds; shows a placeholder popover |
| Modules | none yet: each is carved when its first test needs it |

## Slices, in order

| # | Slice | Modules | Done when |
|---|---|---|---|
| 1 | The pure core | `Measures`, `Services`, `Plans`, `Limits` | percent, level, pace and periods are tested on a neutral fixture, and `d1.json`, `workers.json`, `free.json`, `workers-paid.json` load in definition tests |
| 2 | One read | `Analytics` | `ReadPlan` writes one query for every limit; `AnswerReader` reads recorded answers. The unverified datasets in ENGINE §6 are settled by introspection |
| 3 | The root | `Monitor`, `Storage`, `Billing` (verify, accounts, subscriptions) | connect, choose, refresh, freshness; the token in the Keychain |
| 4 | The Today tab | App | the menu bar and Today from the mockup, on the real account |
| 5 | Warnings | `Alerts` | laws 9–10, with the sent log kept across relaunches |
| 6 | Service tabs | `Analytics` breakdowns, `Billing` deployments | D1 and Worker tabs, with deployment pins and the focus picker |
| 7 | The bill | `Billing` | estimate, forecast, quote, invoices |

## Decisions

| Date | Decision |
|---|---|
| 2026-10-09 | Its own app, beside ClaudeBar and AgentNexus, in the same design method |
| 2026-10-09 | Rate limits stay out of v1: Cloudflare keeps no analytics for Rate Limiting bindings |
| 2026-10-09 | The bill is an estimate from the plan files; Cloudflare's billable-usage API is alpha |
| 2026-10-09 | The API implementation only: an API token, HTTP behind the `Analytics` and `BillingAPI` ports. The `cf` CLI can't serve every read (ENGINE §6) |
| 2026-10-09 | Design approved; slice 1 starts |

## Open questions

- The name *Edge Meter* is a working name.
- Every dataset is now verified by a read or introspection (ENGINE §6).

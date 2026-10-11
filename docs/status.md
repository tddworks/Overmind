---
description: Where Overmind stands — what is built per module with test counts, the decisions taken, open questions, and the slices in order. Read before picking up work.
---

# Status

> As of **2026-10-11** · **154 tests** (and 4 live checks), all passing. Every slice is built; the app
> runs on a real account and on demo data. This file is the one home for
> "what's built and what's next". Update it when a slice lands.

## What is built

| Piece | Holds | Tests |
|---|---|---|
| Design: the five docs, the mockup | approved | — |
| `Overmind` app | the menu bar, Today, the Workers and D1 tabs, Bill, Connect, the Settings window, `LoginItem`, `Updater` (Sparkle), the icon; demo mode and screenshots | — |
| Release | `tests.yml`, `release.yml` (sign, notarize, DMG, appcast), ClaudeBar's scripts; a universal Release archive built and Developer-ID-signed locally | — |
| `Measures` | `Quantity` (reads *5M rows*, prints *3.75M*, *75.7k ms*), `Money` (Decimal), `Period` (UTC day, billing month), `Percent`, `LimitID` | 18 |
| `Services` | `ServiceDefinition` (`watchedByDefault`), `LimitDefinition`, `Read` (`where`), `BreakdownDefinition`, `ServiceCatalog`; `workers.json`, `d1.json`, `kv.json` | 14 |
| `Plans` | `PlanDefinition` (upgrade link), `Plan`, `Allowance`, `Price`, `cost(of:)`, `lines(of:)`, `PlanCatalog`; `free.json`, `workers-paid.json` (Workers, D1, KV) | 22 |
| `Limits` | `Limit` (laws 2–8), `Usage`, `Level`, `Pace` | 16 |
| `Analytics` | `ReadPlan` (one query; storage summed per database; per-day use; `where` filters), answers, breakdowns, `Focus`; `GraphQLAnalytics` | 18 + 2 live |
| `Billing` | `Bill` (estimate, forecast, quote, lines, days stopped, verdict), `BillingAPI`; `CloudflareREST` | 16 + 1 live |
| `Alerts` | laws 9–10, CPU stopped invocations; `UserNotifier` | 11 |
| `Monitor` | `Account` (connect, choose, refresh, freshness, tabs, bill, alerts, read interval, plan re-read, watching), `Refresher` | 35 + 1 live |
| `Storage` | `KeychainTokenVault`, `JSONSettingsFile` (older files still read) | 4 |
| `Diagnostics` | `AppLog` | — |

## Slices, in order

| # | Slice | Modules | Done when |
|---|---|---|---|
| 1 ✅ | The pure core | `Measures`, `Services`, `Plans`, `Limits` | percent, level, pace and periods are tested on a neutral fixture, and `d1.json`, `workers.json`, `free.json`, `workers-paid.json` load in definition tests |
| 2 ✅ | One read | `Analytics` | `ReadPlan` writes one query for every limit; `PlannedRead` reads recorded answers. The unverified datasets in ENGINE §6 are settled by introspection |
| 3 ✅ | The root | `Monitor`, `Storage`, `Billing` (verify, accounts, subscriptions) | connect, choose, refresh, freshness; the token in the Keychain |
| 4 ✅ | The Today tab | App | the menu bar and Today from the mockup, on the real account |
| 5 ✅ | Warnings | `Alerts` | laws 9–10, with the sent log kept across relaunches |
| 6 ✅ | Service tabs | `Analytics` breakdowns, `Billing` deployments | D1 and Worker tabs, with deployment pins and the focus picker |
| 7 ✅ | The bill | `Billing` | estimate, forecast, quote, invoices |
| 8 ✅ | Watching | `Services` (`watchedByDefault`), `Monitor` (`watching`, `watch`, `unwatch`, law 21), App (Settings → *Watching*, Bill caption) | an unwatched service has no tab, card, query, warning or bill line; the choice survives a relaunch; the last one can't be turned off |
| 9 ✅ | KV | `Services` (`where` on a read, ENGINE §2), `Analytics` (`ReadPlan` writes it), `kv.json` (`watchedByDefault: false`), both plan files | KV reads, writes, deletes, lists and storage on Today, a KV tab, warnings and Bill lines once watched; the unverified `actionType` values in ENGINE §6 checked by a live read |
| 10 | The quiet menu bar | `Monitor` (`MenuBarState` as cases, `menuBarShows`, law 22), App (Settings row, label) | *Icon only* shows `☁` and the worst mark; before the first read the bar is `☁`, never an empty number. The GitHub issue's ask |
| 11 | Queues | `queues.json`, both plan files, the `operations` unit | Queues operations against Free's 10k a day and Paid's 1M a month, off until watched |
| 12 | R2, an add-on plan | `Plans` (`addOn`, `Plan.addOns`, law 23), `r2-paid.json`, `r2.json` | Class A, Class B and storage against R2's own free tier, on either Workers plan, priced in the Bill; off until watched |
| 13 | Workers AI | `ai.json`, both plan files | **blocked**: the dataset is not documented; `scripts/introspect-datasets.sh 'ai'` first |
| 14 | Vectorize | `vectorize.json`, both plan files | **blocked**: as above, `'vectorize'` |
| 15 | Durable Objects | `durable-objects.json`, both plan files | **blocked**: time filter, duration and SQLite rows to confirm, `'durableObjects'` |

## Decisions

| Date | Decision |
|---|---|
| 2026-10-09 | Its own app, beside ClaudeBar and AgentNexus, in the same design method |
| 2026-10-09 | Rate limits stay out of v1: Cloudflare keeps no analytics for Rate Limiting bindings |
| 2026-10-09 | The bill is an estimate from the plan files; Cloudflare's billable-usage API is alpha |
| 2026-10-09 | The API implementation only: an API token, HTTP behind the `Analytics` and `BillingAPI` ports. The `cf` CLI can't serve every read (ENGINE §6) |
| 2026-10-09 | Design approved; slices 1–7 built the same day |
| 2026-10-09 | A per-invocation limit acts only when Cloudflare stopped invocations, and is never the closest: a real account ran p99 17 ms past Free's 10 ms with none stopped |
| 2026-10-11 | R2 is an add-on plan beside the Workers plan, not a third plan (law 23) |
| 2026-10-11 | A dataset nobody verified never ships: Workers AI, Vectorize and Durable Objects wait for introspection |
| 2026-10-11 | New services ship one at a time, each off until the person watches it; an unwatched service is not read at all, and the Bill says what its estimate covers (law 21) |

## Open questions

- The first release needs the GitHub repo, its secrets and Pages turned on ([release setup](release/RELEASE_SETUP.md)); notarization has not run yet.

- The name *Overmind* is a working name.
- KV's `actionType` values `write`, `delete`, `list` and a per-namespace storage dimension are unverified until a live read (ENGINE §6); `read` is documented.
- Workers Paid's `rate_plan` id (`workers_paid`) is unverified: no Paid account has been read.
- Invoices have only been read as *forbidden* (the `cf` login has no billing scope); a token with Billing Read will show them.
- Checked end to end on a real Free account on 2026-10-09: plan, 5 limits, both tabs with 10 deployment pins, and the Workers Paid quote ($5).

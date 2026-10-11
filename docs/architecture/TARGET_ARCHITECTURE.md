---
description: How Overmind runs. It covers the pieces, each with one job, and the flows: connect, the refresh, a warning, opening a service tab, the bill, plus concurrency, errors and logging. Read before adding a piece or changing a flow.
---

# Overmind — target architecture

> **#3 of 5** in [the design](ARCHITECTURE.md) · **Answers:** how it runs:
> the pieces and the flows · **Builds on:** [CANONICAL_MODEL.md](CANONICAL_MODEL.md)
> · **Next:** [MODULAR_DESIGN.md](MODULAR_DESIGN.md)

---

## 1 · The picture

```text
                ┌──────────────────── Sources/App ─────────────────────┐
                │ MenuBarLabel · PopoverView · tabs · ConnectSheet      │
                │ render and tell; never compare, count or price        │
                └──────────────┬───────────────────────────────────────┘
                               │ reads / tells
                               ▼
              ┌──────────── Account (@MainActor @Observable) ────────────┐
              │ connection · plan · services · focus · bill · alerts     │
              │ refresh(at:) — the one place a reading lands             │
              └──┬───────────────┬──────────────┬───────────────┬────────┘
                 │               │              │               │
         ReadPlan│        BillingAPI       Notifier        TokenVault · SettingsStore
                 ▼               ▼              ▼               ▼
            Analytics      Cloudflare REST   UNUserNotif.   Keychain · settings.json
         (one GraphQL POST) (subscriptions,
                             billing/history,
                             deployments, verify)
```

## 2 · The pieces

| Piece | Job | Context | Inputs → outputs |
|---|---|---|---|
| `ServiceCatalog` | load the built-in service files | Services | bundle → `[ServiceDefinition]` |
| `PlanCatalog` | load the plan files; pick the account's Workers plan and its add-ons from its subscriptions | Plans | bundle, `[Subscription]` → `Plan` (with `addOns`) |
| `Limit` | turn usage and an allowance into percent, level and pace | Limits | `Usage`, `Allowance`, now → derived values |
| `ReadPlan` | every limit's read for one period, as **one** query | Analytics | `[LimitDefinition]`, `Period`s, accountID → `AnalyticsQuery` |
| `AnalyticsAPI` (port) | send a query, return the rows | Analytics | `AnalyticsQuery` → `AnalyticsAnswer` |
| `GraphQLAnalytics` | the port over `POST /client/v4/graphql` | Analytics/Internal | HTTP |
| `PlannedRead` · `PlannedBreakdowns` | read each limit's number (or each chart) out of the answer, by the paths its definition names | Analytics | `AnalyticsAnswer` → `[LimitID: Usage]` · `[Breakdown]` |
| `BillingAPI` (port) | accounts (how a token is checked), subscriptions, invoices, Workers, deployments | Billing | REST → values |
| `Bill` | estimate, forecast, quote; invoice when there is one | Billing | `Plan`, `[Limit]`, `[Invoice]` → money |
| `Alerts` | decide which warnings are new | Alerts | `[Limit]`, now → `[Warning]` |
| `Notifier` (port) | show a warning | Alerts | `Warning` → a notification |
| `Account` | the root; owns the refresh and every law that spans services | Monitor | all of the above |
| `Refresher` | tell `Account.refresh` every 5 minutes, on wake and on *Refresh* | Monitor | a clock → commands |
| `TokenVault` (port) | keep the token | Monitor | Keychain |
| `SettingsStore` (port) | keep the choices (with `watch: [ServiceID: Bool]`, only the services the person chose for) and the sent-warnings log | Monitor | `~/.overmind/settings.json` |
| `SettingsView` | the Settings window: renders `Account` and tells it, like the popover | App | — |
| `LoginItem` | *Start at login*, over `SMAppService.mainApp` | App | the system's login items |
| `Updater` | Sparkle: checks the appcast, installs signed updates | App | `https://tddworks.github.io/Overmind/appcast.xml` |

## 3 · Flows

### 3.1 · Connect (journeys 1–3)

```text
ConnectSheet ─ account.connect(token)
  BillingAPI.verify(token)                  401/403 → refused, nothing stored
  BillingAPI.accounts(token)                one → chosen; several → the picker
  Analytics probe: an empty read           fails → "needs Account Analytics Read", nothing stored
  BillingAPI.subscriptions                 403 → connection.missing += .billing (law 12)
  TokenVault.save(token) · SettingsStore.save(accountID)
  refresh(at: now)
```

### 3.2 · The refresh (journeys 4–7, 16)

```text
Refresher ─ account.refresh(at: now)
  limits of the watched services only            law 21
  none (only AI Gateway watched) → a good read, no query: an empty query is a GraphQL error
  plan.period(for: each limit, at: now)          law 5
  ReadPlan(limits, periods) → one AnalyticsQuery  one POST per refresh: the GraphQL API allows 300 per 5 min
  AnalyticsAPI.read(query) → answer
  PlannedRead.usages(from: answer) → [LimitID: Usage]
  limit.record(usage)                             law 7: newer and same period, or dropped
  connection.didRead(at:) / didFail(…)            law 11
  alerts.check(limits, at: now) → [Warning]       laws 9–10
  Notifier.post(warning) · SettingsStore.save(alerts.sent)
```

A failed read changes `freshness` and nothing else: the last good usage stays
on screen with *STALE*, never zeros.

### 3.2a · Watching a service (journey 21)

```text
SettingsView ─ account.watch(id) / unwatch(id)
  unknown id, or the last watched one → no (law 21)
  settings.watch[id] = true / false · SettingsStore.save
  limits = Account.limits(watched services, on: plan, keeping: limits)
  watch → refresh(at: now)                        its numbers appear at once
```

A choice for a service the files no longer have is ignored; a service the
choices don't name takes its file's `watchedByDefault`.

### 3.3 · Opening a service tab (journeys 12–14)

```text
PopoverView ─ account.open(service)
  breakdowns older than one refresh? → ReadPlan.breakdowns(service, focus) → AnalyticsAPI → PlannedBreakdowns
  deployments for the focused Worker → BillingAPI.deployments (once per open, cached 5 min)
```

The focus enters the breakdown query only. `ReadPlan` for limits has no focus
parameter, so law 1 can't be broken by a caller.

### 3.4 · The bill (journey 15)

```text
account.bill
  only the watched services' limits; the estimate names them when one isn't watched (law 21)
  invoice for this period? → shown as is (law 13)
  else plan.cost(of: limits' month-to-date)  — Paid only; Free is $0 and can't overspend
  forecast = plan.cost(of: limits' month pace)
  quote(on: other) = other.cost(of: the same usage)
```

Month-to-date for a Paid plan is read as its own `ReadPlan` over the billing
period. Cloudflare's billable-usage API is alpha (2026-10); it can replace the
estimate later without changing `Bill`'s shape.

## 4 · Concurrency, errors, logging

- `Account`, `Alerts` and the views are `@MainActor`. Ports are `Sendable` and
  `async`; a read never holds the main actor while it waits.
- One refresh at a time: a refresh asked for while one runs joins it.
- Errors are typed per port (`AnalyticsError`, `BillingError`) and land as
  state (`freshness`, `missing`, a breakdown's reason). Views never see a thrown
  error.
- `AppLog.<category>` (`monitor`, `analytics`, `billing`, `alerts`). Log that a
  read happened and how long it took, never the token, an `Authorization`
  header, or a query's answer.

---
description: How Edge Meter's code is cut into modules. There is one module per bounded context, each with its domain at the root and its implementations in Internal/; there is no Infrastructure layer. Covers the factories, the dependency rules, ports and testing. Read before adding a file, a type or a module.
---

# Edge Meter — the modular design

> **#4 of 5** in [the design](ARCHITECTURE.md) · **Answers:** where the code
> lives: which module a file goes in, what a module shows and hides, and what
> it may import · **Builds on:** [TARGET_ARCHITECTURE.md](TARGET_ARCHITECTURE.md) ·
> **Next:** [ENGINE_DESIGN.md](ENGINE_DESIGN.md)
>
> **Status: PROPOSED.** Nothing is built; what lands slice by slice is in [docs/status.md](../status.md).

---

## 1 · Modules by context, not layers by technology

The same cut as ClaudeBar and AgentNexus
([ClaudeBar's §1](https://github.com/tddworks/ClaudeBar/blob/main/docs/architecture/MODULAR_DESIGN.md#1--modules-by-context-not-layers-by-technology)):
**one module per bounded context**, each in two halves.

```text
Modules/<Context>/
├── Sources/
│   ├── *.swift            THE DOMAIN: public values, aggregates and the ports
│   ├── <Context>.swift    THE FACTORY: a public enum that builds and wires
│   └── Internal/          THE IMPLEMENTATION: `internal` types that touch the
│                          network, a file or the Keychain
├── Resources/             data the module ships (definitions)
└── Tests/
```

**There is no Infrastructure layer and no Cloudflare module.** Cloudflare's
products and prices are JSON in `Services/Resources/` and `Plans/Resources/`;
its HTTP APIs sit behind ports, implemented in `Analytics/Internal` and
`Billing/Internal`.

```swift
// App — the composition root; it cannot construct an implementation
let settings = Storage.makeSettings()
let vault    = Storage.makeVault()
let account  = Account(
    services:  Services.makeCatalog().builtIn(),
    plans:     Plans.makeCatalog(),
    analytics: Analytics.make(vault: vault),
    billing:   Billing.make(vault: vault),
    alerts:    Alerts(settings: settings.alerts, notifier: Alerts.makeNotifier()),
    settings:  settings,
    vault:     vault
)
Refresher(account: account, every: .minutes(5)).start()
```

## 2 · The modules

| Module | Context ([model §3](CANONICAL_MODEL.md#3--the-bounded-contexts)) | Public (the domain) | `Internal/` · `Resources/` |
|---|---|---|---|
| `Measures` | shared kernel | `Quantity`, `Unit`, `Money`, `Period`, `Percent`, `JSONPath` | — |
| `Services` | core | `ServiceDefinition`, `LimitDefinition`, `BreakdownDefinition`, `Read` (ENGINE §2), `ServiceCatalog` | `Resources/Services/`: `workers.json`, `d1.json` |
| `Plans` | core | `PlanDefinition`, `Allowance`, `Price`, `PlanCatalog` (`plan(for: [Subscription])`), `cost(of:)` | `Resources/Plans/`: `free.json`, `workers-paid.json` |
| `Limits` | core | `Limit`, `Usage`, `Pace`, `Level` | none: pure |
| `Analytics` | supporting | `ReadPlan`, `AnalyticsQuery`, `AnalyticsAnswer`, `AnswerReader`, `Breakdown`, the port `Analytics` | `GraphQLAnalytics` (over `HTTP`) |
| `Billing` | supporting | `Bill`, `Invoice`, `Subscription`, `Deployment`, `AccountSummary`, the port `BillingAPI` | `CloudflareREST` (over `HTTP`) |
| `Alerts` | supporting | `Alerts`, `Warning`, the port `Notifier` | `UserNotifier` |
| `Storage` | generic | `Storage.makeVault()` (`TokenVault`), `.makeSettings()` (`SettingsStore`) | `KeychainTokenVault`, `JSONSettingsFile` |
| `Diagnostics` | cross-cutting | `AppLog` and its categories | `FileLogger` |
| `Monitor` | core · the root | `Account` (`@MainActor @Observable`), `Connection`, `Focus`, `MenuBarState`, `Refresher`, the ports `TokenVault` · `SettingsStore` | — |
| `EdgeMeter` (App) | the composition root | SwiftUI views, the Pop theme (AgentNexus's), the menu-bar label | — |

The HTTP call itself is a small `internal` type in each of `Analytics` and
`Billing`, so neither imports the other. The two copies are a few lines;
sharing them would cost a module.

## 3 · The dependency rules

| Module | May import |
|---|---|
| `Measures` | nothing |
| `Services` · `Plans` | `Measures` |
| `Limits` | `Measures` · `Services` · `Plans` |
| `Analytics` | `Measures` · `Services` · `Limits` (it hands back `Usage`) |
| `Billing` | `Measures` · `Plans` · `Limits` |
| `Alerts` | `Measures` · `Limits` |
| `Storage` | `Measures` · `Alerts` · `Monitor` (it implements their ports) |
| `Monitor` | all of the above but `Storage` |
| `EdgeMeter` (App) | everything; it is the only place `Storage` meets `Monitor` |
| any | `Diagnostics` |


1. **`Measures` imports nothing.** Every other module may import it.
2. **`Services`, `Plans` and `Limits` are pure**: no network, no file outside
   their bundle, no clock (time comes in as an argument).
3. **`Limits` knows a definition and an allowance, never where they came
   from.** It imports `Services` and `Plans`, not `Analytics`.
4. **A port lives in the module that needs it**; its implementation lives in
   the module that owns the technology (`TokenVault` in `Monitor`, implemented
   by `Storage`).
5. **No port writes to Cloudflare** (model law 16). A `BillingAPI` or
   `Analytics` method is a read; a review rejects a `POST` that changes state.
   (GraphQL's `POST` is a read.)
6. **No module's Swift names a Cloudflare product, dataset or number.**
   `d1AnalyticsAdaptiveGroups` and `5_000_000` are only in JSON.
7. **Only `Monitor` and the App are `@MainActor`.**

## 4 · Testing

- **One suite per aggregate**, on neutral fixtures (`ServiceDefinition.acme`,
  a plan that allows *100 widgets a day*), before any test through the real
  JSON.
- **Each built-in definition gets a definition test** through its real file:
  *should know D1 counts rows read against the Free plan's 5M a day*.
- **Ports are `@Mockable`** and stubbed to answer; tests assert on the
  resulting state, never `verify()`.
- **Recorded GraphQL and REST answers** live in `Modules/<X>/Tests/Fixtures/`
  with the account ID, names and emails replaced by placeholders.

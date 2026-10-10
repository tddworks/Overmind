---
description: The normative tree Overmind binds to. It covers every node from the Account down, the word the screen prints for it, its laws and their one owner, and the bounded contexts. Read before adding or changing any domain type, service or plan.
---

# Overmind — the canonical model

> ONE tree. The menu bar, the popover, the Connect sheet and the
> notifications all read it, and none of them adds a rule to it. A node is
> here because a person can point at it on screen. A rule lives on **the node
> that holds the data it needs** (tell, don't ask).
>
> **#2 of 5** in [the design](ARCHITECTURE.md) · **Answers:** what is true:
> the nodes, the words, the laws and their owners · **Builds on:**
> [USER_JOURNEYS.md](USER_JOURNEYS.md) · **Next:**
> [TARGET_ARCHITECTURE.md](TARGET_ARCHITECTURE.md)

---

## 0 · How to read it

| Mark | Means |
|---|---|
| **◆** | a domain object with commands and laws; it can say no |
| **◇** | a value; it answers, and cannot be told anything |
| **DERIVED** | computed from other nodes, never stored |

### 0.1 · The words

The words are the ones the screen prints ([USER_JOURNEYS §4](USER_JOURNEYS.md#4--the-words-the-screens-print)).
Where ClaudeBar or AgentNexus already has a word for the same thing (`Money`,
`Period`, `CredentialLookup`, `AppLog`), Overmind uses it.

| On screen | The node | Why this word |
|---|---|---|
| *tddworks · Cloudflare account* | **`Account`** | the root: what the token reads |
| *LIVE · read 1 min ago* · *STALE* | **`Connection`** | the token, the account it chose, and how fresh the last read is |
| *FREE* · *WORKERS PAID* | **`Plan`** | Cloudflare's word. A plan is data: allowances and prices per limit |
| *D1* · *Worker* (tabs) | **`Service`** | a Cloudflare product, as data: its limits and its breakdowns |
| a card in *Every limit today* | **`Limit`** | one thing counted against the plan. Cloudflare's own pages are titled *Limits* |
| *5M / day* · *10 ms / invocation* · *5 GB total* | **`Allowance`** | what the plan includes. Not *quota*: that's ClaudeBar's word for a provider's own counter |
| *912k* · *read since 00:00 UTC* | **`Usage`** | used, in which period, read when |
| *resets in 9h 40m* · *00:00 UTC* | **`Period`** | a UTC day, or the billing month that starts on the renewal date |
| *on pace for 31% by midnight* | **`Pace`** | where the current rate ends the period |
| *OK · WATCH · ACT NOW* | **`Level`** | |
| *Warn me at 50% 75% 90% · pace · Notify* | **`Alerts`** | the setting; what it sends is a **`Warning`** |
| a chart or list on a service tab | **`Breakdown`** | where a limit's use came from |
| *d605dc93* on a chart | **`Deployment`** | |
| *leaderboard ▾ · All workers* | **`Focus`** | which Worker the breakdowns describe |
| *This month · est.* · *Forecast* · *Invoices* | **`Bill`** · **`Invoice`** | |

> **One number, two homes.** *5M* is a fact about the **plan** (`Allowance`),
> *912k* a fact about the **account** (`Usage`). A `ServiceDefinition` holds
> neither: it says what is counted and how to read it. So a price change edits
> a plan file, and a new Cloudflare product adds a service file.

## 1 · The tree

```text
Account  ◆                                  THE ROOT — one per app (v1)
├── connection: Connection  ◆               "LIVE · read 1 min ago"
│   ├── token                               in the Keychain only; shown as its last 4 characters
│   ├── accountID · name                    the one the person chose
│   ├── missing: [Permission]               "Bill needs Billing Read" — what the token can't read
│   └── freshness                           DERIVED — live · stale · refused
│
├── plan: Plan  ◇                           "FREE" — a PlanDefinition, picked by the account's subscriptions
│   ├── allowance(for: Limit.ID)            5M per day · 10 ms per invocation · 5 GB total
│   ├── price(for: Limit.ID)                beyond the allowance; nil on Free (it stops instead)
│   ├── subscription: Money                 $0 · $5 a month
│   └── period(for:at:) → Period            Free: the UTC day · Paid: the billing month
│
├── services: [Service]  ◆                  "D1" · "Worker" — one ServiceDefinition each
│   ├── definition: ServiceDefinition  ◇    id · name · look · limits · breakdowns (DATA)
│   ├── limits: [Limit]  ◆                  one per limit the plan has an allowance for
│   │   ├── definition: LimitDefinition ◇   id · name · short name ("D1") · unit · how it is read
│   │   ├── allowance: Allowance  ◇         from the plan
│   │   ├── usage: Usage?  ◇                used · period · readAt — nil until the first read
│   │   ├── percent                         DERIVED
│   │   ├── level: Level                    DERIVED — ok · watch · actNow
│   │   └── pace: Pace?                     DERIVED — nil in a period's first hour
│   └── breakdowns: [Breakdown]  ◇          read when the tab opens, for the focus
│
├── focus: Focus  ◇                         .worker(name) · .allWorkers — breakdowns only
├── interval                                "Read every 5 min" — 5 · 10 · 15 · 30 minutes
├── deployments: [Deployment]  ◇            id · when — pins on the charts
├── limits                                  DERIVED — every service's limits, in catalog order
├── closest: Limit?                         DERIVED — the headline and the menu bar
├── menuBar: MenuBarState                   DERIVED — "D1 18%" and its level
│
├── bill: Bill  ◇                           "This month · est." — estimate · forecast · invoices
│   ├── stopped: [LimitID: [Date]]          "Free stopped you on 2 days" — days a daily allowance ran out
│   ├── verdict                             DERIVED — enough · stopped(days)
│   └── quote(on: Plan) → Quote             "Workers Paid · $5.00 this month" — the same usage, priced by
│                                           another plan, with one line per limit
│
└── alerts: Alerts  ◆                       "Warn me at" — levels · pace · isOn
    └── sent: [Warning.Key]                 limit · level · period — the once-only log
```

## 2 · Data, choices and readings

Three kinds of fact, three homes. Mixing them is the usual bug.

| Kind | Examples | Home | Changes when |
|---|---|---|---|
| **Definitions** (data) | D1 counts *rows read* from `d1AnalyticsAdaptiveGroups`; Free allows 5M per day | `Resources/Services/*.json` · `Resources/Plans/*.json` | Cloudflare changes a product or a price |
| **Choices** (settings) | the account, the focus, the read interval, the alert levels | `~/.overmind/settings.json`; the token in the Keychain | the person changes them |
| **Readings** (state) | 912k read at 14:20; the warnings already sent | memory; the sent-warnings log in settings | every refresh |

**No Swift names a Cloudflare product or a number Cloudflare can change.**
`"d1"`, `rowsRead` and `5_000_000` appear only in JSON.

## 3 · The bounded contexts

| Context | Holds | Speaks to the outside through |
|---|---|---|
| **Measures** — the kernel | `Quantity` · `Unit` · `Money` · `Period` · `Percent` | nothing |
| **Services** | `ServiceDefinition` · `LimitDefinition` · `BreakdownDefinition` · the catalog | its bundle |
| **Plans** | `PlanDefinition` · `Allowance` · `Price` · the catalog | its bundle |
| **Limits** | `Limit` · `Usage` · `Pace` · `Level` | — (pure) |
| **Analytics** | turning definitions into one GraphQL read, and the answer into `Usage` and `Breakdown` | `AnalyticsAPI` port |
| **Billing** | `Bill` · `Invoice` · which plan the account is on | `BillingAPI` port |
| **Alerts** | `Alerts` · `Warning` | `Notifier` port |
| **Monitor** | `Account` · `Connection` · `Focus` · the refresh | `TokenVault` · `SettingsStore` ports |

## 4 · Commands

| Command | On | Says no when |
|---|---|---|
| `connect(token)` | `Account` | Cloudflare refuses the token, or it can't read Account Analytics |
| `choose(accountID)` | `Account` | the token can't see that account |
| `refresh(at:)` | `Account` | — (a failed read changes `freshness`, never throws to a view) |
| `focus = …` | `Account` | the Worker isn't on the account |
| `open(service)` | `Account` | — (reads its breakdowns if older than one refresh) |
| `toggle(level)` · `isOn` · `paceIsOn` | `Alerts` | — |
| `setInterval(minutes:)` | `Account` | a choice other than 5, 10, 15 or 30 minutes |
| `disconnect()` | `Account` | — (removes the token from the Keychain) |

## 5 · The laws, on the node that owns them

| # | Law | Owner |
|---|---|---|
| 1 | **A limit counts the whole account**, because Cloudflare does. `Focus` narrows breakdowns and never a limit's reading. | `Account` |
| 2 | `percent = used ÷ allowance`. **Level:** under 50 is *ok*, 50 up to 90 is *watch*, 90 and over is *act now*. | `Limit` |
| 3 | A **per-invocation** allowance (*10 ms*) is compared with the period's p99, and the card counts the invocations Cloudflare stopped for it. Cloudflare lets single invocations run past it (a real account: p99 17 ms, none stopped), so its level is *act now* only when some were stopped, and at most *watch* otherwise. It never runs out, so it is never `closest`. | `Limit` |
| 4 | A **total** allowance (*5 GB*) never resets and has no pace. | `Allowance` |
| 5 | **Periods:** Free allowances reset at 00:00 UTC; Paid included amounts reset on the subscription's renewal date. | `Plan` |
| 6 | `Pace = used × length ÷ elapsed`, projected to the period's end. **Nil in the period's first hour**, and for total and per-invocation allowances. | `Pace` |
| 7 | A reading replaces `Usage` only if it is **newer and of the same period**. When a period ends, usage is nil until the first read of the new one; a number from yesterday is never shown as today's. | `Limit` |
| 8 | `closest` is the limit that runs out with the **highest percent**; a tie goes to the higher pace; a limit with no usage is never closest. | `Account` |
| 9 | **One warning per limit, per level, per period.** Falling back under a level and crossing it again in the same period sends nothing new. Turning a level off never clears the log. | `Alerts` |
| 10 | A **pace warning** goes out when pace reaches 90% while percent is under 90, once per limit per period. | `Alerts` |
| 11 | **Freshness:** *live* while the last good read is under two refresh intervals old, *stale* after that, *refused* when Cloudflare rejects the token itself (401/403 on verify). | `Connection` |
| 12 | A permission the token lacks is a **reason on the part that needs it** (*Bill needs Billing Read*), never a failed connect, except Account Analytics Read, without which nothing can be read. A refusal says which it was: a wrong token (401), a token that sees no account (403 on the account list), a token that can't read usage (403 on the query). A token the Keychain won't give back is the Keychain's problem, never shown as Cloudflare's. | `Connection` |
| 13 | **The bill is an estimate**: the plan's subscription plus, for each limit, the price of what went past its allowance. Once Cloudflare issues the invoice for a period, the invoice is shown instead. | `Bill` |
| 14 | A **quote** prices the same usage with another plan; a **forecast** prices the month's pace with this one. | `Plan` (`cost(of:)`) · `Bill` |
| 15 | **The token** lives only in the Keychain, is never logged, and is shown only as its last four characters. | `Connection` (through `TokenVault`) |
| 16 | **Read-only:** no port has a call that writes to Cloudflare. | the ports ([MODULAR_DESIGN](MODULAR_DESIGN.md)) |
| 17 | **Read every 5, 10, 15 or 30 minutes**, 5 unless the person chose; *stale* follows the choice (two intervals). Fewer reads never skip a warning: each read still checks every level. | `Account` |
| 18 | **The plan is re-read** when the Bill tab opens and once a day, so an upgrade made on Cloudflare shows without a restart; the limits follow the new plan's allowances. | `Account` |
| 19 | **A day Free stopped you** is a UTC day in the billing month when a *daily* allowance's use reached it. The verdict is *enough* when there is none, *stopped* otherwise. Each daily limit also answers its **busiest day** of the month. | `Bill` |
| 20 | **A quote line** is one limit: its month's use, what the plan includes, and the price of the rest; the subscription is its own line and the lines add up to the quote. | `Plan` (`lines(of:)`) |

*Start at login* and *updates* are the system's and Sparkle's, not the account's: the App holds them (`LoginItem`, `Updater`) and no law of the tree depends on them.

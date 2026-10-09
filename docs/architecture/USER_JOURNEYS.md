---
description: Who uses Edge Meter and what they ask. It covers the people and the moments, from connecting a Cloudflare account and glancing at the menu bar to being warned, finding the cause and reading the bill, plus the words each screen prints. Read first.
---

# Edge Meter — user journeys

> **#1 of 5** in [the design](ARCHITECTURE.md) · **Answers:** who is asking,
> and what · **Builds on:** nothing; every other document answers this one ·
> **Next:** [CANONICAL_MODEL.md](CANONICAL_MODEL.md)
>
> Where a journey and the model disagree, the journey wins and the model moves.
>
> **The mockup:** [edgemeter-pop.html](../../design-concept/edgemeter-pop.html):
> the menu bar states, the popover (Today · D1 · Worker · Bill), the
> notifications and the *Connect Cloudflare* sheet.

---

## 1 · The people

| Who | Wants | Journey |
|---|---|---|
| **Kai** — runs the ClaudeBar leaderboard: one Worker, one D1 database, on the Free plan | to know, without opening the dashboard, whether today's use stays under the free limits | *Glance* |
| **Kai**, on 2026-10-07 — D1 reached 75% of its 5M free rows read with nobody watching | to be told early enough to act, before reads start failing | *Be warned* |
| **Kai**, after the warning | which query or route spent it, and whether yesterday's deploy fixed it | *Find the cause* |
| **Lee** — a contributor deciding whether to pay | what this month costs, and what Workers Paid would cost at today's pace | *Read the bill* |
| **Lee**, first run | to connect an account without giving the app any power to change it | *Connect* |

Each journey is a promise. A screen that serves none of them is a screen to
question, and a person here that no screen serves is a gap.

## 2 · The moments

Each row lists what the person sees (the words the screen prints), what they
do, the command that lands on the domain, and the node that answers.

| # | Moment | Sees | Does | Command | Node |
|---|---|---|---|---|---|
| 1 | Lee opens Edge Meter the first time | *Connect Cloudflare* · *API token* · *Token needs: Account Analytics · D1 · Workers Scripts · Billing — READ* · *Edge Meter only reads* | pastes a token | `account.connect(token)` | `Connection` |
| 2 | The token answers for two accounts | *Account ▾ tddworks · personal* | picks *tddworks* | `account.choose(accountID)` | `Connection` |
| 3 | The token can't read billing | *Connected · Bill needs Billing Read* | carries on | — | `Connection.missing` — a reading the token can't do is a reason on that tab, never a failed connect |
| 4 | Kai glances at the menu bar | *D1 18%* | nothing | `account.menuBar` | the closest `Limit` |
| 5 | Kai opens the popover | *FREE · resets in 9h 40m* · *claudebar-leaderboard · LIVE · read 1 min ago* · *CLOSEST TO THE LIMIT · D1 rows read · 18% of 5M · on pace for 31% by midnight* | reads | `account.closest` · `limit.pace` | `Limit` · `Pace` · `Plan` |
| 6 | Kai reads *Every limit today* | one card per limit: *D1 reads 912k 18% · OK*, *CPU 7.8 ms 78% · WATCH* … *resets 00:00 UTC* · *82% left* | taps a card | `account.limits` | `Limit` · `Level` |
| 7 | It's 00:20 UTC | the headline reads *too early to tell* instead of a pace | nothing | `limit.pace` | `Pace` is nil in a period's first hour |
| 8 | D1 crosses 50%, then 75% | a notification each time: *D1 rows read at 75% · 3.75M of 5M free · on pace for 101% by 00:00 UTC* | opens the popover | — | `Alerts` — once per limit, per level, per period |
| 9 | Today's rate would cross 90% before midnight | *Pace: D1 would cross 90% at 22:40* | — | — | `Alerts`, with *pace* on |
| 10 | The menu bar at 62%, then 91% | *D1 62%* in butter, *D1 91%* in coral; headline *ACT NOW* · *crosses 5M at 22:40 UTC, reads fail until reset* | — | `limit.level` | `Level` |
| 11 | Kai turns *75%* off, or *Notify* off | the chip dims | — | `alerts.toggle(.percent(75))` · `alerts.isOn = false` | `Alerts` |
| 12 | Kai opens *D1* | *Rows read · last 7 days* with *d605dc93* pinned on 10-08 · *per hour today* · *Top queries by rows read* · *Database: storage, rows written* | reads | `service.breakdowns` | `Breakdown` · `Deployment` |
| 13 | Kai opens *Worker* | *Requests per hour* (errors in coral) · *CPU p50 / p99* · *Hourly cron · last run OK · 24/24* | reads | `service.breakdowns` | `Breakdown` |
| 14 | Kai picks *All workers* in the strip | the breakdowns cover every Worker; the limits don't change | — | `account.focus = .allWorkers` | `Focus` — a limit is the account's, a focus only narrows breakdowns |
| 15 | Lee opens *Bill* | *October so far $0.00* · *Forecast · Oct 31* · *IF YOU UPGRADED* · *Free is enough* or *Free stopped you on 2 days* · *Free · YOUR PLAN $0.00 this month* · *Workers Paid · $5 / mo · $5.00 this month, if you'd been on it* · *This month on Workers Paid*, one line per limit · *Invoices* | reads | `account.bill` · `bill.verdict` · `quote.lines` | `Bill` · `Plan` |
| 15c | Lee taps a plan card | the chosen card is purple; below it, *This month on Free* (each limit's allowance, busiest day, days it stopped you, $0.00) or *This month on Workers Paid* (the subscription and one line per limit) | taps the other card | — (the view's choice) | `Bill` · `Quote` |
| 15a | Lee decides to upgrade | *Upgrade on Cloudflare ↗* · *Edge Meter only reads: plans change on Cloudflare* | clicks it; pays on Cloudflare | — | the plan file's `upgradeURL` |
| 15b | Lee comes back after upgrading | *WORKERS PAID* in the header; monthly allowances on the cards | nothing; no restart | `account.openBill(at:)` · `refresh(at:)` | `Account` re-reads the plan (law 18) |
| 16 | The Mac slept for a night | the strip reads *STALE · read 9h ago* until the next read lands | nothing | `account.refresh()` | `Connection.freshness` |
| 17 | The token is revoked | *Cloudflare refused the token* · *Connect again* | pastes a new one | `account.connect(token)` | `Connection` |
| 17 | Kai clicks *Dashboard ↗* | the Cloudflare dashboard opens on that account | — | — | `Account.dashboardURL` |
| 18 | Kai opens *⚙ → Settings…* | the Settings window: *Account* · *Reading* · *Warnings* · *General* | — | — | the same `Account` the popover reads |
| 19 | Kai wants fewer reads | *Read every 5 min · 10 · 15 · 30*; *STALE* waits for two missed reads | picks *15* | `account.setInterval(minutes:)` | `Account.interval` (law 17) |
| 20 | Lee wants it there after a restart | *Start at login* | turns it on | — | the system's login items (`LoginItem`, App) |
| 22 | A new version is out | Sparkle's *A new version of Edge Meter is available* · *Check now* in Settings | installs | — | `Updater` (App, Sparkle) |

## 3 · What the person never has to know

- **GraphQL, datasets, field names.** The cards say *D1 rows read*, never `d1AnalyticsAdaptiveGroups.sum.rowsRead`.
- **Which plan they're on.** It is read from the account; *FREE* or *PAID* is printed for them.
- **UTC.** The reset is shown as a countdown (*resets in 9h 40m*); `00:00 UTC` appears only on the cards that reset at it.
- **That a limit is account-wide.** The strip's Worker picker narrows the D1 and Worker tabs only; the Today cards always count the whole account, because Cloudflare does (moment 14).

## 4 · The words the screens print

| Word | Means | Never |
|---|---|---|
| **Account** | the Cloudflare account the token reads | zone, tenant |
| **Plan** — *FREE*, *WORKERS PAID* | what Cloudflare includes and charges | tier |
| **Limit** | one thing Cloudflare counts against the plan: *D1 rows read*, *Requests*, *CPU* | metric, quota |
| **Allowance** — *5M / day*, *10 ms / invocation* | how much of a limit the plan includes | cap, quota |
| **Used** — *912k* | how much of the allowance this period has used | consumption |
| **Pace** — *on pace for 31% by midnight* | where today's rate ends the period | forecast (that's the Bill's word) |
| **Level** — *OK · WATCH · ACT NOW* | under 50% · 50 to 90% · 90% and over | |
| **Warning** | a notification Edge Meter sent | alert (the setting is *Warn me at*) |
| **Service** — *D1*, *Worker* | a Cloudflare product with its own tab | product |
| **Breakdown** | a chart or list that says where a limit's use came from | report |
| **Deployment** — *d605dc93* | a Worker version going live, pinned on charts | release |
| **Focus** — *leaderboard · All workers* | which Worker the breakdowns describe | scope, filter |
| **Bill** · **Forecast** · **Invoice** | money: this month's, its projection, past months | |
| **Stale** | the last read is older than two refreshes | offline |
| **Settings** | the window for the choices: account, reading, warnings, general | preferences |

## 5 · Out of scope, for now

- **Changing anything on Cloudflare.** The token is read-only, and no port has a write call.
- **Several accounts at once.** One connected account; switching is *Connect again*.
- **Services other than Workers and D1.** KV, R2, Queues and Durable Objects are one JSON file each once someone needs them ([ENGINE_DESIGN](ENGINE_DESIGN.md)); none ships in v1.
- **The `cf` CLI's login.** v1 connects with an API token. `Analytics` and `BillingAPI` are ports, so a `cf`-backed credential or adapter can come later without touching the domain.
- **Changing the plan from Edge Meter.** Cloudflare's API can (`POST`/`PUT`/`DELETE /accounts/{id}/subscriptions`), but it needs *Billing: Edit*, which can cancel any subscription, and the payment belongs in Cloudflare's own flow. Decided 2026-10-09: a link to Cloudflare's plans page instead; revisit as an opt-in capability once a Paid account can verify it.
- **Rate limits.** Cloudflare keeps no analytics for Rate Limiting bindings, and a request the Worker answers with 429 is a *success* to Workers analytics. Once a Worker writes an Analytics Engine data point per block, a *Blocked by rate limit* breakdown is one entry in `worker.json`. Decided 2026-10-09: not in v1.

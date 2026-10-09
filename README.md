# Edge Meter

**Know before the free tier says no.** A macOS menu bar app that watches a Cloudflare
account's usage and bill: the limit closest to running out, a warning before it does,
the query or deploy behind it, and what the month costs — read with a read-only token.

ClaudeBar's and AgentNexus's sibling: same design method, same Pop theme.

<img src="design-concept/screenshots/popover-today.png" width="360" alt="The Edge Meter popover on demo data">

## Install

Download the DMG from [Releases](https://github.com/tddworks/EdgeMeter/releases), open it and drag
Edge Meter to Applications. It updates itself (Settings → General).

Or build from source (macOS 15+, Xcode, [Tuist](https://tuist.dev)):

```bash
tuist install && tuist generate
xcodebuild build -workspace EdgeMeter.xcworkspace -scheme EdgeMeter -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/dd
open .build/dd/Build/Products/Debug/EdgeMeter.app
```

Try it without an account: `EDGEMETER_DEMO=1 .build/dd/Build/Products/Debug/EdgeMeter.app/Contents/MacOS/EdgeMeter`.

## First run

1. [Create an API token](https://dash.cloudflare.com/profile/api-tokens) with **read** access to
   **Account Analytics** and **Workers Scripts**, and **Billing** if you want the plan and invoices.
2. Click **☁** in the menu bar, paste the token, **Connect**. It is kept in your Keychain.
3. The menu bar shows the limit closest to running out (**D1 18%**). Edge Meter reads every 5 minutes
   and after the Mac wakes, and warns at 50%, 75% and 90%, or early when today's pace would cross 90%.
4. **⚙ → Settings…** changes how often it reads, the warnings, starting at login and updates
   ([features](docs/features/)).

## What it watches

| Service | Limits | Tab |
|---|---|---|
| Workers | requests, CPU per invocation (Free) or CPU time (Paid) | requests per hour, invocations by outcome, cron runs, deployments |
| D1 | rows read, rows written, storage | rows read per day and hour, top queries |

Plans: Free and Workers Paid; the Bill tab prices this month on both. Other Cloudflare products
are one JSON file each → [ENGINE_DESIGN](docs/architecture/ENGINE_DESIGN.md).

Edge Meter only reads: no call it makes can change your account.

## Docs

[The design](docs/architecture/ARCHITECTURE.md) · [features](docs/features/) · [releasing](docs/release/RELEASE_SETUP.md) · [status](docs/status.md) · [for agents](AGENTS.md)

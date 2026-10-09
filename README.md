# Edge Meter

**Know before the free tier says no.** A macOS menu bar app that watches a Cloudflare
account's usage and bill: the limit closest to running out, a warning before it does,
the query or deploy behind it, and what the month costs — read with a read-only token.

ClaudeBar's and AgentNexus's sibling: same design method, same Pop theme.

> **Status:** design proposed, nothing built yet → [docs/status.md](docs/status.md) ·
> the screens → [design-concept/edgemeter-pop.html](design-concept/edgemeter-pop.html)

## Build

macOS 15+, Xcode, [Tuist](https://tuist.dev):

```bash
tuist install && tuist generate
xcodebuild build -workspace EdgeMeter.xcworkspace -scheme EdgeMeter -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/dd
open .build/dd/Build/Products/Debug/EdgeMeter.app
```

## What it will watch (v1)

| Service | Limits |
|---|---|
| Workers | requests, CPU per invocation |
| D1 | rows read, rows written, storage |

Plans: Free and Workers Paid. Other Cloudflare products are one JSON file each →
[ENGINE_DESIGN](docs/architecture/ENGINE_DESIGN.md).

## The token

Create an API token with **read** access to Account Analytics, D1, Workers Scripts and
Billing. Edge Meter keeps it in the Keychain and has no call that changes your account.

## Docs

[The design](docs/architecture/ARCHITECTURE.md) · [status](docs/status.md) · [for agents](AGENTS.md)

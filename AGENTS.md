# AGENTS.md

Rules for AI coding agents (Claude Code, Codex, Cursor, …) in this repo. This is the only agent-instructions file; there is no `CLAUDE.md`. Everything else is one link away: [architecture](docs/architecture/ARCHITECTURE.md) · [status](docs/status.md) · [docs design](docs/documentation-design/README.md) · [mockup](design-concept/overmind-pop.html).

Overmind is a macOS menu bar app that watches a Cloudflare account's usage and bill, read-only. It is ClaudeBar's and AgentNexus's sibling. **Cloudflare products and plans are JSON definitions** in `Modules/Services/Resources/Services/` and `Modules/Plans/Resources/Plans/`, and no Swift names a product, a dataset or a number Cloudflare can change.

## Build & test

```bash
tuist install && tuist generate          # generated *.xcodeproj / *.xcworkspace are git-ignored
tuist test                               # every test target
tuist test Limits                        # one scheme
xcodebuild test -workspace Overmind.xcworkspace -scheme Overmind-Workspace \
  -destination 'platform=macOS,arch=arm64'                    # bypasses Tuist's result cache
```

- `tuist test` caches results; use `xcodebuild test` when a test must really run.
- Sources use `**` globs in `Project.swift`, so new subfolders are picked up without edits. A new module is one `module(…)` and one `tests(…)` line there.

## Architecture

One module per bounded context ([MODULAR_DESIGN.md](docs/architecture/MODULAR_DESIGN.md)): the domain at `Sources/`, its implementation in `Sources/Internal/`, one factory enum per module.

| Module | Holds |
|---|---|
| `Modules/Measures` | the kernel: `Quantity`, `Money`, `Period`, `Percent`. Imports nothing |
| `Modules/Services` · `Modules/Plans` | definitions and their catalogs; `Resources/Services/<id>.json`, `Resources/Plans/<id>.json` |
| `Modules/Limits` | `Limit`, `Usage`, `Pace`, `Level`. Pure |
| `Modules/Analytics` · `Billing` · `Alerts` · `Storage` | the outside, behind `@Mockable` ports (`AnalyticsAPI`, `BillingAPI`, `Notifier`, `TokenVault`, `SettingsStore`) |
| `Modules/Monitor` | `Account`, the root the views read |
| `Sources/App` | SwiftUI views (AgentNexus's Pop theme) and the composition root |

- **No ViewModel or AppState layer.** Views read `Account` directly, render and tell; they never compare, count or price.
- **A limit counts the whole account.** The Worker focus narrows breakdowns only (model law 1).
- **Read-only.** No port has a call that changes anything on Cloudflare.

## Design docs are the source of truth

The design leads; code follows it. Before any change, in this order:

1. **Read the design, in order** ([the map](docs/architecture/ARCHITECTURE.md)): [USER_JOURNEYS](docs/architecture/USER_JOURNEYS.md), [CANONICAL_MODEL](docs/architecture/CANONICAL_MODEL.md), [TARGET_ARCHITECTURE](docs/architecture/TARGET_ARCHITECTURE.md), [MODULAR_DESIGN](docs/architecture/MODULAR_DESIGN.md), [ENGINE_DESIGN](docs/architecture/ENGINE_DESIGN.md).
2. **Place the change in it.** Which node owns it? Which law (CANONICAL §5) does it keep? Think how the domain should be, from the person's problem rather than the type you are editing, for every change, a fix too: names the person would say, each thing deciding about itself, every state visible, nothing bigger than it needs, what differs between services and plans as data → [domain-shape.md](.claude/skills/implement-feature/references/domain-shape.md).
3. **Write the design change first** when the docs don't say it or say otherwise. Code that disagrees with the docs is behind.
4. **Ask the person to confirm the design** before writing code.
5. **Implement to the doc.** SRP: a type changes for one reason. OCP: a new product, plan or case is data or a new case, never an edit to a neighbour.
6. **Ship the docs with the code**, and update [status.md](docs/status.md) when a slice lands.

UI changes come with a mockup in `design-concept/` first.

## TDD is the default

- Write the failing test first. Swift Testing (`@Suite`, `@Test`, `#expect`) with Mockable for ports.
- **Chicago school**: assert on resulting state and return values; stub dependencies, never `verify()` calls.
- **Name a test for the behaviour it guards**: `` `should <outcome> [when <situation>]` `` in the person's words → [Naming tests](.claude/skills/implement-feature/references/tdd-patterns.md#naming-tests).
- Time is an argument (`at: Date`), never `Date()` inside a domain type, so periods and pace are testable.

## Privacy and logging

- **Never log, store outside the Keychain, or commit a token**, an `Authorization` header, an account ID or an invoice. Fixtures use placeholders.
- Use `AppLog.<category>` (`monitor`, `analytics`, `billing`, `alerts`). Log that something happened, never what it carried. A refusal logs its HTTP status and the path's first word: `log show --last 1h --predicate 'subsystem == "com.tddworks.overmind"'`.
- Live checks against a real account run only with `TEST_RUNNER_OVERMIND_LIVE_TOKEN` (and `…_LIVE_ACCOUNT` for Analytics) set; they print numbers, never ids.
- Screenshots come from demo data only: `OVERMIND_DEMO=1 OVERMIND_SNAPSHOT_DIR=$PWD/design-concept/screenshots <app>/Contents/MacOS/Overmind`.

## Gotchas

- In a `@MainActor` suite, mark Mockable's `willProduce` **and** `.matching` closures `@Sendable` (as in AgentNexus).
- Free allowances reset at 00:00 UTC, not local midnight; Paid ones on the subscription's renewal date.
- No `TimelineView` in the `MenuBarExtra` label: it makes the label update in a loop and the app hangs. The label redraws when `Account` changes.
- `ImageRenderer` draws a `SecureField` as a placeholder block: the Connect screenshot shows it so; the real field is fine.
- D1 datasets filter by `date`, Workers datasets by `datetime` ([ENGINE §2](docs/architecture/ENGINE_DESIGN.md#2--read--how-a-limits-number-is-found)).

## Releasing

- Tag `vX.Y.Z` and push: `.github/workflows/release.yml` tests, builds a universal app, signs, notarizes, publishes the DMG and ZIP, promotes `[Unreleased]` and updates `docs/appcast.xml` → [docs/release/RELEASE_SETUP.md](docs/release/RELEASE_SETUP.md).
- `docs/appcast.xml` is Sparkle's live feed. Never move or hand-edit it.
- The app icon is drawn by `swift scripts/make-app-icon.swift` from the logo, `design-concept/logos/overmind-cloud-eye-concept.png`; change the logo or the script, never the icon PNGs.

## When you are…

- adding a feature → `implement-feature` skill
- adding a Cloudflare product → `add-service` skill
- fixing a bug → `fix-bug` skill
- improving existing behaviour → `improvement` skill

---
name: implement-feature
description: |
  Guide for implementing features in Overmind following architecture-first design, TDD, rich domain models, and Swift 6.2 patterns. Use this skill when:
  (1) Adding new functionality to the app
  (2) Creating domain models that follow the person's mental model
  (3) Building SwiftUI views that consume domain models directly
  (4) User asks "how do I implement X" or "add feature Y"
  (5) Implementing anything that spans modules (Limits, Analytics, Billing, Alerts, Monitor …) and the App
---

# Implement Feature in Overmind

Adapted from ClaudeBar's and AgentNexus's skill of the same name; the method is the same.

```
0. ARCHITECTURE DESIGN (user approval)  →  1-3. TDD (Chicago school)  →  docs + status
```

## Phase 0: Architecture Design (MANDATORY)

Read in order ([ARCHITECTURE.md](../../../docs/architecture/ARCHITECTURE.md) maps it):
[USER_JOURNEYS](../../../docs/architecture/USER_JOURNEYS.md) (the person and the moment),
[CANONICAL_MODEL](../../../docs/architecture/CANONICAL_MODEL.md) (the tree, the words, each law and its owner),
[TARGET_ARCHITECTURE](../../../docs/architecture/TARGET_ARCHITECTURE.md) (pieces and flows),
[MODULAR_DESIGN](../../../docs/architecture/MODULAR_DESIGN.md) (modules),
[ENGINE_DESIGN](../../../docs/architecture/ENGINE_DESIGN.md) (cases). Then answer:

| Question | If yes |
|---|---|
| Does a service or plan need something its file can't say? | a **new case** (read, allowance, price, breakdown), written into ENGINE_DESIGN first. Never a Swift line that names a product |
| Does it read Cloudflare? | it joins the one `ReadPlan` query, or says why it can't (ENGINE §2) |
| Could it touch the token or an invoice? | it keeps CANONICAL laws 15–16: Keychain only, nothing logged, no write call |
| Is it a choice or a reading? | choices go to `settings.json`, readings stay in memory (CANONICAL §2) |
| Is a law missing, or owned twice? | add it to CANONICAL §5 with **one** owner |

### Think the domain first

Before components, ask how the domain should be: from the person's problem (the issue,
the journey) to the facts it must respect, to the concepts those force, then compare with
the code. Ask the five questions of every type the feature touches (would the person say
it, does the thing decide about itself, can you see every state, is it as small as it can
be, is what differs data) and draw now beside proposed →
[references/domain-shape.md](references/domain-shape.md). A new node, a moved law or a
changed owner goes into the docs change below.

Write the change into the docs first, then present it: an ASCII diagram in the module
words ([references/architecture-diagrams.md](references/architecture-diagrams.md)) and a
table (component · purpose · inputs · outputs · dependencies). Ask with AskUserQuestion,
"Approve" / "Modify". Do NOT proceed until the user approves. When the user has already
approved the docs and asked for a slice from [status.md](../../../docs/status.md), the docs
are the approved design: say which slice you build.

## Core principles

### Rich domain models — a rule lives on the node that holds its data

```swift
public struct Limit: Sendable, Equatable {
    public let definition: LimitDefinition
    public let allowance: Allowance
    public private(set) var usage: Usage?

    // The person asks: "how close am I?" — nil when there's no reading for this period
    public func percent(at now: Date) -> Percent? { … }
    public func level(at now: Date) -> Level? { … }
    public func pace(at now: Date) -> Pace? { … }

    // The refresh tells it what Cloudflare said; it decides whether that counts (law 7)
    public mutating func record(_ reading: Usage) { … }
}
```

### Swift 6.2 — no ViewModel layer

Views read `Account` directly ([references/swift-observable.md](references/swift-observable.md)).

The patterns, on Overmind's own types (a type answers the person's questions, tell don't ask,
a case per state, values over classes, what differs is data) →
[references/domain-models.md](references/domain-models.md).

### Ports are `@Mockable`, at the module's root; implementations are `internal`

```swift
@Mockable
public protocol Analytics: Sendable {
    func read(_ query: AnalyticsQuery) async throws(AnalyticsError) -> AnalyticsAnswer
}
```

## Where things go

| Where | Holds | Tests |
|---|---|---|
| `Modules/Services/Resources/Services/<id>.json` | every Cloudflare product | `Modules/Services/Tests/` (one definition test each) |
| `Modules/Plans/Resources/Plans/<id>.json` | every plan | `Modules/Plans/Tests/` |
| `Modules/Measures/Sources` | the kernel | `Modules/Measures/Tests/` |
| `Modules/Limits/Sources` | `Limit`, `Usage`, `Pace`, `Level` (pure) | `Modules/Limits/Tests/` |
| `Modules/<Context>/Sources/Internal` | the implementation of that module's ports | that module's `Tests/` |
| `Modules/Monitor/Sources` | `Account`, `Connection`, `Refresher` | `Modules/Monitor/Tests/` |
| `Sources/App` | SwiftUI views, the composition root | — |

## TDD (Chicago school)

Name each test `should <outcome> [when <situation>]` → [Naming tests](references/tdd-patterns.md#naming-tests).
Assert on state and return values; stubs answer, never `verify()`.

```swift
@Suite
struct PaceTests {
    @Test func `should say the day ends at 48% when a fifth of the allowance went in the first ten hours`() {
        // Given
        var limit = Limit(.acmeWidgets, allowance: .perDay(100))
        limit.record(Usage(used: 20, period: .day("2026-10-09"), readAt: .utc("2026-10-09T10:00")))

        // When
        let pace = limit.pace(at: .utc("2026-10-09T10:00"))

        // Then
        #expect(pace?.atPeriodEnd == Percent(48))
    }
}
```

```bash
tuist test Limits            # one module while working
xcodebuild test -workspace Overmind.xcworkspace -scheme Overmind-Workspace \
  -destination 'platform=macOS,arch=arm64'   # the final check
```

## Checklist

- [ ] Read the five design docs; placed it: owner, law, module
- [ ] Thought the domain first: the five questions asked of touched types, now/proposed drawn ([domain-shape.md](references/domain-shape.md))
- [ ] Design change written into the docs; **user approval** before code
- [ ] Failing test first, asserting STATE; minimal code; refactor
- [ ] No Swift names a Cloudflare product, dataset or price
- [ ] Ports `@Mockable`, implemented in `Internal/`; time passed in, never `Date()` in the domain
- [ ] Views render and tell only
- [ ] Nothing logs or stores the token outside the Keychain
- [ ] Docs, `status.md` and a CHANGELOG line updated; full `xcodebuild test` green

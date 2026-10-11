# Rich domain model patterns

The basic patterns, shown on Overmind's own types. Before any change, think how the domain should be: [domain-shape.md](domain-shape.md) (five questions for a domain easy to understand).

The aim of every pattern here is **less to hold in your head**. Someone reading `Limit` should be able to say what it is, what it answers and what it can be told, in the person's words, without opening another file.

## A type answers the person's questions

Each public member is a question the person asks, named the way they'd ask it, with time passed in:

```swift
/// One thing counted against the plan: a card in *Every limit today*.
public struct Limit: Sendable, Equatable, Identifiable {
    public let definition: LimitDefinition
    public let allowance: Allowance
    public private(set) var usage: Usage?

    // "How much have I used?"           nil with no reading for this period
    public func percent(at now: Date) -> Percent? { … }
    // "Should I worry?"                  OK · WATCH · ACT NOW (law 2, law 3)
    public func level(at now: Date) -> Level? { … }
    // "Where will I end up?"             nil in the period's first hour (law 6)
    public func pace(at now: Date) -> Pace? { … }
}
```

- **The doc comment says what the screen prints**, in italics: `/// *OK · WATCH · ACT NOW*`. Reading the type is reading the screen.
- **Name the law it keeps** (`(law 7)`), so the owner is findable from CANONICAL §5 and back.
- **`at now: Date`, never `Date()`** inside a domain type. It keeps the type pure and the test one line.

## Tell, don't ask

The caller hands over a fact; the type decides what it means. No caller reads the state and decides for it:

```swift
// The refresh tells it what Cloudflare said; it keeps the reading only if it is newer
// and not from an earlier period (law 7).
public mutating func record(_ reading: Usage) {
    guard usage.map({ $0.isSuperseded(by: reading) }) ?? true else { return }
    usage = reading
}

// NOT at the caller:
// if reading.readAt > limit.usage?.readAt ?? .distantPast { limit.usage = reading }
```

A rule that needs data from several nodes lives on the node that holds them all: `Account.closest(at:)` compares limits, so neither the menu bar nor Today ever compares percents.

## Enums for states, each state a case

A finite set of states the person can meet is an enum, and the rule that picks the case lives on it:

```swift
/// *OK · WATCH · ACT NOW* (CANONICAL law 2).
public enum Level: Sendable, Equatable, Comparable {
    case ok, watch, actNow

    public init(_ percent: Percent) { … }   // the thresholds live here, and only here
}

public enum Freshness { case live, stale, refused, never }       // not a Date? each view reads
public enum Allowance { case perDay(Quantity), perMonth(Quantity), perInvocation(Quantity), total(Quantity) }
```

- **One value never means two things.** If `nil`, `""` or `0` could mean both *not read yet* and *nothing there*, it's two cases ([domain-shape §3](domain-shape.md#five-questions)).
- **`Comparable` when the person ranks them**: the worst level is `levels.max()`.
- **No colours, fonts or glyphs in the domain.** The view maps `Level` to coral or butter; the domain says *act now*.

## Values for data, one class for what changes

| Shape | When | Overmind |
|---|---|---|
| `struct` | data with rules, compared by value | `Limit`, `Usage`, `Pace`, `Focus`, `Percent`, `Money`, `Period` |
| `enum` | a closed set of states or kinds | `Level`, `Allowance`, `Price`, `Read`, `Freshness` |
| `@MainActor @Observable final class` | the one thing that changes over time and that views watch | `Account` |
| `protocol` (`@Mockable`) | the outside world only | `AnalyticsAPI`, `BillingAPI`, `Notifier`, `TokenVault`, `SettingsStore` |

A new class or protocol inside the domain needs a reason the table doesn't already give. No managers, no services-of-services, no ViewModel.

## What differs is data, not code

A Cloudflare product or plan is a definition read from JSON. A difference between products is a field, or a generic case every definition gains, never a `switch` on an id:

```swift
// A plan without an allowance for a limit doesn't show it: the plan answers nil.
guard let allowance = plan.allowance(for: definition.id) else { return nil }

// A per-invocation allowance doesn't run out; the Allowance case says so, not "is this CPU?"
public var runsOut: Bool {
    if case .perInvocation = allowance { return false }
    return true
}
```

## Kernel values carry their unit

`Quantity`, `Money`, `Percent` and `Period` come from `Measures`. A number that has a unit is never a `Double` or `Int`: `"5M rows"` parses into a `Quantity`, a reset is a `Period`, a price is `Money`. The compiler then refuses rows compared to milliseconds.

## Factories, one per module

Construction that reads a bundle or builds a port lives on the module's factory enum, so callers never see `Internal/`:

```swift
let services = try ServiceCatalog.builtIns()          // every Resources/Services/*.json
let day = Period.day(containing: now)                 // 00:00 UTC to 00:00 UTC
let month = Period.month(containing: now, renewsOn: renewal)
```

## Checklist for a type you add or touch

- [ ] Its doc comment quotes what the screen prints
- [ ] Every public member answers a question the person asks, or is a command they'd give
- [ ] Each state is a case; no `nil` or `""` with two meanings
- [ ] Time comes in as `at:`; units are `Measures` values
- [ ] No product id, dataset or Cloudflare number in Swift
- [ ] No colour or wording choice that belongs to the view

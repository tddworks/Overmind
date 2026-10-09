# TDD Test Patterns (Chicago School)

| Chicago School (We Use This)          | London School (Avoid)                    |
|---------------------------------------|------------------------------------------|
| Test state changes and return values  | Test interactions between objects        |
| Mocks stub data, not verify calls     | Mocks verify method calls were made      |
| Focus on "what" (outcomes)            | Focus on "how" (behavior)                |
| Design emerges from tests             | Design upfront, tests verify design      |

## Swift Testing

Use `@Test` and `@Suite`, not XCTest:

```swift
import Testing
@testable import Limits

@Suite
struct LevelTests {
    @Test func `should ask the person to act when a limit is nine-tenths used`() {
        var limit = Limit(.acmeWidgets, allowance: .perDay(100))
        limit.record(Usage(used: 90, period: .day("2026-10-09"), readAt: .utc("2026-10-09T12:00")))
        #expect(limit.level(at: .utc("2026-10-09T12:00")) == .actNow)
    }
}
```

## Naming tests

A test name is the behaviour it guards, as one sentence in a backtick identifier:

```
should <outcome the person / menu bar / warning observes> [when <situation in the world>]
```

- **Say what the person gets, not which code runs.** The actors are the person, the menu
  bar, a card, a warning, the bill. The name never holds a method or type name (`pace`,
  `ReadPlan`), a JSON key (`perDay`), or a mechanism verb (`returns`, `parses`, `maps`).
- **The `when` is a fact about the world**: "when the UTC day has just turned", not
  "when `period != usage.period`".
- **Pair every happy path with its counterpart.** "should warn at 75%" travels with
  "should not warn twice when reads dip under 75% and cross it again".

| Mechanism-shaped (avoid) | Business-shaped |
|---|---|
| `percent returns 18 for 912k of 5M` | `should show 18% when 912k of a 5M daily allowance is read` |
| `pace is nil before one hour` | `should say it's too early to tell in the first hour of the day` |
| `alerts dedupes by key` | `should not warn twice when reads cross 75% again the same day` |
| `json decodes allowances` | `should know the Free plan allows 5M D1 rows read a day` |

## Given-When-Then

```swift
@Test func `should not warn twice when reads cross 75% again the same day`() {
    // Given
    let alerts = Alerts(levels: [75], notifier: …)
    _ = alerts.check([limit(at: 76)], at: noon)

    // When
    let warnings = alerts.check([limit(at: 77)], at: noon + .hours(1))

    // Then
    #expect(warnings.isEmpty)
}
```

## Mocking with @Mockable (Chicago style)

Stub what the port answers; assert on the resulting state:

```swift
@Test func `should keep the last reading and say stale when Cloudflare can't be reached`() async {
    // Given
    let analytics = MockAnalytics()
    given(analytics).read(.any).willThrow(.unreachable)
    let account = Account.fixture(analytics: analytics, lastRead: .utc("2026-10-09T12:00"))

    // When
    await account.refresh(at: .utc("2026-10-09T12:20"))

    // Then — STATE, not calls
    #expect(account.connection.freshness(at: .utc("2026-10-09T12:20")) == .stale)
    #expect(account.closest?.usage?.used == 912_000)
    // ❌ AVOID: verify(analytics).read(.any).called(1)
}
```

## Definition tests

A built-in service or plan is tested through its **real JSON**:

```swift
@Test func `should know the Free plan allows 5M D1 rows read a day`() throws {
    let free = try PlanCatalog.builtIn("free")
    #expect(free.allowance(for: "d1.rowsRead") == .perDay(Quantity(5_000_000, .rows)))
}
```

## Fixtures

Recorded GraphQL and REST answers live in `Modules/<X>/Tests/Fixtures/`. Replace the account
ID, names, emails and invoice numbers with placeholders before committing.

## Red-Green-Refactor

```
1. RED      - a failing test that asserts expected STATE
2. GREEN    - minimal code to pass
3. REFACTOR - improve while green
```

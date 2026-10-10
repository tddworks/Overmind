# Swift 6.2 @Observable Patterns

## @Observable, isolated to the main actor

```swift
@MainActor @Observable
public final class Account {
    public private(set) var connection: Connection
    public private(set) var services: [Service]
    public var focus: Focus
    public let alerts: Alerts

    public var closest: Limit? { … }            // derived, never stored
    public func refresh(at now: Date) async { … }  // a command the Refresher tells
}
```

Never `ObservableObject` / `@Published`.

## No ViewModel layer

Views consume the domain directly, and tell it what happened:

```swift
struct LimitCard: View {
    let limit: Limit
    let now: Date
    var body: some View { … limit.level(at: now) … }   // draws the level; never computes it
}
```

## @State owns the root

```swift
@main
struct OvermindApp: App {
    @State private var account: Account     // built in init(), the composition root
    var body: some Scene {
        MenuBarExtra { PopoverView(account: account) } label: { MenuBarLabel(account: account) }
            .menuBarExtraStyle(.window)
    }
}
```

## Time is an argument

Periods, pace and freshness depend on the clock. Domain types take `at now: Date`;
only `Refresher` and the views (through `TimelineView`) read the clock.

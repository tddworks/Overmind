# Think the domain first

Before any change, a fix too, ask how the domain should be, not only where the line fits. The aim is a domain that is **easy to understand**: someone new reads a type's public surface and can explain it in the person's words. We borrow from DDD only what serves that; no pattern is added for its own sake.

Adapted from ClaudeBar's reference of the same name. The tree, the words and each law's owner are in [CANONICAL_MODEL](../../../../docs/architecture/CANONICAL_MODEL.md); the cases a definition can use in [ENGINE_DESIGN](../../../../docs/architecture/ENGINE_DESIGN.md).

## Five questions

**1. Would the person say it?**
Names come from the screen and the person ([USER_JOURNEYS §4](../../../../docs/architecture/USER_JOURNEYS.md#4--the-words-the-screens-print), [CANONICAL §0.1](../../../../docs/architecture/CANONICAL_MODEL.md)), never from the mechanism. Start from their problem: if the facts need a concept the code doesn't have, it is hiding somewhere as optionals, a flag or an empty string. *`Allowance`, not quota: Cloudflare's pages say "limits" and "included", and quota is ClaudeBar's word for something else.*

**2. Does the thing decide about itself?**
A rule lives on the node that holds its data; callers tell it, they don't read its state and decide. *`Limit.record(_:)` decides whether a reading counts (law 7); `Account.closest(at:)` picks the headline, so the menu bar and the Today header never compare percents themselves.*

**3. Can you see every state?**
Each state the person can meet is a case, carrying its data; one value never means two things. *`Freshness` is `never · live · stale · refused`, not a `Date?` each view interprets.*

**4. Is it as small as it can be?**
A plain value when it is data with rules; a class only when it changes over time; a protocol only at the outside world (Cloudflare, the Keychain, settings, notifications), so tests can stub it. No type, layer or flag the change doesn't need. *`Focus` is a value (a dimension and a value, or `.everything`); no `FocusManager`.*

**5. Is what differs between services and plans data?**
A field in the service or plan file, or a generic case every definition gains ([ENGINE_DESIGN](../../../../docs/architecture/ENGINE_DESIGN.md)); never a `switch` on a service id or a Swift line naming a product, dataset or number Cloudflare can change. *A plan without an allowance for a limit doesn't show that limit: `plan.allowance(for:)` returns `nil`, and no code asks "is this Free?".*

## An example: the menu bar that can't say why it's blank

An issue asks to hide *CPU time 10%* from the menu bar. A fix at the view (a toggle in `MenuBarLabel`) would work, but asking the five questions of `MenuBarState` first finds a shape that would make that toggle a guess.

```swift
// NOW (Modules/Monitor/Sources/Account.swift)
/// *D1 18%* and its level; the account's name before the first read.
public func menuBar(at now: Date) -> MenuBarState {
    guard let closest = closest(at: now), let percent = closest.percent(at: now)
    else { return MenuBarState(text: "", level: .ok) }      // "": not read yet, OR nothing on the plan runs out
    …
}

// the view (Sources/App/MenuBarLabel.swift)
case (.connected, _): Text(state.text.isEmpty ? "☁" : "☁ \(state.text)")   // which empty?
```

| Question | What it finds |
|---|---|
| 1. Would the person say it? | Yes: *D1 18%* is what USER_JOURNEYS journey 4 prints. Keep the words |
| 2. Does the thing decide about itself? | Mostly: `Account` picks the limit. But the view decides what `""` means |
| 3. Can you see every state? | No: `""` covers *not read yet* and *nothing runs out*, and the doc comment promises a third (the account's name) that the code never returns |
| 4. Is it as small as it can be? | A small enum is enough; no new type for the label, no flag on the view |
| 5. Is what differs data? | Yes already: `short` comes from the limit's definition |

```swift
// PROPOSED: the states the person meets, each one a case
public enum MenuBarState: Equatable {
    case notReadYet
    case nothingRunsOut
    case closest(short: String, percent: Percent, level: Level)
}

// the view draws each state; the person's choice of *icon only* becomes one more input, not a guess
```

Since it changes what the menu bar says, it goes into USER_JOURNEYS and CANONICAL (`menuBar: MenuBarState`) first.

## Keep it in scope

- Fix what these questions find **in the types the change touches**, test first. Leave the rest for its own change.
- A new node, a moved law or a changed owner is a design change: the docs first, confirmed before code ([AGENTS.md](../../../../AGENTS.md#design-docs-are-the-source-of-truth)).
- A new Cloudflare product is question 5 by default: a JSON file, or a new ENGINE case proposed first ([add-service](../../add-service/SKILL.md)).
- When it isn't obvious, draw now beside proposed as a few lines of ASCII:

```
 NOW                                   PROPOSED
 Account                               Account
  └─ limits ← every service             ├─ watching: [Service.ID]   a choice, in settings.json
                                        └─ limits ← watched services only
```

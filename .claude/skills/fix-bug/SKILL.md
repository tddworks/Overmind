---
name: fix-bug
description: |
  Guide for fixing bugs in EdgeMeter following Chicago School TDD and rich domain design. Use this skill when:
  (1) User reports a bug or unexpected behavior
  (2) Fixing a defect in existing functionality
  (3) User asks "fix this bug" or "this doesn't work correctly"
  (4) Correcting behavior that violates the person's mental model
---

# Fix Bug in EdgeMeter

```
1. REPRODUCE & UNDERSTAND  →  2. WRITE FAILING TEST (Red)  →  3. FIX & VERIFY (Green)
```

## Phase 1: Reproduce & Understand

1. **Reproduce**: the exact steps.
2. **Expected**: what SHOULD happen, as the person sees it ([USER_JOURNEYS](../../../docs/architecture/USER_JOURNEYS.md)).
3. **Actual**: what IS happening.
4. **Root cause**: WHY, in the code.

For a number that looks wrong:
- **Compare with the dashboard** for the same account, period and focus. Cloudflare's
  analytics lag; a gap of a few minutes is not a bug.
- **Record the GraphQL or REST answer** and replace the account ID, names, emails and any
  invoice with placeholders before it becomes a fixture. Never log the token while
  investigating.

### Find the law it breaks

A bug is usually a law in [CANONICAL_MODEL.md §5](../../../docs/architecture/CANONICAL_MODEL.md#5--the-laws-on-the-node-that-owns-them)
that the code breaks. Find the law and its **one owner**, and fix it there, not at a call
site. If the right fix changes a law or moves it, that is a design change: update the doc and
ask the user to confirm first. If no law covers it, propose the law first.

### Locate in the modules

The map is [implement-feature → Architecture](../implement-feature/SKILL.md#architecture).
A wrong dataset, field or price is fixed in its service or plan file, or generically in the
module that owns the case. Never with a Swift branch on a service id.

## Phase 2: Write Failing Test (Red)

Name it `should <correct outcome> when <the situation that showed the bug>` →
[Naming tests](../implement-feature/references/tdd-patterns.md#naming-tests).
Chicago school: assert on state, stub ports, no `verify()`.

```swift
@Test func `should not show yesterday's reads as today's when the day has just turned`() {
    // Given — a limit read at 23:58 UTC
    var limit = Limit(.acmeWidgets, allowance: .perDay(100))
    limit.record(Usage(used: 90, period: .day("2026-10-08"), readAt: .utc("2026-10-08T23:58")))

    // When — it is now the next UTC day
    let now = Date.utc("2026-10-09T00:03")

    // Then — the CORRECT behavior (fails before the fix)
    #expect(limit.percent(at: now) == nil)
}
```

Run it and watch it fail: `tuist test <Module>`.

## Phase 3: Fix & Verify (Green)

1. **Minimal change**, at the law's owner.
2. **A product or plan is data**: its JSON, or a generic case every definition gains.
3. **The owner stays self-validating**: tell, don't ask.
4. **No unrelated refactors.**

Then run the full suite:
`xcodebuild test -workspace EdgeMeter.xcworkspace -scheme EdgeMeter-Workspace -destination 'platform=macOS,arch=arm64'`.

## Checklist

- [ ] Bug reproduced; the law it breaks and its owner found
- [ ] Failing test written, FAILS before the fix
- [ ] Minimal fix at the owner; test PASSES
- [ ] All tests pass
- [ ] No token, account ID or invoice in any fixture or log
- [ ] The service's `design.md` or ENGINE §6 updated where someone would look
- [ ] One line under `## [Unreleased]` in `CHANGELOG.md` for a change the person notices

---
name: improvement
description: |
  Guide for making improvements to existing Overmind functionality using TDD. Use this skill when:
  (1) Enhancing existing features (not adding new ones)
  (2) Improving UX, performance, or code quality
  (3) User asks "improve X", "make Y better", or "enhance Z"
  (4) Small enhancements that don't require full architecture design
  For NEW features, use implement-feature instead.
---

# Improve Overmind

| Scenario | Skill |
|---|---|
| Enhance existing behavior | **improvement** (this skill) |
| Fix broken behavior | fix-bug |
| Add a new feature | implement-feature |
| Add a Cloudflare product | add-service |

```
0. CHECK THE DESIGN → 1. UNDERSTAND CURRENT STATE → 2. TEST THE IMPROVED BEHAVIOR (Red) → 3. IMPLEMENT (Green)
```

## Phase 0: Check the design

Read [USER_JOURNEYS](../../../docs/architecture/USER_JOURNEYS.md),
[CANONICAL_MODEL](../../../docs/architecture/CANONICAL_MODEL.md) and
[TARGET_ARCHITECTURE](../../../docs/architecture/TARGET_ARCHITECTURE.md). An improvement
that only makes the code match the docs needs no approval. One that changes a law, its owner,
a word the screen prints, or adds a piece is a design change: write it into the docs and ask
the user to confirm before coding.

## Kinds of improvement

| Kind | Examples | Test approach |
|---|---|---|
| UX | a clearer warning, a calmer menu bar | a mockup in `design-concept/` first; views render and tell |
| Domain | a rule a view worked out moves onto its owner | state tests on the owner |
| Definition | a service's breakdown, a plan's price | its definition test, through the real JSON |
| Reads | fewer queries, less lag | `ReadPlan` tests on recorded answers |

Never put a rule in a view, never name a Cloudflare product in Swift, never log a token.

## TDD (Chicago school)

Name it `should <improved outcome> [when <situation>]` →
[Naming tests](../implement-feature/references/tdd-patterns.md#naming-tests). Keep existing
tests green: `tuist test <Module>`, then the full `xcodebuild test`.

## Checklist

- [ ] Design checked; doc changed and confirmed if a law/word/piece changed
- [ ] Test for the improved behavior written and FAILS first
- [ ] Improvement implemented; all tests pass
- [ ] Docs and a CHANGELOG line for a change the person notices

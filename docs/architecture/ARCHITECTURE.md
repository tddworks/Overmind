---
description: The map of Edge Meter's design. Five documents are read in order, from the person's question to how each case runs, and this map says which one to open for a change. Start here before any design or code change.
---

# Edge Meter — architecture

Edge Meter is a macOS menu bar app that watches a Cloudflare account's
usage and bill: the limit closest to running out, a warning before it does,
where the use came from, and what the month costs. It reads with a read-only
token and never changes anything. It is ClaudeBar's and AgentNexus's sibling,
and shares their design method, their JSON-definition approach and
AgentNexus's Pop theme.

Its design is five documents. **Each answers a question that only exists
once the one before it is answered**, so they are read in order. A later one
may cite an earlier one, never the reverse.

| # | Document | Answers |
|---|---|---|
| 1 | [USER_JOURNEYS.md](USER_JOURNEYS.md) | **Who is asking, and what?** The people, the moments, the words each screen prints |
| 2 | [CANONICAL_MODEL.md](CANONICAL_MODEL.md) | **What is true?** The tree, each law and its one owner |
| 3 | [TARGET_ARCHITECTURE.md](TARGET_ARCHITECTURE.md) | **How does it run?** The pieces, each with one job, and the flows |
| 4 | [MODULAR_DESIGN.md](MODULAR_DESIGN.md) | **Where does the code live?** The modules and what each may import |
| 5 | [ENGINE_DESIGN.md](ENGINE_DESIGN.md) | **How does each case work?** Reads, allowances, prices, breakdowns, and Cloudflare's APIs as verified |

**The mockup** for every screen named here:
[design-concept/edgemeter-pop.html](../../design-concept/edgemeter-pop.html).

## Why this order

ClaudeBar's reasoning applies unchanged
([its map](https://github.com/tddworks/ClaudeBar/blob/main/docs/architecture/ARCHITECTURE.md#why-this-order)).
Everything answers a person. Each step needs the one before it. Change flows
downhill. **One home per fact.**

## The one idea

**A Cloudflare product is a JSON file, and so is a plan.** A service file says
what is counted and where the number sits in Cloudflare's analytics; a plan
file says how much is included and what the rest costs. One `ReadPlan` reads
every limit in one query. When Cloudflare changes a price, a plan file changes;
when someone wants KV or R2, a service file is added. No Swift names either.

## Where a change starts

| You are… | Start at | Then |
|---|---|---|
| fixing a bug or reviewing a PR | #1: which moment breaks, for whom? | the law (#2), its owner (#3) |
| adding a feature or a screen | #1, with a mockup in `design-concept/` | #2 → #3 |
| adding a Cloudflare product | a similar service file | #5 for the reads and breakdowns it can use |
| Cloudflare changed a limit or a price | the plan file | #5 §6, the verified table |
| adding a read, allowance, price or breakdown case | #5 | #2 if it needs a new law |
| adding a file, type or module | #4 | #3 for the piece it belongs to |

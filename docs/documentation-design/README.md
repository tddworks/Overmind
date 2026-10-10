---
description: How Overmind's docs are layered and where each kind of content lives. It adopts ClaudeBar's documentation design and records only what differs. Read before adding or restructuring any doc.
---

# Documentation Design

> Adopted from [ClaudeBar's documentation design](https://github.com/tddworks/ClaudeBar/blob/main/docs/documentation-design/README.md),
> as AgentNexus did. This file holds **only what Overmind does differently**.

## Goal

Each fact has one home, so a code change touches at most one doc. When choosing
between two options, pick the one where *the next change touches fewer places*.

## What differs

| Topic | ClaudeBar | Overmind | Why |
|---|---|---|---|
| Units of docs | providers, then features | **services, then features** | A service (`d1`, `workers`) is what drifts with Cloudflare |
| A service `design.md` covers | — | its datasets and fields as found by introspection, what the dashboard shows that the API doesn't | the code can't explain Cloudflare's schema |
| Prices and limits | — | live in plan files and [ENGINE §6](../architecture/ENGINE_DESIGN.md#6--cloudflare-as-verified-2026-10-09) only, with the date they were checked | a number written twice drifts |
| Privacy in docs | no real names, emails or usage | **also no account ID, token or invoice** in a doc, screenshot or fixture | the app reads a billing account |

## Layout

```
README.md · AGENTS.md · CHANGELOG.md   tier 1
design-concept/                        HTML mockups
docs/
├── README.md                          the index
├── architecture/                      the five design documents; ARCHITECTURE.md is their map
├── status.md                          what's built, test counts, the next slice
├── services/<id>/                     README.md (+ design.md), once a service has something to say
└── features/<x>/                      README.md + design.md, once a feature does
```

**Nothing empty.** A folder appears only when its first file has something to say.

## Update rules

| Change | Touch |
|---|---|
| New service | its `Resources/Services/<id>.json`, its allowances in each plan file, `docs/services/<id>/README.md`, one CHANGELOG line. **No Swift** |
| Cloudflare changed a limit or price | the plan file and ENGINE §6's table, with the date |
| New read, allowance, price or breakdown case | ENGINE_DESIGN first, confirmed, then code |
| A domain or design change | CANONICAL_MODEL / TARGET_ARCHITECTURE first, confirmed before code |
| A UI change | a mockup in `design-concept/` first |

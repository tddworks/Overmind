---
name: add-service
description: |
  Add a Cloudflare product (KV, R2, Queues, Durable Objects …) to Overmind as a JSON service file plus its allowances in each plan file. Use this skill when:
  (1) Someone wants Overmind to watch another Cloudflare product
  (2) Cloudflare changed a dataset, field, limit or price
  (3) User asks "how do I add a service" or "track X on Cloudflare"
---

# Add a Cloudflare service

A service is data. **No Swift changes** unless it needs a case ENGINE_DESIGN doesn't have.

## 1. Find the numbers

1. Cloudflare's pricing and limits pages for the product: each counted thing, its Free and
   Paid allowance, its overage price, when it resets.
2. The GraphQL dataset and fields: introspect the schema with a read-only token
   (`__type(name: "AccountTypes")`), then run one query over a day and compare with the
   dashboard. Note the time filter (`date` or `datetime`) and the focus dimension.
3. Record what you found, with the date, in ENGINE §6 and `docs/services/<id>/design.md`.

## 2. Check the cases

Every limit must be a `Read` case (`sum` · `max` · `quantile`), every allowance an
`Allowance` case, every price a `Price` case, every chart a `Breakdown` case
([ENGINE_DESIGN](../../../docs/architecture/ENGINE_DESIGN.md)). If one isn't, stop:
propose the new case in ENGINE_DESIGN and ask the user to confirm before code.

## 3. Write the files, test first

1. A definition test: *should know R2 counts Class A operations against the Free plan's 1M a month*.
2. `Modules/Services/Resources/Services/<id>.json`.
3. Its allowances (and prices) in **every** plan file under `Modules/Plans/Resources/Plans/`.
   A plan without an allowance for a limit doesn't show that limit.
4. A recorded GraphQL answer (account ID replaced) and an `AnswerReader` test that reads it.

## 4. Ship

- `docs/services/<id>/README.md`: what it watches, which token permission it needs.
- One README table row, one CHANGELOG line under `Added`.
- A mockup in `design-concept/` if the service gets a tab with a new kind of breakdown.

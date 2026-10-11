---
description: What the Bill tab says — this month's estimate, the forecast, the same month on the other plan, and invoices — and why invoices may be missing. Read when the bill looks wrong.
---

# Bill

- **This month · est.** — what the month has cost so far by the plan's prices. On Free it is always $0: Free stops at its limits instead of charging. When a service isn't watched (*Settings → Watching*), the estimate leaves it out and says so: *est. · Worker only*. R2 is an add-on: its lines join the Workers plan's, and a quote for the other Workers plan keeps R2. Workers AI's 10k neurons are a day's allowance even on Workers Paid, so its line charges each day's neurons past 10k, never the month's total.
- **Forecast** — the month at its pace.
- **If you upgraded** — first a verdict: *Free is enough*, or *Free stopped you on N days* (days a daily limit ran out). Then both plans for this month, and *This month on Workers Paid*: the subscription and one line per limit, so you see where each dollar would come from.
- **Upgrade on Cloudflare ↗** — opens Cloudflare's Workers plans page; Cloudflare takes the payment. Overmind never changes your plan; after you upgrade, the next look at the Bill tab shows Workers Paid.
- **Invoices** — need a token with **Billing: Read**. Once Cloudflare invoices the month, the invoice replaces the estimate.

Prices are in `Modules/Plans/Resources/Plans/*.json`, checked against Cloudflare's pricing on the date in [ENGINE §6](../../architecture/ENGINE_DESIGN.md#6--cloudflare-as-verified-2026-10-09).

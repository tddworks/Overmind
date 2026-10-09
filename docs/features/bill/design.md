---
description: Who prices the month (Plan.cost, Bill) and how the month's use is read. Read before changing the bill.
---

# Bill — design

- `Account.openBill(at:)` reads every priced limit over the billing month (kept limits, like storage, as they are) in one query.
- `Bill` holds the estimate (`plan.cost(of: monthToDate)`), the forecast (the month's pace, kept limits not stretched) and `issued`, an invoice dated inside the month (law 13).
- `Quote` is another plan's `cost(of:)` on the same projection (law 14), with `lines` from `Plan.lines(of:)` (law 20).
- `Bill.stopped` comes from `ReadPlan.daily`: the billing month's use per UTC day of each daily limit (law 19); `verdict` is derived from it.
- `openBill` re-reads the plan first (law 18), so the Bill and the limits follow an upgrade made on Cloudflare.
- The plan is picked from `/accounts/{id}/subscriptions` by each plan file's `matches`.

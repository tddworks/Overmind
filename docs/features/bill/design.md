---
description: Who prices the month (Plan.cost, Bill) and how the month's use is read. Read before changing the bill.
---

# Bill — design

- `Account.openBill(at:)` reads every priced limit over the billing month (kept limits, like storage, as they are) in one query.
- `Bill` holds the estimate (`plan.cost(of: monthToDate)`), the forecast (the month's pace, kept limits not stretched) and `issued`, an invoice dated inside the month (law 13).
- `Quote` is another plan's `cost(of:)` on the same projection (law 14).
- The plan is picked from `/accounts/{id}/subscriptions` by each plan file's `matches`.

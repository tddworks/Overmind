---
description: The Worker, D1, KV, Queues, R2, Workers AI, Vectorize, Durable Objects and AI Gateway tabs — the charts and lists each shows, the Worker focus, and the deployment pins. Read when a chart looks empty or different from the dashboard.
---

# Service tabs

| Tab | Shows |
|---|---|
| **Worker** | requests per hour today · invocations by outcome · cron runs · the Worker limits |
| **D1** | rows read per day (7 days) and per hour · top queries by rows read · the D1 limits |
| **KV** | reads per day (7 days) · operations by type · the KV limits. Only when KV is watched (*Settings → Watching*); Cloudflare keeps KV's analytics by day, so there is no per-hour chart |
| **Queues** | operations per hour today · operations by type (write, read, delete) · the Queues limit. Only when watched; the focus doesn't narrow it |
| **R2** | Class A and Class B per hour today · operations by type · the R2 limits, against R2's own free tier. Only when watched, and only on an account with an R2 subscription |
| **Workers AI** | neurons per hour today · top models by neurons · the neurons limit (10k a day on both plans) |
| **Vectorize** | queried dimensions per day (7 days) · top indexes · queried and stored dimensions |
| **Durable Objects** | requests per hour today · requests by outcome · requests, SQLite rows read and written, storage. The Worker focus narrows the request charts. GB-s duration isn't counted yet |
| **AI Gateway** | requests by model · tokens by model · requests by provider · errors by model, over the last 24 hours. Charts only: AI Gateway is free, so it has no limits, cards or warnings |

- **The focus** (*leaderboard ▾ · All Workers*) narrows the charts to one Worker. The limits never change: Cloudflare counts them across the account.
- **Pins** (*d605dc93*) mark when a version of the focused Worker went live.
- Charts are read when you open the tab and again after one refresh interval. Cloudflare's analytics can lag a few minutes.

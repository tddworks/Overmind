---
description: The Worker, D1 and KV tabs — the charts and lists each shows, the Worker focus, and the deployment pins. Read when a chart looks empty or different from the dashboard.
---

# Service tabs

| Tab | Shows |
|---|---|
| **Worker** | requests per hour today · invocations by outcome · cron runs · the Worker limits |
| **D1** | rows read per day (7 days) and per hour · top queries by rows read · the D1 limits |
| **KV** | reads per day (7 days) · operations by type · the KV limits. Only when KV is watched (*Settings → Watching*); Cloudflare keeps KV's analytics by day, so there is no per-hour chart |

- **The focus** (*leaderboard ▾ · All Workers*) narrows the charts to one Worker. The limits never change: Cloudflare counts them across the account.
- **Pins** (*d605dc93*) mark when a version of the focused Worker went live.
- Charts are read when you open the tab and again after one refresh interval. Cloudflare's analytics can lag a few minutes.

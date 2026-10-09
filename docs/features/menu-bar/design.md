---
description: Which node answers the menu bar, and why its label must not use a TimelineView. Read before changing the menu bar label.
---

# Menu bar — design

- `Account.menuBar(at:)` answers it: the text is `closest` (law 8), the level the worst `Limit.level` (laws 2–3).
- `MenuBarLabel` renders it and decides nothing.
- **No `TimelineView` in a `MenuBarExtra` label**: it makes MenuBarExtra update in a loop and the app
  hangs (seen 2026-10-09). The label redraws whenever `Account` changes, which every read does.

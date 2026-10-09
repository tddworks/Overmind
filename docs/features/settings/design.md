---
description: Where each setting is owned — Account (focus, interval), Alerts (levels), the system (login item), Sparkle (updates) — and how the window is opened from a menu bar app. Read before adding a setting.
---

# Settings — design

| Setting | Owner | Kept in |
|---|---|---|
| account, focus, interval | `Account` (law 17 for the interval) | `settings.json` |
| levels, pace, notify | `Alerts` via `Account` | `settings.json` |
| start at login | `LoginItem` (App), `SMAppService.mainApp` | the system |
| automatic checks | `Updater` (App), Sparkle | Sparkle's defaults |

- The window is SwiftUI's `Settings` scene, opened with `openSettings` after activating the app: a menu bar app is never frontmost on its own.
- `Settings` decodes a file without `interval` as 5 minutes, so older files keep working.

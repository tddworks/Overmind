---
description: Who decides a warning is new (Alerts, laws 9–10), where the once-only log lives, and how notifications are shown. Read before changing a warning.
---

# Warnings — design

- `Alerts.check(limits, at:)` returns only new warnings and marks them: the key is limit · mark (level, pace, stopped) · period start.
- The log is a choice-adjacent record, kept in `settings.json` (`sent`), so a relaunch never repeats a warning; entries older than 40 days are dropped.
- A refresh that jumps past two levels sends one warning, for the highest, and marks both.
- `Notifier` is the port; `UserNotifier` (Alerts/Internal) asks for permission on the first warning.

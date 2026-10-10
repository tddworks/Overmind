---
description: When Overmind sends a notification — at 50%, 75% and 90%, on pace, and when Cloudflare stopped Worker invocations — and how to change it. Read when you get too many or too few warnings.
---

# Warnings

| Warning | When | How often |
|---|---|---|
| *D1 rows read at 75%* | a limit crosses a level you chose (50, 75, 90) | once per limit, per level, per reset |
| *Pace: D1 rows read would cross 90% at 22:30 UTC* | today's rate would cross 90% before the reset | once per limit per reset |
| *CPU: 3 invocations stopped* | Cloudflare stopped invocations for going past the CPU allowance | once a day |

Change them in the popover's *Warn me at* card or in **Settings → Warnings**. Turning *Notify* off
sends nothing; turning a level off and on again doesn't re-send what was already sent.

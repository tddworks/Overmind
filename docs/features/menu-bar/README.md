---
description: What the menu bar shows — the limit closest to running out, as "☁ D1 18%", and its warning marks. Read when the menu bar says something you don't expect.
---

# Menu bar

| You see | Means |
|---|---|
| `☁` | not connected, or nothing read yet |
| `☁ D1 18%` | the limit closest to running out, and how much of it is used |
| `☁ ◐ D1 62%` | something is between 50% and 90%, or CPU ran past its allowance |
| `☁ ⚠︎ D1 91%` | something is at 90% or more, or Cloudflare stopped invocations |
| `☁ ⚠︎` | Cloudflare refused the token: open the popover to connect again |

**Icon only** (*Settings → General → Menu bar shows*): the bar never names a limit. It shows `☁`,
`☁ ◐` while something is at *WATCH*, and `☁ ⚠︎` at *ACT NOW* or when the token is refused.

The percent is the closest limit's; the mark is the worst level of any limit. CPU per invocation
never names the menu bar: it never runs out ([design](design.md)).

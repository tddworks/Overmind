---
description: Connecting a Cloudflare account — the API token and its permissions, and what each refusal means. Read when connecting fails.
---

# Connect

1. [Create an API token](https://dash.cloudflare.com/profile/api-tokens) with **Account Analytics: Read** and **Workers Scripts: Read**, and **Billing: Read** for the plan and invoices.
2. Paste it in the popover and press **Connect**. It goes to your Keychain and nowhere else.

| Message | Means | Do |
|---|---|---|
| *Cloudflare refused the token (401)* | wrong, revoked or expired | check it, or make a new one |
| *The token works, but Cloudflare shows it no account (403)* | it has no account in its scope | edit the token's *Account Resources* |
| *The token can't read usage (403)* | it lacks Account Analytics | add *Account Analytics: Read* |
| *Couldn't read the token back from the Keychain* | the Keychain refused this build | connect again; a signed release doesn't hit this |

Logs: `log show --last 1h --predicate 'subsystem == "com.tddworks.overmind"'` (codes only, never the token).

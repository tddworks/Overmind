---
description: How connecting works — TokenVault, GET /accounts as the token check, the refusal reasons, and TokenUnavailable. Read before changing how a token is checked or kept.
---

# Connect — design

- `Account.connect(token:at:)` saves the token, asks `BillingAPI.accounts()`, and chooses the only account or offers the list (journeys 1–2).
- **The check is `GET /accounts`**, not `/user/tokens/verify`, which refuses account-owned tokens and OAuth logins.
- `Account.Refusal`: 401 → `invalidToken`; 403 on accounts → `cannotSeeAccount`; 403 on the usage query → `cannotReadAnalytics` (law 12). A refused connect deletes the token.
- `TokenUnavailable` is the App's bearer saying the Keychain gave nothing back; it is shown as the Keychain's problem, never Cloudflare's.

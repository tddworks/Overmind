---
description: How Sparkle is wired — the App-only Updater, the Info.plist keys, the shared EdDSA key with ClaudeBar, and the appcast on GitHub Pages. Read before changing updates or releases.
---

# Updates — design

- `Updater` (App) wraps `SPUStandardUpdaterController`; it is the only code that links Sparkle. Demo mode starts it with no checks.
- `Sources/App/Info.plist`: `SUFeedURL`, `SUPublicEDKey`, `SUEnableAutomaticChecks`. The release workflow sets the version and build number in it.
- **The EdDSA key is ClaudeBar's** (same publisher): one private key, kept as the `SPARKLE_EDDSA_PRIVATE_KEY` secret in both repos. To give Overmind its own, run `scripts/sparkle-setup.sh` and replace `SUPublicEDKey`.
- `docs/appcast.xml` is the live feed, deployed with the docs to GitHub Pages by `release.yml`. Never hand-edit or move it.

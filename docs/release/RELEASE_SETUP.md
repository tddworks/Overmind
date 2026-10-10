---
description: How to release Overmind — the GitHub secrets, tagging a version, what release.yml does, and the one-time setup. Read before the first release or when a release fails.
---

# Release setup

Releases run in GitHub Actions (`.github/workflows/release.yml`), the same pipeline as
ClaudeBar's ([its guide](https://github.com/tddworks/ClaudeBar/blob/main/docs/release/RELEASE_SETUP.md)
explains each secret step by step).

## Secrets (repository → Settings → Secrets → Actions)

| Secret | What | Same as ClaudeBar's? |
|---|---|---|
| `APPLE_CERTIFICATE_P12` | Developer ID Application certificate, base64 | yes |
| `APPLE_CERTIFICATE_PASSWORD` | its password | yes |
| `APP_STORE_CONNECT_API_KEY_P8` | App Store Connect API key, base64 (notarization) | yes |
| `APP_STORE_CONNECT_KEY_ID` · `APP_STORE_CONNECT_ISSUER_ID` | the key's ids | yes |
| `SPARKLE_EDDSA_PRIVATE_KEY` | signs updates; its public half is `SUPublicEDKey` | yes ([why](../features/updates/design.md)) |

## One-time setup

1. Create `tddworks/Overmind` on GitHub and push `main`.
2. Add the secrets above.
3. **Settings → Pages → Source: GitHub Actions**, so the release can publish `docs/appcast.xml`.

## Releasing

1. Move the lines under `## [Unreleased]` in `CHANGELOG.md` into shape.
2. Tag and push: `git tag v0.1.0 && git push origin v0.1.0` (or run *Release* by hand with a version).
3. The workflow tests, builds a universal app, signs it with hardened runtime, notarizes and staples it, makes a ZIP and a DMG, publishes the GitHub Release with the CHANGELOG's notes, promotes `[Unreleased]` to the version, and updates the appcast. A version with `-beta` goes to Sparkle's beta channel.

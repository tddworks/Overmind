# Changelog

All notable changes to Edge Meter are recorded here, in the reader's order: Removed → Changed → Fixed → Added.

## [Unreleased]

### Changed

- The Bill tab answers "should I upgrade?": Free is enough, or the days it stopped you; choose Free or Workers Paid to see that plan's month line by line → [docs](https://github.com/tddworks/EdgeMeter/blob/main/docs/features/bill/README.md)

### Added

- Upgrade on Cloudflare ↗ under Workers Paid's month, and the plan is re-read when the Bill tab opens, so an upgrade shows without a restart → [docs](https://github.com/tddworks/EdgeMeter/blob/main/docs/features/bill/README.md)

---

## [0.1.0] - 2026-10-09

### Added

- A Settings window (⚙ → Settings…): the account and Worker focus, how often to read (5–30 min), warnings, start at login, and updates → [docs](https://github.com/tddworks/EdgeMeter/blob/main/docs/features/settings/README.md)
- Updates through Sparkle: checks daily or on Check now, signed and notarized → [docs](https://github.com/tddworks/EdgeMeter/blob/main/docs/features/updates/README.md)
- Edge Meter: a menu bar meter for a Cloudflare account — the limit closest to running out, warnings at 50/75/90% and on pace, Workers and D1 charts with deployment pins, and this month's bill on Free and Workers Paid, read with a read-only API token → [docs](https://github.com/tddworks/EdgeMeter/blob/main/docs/architecture/ARCHITECTURE.md)

# Changelog

All notable changes to Overmind are recorded here, in the reader's order: Removed → Changed → Fixed → Added.

## [Unreleased]

---

## [0.2.3] - 2026-10-11

### Added

- AI Gateway: a tab with requests and tokens by model, requests by provider and errors, once watched. It is free, so it adds no limits.

---

## [0.2.2] - 2026-10-11

### Fixed

- Before the first read the menu bar shows `☁` alone, never an empty number.

### Added

- Install with Homebrew: `brew install --cask tddworks/tap/overmind`.
- Choose what Overmind watches: *Settings → Watching* turns Worker or D1 off. A service you don't watch is never read: no tab, no card, no menu bar number, no warning, and the Bill says what its estimate covers (*est. · Worker only*). New Cloudflare products will arrive off.
- *Settings → General → Menu bar shows: Icon only* keeps the menu bar to `☁`, with `◐` or `⚠︎` when a limit needs watching.
- Workers AI, Vectorize and Durable Objects (requests, SQLite rows, storage), each off until watched. On Workers Paid, Workers AI is billed day by day past its 10k neurons.
- R2, on an account with R2: Class A, Class B and storage against R2's own free tier, priced in the Bill beside your Workers plan.
- Queues: operations against Free's 10k a day or Workers Paid's 1M a month, once watched.
- KV: turn it on in *Settings → Watching* to see reads, writes, deletes, lists and storage against your plan, with a KV tab, warnings and its lines in the Bill.

---

## [0.2.1] - 2026-10-10

### Changed

- Edge Meter is now Overmind. It is a new app to macOS: download it once from [Releases](https://github.com/tddworks/Overmind/releases) (Edge Meter won't offer the update), paste your API token again, and set your warnings and Start at login again. Delete Edge Meter.app afterwards.
- A new icon: an eye in a cloud, watching your Cloudflare account.

---

## [0.2.0] - 2026-10-09

### Changed

- The Bill tab answers "should I upgrade?": Free is enough, or the days it stopped you; choose Free or Workers Paid to see that plan's month line by line → [docs](https://github.com/tddworks/Overmind/blob/main/docs/features/bill/README.md)

### Added

- Upgrade on Cloudflare ↗ under Workers Paid's month, and the plan is re-read when the Bill tab opens, so an upgrade shows without a restart → [docs](https://github.com/tddworks/Overmind/blob/main/docs/features/bill/README.md)

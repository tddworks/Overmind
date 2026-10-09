---
description: How Edge Meter updates itself with Sparkle — automatic checks, Check now, and where the feed lives. Read when an update doesn't arrive.
---

# Updates

Edge Meter checks for updates once a day (**Settings → General → Check for updates automatically**),
or now with **Check now**. Updates are signed twice: by Apple (notarized) and by Sparkle's EdDSA key.

The feed: `https://tddworks.github.io/EdgeMeter/appcast.xml`, published by the release workflow
([release setup](../../release/RELEASE_SETUP.md)). A debug build has its own bundle ID
(`com.tddworks.edgemeter.debug`) so it never takes an installed copy's update.

# Compare the two native recap sources

Alpha.59 adds an owner-armed, recap-only comparison for a case where Named hits appears to end before the actual death. It gathers evidence; it does not change which packet Arsenal displays or claim to fix the missing hits.

## One test

1. Enable Death Recap, then run `/rcp recapdebug native start` shortly before the test. It arms for two minutes. Reproduce the Fire Mage / Cauterize case when convenient; no separate charge, potion or layout tests are needed.
2. After death, wait two seconds. The addon saves Blizzard's own default recap at the death notification and reads it once more one second later. It also preserves Arsenal's independently attached native packet.
3. Run `/rcp recapdebug`, select all and copy the export. No Blizzard window or screenshot is required. Once both snapshots have been saved, this export remains available after reload by selecting that death. The optional `reread` command still requires the same login and is not needed for this test.

Do not use `/rcp recapdebug live` for this comparison: that shorter report omits the native packets. If the arm expires, run the start command again. Disabling Death Recap or replacing the test cancels pending comparison work.

## What the export answers

- **FROZEN NATIVE** is the explicit personal meter ID attached by Arsenal.
- **PERSONAL DEFAULT PROBE** is the separate native response used by Blizzard's own death dialog, captured at death.
- **PERSONAL DEFAULT AFTER ONE SECOND** is the later response from that same default API path. Each snapshot keeps its actual read time and its own native timestamps.
- The source comparisons report exact captured-field differences. They do not infer a shared event identity, match by damage amount, bridge native/local clocks, or assume a Cauterize proc from death.

If the two sources disagree, investigate record selection. If the default response changes later, investigate capture timing. If both native sources stop at the earlier hit, preserve that finding as a native-source limitation rather than inventing the later named attacks.

## Scope and bounds

This test is off until explicitly armed. Native-only mode adds no UNIT_COMBAT or COMBAT_TEXT_UPDATE listeners, no per-frame polling and no gameplay actions. It uses one bounded arm timer and at most one delayed comparison timer. Each personal response retains at most 64 sanitized public rows; unreadable data stays unavailable. The delayed read cannot repeat, follow a newer death, run after disable, or query a restored page. Both captured responses use the existing five-death history sanitizer.

The existing 30-second `/rcp recapdebug live start` transport diagnostic remains separate. Ordinary unarmed deaths perform no additional default-recap reads.

Blizzard's [release-dialog code](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_StaticPopup_Game/Mainline/GameDialogDefs.lua) opens its own recap without an explicit ID. The [recap API](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/DeathRecapDocumentation.lua) permits that default selector. The comparison never parses a link or promotes the default response into a guessed meter ID.

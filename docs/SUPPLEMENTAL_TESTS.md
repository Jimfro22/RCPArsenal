# Alpha.53 supplemental testing

## Performance recording

Enable in General → Diagnostics, or use `/rcp perf on`. A static
“Performance recording ON” indicator must remain visible while enabled.
Left-click it for reports; right-click to stop. `/rcp perf` also opens the
copyable report, and `/rcp perf off` stops recording.

Recording is session-only: it starts OFF after every login/reload. The last
five reports survive reload outside portable profiles. Profile reset/import
stops recording. Disabled recording has no native profiler queries, active
event demand, timer or indicator. The UI controls exist when General opens.

The recorder reads only Arsenal's native addon metrics at fight start/end.
Generic combat records start/end counter differences and recent average at
finish; only a matching completed boss encounter labels the native encounter
average. The peak is explicitly a **session** peak, not an inferred fight
maximum. Missing/protected results and reset counters remain unrecorded.
There is no per-frame polling, custom function hook or `scriptProfile` change.
Native measurement overhead has not been benchmarked; do not claim zero cost.

Test: enable, finish a short fight, open the report, then disable. Confirm
the indicator disappears and no further fight records appear. Reload:
recording must be OFF and existing reports must remain copyable. Also check
an ordinary boss pull and a stopped/partial capture. Offline tests verify
lifecycle, limits and units; they do not establish native overhead or API
update order.

## Death Log shortcut and Summary

`/recap` follows `/rcp recap`, opening the selected retained Death Log or its
settings when no death exists. It uses normal slash registration and does
not rewrite Blizzard's command hashes.

The compact Death Summary resumes above Blizzard's death popup only after
an explicitly reported UI reload, while still dead and not a ghost. A marker
from the witnessed death must match the newest saved death ID and current
player GUID. A normal login, other character, different saved death, explicit
right-click dismissal, or unverified reload/death state must not show an old
Summary. The entry reads frozen badges; it never rechecks live cooldowns.
Blizzard's popup is observed through the existing hooks and never modified.

Test: die, `/reload` while still dead, and check the Summary and badges.
Click it to open that same death. Right-click to dismiss, reload again and
confirm it stays dismissed. Release/resurrect: no Summary should remain.

## Missing raid buffs chat

The existing hardware click sends one line to RAID:

`MISSING RAID BUFFS: Mage, Priest, Warrior`

The names come from the displayed missing provider list, combining buff and
debuff provider classes with duplicates removed. The existing permission,
combat/chat restrictions, click throttle and no-rescan behavior are retained.
The classes above are an example, not a captured roster.

## Next focus

This update does not change native named-hit capture, timestamps, grouping or
the separate eight-second incoming feed. Investigate the named-hit history
gap independently; never create spell identities from anonymous receipts.

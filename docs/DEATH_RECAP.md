# Personal Death Recap — alpha.28 test slice

Enable **Personal Tools → Death Recap** explicitly. New and existing profiles
start OFF. Opening settings, Preview and View last never enables recording.
The feature records only this player's mapped, learned active spells and local
supported supplies. It works with the existing consumable reminder OFF.

`/rcp recappreview` is a persistent **Sample preview** with inert Share/reminder
actions. `/rcp recap` opens the last retained personal death in this login session
or Personal Tools when none exists. `/rcp recapstatus` prints safe counters,
association reason and guarded client build/interface alongside the audited
catalog build. It does not send messages or inspect other players.

## Evidence flow

1. Opt-in acquires a consumer of the lazy, event-invalidated local supply cache.
   It does not turn on the reminder, health sampling, audio or raid inspection.
2. Alive combat entry captures a baseline. Relevant cooldown/charge, bag and
   item-readiness signals update typed public observations. Successful own casts
   are independent use facts. A 0.5s reconciliation ticker exists only while
   native active cooldown/recharge observations need expiry reconciliation;
   already inactive spells retain their actual earlier observation timestamps.
3. Own `PLAYER_DEAD` freezes the last-alive sample and recent successful casts.
   A separately named death-notification sample reads cooldown/charge/item-count
   facts, never dead-state item usability. A cast does not imply cooldown, zero
   charges, self-benefit or that a spell would have prevented the death.
4. Native collection requires a witnessed clean meter epoch and a complete
   public alive personal-ID baseline. A positive current-session event ID is
   corroborated with current/explicit session sets. Exactly one new personal
   recap ID and one unresolved own death are required, with no removed IDs,
   reset or session switch. Getters receive that explicit ID; changing the
   default selected recap/link can never supply this death. Late enable/reload,
   unreadable/overflowed baseline, multiple deaths and ambiguity remain
   **association unverified**. Native ingestion/synchronization is not promised
   by source documentation and remains a client acceptance gate.
5. The partial popup uses only readable same-record native timestamp offsets.
   Local cast receipt, encounter-start and death-notification clocks are not
   placed on that axis. Missing healing says Not recorded; HP history/snapshots
   remain unavailable. No damage subtraction, HP curve or healing is fabricated.

The last-alive tray uses separate charge-query status, current charge counts,
held/enabled flags, cooldown facts, item remaining uses and cached carriage
timestamps. Unknown/opaque/error is distinct from supported absence. Inventory
and readiness older than the 30s display window stay Unknown. Item rows describe
each captured item ID, never infer that every family variant is cooling. All
historical facts remain frozen; hovering never refreshes inventory/cooldowns.

The independently audited catalog covers 40 specs/13 classes with 68 verified
identity/eligibility entries and 18 disabled candidates, build 12.1.5.70575.
It is a bounded PvE subset, not exhaustive coverage. Major/minor is a product
classification. Exact current known/active/override IDs and all prerequisite
talents gate activation; passive prerequisite modifiers are allowed. Unreadable
eligibility remains a gap. No assumed unused consumable is presented as verified.
Audit data and pinned evidence are in `provenance/death-recap/`.

## Workload and lifetime

- OFF releases optional subscriptions, active session, supply consumer and all
  owned timers. One compact frozen last page remains for explicit View last;
  it is not persisted across reload/logout. No permanent OnUpdate.
- Enabled idle creates no observation ticker or bag scans. A clean native-meter
  epoch may read one bounded current snapshot; its first session bind may read
  current + explicit snapshots. Repeated same-ID updates do scalar work only.
- Up to 32 mapped known active spells are observed per relevant spell signal.
  Same-type bursts coalesce into one 0.1s trailing refresh; item and charge
  signals cannot consume each other's dirty refresh. Interval reconciliation
  skips already inactive spell observations and preserves their timestamps.
- Supply cache: six bags, at most 100 slots each, 32 delivered item candidates;
  one evaluation per invalidation shared with the reminder. No bank, health
  event, hover or frame-driven bag scans. Explicit raid checks retain their
  independent finite Snapshot operation.
- Native association scans one session, at most 128 rows/64 personal IDs.
  Three fetch attempts per death, reserving one OOC attempt when combat reads
  are opaque. No retries after disable/reset/new capture/resurrection.
- Retention: one live last-alive sample, up to 64 own casts from 30s, one last
  page with independent last-alive/death observations and up to 16 native rows.
  No unused full-pull/sample-history arrays. Native row 1 is retained before
  display ordering; overlapping events group without changing their offsets.
- UI pools are reused, refreshed on model/show/selection changes. Observations
  wrap; recent cast subset is disclosed. Counters are operation counts in mocks,
  not a measured native FPS/RAM or zero-cost guarantee.

## Manual actions and acceptance

Share previews a short public summary and prepares the normal native composer
for Whisper/Say/Party/Raid only after current restrictions/group/recipient
guards. The user submits there. Blocked/unavailable cases retain copyable text;
there is no direct send, automatic broadcast, flood or deferred send. Preview
cannot use live action callbacks. The bell confirms before enabling only the
existing reminder master; saved child preferences remain intact.

No verified Journal mappings ship in this slice, so no books appear. The mapped
code path independently checks encounter/difficulty, section identity and
out-of-combat permission before explicit native navigation. Details is disabled
until an actual advanced view exists. No automatic navigation after combat.

Windows test: update the existing GitHub checkout, restart WoW and verify
`/run print(RCPArsenal.VERSION)` reports alpha.28. Check Preview with recording
OFF; then enable before a new pull. Exercise one death, native meter unavailable,
two deaths/combat resurrection, close/release/resurrection, View last, disable,
both tools OFF, and reminder OFF with supplies carried/absent/on cooldown.
Record `/rcp recapstatus` before/after, actual client build and screenshots.
Check charges/resets, passive/override/talent variants, grouped event cycling,
UI scales and light/dark scenes. Share/Journal/native event restrictions, meter
identity and ingestion, font fit, tooltip, taint and performance need actual
client acceptance. Offline tests do not certify them. CurseForge, tags and
releases require separate Root/owner workflow clearance.

# Consolidation and validation

Current consolidation build: **0.15.3-alpha.58**, reviewed 2026-11-03. This is the current engineering checklist. Older release documents remain historical records. [Recent updates](RECENT_UPDATES.md) and the manual **What's new** button use `RCPArsenal/ReleaseNotes.lua` as their shared source.

## Release decision

Ready for a small GitHub pilot on other classes/specs. Broad class coverage and full native-client QC remain open. Existing Mage results support the specific cases below; they do not validate every defensive, talent, permission, or encounter. No CurseForge submission is part of this build.

## Built and confirmed

| Area | Built | Evidence and remaining boundary |
| --- | --- | --- |
| Settings | General first, Personal Tools second; immediate switches; remembered tab; Preview all / Move all | Owner confirmed clearer navigation. Full scale/profile regression remains below. |
| Death Summary | Centered above the death dialog; matching readiness badges; left-click Open / right-click Close | Owner confirmed appearance and right-click. Restoration after reload needs a fresh check. |
| Death Log | Movable window, five saved deaths, `/recap`, compact report sharing, two source views | Saved badges survived owner reload tests. All chat destinations still need coordinated acceptance. |
| Defensive uses and readiness | Separate successful-use records and frozen availability; learned replacement filtering | Owner verified Arcane/Frost charge depletion, Mirror Image use, and Ice Cold use. Fire test confirmed Ice Cold use, a remaining Blazing Barrier charge, unused Alter Time, and Mirror Image omitted as a defensive. |
| Consumables | Healthstone/potion use, bag presence, cooldown readiness, dimmed unavailable icons | Owner verified empty Healthstone bags, a carried ready Healthstone, and used/on-cooldown potions and stones. Fire also confirmed the used Healthstone unavailable at death. Other item variants need pilot coverage. |
| Named hits | Shows supplied native records through eight seconds; grouped damage/absorbs; native spell details and boss Journal lookup | Owner confirmed earlier hits, boss click behavior, and the saved 5:08 fight-time label clear of the chart. Native packets can cover less than eight seconds. |
| Incoming history | Bounded eight-second damage/healing receipts with recorded uses | Owner supplied open-world, raid-trash, and boss captures. These receipts have no spell names or attackers. |
| Raid tools | Versions, supplies, Quick Bar, missing-class chat, draft/save/load/sort/import/apply raid groups | Implemented; a coordinated two-client regression remains. Raid composition statistics are still future work. |
| Markers | Separate instant, radial, and clear/cancel controls | Stable separate-key direction adopted. Native combat/permission smoke remains; timed one-key experiments are shelved. |
| Personal tools | Resurrection switches; optional potion reminder, combat filter, sizes/text, sound and glow controls | Implemented; final live reminder/offer acceptance checks remain. |
| Performance reports | Opt-in recording, default OFF, persistent ON indicator, saved reports | One owner boss run measured 0.188 ms per UI tick for the whole addon. No paired baseline, memory result, or per-module attribution yet. |

## Active fixes and investigations

1. **Named history and healing:** retain every supplied native hit; investigate additional supported named history and defensible time alignment. The live eight-second feed and native recap use different clocks. Do not attach guessed spell names or move healing onto the named timeline from a timestamp/amount resemblance.
2. **Defensive catalog completeness:** the reviewed catalog has 71 verified identity/eligibility entries across 13 classes and 40 spec IDs, plus 18 disabled candidates. This is not complete defensive coverage or native validation of 40 specs. Check replacements, charges, resets, talent changes and consumable variants with volunteers.
3. **Large hits and HP wording:** preserve reported damage and overkill, while making large killing blows readable. Recorded event HP must not imply health after the killing blow. Investigate before changing those semantics.
4. **Diagnostic clarity:** distinguish an actual overwritten eight-second window from a long fight merely producing more than the ring capacity. Keep late delivery separate from proven damage time.
5. **Full-pull use history:** aggregate use counts exist, but the detailed cast history remains bounded to 30 seconds / 64 receipts. A full-pull defensive/consumable archive is not delivered.

## Validation order

### 1. One short owner check on alpha.58

Use a saved death; no new fight is needed. Open Post to chat once from each tab and compare the report: the same last six named hits inside six seconds, compact totals and confirmed available abilities. Choose a targeted-player Whisper and verify the received lines and clickable spell links. The report must not dump anonymous history, late reports, cast history or per-hit absorb detail.

The saved 5:08 fight-time overlap check and the reported Fire Mage use/readiness checks are accepted. The scrolling feedback is recorded below; do not repeat accepted tests without a mismatch.

For a mismatch, send the version, screenshot, class/spec, what you actually used and what remained available, plus `/rcp recapfacts`. Request the longer `/rcp recapdebug` export only when needed to investigate that mismatch.

### 2. One coordinated raid-tools session

| Check | Pass condition |
| --- | --- |
| Two-client versions and supplies | Received reports match the second character; missing response is not reported as a missing addon/item. |
| Missing providers | Clicking the badge posts `MISSING RAID BUFFS: ` and the missing classes once, with the expected raid authority/channel. |
| Raid Groups | With a two-player raid and a template containing absent players, review and apply changes to present players; verify actual subgroup changes. Include a WowUtils import, saved layout, dirty state and load. |
| Marker controls | Instant places directly; wheel selection/cancel/clear behave correctly outside and during combat with the required authority; unbound controls do not steal keys. |
| Report sharing | Post → Whisper uses the targeted player; the same concise report arrives from either tab, with up to six named hits in six seconds, a separate healing summary, confirmed availability and clickable native spell links. Check the other destinations with the second client. |

### 3. Remaining whole-addon native QC

| Area | Checks still required |
| --- | --- |
| Quiet defaults | Fresh profile: optional tools stay off through login, group join, encounter and ready check; passive requested reporting still works. |
| Settings and profiles | Remembered tab; profile import/reset; positions; Preview all / Move all; minimum supported screen/UI scale; no clipped text, orphaned overlays or invisible controls. |
| Reminder and resurrection | Ready, empty and cooldown item cases; Healthstone preference; combat visibility; 35% sound/glow; channel/mute switches; ordinary and combat offers with explicit opt-ins. Record actual acceptance separately from a request. |
| Recording lifecycle | Disable Death Recap/scanning/reminder and confirm their work stops; re-enable; test another death in the same pull, resurrection, spec/talent changes and reload recovery. |
| CPU and memory | Compare optional tools off versus normal settings in comparable play; settings open versus closed. Record client/build, enabled tools, encounter average and frame-rate context. Measure memory growth across repeated window opens and five saved deaths. Recording itself stays off unless explicitly enabled. |

Offline checks cover source behavior and lifecycle; native rendering, taint, hardware dispatch, combat permissions and actual CPU/memory require the client. A green automation run cannot close these rows.

### 4. Small class/spec pilot

Start with two or three volunteers covering ordinary cooldowns, charge abilities and a talent replacement. Include a Warlock if available to cover the alternate Healthstone. Each tester records their class/spec, actual uses and available abilities, a screenshot and `/rcp recapfacts` after a normal death. Test a saved death again after reload. A mismatch blocks acceptance for that ability/case, rather than being generalized to the entire class.

## Notes for the next pass

- Reduce the What's new wheel distance; owner reports roughly ten lines per notch. Native fine-scrolling acceptance remains open.
- Cauterize belongs on the timeline as an observed proc, never in available cooldowns. Proc capture is pending a verified public in-combat signal. Do not infer it from death, burn damage timing, or an aura already present. Blizzard's [UNIT_AURA documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua) marks the event secret when auras are restricted; the spell-specific aura query also requires a non-secret aura. This needs a native Fire Mage receipt before activation.
- Keep separate observed Ice Cold activations for multiple charges. Successful uses and remaining readiness remain separate facts.

## Later and deferred

**Later:** undo last Arsenal marker; raid composition/buff summary; advanced/full-pull personal recap, followed by leader browsing; WowUtils planned-versus-used cooldowns; verified avoidable/interruptible/dispellable indicators; optional defensive bouncing; movement-mode refinements; WoW Forever research including camps and exclusive buffs.

**Deferred by owner:** scheduled announcements, explicit raid-note sharing and personal defensive fallback priority. **Shelved:** unreliable one-key timed marker experiments and an unproven who-pulled detector. Raid Groups and the six-addon setup checklist are already built and must not return to the future-feature list.

## Engineering checks for this build

Run every Lua harness and Python safeguard, parse the addon with Lua 5.1, check generated notes, then build the install ZIP. The new settings-log test checks lazy creation, navigation/close lifecycle, fitted parent bounds, no gameplay/network/timer work, and agreement between the in-game and written notes. Keep raw owner captures outside the public repository.

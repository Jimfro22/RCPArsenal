# Consolidation and validation

Current consolidation build: **0.15.3-alpha.64**, reviewed 2026-11-04. This is the current engineering checklist. Older release documents remain historical records. [Recent updates](RECENT_UPDATES.md) and the manual **What's new** button use `RCPArsenal/ReleaseNotes.lua` as their shared source.

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
| Incoming history | Bounded eight-second public receipts plus a native-rendered protected path; recorded uses | Owner supplied public captures and a successful standalone protected-number display in a dungeon. Integrated native bars and hover labels confirmed in one owner dungeon capture. An alpha.63 owner screenshot confirmed five protected late amounts. Retention through reopening and performance remain open. These receipts have no spell names or attackers. |
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

### 1. Named recap startup and protected delayed events

One owner alpha.62 dungeon capture confirmed the integrated native bars and
hover labels: 14 protected incoming receipts, including damage and healing,
were visible. This establishes native rendering in that case; it does not
identify unnamed receipts or prove a clock bridge to named hits.

The same export recorded a protected callback after the death notice that
alpha.62 excluded. Alpha.63 retains up to 32 receipts in the existing one-second
window and exposes them separately under **Received after death**. It reuses
native labels, stores protected values only in private session memory and
adds no event listener or timer. Late callbacks are not backdated, assigned
spell names, called killing blows or included in chart/chat totals.

An alpha.63 owner screenshot confirmed all five protected late amounts in that separate panel. The later saved report correctly explained that reload cleared session-only amounts. Reopening/history switching and native CPU/RAM measurements remain pending.

The same capture had no named packet because the alive baseline was unverified. Alpha.64 fixes a reproduced startup omission: enabling while alive/out of combat now checks the complete public Current personal set once, without waiting for a meter notification. Readable empty startup can also recover at existing alive/world/combat-end boundaries. Existing known baselines do no extra work; unresolved deaths, opaque parents and nonempty unverified sessions cannot be certified retroactively. Real Current changes still invalidate the epoch. No timer or additional event subscription was added.

Native check for alpha.64: enable/reload while alive and out of combat, then inspect the next ordinary death before reloading. Compare Named hits with Blizzard and copy `/rcp recapdebug`; the saved NATIVE ASSOCIATION section records the baseline source, status and epoch cause. The startup regression passes offline, but native event order and any opaque combat-start reset still require this check. Do not infer a complete named history from the separate incoming stream.
Facts now count public/protected inputs explicitly, with capacity and cleared
session explanations. Old protected late amounts cannot be recovered.

The reviewed native packet had ten records, of which eight fell in the shown
eight-second window. All eight were represented in seven icon groups; the
remaining two were older. This capture does not establish another source for
longer named history in denser fights, or a Cauterize-specific cutoff.

The saved 5:08 label and reported Fire Mage use/readiness results remain accepted. Compact sharing is implemented; coordinated native delivery acceptance remains below.

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

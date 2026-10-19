# RCP Arsenal — 0.15.1-alpha.1

Open **`/rcp`** for Morning Brew. The four sections are **Addons**, **My tools**, **Raid tools**, and **Settings**. `/rcparsenal` is an alternate entry if another addon also uses `/rcp`; older Arsenal aliases still work.

## Quiet startup

Fresh and reset profiles start with optional tools off. The one-time schema-19 migration turns inherited HUD/demo/scan/Quick Bar/callout defaults off while retaining content choices, templates, appearance, and positions. Existing schema-18 world-marker opt-in and order are preserved. Choices you make after this migration persist.

**My tools → Capability HUD + talent inspection** is the explicit inspection switch. Switching it off stops the scan queue. Quick Bar is independent and does not start scans. Opening settings or resetting an overlay position does not enable it. Imported profiles preserve local tool switches, positions, marker order, and addon comparison targets.

## Addons and group versions

The shelf detects Arsenal, Northern Sky Raid Tools, RCLootCouncil, Simulationcraft, WowUtils, AutoPotion, and BigWigs. Installed, configured enabled, loaded, and version are separate facts. An enabled addon may still be unloaded; an addon disabled pending reload may still be running. Links are for manual copying into your browser. Arsenal never installs or updates other addons.

On **Raid tools**, select an addon, enter an exact local target, or deliberately capture your enabled addon versions. These account-local profile targets are your comparison baseline, not a claim about the latest web release or a shared guild policy. Capturing skips missing, disabled, and unknown versions without erasing previous targets.

A party/raid leader or assistant can click **Check group versions** outside combat and communication restrictions. Other players need Arsenal running to report their local metadata; their optional tools can all be off. Non-response is unknown, offline stays offline, and missing requires an explicit valid reply. Partial replies and unknown versions are not treated as success. Ordered numeric versions distinguish older/newer; suffixes and incompatible schemes use exact-match/different states. Snapshots expire visibly and roster changes invalidate remote results. No periodic network query runs.

## Northern Sky Setup

Open **Addons → Northern Sky → Setup** or **`/rcp nsrt`**. Stock NSRT remains separately installed. Current shared/personal notes and saved profiles use public reads. Internal writes require reviewed stock **12.1.32**, completed initialization, safe native state, and unchanged context. Unknown versions offer supported reads and original settings; base/UI companion states are shown separately.

Editing is an Arsenal draft. **Save local Arsenal copy** creates/selects a unique local shared-note copy without replacing an existing team note or sending it. Current AutoShare must be off. If you enable NSRT AutoShare later, a ready/pull check can send the active copy. Review Current lets you keep a dirty draft while acknowledging a new source context. Personal notes are view-only in this first pane.

Profile selection is separate from apply. **Apply settings as Arsenal copy** creates/activates a new profile, preserving current notes/runtime strings, local anchored geometry/sizes (including timer fonts), and AutoShare. Originals stay intact. Placement edits native anchors/offsets/dimensions/font sizes; a separate labeled sample does not enable NSRT's real reminder. There is no invented generic scale setting. Finish/lock an existing native preview/drag before conflicting changes.

Session restore is guarded against external changes. **Keep Current / Release Undo** forgets only Arsenal's undo record and changes nothing in NSRT. A failed operation retains recovery text for copying/review; unresolved recovery blocks new writes. These bounded in-memory backups disappear on reload, so keep SavedVariables backups and copy recovery text first. Live interoperability, persistence, codec behavior, and rollback still need the release's Windows tests. No NSRT source, codec, assets, share path, synthetic event, or reminder engine is bundled.

## Personal tools

**Accept normal resurrection** is off by default. It requests acceptance only outside detected player, pet, group combat, and encounters, with a second safety check after deferral. Combat/encounter offers and unknown states stay manual. The event does not identify the offered spell; this is conservative combat exclusion, not universal battle-res spell classification.

**Healthstone / potion reminder** is an experimental, independent opt-in visual. It prefers a present, usable, ready Healthstone, then a known health potion. It uses a native health curve directly for alpha and performs no health-value arithmetic or branching in Lua. It never uses an item or presses a key. **Press your item/macro key yourself.** Dead/ghost/unknown life state suppresses the reminder. Unsupported or restricted item data shows nothing.

The threshold is editable (initial implementation default 40%). **Preview**, **Move**, **Stop**, and **Reset** let you arrange a separate labeled sample without enabling the live reminder. Moving saves the position; closing/navigating away from the hub removes the sample. Native threshold equality and raid item behavior still need client validation.

## Existing raid tools

The HUD lists pre-pull capability ownership and freezes its encounter snapshot; it does not track live cooldown availability. Quick Bar retains ready checks/countdowns, sorting, and role → class → spec → movement split priority. Layouts needing unknown specializations explain the inspection dependency. Major coverage means provider-class presence, not active buff/debuff aura coverage.

The optional world-marker cycler is under **My tools → World markers** or `/rcp markers`. Configure a unique numbered order outside combat, enable it, and assign native **AddOns → RCP Arsenal — World markers** bindings for **Place next world marker** and **Clear all world markers**. Each hardware press attempts the next cursor ground marker and wraps. Clear restarts the sequence without changing its order. Empty order disables placement. Disable retains Blizzard-owned keys but makes actions inactive. The game enforces permissions and terrain; a rejected attempt can still advance the local sequence.

## Install and test

Use the versioned **release ZIP**, not GitHub's automatic source archive. Replace only `Interface/AddOns/RCPArsenal`; preserve `RaidArsenalDB` SavedVariables. Interface remains 120100 pending exact target-client testing. Packaged version/build is 0.15.1-alpha.1, profile schema 19, ability catalog 6, readiness protocol 1.

Offline Lua, packaging, and source reviews do not establish native rendering, secure hardware dispatch, taint, communication, resurrection acceptance, or combat behavior. Follow the release's Windows validation checklist before treating this alpha as accepted. External addons remain separately installed; none is bundled or controlled through an unverified adapter.

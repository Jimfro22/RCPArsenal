# 0.15.3-alpha.22 owner test candidate

General now applies Personal and Raid tool switches immediately and shows all six Morning Brew addon rows with local state-specific actions. The staged Setup editor and Resume review footer are retired; legacy setup entry points open General. Personal Tools keeps collapsed reminder sections, short labels and hover help, and separates the editable visual threshold from fixed 35% sound/glow behavior.

Auto resurrection gains a separate strict default-OFF combat opt-in. Settings affect future offers only, use request-generation cancellation, preserve reminder runtime state, and leave native manual popups intact. No offer spell classification, cast, retry loop, or native acceptance guarantee is provided. The optional Hardcore predicate may be absent on positively identified Retail; an existing predicate must still return readable false, and invalid namespaces or an omitted predicate with unknown flavor remain manual. Actual resurrection acceptance and UI fit remain Windows owner checks. No CurseForge release or tag is created.

# RCP Arsenal v0.14.2-alpha.1 — Build Notes

## v0.14.2 optional world marker cycler

- Added an independent secure marker module and native CLICK keybinding declarations; no default keys or override-binding APIs.
- Added a World markers setup subview under Quick Bar, with a numbered unique sequence, palette, move/remove controls, and separate binding readouts.
- Source-reviewed cursor placement uses prepared `/wm [@cursor] N` secure macros. Restricted wrappers advance on the down phase only. Sequence fields use a private namespace to avoid reserved macro1 attributes.
- Clear all uses the native worldmarker clear action with no marker ID, and resets the cycle index through a secure frame reference.
- Schema 18 stores local opt-in and order. Migration starts off, explicit empty orders survive reload, and imports preserve local marker settings without exporting them or changing Blizzard bindings.
- Lua 5.1 syntax and offline state/snippet tests supplement package/ZIP checks. These do not verify WoW taint, hardware dispatch, terrain, or combat permission behavior.
- Interface remains 120100; actual Retail client compatibility is a live-test gate. Catalog remains 6. Existing HUD/inspection/sort/split engines are unchanged.


## v0.14.1 major-coverage additions

- Added Devotion Aura to the composition-based major raid coverage list (Paladin; 3% damage reduction).
- Hunter's Mark remains composition-tracked, is now correctly listed under Debuffs, and shows its current +3% damage-taken effect.
- Missing-coverage rows can show a short effect summary next to the spell name.
- Coverage remains provider-based only; it does not claim the aura/debuff is currently applied.

## v0.14.0 smart split + cold-login repair

- Split priority is now lexicographic: **role balance -> class balance -> spec balance -> movement minimization**.
- Role balance is a hard constraint; class/spec optimization only swaps players inside the same role bucket.
- Odd role counts evaluate all valid side-quota combinations so class utility can still be spread without worsening role balance.
- Exact subgroup placement preserves players already in a valid group on their assigned side whenever possible.
- After a successful split completes, only players whose side changed receive a whisper showing the old and new side.
- Added a cold-login visual refresh path: custom registered textures are reapplied and the HUD/Panic visuals are rebuilt twice after `PLAYER_LOGIN`.
- No permanent visual polling was added.
- Profile schema remains 17; catalog version remains 6.

## v0.13.4 optional non-leader visibility

- Added `leaderToolbox.showForNonLeaders`, default `true`.
- Settings -> Quick Bar now includes **Show when not Leader/Assist**.
- OFF hides the puck for normal raid members and shows it again immediately after gaining raid lead/assist.
- ON preserves v0.13.3 behavior: all raid members can see the Quick Bar, while restricted actions remain permission-gated.
- The preference is included in profile export/import.
- Profile schema is now 17; catalog version remains 6.

## v0.13.3 always-visible Quick Bar

- The Quick Bar puck now remains visible to every raid member while the feature is enabled.
- Countdown, Ready Check, Sort, Split, and Undo remain guarded by raid leader/assistant permission.
- Sort and Split use a persistent dimmed/locked treatment when the player lacks permission or is in combat.
- Clicking a permission-gated action prints a clear raid lead/assist requirement message.
- Puck, Sort, and Split tooltips explain restricted availability.
- Missing-coverage viewing and Quick Bar pinning remain available to non-leaders.
- Automatic inspection work for raid-layout planning still starts only for raid leaders/assistants.

## Scope

v0.13 completes the current Raid Leader Quick Bar usability queue on top of v0.12.1.

### Added

- Checkmark-only Quick Bar launcher asset.
- Missing-major-coverage count badge attached to the puck.
- Badge severity: hidden at 0, amber at 1-2, urgent at 3+.
- Middle-click puck pin/unpin.
- Right-click puck starts a Ready Check when the player has raid lead/assist permission.
- Click-away immediate dismissal while retaining mouse-out grace delay.
- Quick Bar flyout direction: Auto / Right / Left / Down / Up.
- Main capability HUD direction: Auto / Right / Left / Down / Up.
- Session-scoped Undo Last Raid Sort in Sort Options.
- Dedicated HUD -> Quick Bar settings page.

### Changed

- Panic moved from the Quick Bar puck to the first visible capability category.
- Quick Bar, flyouts, missing badge, and HUD mover lowered to normal HUD-level frame strata.
- Dock logo uses the simplified checkmark asset too.
- Actions settings now focus on ability-tile callouts and Panic; Quick Bar preferences no longer live there.

## Click-away implementation

A tiny monitor frame has an `OnUpdate` script only while the Quick Bar is open. It watches for a new left/right/middle mouse press using `IsMouseButtonDown`. If the press begins outside the puck, missing badge, bar, and open flyouts, the bar closes immediately.

The monitor is disabled when the bar closes and is ignored while the bar is pinned. There is no permanent per-frame Quick Bar poller.

## Pin implementation

Pin state is session-only and intentionally not exported in profiles. Middle-clicking the puck toggles pin state. A small magenta dot indicates the pinned state. A pinned bar ignores normal mouse-out and click-away dismissal until unpinned.

## Missing badge

The badge uses the existing roster-composition missing-coverage data. It does not inspect combat aura state. It occupies the former puck-attached Panic position and disappears when no major coverage is missing.

## Panic relocation

Panic remains a `SecureActionButtonTemplate` prepared out of combat. It is now parented to UIParent and anchored immediately to the left of the first visible Detailed category or Compact lane. It remains separate from the non-secure Quick Bar so the hover dock can freely show/hide during combat.

## Undo sort

Immediately before a non-undo subgroup plan starts, the addon captures the eligible players' current subgroup mapping. The Sort Options flyout exposes `UNDO LAST SORT` while that snapshot remains valid.

Undo:

- is out-of-combat only;
- requires raid leader/assistant permission;
- refuses if a required member is missing/ignored or the roster no longer matches the saved layout;
- uses the same one-operation-at-a-time Set/Swap subgroup engine;
- clears the snapshot after a successful undo.

The snapshot is session-scoped and is not persisted or exported.

## Direction behavior

Quick Bar flyouts can explicitly open Right, Left, Down, or Up. Auto compares available screen space around the puck.

The main HUD can be anchored to grow from Right, Left, Down, or Up relative to its stable anchor. Auto chooses the side with the most available screen space. Direction changes do not rewrite the saved anchor.

## Positioning

The stable unscaled anchor architecture from v0.12.1 is preserved. No roster/scan/layout callback intentionally saves or normalizes placement after the initial legacy migration.

## Profile/schema

- `RA.VERSION = 0.13.3-alpha`
- `RA.PROFILE_SCHEMA = 16`
- `RA.CATALOG_VERSION = 6`

New portable fields:

- `hudDirection`
- `leaderToolbox.flyoutDirection`

Local HUD/puck positions and current pin/undo state remain non-portable.

## Validation

- All Lua files must pass loader syntax validation before packaging.
- Final ZIP contents are checked for integrity.
- No Expressway font files are distributed.
- SavedVariables remains `RaidArsenalDB`.
- Capability catalog remains version 6, so this UI-only update does not intentionally invalidate existing verified capability reports.


## v0.13.2 ready check

- Right click on the Quick Bar puck starts a Ready Check.
- The previous right-click Settings shortcut was removed.

## v0.13.1 puck countdown

- Left click on the Quick Bar puck starts `C_PartyInfo.DoCountdown()` using the configured duration (15 seconds by default), matching `/countdown <seconds>`.
- A second left click during that window calls `C_PartyInfo.DoCountdown(0)` to cancel it.
- The puck has no countdown animation or visual state change.
- Added **Quick Bar -> Puck Countdown** (1–60 seconds).
- Dragging the puck is guarded so a drag cannot trigger the countdown.

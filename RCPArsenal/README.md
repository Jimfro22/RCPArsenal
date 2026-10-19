# RCP Arsenal — v0.14.1-alpha


## v0.14.1 highlights

### Smarter raid splits

Split planning now uses a strict priority ladder:

1. **Roles first** — Tanks, Healers, Melee DPS, and Ranged DPS are split as evenly as mathematically possible.
2. **Classes second** — duplicate classes are spread across the two sides whenever role balance allows, helping distribute class buffs and utility such as gateways/debuff coverage.
3. **Specs third** — duplicate specializations are split after class balance is already optimal.
4. **Movement last** — only after the above priorities are tied does the planner prefer keeping players on their current side/group.

After a split fully finishes, players whose **side** changed are whispered their old and new side. Players moved only between groups on the same side are not whispered.

### Cold-login icon repair

A true game launch can make custom addon artwork or spell icons initialize before WoW has fully settled its media/spell state. v0.14 performs two one-shot visual refreshes after `PLAYER_LOGIN`, reapplying custom textures, the Panic `!` glyph, and HUD spell icons. This does not add permanent polling and does not change `/reload` behavior.

## v0.13.4 highlights

- Quick Bar now has **Show when not Leader/Assist** under Settings -> Quick Bar.
- The setting defaults ON, preserving the always-visible-in-raid behavior from v0.13.3.
- Turning it OFF automatically hides the puck unless you are raid leader or assistant.
- Restricted Quick Bar actions remain permission-gated regardless of visibility.


## v0.13.3 highlights

### Quick Bar visible for all raid members

- The checkmark puck now remains visible to every raid member, not only raid leaders/assistants.
- **Middle click** pin/unpin and missing-coverage viewing remain usable by everyone.
- Raid-leader-only actions stay protected:
  - **Left click puck:** countdown / cancel
  - **Right click puck:** ready check
  - **Sort / Split:** raid subgroup changes
- Sort and Split are dimmed when unavailable. Clicking a restricted action gives a clear `raid lead or assist required` message instead of silently failing.
- Tooltips identify which actions require raid lead/assist.

## v0.13.1 highlights

### Puck pull countdown

- Left-click the Quick Bar puck to start the configured player countdown (15 seconds by default), equivalent to `/countdown <seconds>`.
- Left-click again before that countdown window ends to cancel it, equivalent to `/countdown 0`.
- The puck itself does not animate or change appearance.
- Configure the duration under **Quick Bar -> Puck Countdown**.
- Dragging the puck never starts or cancels a countdown.

## v0.13 highlights

v0.13 is the Raid Leader Quick Bar interaction pass. It keeps the stable-anchor work from v0.12.1 and finishes the current usability queue without adding any in-combat cooldown tracking.

### Quick Bar launcher

The launcher now uses a simplified **RCP checkmark-only** asset. The hexagon and `R / P` lettering were removed from the tiny puck because they did not survive WoW's small-texture rendering cleanly.

The puck supports:

- **Hover:** open the Quick Bar immediately.
- **Middle click:** pin/unpin the Quick Bar.
- **Right click:** start a Ready Check when you have raid lead/assist permission.
- **Mouse leave:** close after the configured grace delay.
- **Click anywhere outside the puck, bar, or active flyout:** close immediately.

A small magenta pin dot appears while the bar is pinned.

### Missing-coverage badge

The badge occupying the old Panic-button position is now the number of missing major raid buffs/debuffs:

- **0 missing:** badge hidden.
- **1-2 missing:** amber treatment.
- **3+ missing:** urgent treatment.

Hovering the badge opens the Quick Bar and missing-coverage panel. Only missing entries are listed.

### Panic belongs to the encounter HUD

The emergency **!** control no longer overlaps the Quick Bar puck. It is attached immediately beside the first visible ability category instead.

One hardware click sends exactly one preconfigured Raid Warning:

```text
PANIC: USE DEFENSIVES + HEALTH POTIONS NOW!
```

There is no mass-whisper fan-out.

### Undo Last Raid Sort

Before RCP Arsenal starts a successful subgroup arrangement, it stores the eligible raid members' original subgroups for the current session.

Right-click **Sort** to open Sort Options and choose:

```text
UNDO LAST SORT
```

Undo is intentionally conservative. It refuses when the relevant roster changed or when the operation is not safe to perform. Undo is out-of-combat only, like every subgroup mutation.

### Direction controls

The UI can now grow away from its anchor in different directions.

**Quick Bar flyout direction:**

- Auto
- Right
- Left
- Down
- Up

**Main HUD direction:**

- Auto
- Right
- Left
- Down
- Up

`Auto` chooses the side with the most available screen space. The default HUD direction remains **Right** so existing layouts do not unexpectedly flip after upgrading.

### Lower overlay strata

The mover tab, Quick Bar, badge, and flyouts use normal HUD-level strata rather than sitting above major Blizzard dialogs such as the Group Finder.

### Dedicated Quick Bar settings page

The sidebar now presents **Quick Bar** directly under HUD. This page owns launcher/flyout preferences:

- Enable Quick Bar
- Missing raid coverage badge
- Flyout direction
- Puck size
- Tooltip delay
- Mouse-out close delay
- Reset Quick Bar position

The page also documents middle-click pinning, right-click settings, click-away dismissal, and badge severity.

### Delayed help tooltips

Quick Bar control help and Panic help do not appear immediately. They use the configurable tooltip delay and cancel if the pointer leaves before the delay expires.

### Stable positioning retained

The main capability HUD and Quick Bar puck still use dedicated unscaled UIParent anchors. Scan completion, category wrapping, world transitions, frame-size changes, and Quick Bar geometry changes do not intentionally rewrite the saved anchor position.

## Existing Quick Bar tools

### Sort

- **Left click:** Tanks -> Melee -> Ranged -> Healers.
- **Right click:** Sort Options, including Undo Last Sort.

### Split

- **Left click:** balanced odd/even split.
- **Right click:** balanced G1+G2 / G3+G4-style adjacent split.

### Missing

Shows missing major raid composition coverage.

Current coverage list:

**Buffs**
- Mark of the Wild
- Blessing of the Bronze
- Devotion Aura — 3% damage reduction
- Arcane Intellect
- Power Word: Fortitude
- Skyfury
- Battle Shout

**Debuffs**
- Hunter's Mark — target takes 3% increased damage
- Chaos Brand
- Mystic Touch

Coverage means an online provider class exists in a tracked raid group. It does **not** mean the buff/debuff is currently applied.

## Capability tile callouts

Left click uses exactly one configured primary channel:

- **Whisper** — default
- **Say**
- **Off**

Say and Whisper are mutually exclusive so one ability click cannot generate two chat lines. Right click remains optional Raid Warning.

## Product scope

RCP Arsenal tells a raid leader what the tracked raid **brought** and who owns each tool. During an encounter the capability list is a static reference plus user-driven secure callouts. It does not infer remote cooldown readiness, usage, or remaining cooldown time.

## Installation

Delete the existing addon folder and extract the new `RCPArsenal` folder into:

```text
World of Warcraft/_retail_/Interface/AddOns/
```

Then:

```text
/reload
/rcpa config
```

SavedVariables remains `RaidArsenalDB`, so existing profiles and inspection reports migrate forward.

## Commands

```text
/rcpa                 open settings
/rcpa config          open settings
/rcpa show            show capability HUD
/rcpa hide            hide capability HUD
/rcpa recover         recover/recenter HUD
/rcpa scan            scan missing/stale players
/rcpa rescan          force tracked-roster rescan
/rcpa clearcache      clear inspection reports
/rcpa pause           pause inspection queue
/rcpa resume          resume inspection queue
/rcpa compact         Compact HUD mode
/rcpa detailed        Detailed HUD mode
/rcpa scale 125       set overall HUD scale
/rcpa demo            toggle demo mode
/rcpa demoscan        toggle demo scan strip
/rcpa export          export portable settings
/rcpa import          import portable settings
/rcpa status          print scan coverage
/rcpa sort            normal role sort
/rcpa split           odd/even balanced split
/rcpa groupsplit      adjacent-half balanced split
/rcpa missing         open missing coverage
```

Legacy aliases `/arsenal` and `/raidarsenal` remain available.

## Expressway font

Font files are **not distributed** with RCP Arsenal. Expressway is used when available through LibSharedMedia or when the user supplies their own licensed local copies. Blizzard Arial Narrow remains the fallback.

## v0.13 live-test checklist

1. Hover the checkmark puck and confirm the dock opens immediately.
2. Middle-click the puck and confirm the dock remains pinned; middle-click again to release it.
3. Right-click the puck and confirm Settings opens directly to Quick Bar.
4. Open the dock, click elsewhere in the game world, and confirm it dismisses immediately.
5. Move out normally without clicking and confirm the configured close delay still applies.
6. Confirm the missing badge hides at zero, is amber at 1-2, and becomes urgent at 3+.
7. Confirm Panic appears beside the first visible ability category rather than on the puck.
8. Right-click Sort, run a real arrangement, then test Undo Last Sort.
9. Test Quick Bar flyout directions near several screen edges.
10. Test HUD direction changes without the saved position creeping after scans/reloads/zoning.
11. Open Group Finder and confirm the mover/Quick Bar do not render over the major Blizzard window.
12. Confirm no full roster rescan occurs solely because of this update.

## Alpha status

All packaged Lua files are syntax-checked before release. Real-client verification is still required for protected subgroup operations, secure chat delivery, click-away timing, direction behavior at unusual UI scales, and Blizzard-window strata interactions.

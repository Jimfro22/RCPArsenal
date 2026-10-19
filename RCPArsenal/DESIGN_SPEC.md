# RCP Arsenal — v0.13 Product and Visual Specification

## Product promise

RCP Arsenal is a raid-leader-installed inventory of the tools the tracked raid brought, paired with lightweight pre-pull raid-management utilities and user-driven encounter callouts.

The capability HUD is not a remote cooldown tracker.

## Accuracy contract

Allowed static states:

- Present at pull
- Brought by the tracked raid
- Scanned
- Pending

The addon must not automatically claim:

- Ready now
- Off cooldown
- Used during the encounter
- Remaining remote cooldown

## Main capability HUD

### Compact

One icon tile per ability owner. Category label and owner tiles form the capability reference. Player names are abbreviated according to settings and realm names are not displayed.

### Detailed

Detailed mode uses the same Obsidian Ember rounded top-edge accent system as Compact mode.

### Growth direction

The stable HUD anchor supports:

- Auto
- Right
- Left
- Down
- Up

Changing direction changes where the HUD is bound relative to the saved anchor; it must not rewrite that saved anchor.

## Movement

When unlocked, the HUD uses a dedicated mover tab. Ability tiles are not drag handles. The mover sits at normal HUD strata so major Blizzard windows can cover it.

Both capability HUD and Quick Bar launcher use separate unscaled UIParent anchors for stable positioning.

## Encounter Panic

Panic is an encounter-HUD action, not a raid-setup action.

- It appears immediately beside the first visible capability category.
- It is visually distinct from ordinary capability tiles.
- It is a secure hardware-click button prepared out of combat.
- One click sends one configured Raid Warning.
- No mass whispering.
- Help tooltip is delayed according to the Quick Bar tooltip-delay preference.

## Raid Leader Quick Bar

### Collapsed puck

- Simplified RCP checkmark only.
- Configurable 24-44 px size.
- Draggable local position.
- Demo Mode may expose it outside raids.
- Real raid visibility requires leader/assistant access.
- It may remain visible in combat while subgroup mutation controls reject protected actions.

### Puck input

- Hover: open immediately.
- Middle click: pin/unpin.
- Right click: open HUD -> Quick Bar settings.
- Mouse leave: one-shot configured close delay.
- Click elsewhere: dismiss immediately unless pinned.

### Missing badge

The old puck-attached Panic location is used for missing-major-coverage status:

- 0: hidden
- 1-2: amber
- 3+: urgent

Hover/click exposes the Missing panel.

### Expanded command rail

```text
[check] [SORT] [ODD | EVEN] [N MISSING]
```

No redundant title block is required.

### Flyout direction

- Auto
- Right
- Left
- Down
- Up

Auto chooses the largest available screen-space direction around the puck.

### Pin state

Pinned state is deliberately temporary/session-scoped. It is indicated by a small magenta dot on the puck.

## Raid-layout tools

### Normal sort

```text
Tanks -> Melee -> Ranged -> Healers
```

Players are assigned sequentially to five-player subgroups.

### Odd/even split

For a standard 20-player raid:

```text
Side A: G1 + G3
Side B: G2 + G4
```

### Adjacent-half split

```text
Side A: G1 + G2
Side B: G3 + G4
```

### Smart split priority

Both split modes use a deterministic smart planner with a strict priority ladder:

1. Roles: Tank / Melee / Ranged / Healer counts are split as evenly as possible.
2. Classes: duplicate classes are spread across sides whenever the role constraints allow it.
3. Specs: duplicate specializations are spread after class balance is already optimal.
4. Movement: only then does the planner prefer keeping players on their current side/subgroup.

Class/spec optimization never worsens role balance. When the completed split is confirmed, players whose side changed are whispered their old and new side; same-side subgroup moves do not trigger a whisper.

### Undo Last Raid Sort

Before a subgroup plan is committed, store the eligible roster's original subgroup mapping for the current session. Sort Options exposes Undo while that snapshot remains valid.

Undo must refuse rather than guess if the tracked roster no longer safely matches the snapshot.

### Sort safety

- Out of combat only.
- Leader/assistant access required.
- Ignored raid groups are untouched.
- Hybrid DPS melee/ranged classification uses known/inspected spec rather than guessing.
- One subgroup Set/Swap operation at a time.
- Wait for roster confirmation between operations.

## Missing major raid coverage

This is composition coverage, not aura-state tracking.

### Buffs

- Mark of the Wild
- Blessing of the Bronze
- Devotion Aura — 3% damage reduction
- Arcane Intellect
- Power Word: Fortitude
- Skyfury
- Battle Shout

### Debuffs

- Hunter's Mark — target takes 3% increased damage
- Chaos Brand
- Mystic Touch

Only missing effects appear. Offline providers and providers in ignored raid groups do not satisfy coverage.

## Ability-tile callouts

### Left click

Exactly one selectable channel:

- Whisper (default)
- Say
- Off

Say and Whisper are mutually exclusive.

### Right click

Optional Raid Warning.

All secure attributes are armed outside combat and are not programmatically rewritten during combat.

## Settings information architecture

Sidebar order begins:

```text
HUD
  QUICK BAR
CONTENT
SCANNING
ACTIONS
```

Quick Bar owns puck/flyout presentation and interaction preferences. Actions owns capability-tile chat behavior and Panic messaging.

## Tooltips

Quick Bar controls and Panic use delayed, cancellable help tooltips. Hover behavior itself must never wait for the tooltip delay.

## Frame layering

Ordinary RCP Arsenal HUD controls use normal HUD-level frame strata. Group Finder and other major Blizzard dialogs should naturally render above the mover and Quick Bar.

## Performance

- No inspect work during encounters.
- No combat-log parser.
- No remote cooldown polling.
- No addon-comms cooldown protocol.
- Quick Bar click-away uses a temporary monitor only while open.
- Drag loops exist only while actively dragging.

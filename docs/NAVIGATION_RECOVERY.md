# Navigation recovery — 0.15.2-alpha.3 source

The owner's first Windows/WoW run loaded Arsenal but failed navigation/usability acceptance and reported a duplicate marker header warning. **0.15.2-alpha.2** fixes the repeated XML header separately. This source correction restores familiar settings access using the existing panels and Obsidian Ember artwork/styles. It is not native usability approval.

`/rcp` still opens the Addons checklist. Every settings page is directly visible in the sidebar:

| Group | Destinations |
| --- | --- |
| Arsenal | HUD, Quick Bar, Content, Scanning, Callouts & Panic, World Markers |
| Raid setup | Addons, Version Check |
| Other | Personal Tools, Profiles & Recovery |

Primary pages select their own sidebar row and have no Back detour. Northern Sky remains under Addons with Back to Addons. The internal pane keys and old slash aliases remain compatible; direct `/rcp hud`, `quickbar`, `content`, `scanning`, `callouts`, and `profiles` routes also open settings without activating tools.

- **HUD:** Enable HUD + inspection, lock/unlock, and Recenter HUD are on its action bar. Growth direction is in Position & Direction. Unlock and drag the grip beside the HUD to move it. The optional layout sample is initially closed and does not enable the tool.
- **Quick Bar:** its independent enable, size, flyout, countdown, and timing settings remain here. Outside combat, left-drag the puck to move it. Reset puck position affects only the puck; HUD controls are no longer on this page. Behavior help uses real line breaks.
- **Callouts & Panic:** channel/templates and Panic switch/message remain together. Panic moves with the HUD; HUD Position opens that page. Initially closed Advanced: Test Callouts opens bounded diagnostics, avoiding the prior 22-unit overlap with the top editor cards. Tests can send messages only through their explicit hardware clicks.
- **Scanning:** status, groups, missing/full rescan, pause/resume, and cache controls remain. Viewing does not enable inspection. Demo options are initially closed in Advanced, without changing a saved demo choice.
- **Personal Tools:** resurrection and consumable reminder controls only, with threshold/preview/move/stop/reset grouped beneath the reminder. No generic Configure detours.
- **Profiles & Recovery:** import/export remain. Full profile reset is separately under Advanced, retaining its existing consequence confirmation. It is not a tool-position reset.

This correction changes no saved positions, anchors, scales, directions, opt-ins, callout templates, profile schema, inspection cache, targets, marker sequences, bindings, or Northern Sky settings. It adds no new profile migration. Sample/advanced visibility is session-only. Fresh setup remains quiet.

The sidebar uses 42-unit rows at a 46-unit pitch with three group labels: the last row ends 642 units below its 728-unit parent top, leaving the lower command hint clear. HUD Position & Direction and its secondary presentation/sample area end at 276 and 624 below pane top respectively, within the 660-unit content region. Callout editor cards end at 432; advanced/HUD-position launchers begin at 454. These source bounds do not prove native font fit or rendering.

Offline real-module navigation assertions click all ten persistent rows, check each selected state, verify nested Northern Sky Back, exercise sample/advanced open/close, and assert navigation preserves saved geometry/opt-ins without scans or network queries. Native screenshot/rendering and owner usability acceptance remain pending.

For the owner's existing linked checkout: close WoW, Desktop **Fetch origin → Pull origin**, restart WoW, and confirm `/run print(RCPArsenal.VERSION)` prints **0.15.2-alpha.3**. Try `/rcp`, find HUD, puck, Panic, markers, Version Check, and Profiles directly. Check the marker warning is gone and existing key assignments remain. Do not reset SavedVariables, reinstall, or rerun Setup for this correction.

This is a source/PR correction. The separate GitHub **0.15.2-alpha.2** release is the binding-only hotfix; it does not contain this navigation patch. CurseForge upload/moderation remains separate and no automated upload is configured.

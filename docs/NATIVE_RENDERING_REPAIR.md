# Caption recovery and feature grouping — 0.15.3-alpha.1

Expanded native testing of 0.15.2-alpha.3 showed blank sidebar, segmented, toggle, footer and ODD/EVEN captions. The selected font and nonempty native GetText value did not prove glyphs were visible. This correction retains intended addon captions independently, bootstraps native font regions, validates optional fonts on cached FontObjects before applying them, and restores captions after font changes. Editable drafts retain their own current value. Visible controls now rebind their registered textures and fonts synchronously on first display, including the puck checkmark, Sort and provider spell icons; they no longer wait for the next warm-up timer after being hidden. The existing single bounded visual recovery queue and built-in texture fallback remain scan-free. Native reload-only texture success is still unverified until cold-start screenshots confirm it. The exact native engine failure is not proved, and offline checks do not establish native rendering success.

The original 256×256 hex RP artwork is unchanged. Theme icons now request linear filtering explicitly. No higher-resolution export matching this exact artwork was found; another differently branded logo is not a replacement. Owner screenshots at actual UI scale must establish the sampling result.

## Feature hierarchy

Six persistent destinations: Available Cooldowns, Addons & Versions, Quick Bar, World Markers, Personal Tools, Profiles & Recovery. Bare `/rcp` opens Addons & Versions. Available Cooldowns starts on Categories, then offers Display & Position, Scanning, and Callouts & Panic. Its fixed master and coverage explanation remain above the scrollable body. Legacy direct HUD/content/scanning/callout routes reach the matching internal tab; `raid` and `versions` reach the combined table. `versions` retains its explicit group-query action.

The coverage statement stays visible: “Shows which raid members can provide each ability. Cooldown use and remaining time aren't tracked.” Master OFF stops HUD and inspection. Explicit ON uses the existing inspection consent and keeps category choices. Existing deliberate master choices remain saved. Quick Bar and World Markers remain independent.

The combined table always shows Player and all seven addons: Arsenal, Northern Sky Raid Tools, RCLootCouncil, SimulationCraft, WowUtils, Auto Potion and BigWigs. Header selection opens compact local descriptions, download/setup/profile and target controls without filtering columns. Unknown response, partial response, missing, disabled, not loaded, pending reload, stale query and target comparisons remain distinct. Targets are local approvals, not claims about website-latest releases. Opening the table and its age ticker never query the group or inspect talents. Refresh Local and Check Group Versions are explicit actions. Target drafts survive refresh and header changes.

## Visible state and Quick Bar defaults

Panic keeps its saved OFF default. Callouts & Panic explains Off, waiting for a visible HUD category, or Visible. It moves with the HUD; a Raid Warning still needs native permission. A complete paused queue no longer leaves an empty scan strip visible. Scanning shows inspection-off, no-work, active/paused/waiting/range/encounter state with the separate strip switch.

Quick Bar itself stays OFF by default. Provider-class coverage is ON for fresh/unset preferences. **Each explicit Enable Quick Bar action also sets provider coverage ON**, adopting the requested default for older profiles whose false value had no provenance. Users may turn coverage OFF separately afterward. Normalization, opening settings, asset recovery, disabling Quick Bar and profile import preserve the current choice; no background activation occurs. Coverage uses roster classes, not active auras or live cooldowns.

The flyout replaces its decorative duplicate check with a compact labelled Ready Check button. The original puck right-click action remains compatible, as do countdown/cancel, pin, Sort, both split modes and provider coverage. The row is 36 units high with 6-unit gaps and bounded measured Ready Check width. No Raid Leader Mode preference or rank-driven regrouping is introduced; that proposal is still exploratory.

Positions, anchors, scales, categories, notes, imported settings, target versions, inspect cache, marker order and native keybindings remain intact. Schema 19, catalog 6, readiness protocol 1 and Interface 120100 are unchanged. No reset or reinstall is required.

## Native acceptance

Using the existing linked Windows checkout, update to this approved source/release, fully exit and restart WoW, and confirm `/run print(RCPArsenal.VERSION)` is `0.15.3-alpha.1`. Do not reset SavedVariables or rerun installation setup.

1. Cold-open `/rcp`: read every sidebar caption, all seven column headers/cells and selected-addon details. Reopen it; edit a target draft while replies arrive and verify it remains intact.
2. Open Available Cooldowns: Categories first, master visible above it, exact honest coverage explanation throughout all four tabs. Confirm Detailed/Up/background options, toggle titles and footer captions are visible immediately. Scroll the body; master/tabs/explanation stay fixed. Merely visiting must not enable tools or inspection.
3. With master OFF, explicitly enable Quick Bar: provider coverage should turn ON, with no HUD or inspection. Turn provider coverage OFF; reopening settings and visual recovery must preserve OFF. Disable and explicitly re-enable Quick Bar; coverage returns ON.
4. Cold-hover/reopen puck: small original puck only, labelled Ready Check, Sort, ODD/EVEN and Missing readable with no clipping. Check right-click Ready Check, countdown/cancel and middle-click pin. Check ordinary-member refusal and leader/assistant permitted actions.
5. Confirm saved Panic OFF reason; when deliberately ON with no visible HUD category it must explain why it is waiting. With an actual visible category it appears at that category and moves with HUD. Check strip OFF/no pending, genuine pending/paused/range and encounter hiding without manufacturing a demo scan.
6. Check original logo edges at actual UI scales; verify existing positions/scales, notes, keys, cache, targets and marker sequence. Capture cold-open and reopened feature/puck screenshots. Native glyph rendering and usability require this evidence.

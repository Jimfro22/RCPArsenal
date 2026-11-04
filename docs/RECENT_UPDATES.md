# Recent RCP Arsenal updates

<!-- Generated from RCPArsenal/ReleaseNotes.lua; edit that source, then run tools/export_release_notes.lua. -->

## 0.15.3-alpha.62 — Protected incoming events in Death Log

### Added

- Death Log's eight-second view can draw protected dungeon/raid damage and healing through native bars.
- Each bar is one event. Hover and scroll to inspect exact amounts without guessing spell names.
- Protected events remain available for five deaths this login. Reload retains named hits and public facts, with a note when live amounts have cleared.
- Chat keeps its named-hit summary and omits a healing total when protected events prevent a complete calculation.

## 0.15.3-alpha.61 — Keep the display test recording

### Fixed

- The manual protected-number test stays armed when combat starts instead of canceling itself.
- External window hides preserve the capture. Reopen with /rcp recapdebug display; CLOSE still cancels an active test.
- COPY STATUS includes the last event and window hides to diagnose a failed test without another fight.

## 0.15.3-alpha.60 — Test protected incoming numbers

### Added

- A manual display test passes protected incoming amounts directly to Blizzard's bars and text.
- Use /rcp recapdebug display start before combat. After death, screenshot the test and COPY STATUS before reload.
- The test is off by default, retains eight seconds in memory, and stops after one death or two minutes.

## 0.15.3-alpha.59 — Save native recap comparisons

### Added

- A manual recap-source test saves Blizzard's own recap at death and again one second later.
- Both comparison snapshots survive reload with the saved death. No Blizzard window is needed.

## 0.15.3-alpha.58 — Compact Death Log sharing

### Changed

- Post to chat shares up to six named hits from the final six seconds, from either view.
- Reports summarize recorded damage, absorbs, overkill, healing and confirmed available abilities.

## 0.15.3-alpha.57 — Consolidation and testing

### Added

- What's new beneath the settings logo. Open it whenever you want to read recent changes.

### Changed

- One current test checklist separates finished work, confirmed results, and remaining checks.

## 0.15.3-alpha.56 — Death Log spacing

### Fixed

- Fight time sits above the eight-second chart, clear of the final healing amount.

## 0.15.3-alpha.55 — Named hits and spell replacements

### Fixed

- Named hits displays every supplied hit within eight seconds, including earlier small hits.
- New deaths use your learned spell replacement instead of also showing its base ability.

## 0.15.3-alpha.54 — Boss ability details

### Added

- Click a mapped boss ability to open its Dungeon Journal entry outside combat.

## 0.15.3-alpha.53 — Quick access and optional performance reports

### Added

- Type /recap to open your saved Death Log.
- Optional performance reports in General. Recording starts off and shows an indicator when on.

### Fixed

- Death Summary can return after reloading while dead, unless you already dismissed it.

### Changed

- The Quick Bar announces missing classes as MISSING RAID BUFFS: followed by the class list.

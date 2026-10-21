# Raid Groups (alpha.19)

Open Raid Groups beside Quick Bar in the sidebar, or use `/rcp groups`. `/rcp raid` keeps its existing Addons destination. All eight groups appear in four columns and two rows, with five slots each. These slots plan subgroup membership; Blizzard raid frames may order people differently within a subgroup.

Drag a card to a slot, or select it and click its destination. Dropping on an occupied slot swaps the two cards locally. The unassigned tray retains current players without a target; every current player must have a group before Apply. Cards show offline, absent and unresolved status, duplicate-name realms and full-identity tooltips. Right-click an absent/unresolved card to match an exact current raider or remove an absent card. No current raider can be removed from the raid through this pane.

From raid explicitly replaces the draft with current groups. Update raid refreshes and matches exact full-name/realm identities while retaining staged slots. It never guesses a short name. Unlisted current players remain visible, including in the tray when their current group has no free draft slot.

Give a draft a boss/layout name, then Save. Load replaces only the local draft. Named layouts survive profile import/reset under `RaidArsenalDB.raidGroupLayouts`, outside portable profiles. Storage holds up to 50 layouts with 80 identities each, using names/realms rather than session GUIDs or raid indices. The active unsaved draft is session-local. There is no automatic boss selection or encounter application.

Import WowUtils accepts plain exported text: `EncounterID:123;Difficulty:Heroic;Name:Boss` headers and comma-positioned `invitelist:` rows with an optional terminal semicolon. Empty positions remain holes. Read sections, explicitly select one and Import draft. Changed paste invalidates that selection. Unsupported, ambiguous or oversized text leaves the draft unchanged. There is no URL fetch, bearer key, invite, kick, chat broadcast or Northern Sky action.

Review changes captures a fresh roster and displays the complete current-to-target mapping. Apply to raid requires that exact eligible preview, a player-organized raid, leader/assistant authority, known out-of-combat members, no active encounter and no competing Quick Bar sort. Ordinary draft editing does not require authority. Missing planned people are disclosed; unresolved identities and current players left unassigned block Apply.

Apply submits one subgroup move or swap at a time, using a fresh GUID-to-index lookup. Only the exact observed roster acknowledgement permits the next operation. Combat, lost authority, changed membership, unexpected group changes or a finite acknowledgement timeout stop the job. It never retries or resumes automatically. Cancel and closing the pane stop future submissions; a request already sent may still settle. Confirmed progress and stopped/partial results remain visible. There is no planner live Undo in this release.

An unresolved submitted request fences both new Apply and Quick Bar sorting. Review raid refreshes and displays the observed full-identity groups. Acknowledge groups recaptures and requires that exact fingerprint plus current eligibility, preserves the draft and sends no subgroup call. It clears the fence only after explicit acknowledgement; a prior native request may still settle. Review changes and a new Apply are required afterward. Any unexpected late result stops a subsequent job. Closing an unresolved planner leaves no background polling; reopening or explicit refresh can observe settlement.

Quick Bar sorting now exposes Cancel while waiting for inspection as well as while sorting. Cancelling clears its pending mode, so later inspection/report callbacks cannot start it. Both controllers reject competing group work. Profile changes stop pending/active work. General, unrelated pages and hidden planner callbacks do not activate roster observation; the planner observes through native events only while visible or applying.

## Windows acceptance

Update the existing checkout with Fetch origin → Pull origin, then fully restart WoW. No saved-variable reset, reinstall or junction change is needed. Offline Lua mocks verify addon decisions; the following native checks remain required:

1. Open `/rcp groups`; verify eight readable groups at your UI scale, duplicate realms, class colors, offline cards, scrolling and full-name tooltips. Drag to empty/occupied slots, drop outside, and use click-select destinations. Check that no live group changes before Apply.
2. Save/load a named boss layout; paste a note with multiple sections and empty positions. Confirm explicit section choice, absent cards and exact matching after a player joins. Update raid must preserve staged slots. Check long paste/list scrolling, Escape, focus cleanup and closing/reopening Arsenal.
3. As a raid member, draft normally but confirm Apply is unavailable. As leader/assistant out of combat, review a small known change and Apply once. Check the native groups and progress after each acknowledgement, including a swap of full groups. No frame-order guarantee is intended.
4. Cancel during Apply; test combat, lost authority, roster churn and another person's group edit. Future requests must stop, the draft must remain and no job may auto-resume. If an acknowledgement does not arrive, review observed groups and explicitly acknowledge them before a fresh review. The warning must disclose that an older request may still settle.
5. Start Quick Bar sorting while roles are unknown, cancel its inspection wait and let inspection finish. It must stay cancelled. During planner Apply or unresolved results, old Sort/Split/Undo must not start. During old pending/active sorting, planner Apply must remain unavailable and become reviewable after cancellation.
6. Confirm General stays quiet, last-page reopening and the placement shelf work, `/rcp raid` still opens Addons, and profile import/reset retains named layouts. Recheck alpha.18 marker center/sector/cancel behavior and existing glow, health and audio settings. Watch for native Lua errors, protected-action blocks and taint.

GitHub review/CI does not establish live-client acceptance. CurseForge, tags and release publication remain separate approval steps.

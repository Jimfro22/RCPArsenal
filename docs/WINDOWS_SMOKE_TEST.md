# RCP Arsenal Windows smoke test

The current owner test candidate is **0.15.3-alpha.22**, schema 19. All native checks below remain pending. Record the exact candidate commit/manifest, ZIP SHA-256, client build, profile origin, role/permissions and shortest reproduction with any Lua error. Preserve SavedVariables and the prior installer. See the [current settings contract](SETTINGS_CLEANUP.md).

## Current settings and resurrection checks

1. With fresh and migrated profiles separately, cold login/reload and join a raid. No optional hub, HUD, puck, reminder, resurrection acceptance or query starts automatically. The combat acceptance child defaults OFF when absent or invalid. A saved child ON with parent OFF must stay inert. First neutral `/rcp` opens General; later visits restore ordinary pages. `/rcp setup` opens General with no review/save/resume controls.
2. Toggle all four General masters individually. Changes apply immediately through normal setters. Confirm child sound/glow/captions, threshold, local role, callouts and coverage preferences survive OFF/ON, navigation, reload and import. Quick Bar explicit activation still adopts its normal coverage default; refreshing an enabled bar must preserve a later coverage OFF preference. Start combat with General already open and attempt a rejected HUD/puck change: show the reason, keep the switch unchanged, and do not apply it after combat.
3. Verify all six addon rows at full and fitted window scale. Exercise Installed, Missing, Disabled (including disabled-but-loaded reload), Not loaded and Unknown states. Only the loaded Northern Sky row opens verified Setup; other installed/not-loaded rows open Details, disabled shows enable guidance, missing copies a link, unknown refreshes local metadata. No automatic group query or external addon setting change.
4. Check short labels, row tints/dividers, hover help, 451px columns with 16px gap, General-first/Personal-second navigation, bottom-left Preview All/Move All and Obsidian Ember styling. Available Cooldowns hover must explain inspection and static providers without remaining-time tracking. Verify the Quick Bar puck hover explains click, pin, ready-check and drag actions; reset only moves its own puck.
5. Personal Tools: parent toggles apply immediately, combat child visibly depends on parent, and the decision line explains accepting offers during pulls/boss fights without casting. Test reminder OFF Settings, Visual health threshold, Show reminder, each collapsed detail section, nested glow, sample preview, sound choice/channel and Requires Master. Verify fixed 35% sound/glow is distinct from editable visual visibility. Test long captions/actual error wraps, scrolling, color/style popup dismissal and all fitted scales. Routine off/hidden prose should not crowd the page; manual/actionable failures remain visible.
6. With Auto resurrection OFF, incoming offers remain manual. Parent ON/child OFF: test a safe outside-combat offer, player/pet/group combat, raid/party member or pet combat, encounter and unknown guard conditions. Only safe outside-combat offers may request acceptance. Changing either switch while an offer is pending must not accept it later. No combat-end retry.
7. In a coordinated test with both parent and child explicitly ON, receive real ordinary and combat offers during pulls/boss fights. Record actual acceptance or rejection separately from request status. Test sickness/timed recovery delay and a no-timer offer during encounter/group combat. Test disappearing/replaced/duplicate offers, profile reset/import, and OFF→ON/child changes during deferral. No stale/repeated acceptance or forced popup disappearance; rejected requests must retain a manual path. Verify unrelated reminder appearance/readiness/audio does not reset when resurrection switches change.
8. Recheck enabled-profile cold-start icons, Raid Groups absent-placeholder apply behavior, marker center-release/native cursor cancellation, ready-item audio and glow in the actual client. Existing focused documents retain their own native acceptance cases; no mock result closes them.

## Historical baseline reference

The steps below describe the original **0.14.1-alpha** reference, including its visible HUD/demo/Quick Bar defaults. Use them only when testing that archived baseline. Current navigation and defaults are described above.

## Prepare

1. Close WoW. Back up the current `Interface/AddOns/RCPArsenal` folder and relevant `WTF` SavedVariables for `RaidArsenalDB`; do not delete the saved profile to install an update.
2. Verify the downloaded ZIP checksum with PowerShell: `Get-FileHash -Algorithm SHA256 <path-to-zip>`. Compare it with the adjacent `.sha256` file.
3. Replace only the addon folder with the ZIP’s `RCPArsenal/` folder under `_retail_/Interface/AddOns/`. Verify `RCPArsenal/RCPArsenal.toc` exists directly there, with no extra nested folder. Test the right game flavor.
4. Use a test character/profile for the fresh-profile path. Preserve the real raid configuration; if renaming saved-variable files for a clean test, do so while the client is closed and retain the backups.

## Baseline quick pass

1. Cold-launch the client. Record version/build from `/run print(GetBuildInfo())`, package filename and SHA-256, and `/run print(RCPArsenal and RCPArsenal.VERSION)`. Expected addon version: `0.14.1-alpha`. Record whether the client marks Interface 120100 out of date; loading out of date is not proof of compatibility.
2. Open `/rcpa config`. Confirm five pages: HUD, Quick Bar, Content, Scanning, Actions. Check icons/artwork on a full client launch and again after `/reload`. Record any blank icons or Lua errors.
3. Switch Compact/Detailed and accent, move/lock HUD and puck, reload and zone. Confirm stable saved positions. Import a copied local profile and verify both positions remain local. Keep an export before reset tests.
4. In a small raid, test regular member then assist/leader. Verify puck privileges, left-click countdown/second-click cancel, right-click ready check, middle-click pin. Another player’s countdown can leave the baseline’s local countdown tracking out of sync; record the result.
5. Before pull, confirm capability ownership and composition coverage labels. In combat, inspection must stop and capability tiles remain static. Do not interpret them as cooldown or buff uptime.
6. On a controlled roster, test one role sort, both split modes, and session undo. Record before/after subgroups. Check role balance first, then class/spec distribution, then movement. Only players who changed split side should receive the completion whisper. Verify no movement in combat and no untracked bench moves. This step requires sufficient people and should stay pending if unavailable.
7. Check tile left-click WHISPER/SAY/OFF, optional right-click Raid Warning, and Panic with appropriate permissions. Coordinate with testers first so callouts are expected. The current code uses one primary channel, despite older bundled help claiming two.

## First hub build acceptance additions

- Test fresh DB, copied schema-17 profile, and reset separately. Login, reload, raid join, ready check, and encounter must not activate optional overlays, demo, reminders, or automation. Open the hub explicitly and opt in to a module; reload must retain that choice.
- Import legacy and new profile strings while optional features are off; they must remain off unless the apply flow explicitly asks the player to enable them. Preserve both local positions and existing content/template values.
- With the six catalog tools absent, disabled, and installed/enabled in turn, confirm local status/version and useful copy/settings controls. A disabled addon is different from an absent addon; no approved-version data means unknown comparison.
- Record the new TOC/Core version and manifest commit. Do not close the health/reminder, resurrection, or two-client reporting checks until those modules exist and their separate test cases pass.

Report failures with the exact client build, ZIP checksum, addon version, profile origin, role/permissions, and shortest reproduction steps. Include the Lua error if one occurs. Restore backups if returning to the prior build. No steps above have been run in this Mac kickoff.

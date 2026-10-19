# RCP Arsenal Windows smoke test

Use the baseline ZIP to establish a real-client reference before the first hub patch. It contains unchanged **0.14.1-alpha** behavior, including visible HUD/demo/Quick Bar defaults. Quiet startup is a later acceptance test.

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

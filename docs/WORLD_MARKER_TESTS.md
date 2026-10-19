# World marker cycler Windows test

Historical detail. [Alpha.6 navigation, direct bindings and reminder polish](NAVIGATION_KEYBINDS.md) supersedes current entry/key-editor/default/glow/mute behavior; its Windows update steps use the existing checkout.

Test **0.14.2-alpha.1** and record `GetBuildInfo()`, the downloaded ZIP checksum, character, raid role, and any error/taint log. Source/API review uses Retail 12.1.5.70448; the addon still declares Interface 120100, which is not a compatibility guarantee. No steps here have been completed in a WoW client.

## Install and opt in

1. Close WoW and back up `Interface/AddOns/RCPArsenal` and the relevant `WTF` SavedVariables. Install the named release ZIP, not GitHub's source archive, with exactly one `RCPArsenal/` root. Preserve the saved profile.
2. Cold-launch with both a fresh profile and a copy of schema 17. Confirm no new marker panel/overlay or keys on login. The inherited HUD/demo/Quick Bar defaults are unchanged. `/run print(RCPArsenal.VERSION)` must show `0.14.2-alpha.1`.
3. Open Quick Bar → World markers, and separately `/rcpa markers`. Confirm the same subview, Quick Bar sidebar selection, working Back/close controls, and readable layout at UI scale 75%, 100%, 125%, and 200%. HUD-specific footer controls should be absent on this subview.
4. While off, build order blue square → green triangle → white skull. Adding a duplicate does not append it; remove/move controls affect the selected numbered slot. Editing must never place a real marker. Remove everything: empty stays empty through reload and profile import. Placement is inactive. Restore the three-marker order; enable explicitly.

## Bindings and placement

1. Open Blizzard Key Bindings → AddOns → RCP Arsenal — World markers. Assign distinct place-next and clear-all keys. Check conflict cancel/confirmation, secondary bindings, account/character binding mode, and unbinding. Confirm the two addon readouts update. Arsenal must not assign or replace another binding on enable, login, import, or reset.
2. With settings closed, point at valid terrain and press/release the place key four times. Expected attempts: square, triangle, skull, square. Each complete press/release advances once. Test both ActionButtonUseKeyDown values, modifiers, rapid taps, held key, and supported mouse-side bindings. There is no addon timer or autonomous placement loop.
3. Repeat with the Quick Bar disabled and with an existing world marker of the same type. Verify cursor placement rather than a second targeting click. Test cursor-over-UI/invalid terrain and record rejected attempts; the local cycle still advances on an attempt, without a success acknowledgement or retry.
4. Clear all should remove world markers, retain target/unit icons and the configured order, and restart the next attempt at slot 1. Test the clear key with an empty placement order too.

## Permissions, combat, and persistence

1. Test solo, normal party member/leader, raid member/assistant/leader, and promotion/demotion. Native permissions are authoritative. An ordinary raid member must not gain marker authority. Record actual solo/party limits rather than assuming all locations allow them.
2. Repeat placement/wrap/clear in open-world combat and a real raid encounter with appropriate authority. Look for blocked actions, taint, double advance, errors, and existing-marker behavior. Offline tests cannot establish these results.
3. Try changing enable/order/bindings through setup while in combat: edits must be unavailable. Any external profile-reset change queued during combat must report that the previous effective state remains until combat ends, then apply once. No insecure combat attribute mutation is allowed.
4. Disable outside combat and press both keys: neither acts. The user's saved bindings remain assigned; reassign/unbind in Blizzard settings if needed. Re-enable and confirm slot 1. Reload off/on and preserve the order; import current and legacy profiles without changing local opt-in/order or key assignments. An explicit full profile reset turns this feature off.
5. Reload during combat: secure frame creation is deferred, so marker keys may be unavailable until combat ends. Confirm recovery after combat, with no unexpected key takeover or login overlay.

Keep each failed or unavailable test open. Report a short reproduction with exact client/addon versions, key input, order, permissions, and logs; a recorded keypress is not evidence that placement succeeded.

# Disabled startup and package optimization — alpha.7

The goal is a quiet ordinary non-leader installation when optional tools are OFF, with passive addon-version and manual supply replies still available. All media remains byte-identical to alpha.6 (`7bba58b309036f78b5cb083adbabd3efbc8a2d0c`). This pass keeps one `RCPArsenal` folder, the existing 25-entry TOC, the Windows directory junction and every saved opt-in. It adds no profiler, polling service or profile-schema migration.

## Package audit

Alpha.6 contains 72 payload files totaling 4,300,888 bytes. Its 33 TGA files account for 3,433,874 bytes (80% of raw size); 25 Lua modules use 768,222 bytes, and the six reviewed OGG clips use 72,175 bytes. The largest single asset is the 1,048,620-byte panel atmosphere texture. Alpha.6's 4,310,752-byte ZIP stored every entry uncompressed.

The packager now explicitly deflates each entry at level 9 while preserving source bytes, ordering, timestamps, file permissions and the single-folder layout. Deflating the unchanged alpha.6 payload produces 825,207 bytes locally, an 80.9% reduction. The final alpha.7 archive has small additional code changes; its manifest/checksum records its exact size and identity. Extracted artwork, audio, font notice and credits are unchanged. There is no image resizing, sound transcoding, minification, obfuscation or comment stripping. Compression changes download size; it does not claim to reduce native texture memory or installed size.

## Runtime changes

- Core keeps a stable handler list and unsubscribes optional native events when no enabled subscriber needs them. Shared events remain registered. Reminder health signals use a native player-only unit filter while enabled.
- Reminder bag, health, usability and cooldown signals follow the reminder master; resurrection follows its own master. Inspection signals follow the HUD master. Encounter bookkeeping and explicit preview cleanup remain available.
- HUD and Quick Bar visuals are created only on enabled or explicit manual demand. Combat/encounter creation waits for the existing safe lifecycle path. Two small secure marker targets remain available for existing native CLICK bindings.
- Northern Sky observation, callback refresh and bounded readiness retries run only while its pane is visible. Hidden callbacks become inert even if the external API cannot unregister them. Reopening refreshes current state; write/undo ownership and context checks remain mandatory.
- Settings refresh only visible controls, lists and previews. Expanding reminder details refreshes newly visible fields, including preferences changed while collapsed. The settings shells are still created on first open.
- Readiness rejects bounded malformed protocol fields before roster identity work. A bounded 24-packets-per-name/15-second ingress budget (maximum 128 names/window) limits parsing cost and retains malformed-packet throttling. This budget does not authenticate senders. Existing current-roster/GUID authorization, separate GUID rate bound, leader permissions, nonce/deadline/replay checks and per-send restriction/identity checks remain required.

## Matched offline measurements

One identical actual-module probe was run against the exact alpha.6 tree and alpha.7 source with the same fresh profile, synthetic solo non-leader and frame/API mocks. These are allocation and call counters, not native WoW CPU, memory or FPS measurements.

| Scenario/counter | Alpha.6 | Alpha.7 |
| --- | ---: | ---: |
| Fresh OFF, settings unopened: mock objects | 115 | 5 |
| Fresh OFF: native event subscriptions | 32 | 18 |
| Fixed health/item/talent/lifecycle stream: event deliveries, including initialization | 1,616 | 16 |
| First Addons-only settings open: mock objects | 2,099 | 1,668 |
| OFF, unopened/closed: active timers / OnUpdate | 0 / 0 | 0 / 0 |
| Partial Northern Sky present, unopened OFF: retry timers | 1 | 0 |
| OFF signal stream: bag / health / cooldown / talent / inspect / send calls | all 0 | all 0 |
| Enabled carried-Healthstone fixture: bag / native alpha sink / cooldown calls | 7 / 2 / 1 | 7 / 2 / 1 |

The five fresh-OFF mock objects include the fixture's UIParent and GameTooltip; Arsenal owns one event frame and two secure marker targets. Previously created visuals remain allocated after deliberate use; disabling hides them and stops optional subscriptions/timers. An open Addons pane owns its existing matrix timer and bounded asset retry; closing stops both. Integration observation only follows an open integration pane.

Passive replies are intentional work: a valid group leader query may read current addon metadata and send a finite response queue even with every optional master OFF. Manual supply reporting may scan supported item counts after a valid authorized request. Current membership, permissions, restrictions and recipient identity are checked again before each queued send. Ordinary roster-change bookkeeping remains. This pass does not promise zero overhead.

## Native acceptance and next architecture choice

Use the existing Windows checkout: **Fetch origin → Pull origin**, then fully restart WoW. No reinstall, reset, folder moves or setup rerun is needed. Confirm version alpha.7 and test:

1. Ordinary non-leader, all masters OFF, settings unopened: compare the owner's native profiler over the same idle/group/encounter window. Record profiler/tool, game build, group size, addons and duration; separate load time, retained memory and steady CPU. Profiling/taint/render/input/audio remain unverified offline.
2. Have a leader query versions and supplies while the subject's masters are OFF. Confirm finite replies, current results and no auto-enabled feature. Leave/change group or enter a restricted state during queued responses; sends must stop.
3. Enable each saved tool, disable it, and re-enable it. Confirm fresh inventory/health/inspection state, saved overlay positions, captions/icons, no extra inspection when HUD is OFF, and no lingering timers after closing settings. Repeat a saved-enabled login and an enable during combat followed by leaving combat.
4. Open Personal Tools and expand Reminder text & sound for the first time; saved text, toggles and sound choices must be current. Collapse, change/import preferences through an existing supported path and re-expand. Reopen Northern Sky and verify fresh state, preview cleanup and guarded local edit/undo.

Keep this single-folder architecture for this pass. Separate load-on-demand sibling addons could defer parsed Lua and retained settings shells further, but would require a reviewed installer/junction change and dependency design. A later internal per-pane lazy rewrite is another option; neither is justified by synthetic counters alone. Use the native profile to select the next bottleneck. No CurseForge publication is authorized by this optimization pass.

## Alpha.8: small enabled-display polish

The expected automatic scan after joining a group is retained. Inspection report notifications now update the scan footer without repainting the unrelated Addons version matrix. Its existing visible one-second heartbeat updates age, restriction status and fresh native query eligibility using the last display snapshot. Readiness updates, explicit target/selection actions, addon loads and the stale-age boundary still refresh the matrix. Hover tooltips compute current ages when entered. Hidden pooled rows clear their tooltip closures so a shrinking group cannot retain whole historical snapshots; returning rows are reused and refreshed.

One unchanged probe ran actual modules against alpha.7 main `160d65811195ea0c934ac5602f7cd7b0d80c6f8e` and this patch with 28 synthetic raid members. Forty paired report/progress notifications while Addons was visible previously caused 40 snapshot copies, 20,400 recursive table copies and 18,160 matrix text writes; those unrelated matrix operations are now zero. Ten idle heartbeats drop from 10 snapshot copies /5,100 table copies /4,540 text writes to no snapshot/table copies and 10 status-label writes. Both retain the same 10 fresh eligibility checks and 280 UI identity-row reads. Ten unchanged roster signals drop from 20 to 10 matrix refreshes; current roster validation is retained.

These are offline source-operation counters, not measured native CPU/RAM/FPS savings. No scan engine, trigger, retry, queue, HUD, marker/key, protocol, per-send authorization, assets, install layout or default changes are included. Focused checks cover unrelated-report isolation, readiness/addon-load freshness, current hover ages, target draft focus, one-time stale transition, closed heartbeat cancellation and row shrink/reuse. Windows acceptance: update the existing checkout, fully restart, confirm alpha.8, and check the same Addons/scan workflow. The native screenshots do not establish an overscan defect or total-machine CPU percentage.

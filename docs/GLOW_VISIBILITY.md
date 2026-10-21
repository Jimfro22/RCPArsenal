# Consumable glow visibility repair — alpha.16

The alpha.15 owner captures showed a 56-unit Healthstone preview: Pixel read like a thin fixed gold outline, Autocast like small dashes and Action Button like a faint blurred edge. These stills establish weak style distinction, not absent motion or a live-health failure.

## Confirmed rendering-input defects

The local preview had an opaque three-unit gold backing. The default two-unit Pixel stroke travelled with its center one unit **inside** that backing, placing its entire thickness on nearly the same gold. Autocast used that inside route too, with small 4–7-unit sparks. Its four tiers also used the same initial normalized phases: only four distinct fractions for sixteen default sparks. These are source geometry/contrast and phase-input defects; they do not require guessing a native C animation implementation.

The repair gives Preview/Move the live reminder's dark backing and keeps the shared placement sample's backing neutral. Pixel and Autocast travel outside the icon box with at least one UI unit between the largest stroke/spark and the static backing. Autocast starts all tiers at distinct fractions. Its four size tiers are 12/10/8/6 UI units, multiplied by saved Size and a bounded icon-size factor (0.75–1.5). The largest spark stays between 4.5 and 27 units across all supported settings. The same shared renderer serves live and both sample paths.

Action Button keeps Blizzard's 6×5/30-frame proc-loop atlas, one-second base cycle, zero automatic frame dimensions, normal blend, and saved tint. Its footprint grows from 1.4× to 1.6× the icon so the halo reads outside the artwork. This is a visual geometry adjustment, not a claim that the native atlas contract was wrong. Every owned effect texture explicitly uses full ordinary alpha on the top overlay sublayer; the owned visual sits above its parent icon and does not clip its own outside geometry. There was no established old strata/clipping failure.

All new extents feed clamping. Item captions sit four units below the halo; the local preview heading clears halo plus bounce, and placement headings clear the halo. Empty-warning text retains its anchor. The touched everyday label uses **35% or lower** because the owner's font rendered the ≤ glyph as a box.

## Lifecycle and unchanged behavior

The renderer now shows its ordinary visual before calling native Play, matching Blizzard's proc/phase examples. The prior reverse order was an avoidable lifecycle difference, **not a proven universal cause**: Blizzard also supports templates that show a hidden parent in OnPlay. No new callback, progress query, polling or timer is introduced.

The existing translation/rotation sequence, native phase seek API and FlipBook layout remain. Their actual interpolation, corner motion, atlas appearance and blending still require the WoW client. No motion is inferred from the supplied stills.

Steady/gold stays default and fallback. Saved style/color/count/speed/size values, saved OFF, optional master defaults, native ≤35% alpha gating, health secrecy, item readiness/expiry, sound and marker behavior are preserved. No extra render objects are needed: the warmed per-owner cap stays 41 textures, 33 native groups and 177 tracks. Animated styles can continue while native-alpha-hidden but otherwise publicly eligible, as before. Public OFF/hide/empty/mask/stop cleanup remains.

Primary Blizzard references: [proc show-before-Play](https://github.com/Gethe/wow-ui-source/blob/b9be9379719047977fca4dba1bb1d9988e8840b3/Interface/AddOns/Blizzard_ActionBar/Shared/ActionButtonSpellAlerts.lua), [proc FlipBook layout](https://github.com/Gethe/wow-ui-source/blob/b9be9379719047977fca4dba1bb1d9988e8840b3/Interface/AddOns/Blizzard_ActionBar/Shared/ActionButtonSpellAlerts.xml), and [native phased Play example](https://github.com/Gethe/wow-ui-source/blob/b9be9379719047977fca4dba1bb1d9988e8840b3/Interface/AddOns/Blizzard_UnitFrame/Mainline/EssenceFramePlayer.lua).

## Verification and owner acceptance

The regression harness measures actual configured UI-unit bounds, outside separation, loop closure inputs, distinct phase fractions, clamp/label clearance, start ordering and the native proc layout at 24/56/128 for both item samples and live paths. It rejects captured alpha.15 renderer and preview modules for the exact overlap and gold-backing defects. It does not simulate a native engine or certify rendered motion.

After reviewed GitHub delivery: **Fetch origin → Pull origin → full WoW restart** in the existing checkout. No reinstall, reset, setup rerun or junction change. Compare Steady, Pixel, Action Button and Autocast with default gold/1×/56 first, then 24/128 and control extrema. Use short native clips over several cycles; verify discrete outside lines/sparks/proc halo, corner/phase motion, no caption/heading overlap, both item kinds, local/global samples, live native-health gates, OFF/empty/hide cleanup and unchanged sound/marker behavior. Native visual, focus/combat/taint and exact health-boundary acceptance remain pending. CurseForge stays held.

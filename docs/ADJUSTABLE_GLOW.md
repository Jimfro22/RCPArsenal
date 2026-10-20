# Adjustable reminder glow — alpha.13

Personal Tools has one initially collapsed **Glow settings** disclosure alongside Text & Sound. Opening either closes the other to fit the existing panel. The everyday **Icon glow at ≤35%** switch remains visible. Steady border and the existing warm gold remain the default; existing users gain no animated cost until choosing an animated style. No media or branding changes, library dependency, or broader UI redesign.

All styles share a native RGB color picker. Only the selected style's controls appear; switching preserves inactive values. Appearance can be prepared while the reminder and glow are OFF. **Reset glow settings** resets style/color/all style values, preserving both feature switches, health threshold, combat policy, sound, size and position. Reset, disclosure close, navigation and profile changes dismiss only Arsenal's own picker and invalidate stale callbacks. Ordinary Cancel restores the current edit's original color.

| Style | Controls / defaults | Native implementation |
| --- | --- | --- |
| Steady border | Shared color: gold `(1, .72, .18)` | Original eight static edge/halo textures |
| Pixel Glow | Lines 1–12 (8); Speed .5×–2× (1×); Line length 4–16 UI units (10); Thickness 1–4 (2) | One rectangular texture per line; four native translations and four brief corner rotations; phase offsets distribute lines |
| Action Button Glow | Speed .5×–2× (1×) | Blizzard's current proc-loop atlas: native 30-frame, 6-row/5-column FlipBook, 1.4× icon footprint, desaturated then tinted |
| Autocast Shine | Particle groups 1–8 (4); Speed .5×–2× (1×); Size 50–150% (100%) | Four sparks per group, in four size/rate tiers, using built-in `Interface\Cooldown\star4` and native square translations |

Speed is the native animation rate multiplier, so larger means faster. Autocast size affects sparks, not icon size. Pixel and Autocast are independently authored renderings of those styles; native corner motion, particle appearance and atlas tint require client acceptance.

## Health, lifecycle and cost

The existing native Step curve and direct `UnitHealthPercent("player", true, glowCurve35)` → owned alpha sink remain. That gate is a separate ancestor above the renderer. No renderer receives health/alpha, reads alpha, evaluates secret data, or performs item/readiness work. Both Healthstone and potion use the saved style. Empty warnings never glow. The main threshold still gates the whole reminder, including when below 35%.

The renderer adds no Lua OnUpdate, ticker, timer, animation callback, scan or idle event subscription. Native animation may continue when publicly eligible but invisible at opaque native alpha 0; no exact health-based animation stop is claimed. Steady border has no animation cost. Public master/glow OFF, combat/life/candidate suppression, empty warning, placement mask and sample close stop native groups. An owned OnHide hook cleans up inherited parent hiding. Health events only sink native alpha and idempotently start an already prepared renderer; they allocate/rebuild nothing and do not restart an active animation.

Per live/sample owner, pools cap at 32 moving textures/groups, one proc texture/group, eight steady fallback textures: **41 textures, 33 groups, 177 animation tracks** after every style/count has been exercised. Pixel uses at most 12 moving lines; Autocast at most 32 sparks. Color dragging, size/count/style edits reuse these objects. A partially failed native Play stops every started group and shows the already prepared steady fallback; failed atlas/animation configuration also falls back. Native runtime cost is bounded, not benchmarked in-game.

Glow-only edits update live/sample geometry and halo clamps without refreshing item readiness, replacing its expiry timer or changing sound eligibility/latch. The NativeWarningAudio and HealingSupplies source are unchanged. Already-active silent Preview/Move and global placement samples follow saved appearance for both item kinds; edits do not start samples, play audio, apply Setup drafts or move anchors. Setup saves preserve style values. Existing local personal preferences remain local across portable profile import; malformed saved appearance normalizes safely. Profile schema remains 19; the settings are additive.

API evidence: Blizzard UI source pinned at `b9be9379719047977fca4dba1bb1d9988e8840b3`, `SimpleAnimGroup` Play offset and speed multiplier, Translation/Rotation APIs, and [current proc FlipBook definition](https://github.com/Gethe/wow-ui-source/blob/b9be9379719047977fca4dba1bb1d9988e8840b3/Interface/AddOns/Blizzard_ActionBar/Shared/ActionButtonSpellAlerts.xml). LibCustomGlow was a behavior/cost reference; no implementation or media was incorporated.

## Verification and Windows acceptance

Actual-module mocks cover opaque below/at/above-35% behavior for both items; style controls, bounds and inactive retention; OFF edits; reset/profile/picker ownership; bounded reuse; public cleanup; partial native failure; clamp updates at icon sizes 24/56/128; silent samples/Setup; and unchanged item-expiry/audio behavior. These checks do not certify native rendering, rotation/translation composition, offset phasing, precise threshold equality, taint or combat restrictions.

After reviewed GitHub delivery, update the existing Windows checkout with **Fetch origin → Pull origin → full WoW restart**. Keep its current junction and settings.

- Confirm alpha.13, legacy Steady/gold and saved OFF. Open/close both disclosures; check labels and all controls at ordinary UI scale.
- Try each style on Healthstone and potion at icon sizes 24, 56 and 128, near all screen edges. Confirm count, speed direction, color, line length/thickness, spark size, smooth perimeter/corner motion and proc atlas/tint.
- Verify visible glow at/below 35%, clearing above, main threshold below 35%, combat policy, death, empty bags and both feature switches. Animated work can remain native-alpha-hidden while otherwise eligible.
- Check live Preview/Move and global placement updates; stopped and empty samples stay quiet. Reset with Color open, then Cancel; gold must remain. Navigation/profile changes close only Arsenal's own picker.
- Check automatic known-ready sound and manual sound Preview retain alpha.12 behavior. No CurseForge publication is included.

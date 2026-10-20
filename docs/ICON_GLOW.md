# Healthstone and potion icon glow — 0.15.3-alpha.11

Both a visible Healthstone icon and a visible healing-potion icon can use the existing steady gold edge and restrained outer halo at or below 35% health. Above 35%, the glow clears. The main reminder's saved visual threshold, master, combat policy and life-state gates still apply to the entire icon and glow. A main threshold below 35% therefore keeps the whole prompt hidden until that lower threshold. OUT OF POTIONS! has no icon or glow.

Personal Tools exposes **Icon glow at ≤35%** beside the text/sound disclosure, visible in compact and expanded layouts. Welcome uses **Icon edge glow** and an icon-glow summary. The existing local `reminderStoneGlow` preference is retained: valid saved OFF stays OFF; unset defaults ON for compatibility. The reminder master remains optional and OFF by default, and schema stays 19. Editing glow while the master is OFF creates no live reminder or health work. Editing the switch while enabled changes only the owned visual, preserving the cached supply readiness and its expiry timer.

The implementation reuses the unchanged fixed native 35% curve, existing artwork and opaque health-alpha display sink. Health events write native output directly to the owned glow's alpha sink without Lua health/alpha comparisons or readback. The potion uses the same halo/bounce clamp allowance as the stone. Global placement samples depict the saved glow for stone/potion and clear it for empty. Sample visuals perform no item, health or sound action.

Glow curve or sink failure suppresses only the glow; the main reminder and existing readiness-expiry work remain. A health event can recover a transient sink failure but never retries a failed curve creation. No new scan, readiness query, polling loop, timer or audio trigger is added. The existing NativeWarningAudio implementation, known-ready automatic-sound gate, consumed episode latch, manual sound Preview and sound CVars are unchanged. See the [ready-item audio contract](READY_CONSUMABLE_AUDIO.md).

## Verification and Windows acceptance

Actual-module tests cover both kinds below/at/above 35%, recovery, a main threshold below 35%, kind changes, saved OFF, empty/dead/combat-hidden/master-OFF states, glow curve/sink failure and unchanged item/readiness/timer work. The integrated audio test verifies glow edits cannot reset, replay or stop automatic audio or refresh item readiness. Hub checks verify the compact control bounds, label/helper fit, expanded-layout separation and OFF preference behavior. Welcome and placement checks cover the updated copy and sample kinds. These mocks do not establish native font fit, precise curve boundary behavior or actual in-game visibility.

Update the existing Windows checkout with **Fetch origin → Pull origin**, then fully restart WoW. Confirm alpha.11; retain the existing checkout/junction and saved settings.

- With the reminder enabled in its allowed context and a visual threshold above 35%, test a ready Healthstone and a ready potion. Check steady glow at/below 35%, clearing above 35%, and recovery without an extra health/animation wait.
- Switch between stone and potion; check gold edge/halo visibility at icon sizes 24, 56 and 128 and near screen edges. Empty bags should keep the text-only warning without a glow.
- Set a main threshold below 35%: the whole icon/glow must remain hidden until that threshold. Check combat policy, death, master OFF and saved glow OFF. Reopening Welcome or Personal Tools must retain OFF.
- Check the Personal Tools glow toggle with text/sound collapsed and expanded. Confirm text stays readable and controls remain separate. Manual sound Preview and alpha.10's known-ready/no-catch-up automatic-sound behavior must remain intact.

Native rendering/visibility and restrictions remain owner acceptance. CurseForge remains held.

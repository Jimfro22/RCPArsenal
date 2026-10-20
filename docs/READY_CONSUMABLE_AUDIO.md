# Ready-item automatic sound — 0.15.3-alpha.10

Automatic low-health sound, including the owner's Sound 6 ("Watch out"), now requires at least one carried Healthstone or supported healing potion positively known ready and usable. Empty bags, unknown inventory/readiness, all items on cooldown, and all unusable items stay silent. A cooling Healthstone does not suppress a positively ready potion. This applies to every selected automatic sound.

PersonalTools records readiness during its existing bounded supply refresh: bag/data events, cooldown/usability signals, allowed policy/life transitions and the existing single public cooldown-expiry timer. The native-warning eligibility getter reads that cache only. Health events and native warning hooks perform no inventory, cooldown or usability queries; no polling or new timer is added. Readiness means the existing public cooldown/usability checks, not a guarantee that the client will allow an item action in every context.

An explicit readiness-change notification silently reconciles the existing audio latch. Losing eligibility stops only Arsenal's owned automatic sound handle. Gaining eligibility while Blizzard's warning is already active neither plays nor rearms that episode. A later genuinely eligible own-warning clear and new warning can play once. The latch still consumes an episode before requesting playback, including muted/failed playback. No health or alpha value is compared or converted by Lua, and Blizzard's warning and sound CVars are unchanged.

Visual behavior stays independent: confirmed empty bags retain OUT OF POTIONS!, and Show while on cooldown can still display a carried cooling/unconfirmed item. Neither visual option grants automatic sound eligibility. Manual Preview sound remains explicit and works with empty bags or the reminder master OFF; it neither changes preferences nor rearms automatic playback. Native sound remains tied to Blizzard's warning, normally around 35%, independently of the saved visual threshold.

Fresh, unset and invalid reminder combat modes now default to In combat. Existing valid Both, In combat and Out of combat choices are preserved. The reminder master remains opt-in and defaults OFF; profile schema remains 19. Saved sound choice/channel/mute permission, thresholds, placement and other tools remain intact.

## Verification and Windows acceptance

The integrated offline harness loads actual HealingSupplies, PersonalTools and NativeWarningAudio modules together. It covers empty/unknown/cooling/unusable supplies, ready stone/potion and cooling-stone plus ready-potion fallback; visual cooldown and empty states; supply loss and recovery while low; public expiry; both native/addon combat callback orders; manual Preview; no health/native-hook item queries; and quiet disabled events. Existing native-audio tests retain consume-before-playback and lifecycle coverage. These mocks do not establish native audibility, restrictions, taint or hardware acceptance.

Update the existing Windows checkout with **Fetch origin → Pull origin**, then fully restart WoW. Confirm version 0.15.3-alpha.10. Keep the existing junction and saved settings.

- With the reminder enabled and Sound 6 selected, enter an allowed combat context with no supported healing items: the empty visual may show, but Arsenal's automatic "Watch out" must stay silent.
- Repeat with every carried item cooling or unusable, with Show while on cooldown OFF and ON. Unknown readiness must also stay silent.
- Test a ready Healthstone, ready potion and cooling stone plus ready potion. A fresh eligible native warning can play once.
- Lose the final ready item during an alert: only Arsenal's automatic handle should stop. Regain a ready item while still low: no catch-up sound. After a genuine eligible native clear/new warning, one new alert is allowed.
- Explicit Preview sound must work with empty bags and with the reminder OFF. Preserve valid saved combat choices; fresh/unset mode should be In combat with master OFF.

CurseForge remains held for explicit owner approval.

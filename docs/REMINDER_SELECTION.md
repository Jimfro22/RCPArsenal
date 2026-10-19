# Reminder selection and audio - 0.15.3-alpha.5

Historical detail. [Alpha.6 navigation, direct bindings and reminder polish](NAVIGATION_KEYBINDS.md) supersedes current entry/key-editor/default/glow/mute behavior; its Windows update steps use the existing checkout.

This update supersedes the item-selection, audio-selection and empty-caption details in the historical [alpha.3 visual/supply contract](HEALING_SUPPLIES.md) and [alpha.4 native-warning contract](NATIVE_WARNING_AUDIO.md). Their native health sink, audio latch, opt-in and raid authorization rules remain in place. Profile schema stays 19. Existing saved thresholds, text, icons, positions, profiles, font/logo corrections and other tools remain intact.

## Controls and behavior

Personal Tools > Reminder text & sound adds an independent Empty text size (48 by default, 16-96), Show while on cooldown (OFF by default), Sound Effects / Master channel, and a sound dropdown. Sound Effects is the explicit default route for migrated/unset settings; a valid saved route is preserved. Built-in alert remains the default choice. Sound 1 through Sound 6 are the six owner-supplied recordings converted to Ogg Vorbis. No gain, trim, remix or normalization was applied. [Asset provenance](../provenance/user-alert-audio/README.md) records transformation and file validation. Source MP3s remain untouched outside the runtime package.

Choosing a sound or channel is silent and does not rearm the warning, refresh inventory or query health. Preview explicitly requests the chosen sound through the chosen route without changing the automatic latch. Both automatic and preview playback use the same fixed catalog: PlaySound for kit 12889 or PlaySoundFile for a reviewed addon path, with an explicit SFX or Master channel. Saved variables cannot supply arbitrary paths or kit IDs. There is no automatic channel fallback or CVar write.

Feedback names the selected route. Public, guarded zero/mute CVar readings on a playback request can identify disabled WoW sound, zero Master volume, and (for SFX only) disabled/zero Sound Effects. Unknown/secret/error readings are not asserted as mute. Otherwise failed playback reports only that the request failed. A successful public result means requested, not proven audible. Master does not bypass the global sound switch or zero Master volume. The prior screenshot does not establish which channel caused the failure.

Automatic audio still follows Blizzard's native low-health warning, normally 35%, independently of the configurable visual threshold. The same guarded hooks, conservative clear/show latch, opt-in, life/combat policy, world bootstrap and separate owned preview/automatic handles apply. No audio polling, health reads, inventory reads or retries are introduced.

## Ready-item selection and empty warning

The local visual prefers a known-ready carried Healthstone, then a known-ready carried supported healing potion in ranked order. A cooling or unknown stone cannot suppress a known-ready potion. With Show while on cooldown OFF, carried supplies without confirmed readiness suppress the item prompt. ON allows the first carried candidate as a fallback, including unusable/unknown readiness; the helper and status distinguish that broad fallback from a confirmed cooldown or ready state.

Only independently confirmed absence of both supported kinds displays **OUT OF POTIONS!** at low health. Unknown inventory or carried-but-cooling items cannot assert empty. The empty warning uses the existing native-alpha reminder and saved icon anchor, with its icon/background hidden. Ordinary text remains 8-32. The empty caption is one unwrapped line with its own size, public viewport fitting and clamp bounds covering the entire caption plus animation. A temporary viewport fit does not rewrite the saved size or anchor. Preview includes an explicit Empty sample; Move uses the existing sample drag anchor.

Readiness uses guarded C_Item.GetItemCooldown and C_Item.IsUsableItem on cached candidate IDs. The cooldown API's third return must be a public boolean; legacy numeric enable flags, malformed/secret/failed outputs, disabled cooldowns and uncertain usability do not prove ready. Positive future start+duration is a public cooldown deadline. Ready requires inactive/expired cooldown plus public usable=true and insufficientPower=false. No bag scan or cooldown/usability query occurs on health events.

Bags remain bounded and event-driven. BAG_UPDATE_COOLDOWN, ACTION_USABLE_CHANGED, SPELL_UPDATE_USABLE and PLAYER_LEVEL_UP reconcile cached candidates while enabled. A single cancellable timer targets the earliest public cooldown expiry plus 0.05 seconds, rechecks only cached candidates, and uses generation/snapshot guards. It can schedule the next distinct public deadline, never a repeated expired deadline. Disable, inventory invalidation, policy/life changes and native sink failure cancel stale work. No ticker or polling loop is used. An expiry refresh uses the existing direct opaque native health-alpha sink, without a Lua health decision or automatic audio action.

## Supported map and raid compatibility

Map version 2026-10-19.2 / revision 2 recognizes Healthstones 224464 and 5512, then potion IDs 271884, 271883, 245918, 241304, 245919, 241305, 244849, 244839, 244838, 244835, 212944, 211880, 212943, 211879, 212942 and 211878. Cached class 0/subclass 1 items with use-spells 1295247, 1234768, 1238009 or 431416 provide the narrow fallback. Mana/stat/Light's Potential exclusions remain. Candidate IDs are deduplicated, ranked and capped at 32, keeping known supported items before generic fallback.

The manual raid check remains carriage-only and never queries cooldown/usability. Protocol 1 now sends map revision 2; incompatible revision-1 requests/replies are ignored. Older clients therefore remain No reply/Unknown rather than contributing false zeroes. Existing authority, nonce, roster, rate, window and response limits are retained.

Data references: the API research contract uses [Blizzard API source b9be9379](https://github.com/Gethe/wow-ui-source/tree/b9be9379719047977fca4dba1bb1d9988e8840b3) and [AutoPotion data pin 80196daa](https://github.com/ollidiemaus/AutoPotion/tree/80196daa5f56d6e3db8bf9a9898cfb438aebdb39) for reviewed item facts only. The implementation is independently authored; no third-party item-selection logic is copied.

## Validation and Windows acceptance

Source checks cover all six asset hashes and Vorbis headers, file whitelist/missing/tampered rejection, fixed sound routes and quiet selection, guarded mute feedback, audio lifecycle, ready potion versus cooling/unknown stone, unknown versus empty, public expiry cancellation, map-2 compatibility and full viewport bounds. These checks do not establish native permission, audio output, font fit or cooldown behavior in the client.

Use the existing GitHub Desktop checkout: Fetch origin, Pull origin, fully exit and restart WoW; confirm /run print(RCPArsenal.VERSION) is 0.15.3-alpha.5. Do not reset/reinstall/move the junction. Check all seven sounds on both routes, mute/volume feedback, silent selection and explicit Preview. Check ordinary combat plus restricted raid/PvP, native warning recovery/re-entry and prior latch/parent/fullscreen behavior. Check ready-stone priority, cooling-stone versus ready-potion fallback, cooldown expiry without a bag move, Show while on cooldown OFF/ON, unknown data and confirmed empty bags. Preview Empty at default 48 and near screen edges, change UI scale/resolution and confirm saved size/anchor survive. Run matching-map raid checks with an older/no-reply member. Native audibility, rendering, restrictions, taint and owner preference remain pending. CurseForge is held for explicit owner approval.

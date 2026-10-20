# World-marker wheel cancellation and ground targeting — alpha.15

The optional wheel uses the existing Place and Clear binding identities. Every center/no-sector release closes the gesture without placing a marker, including a quick tap or stationary long hold. All eight outward sectors remain available. Turning the wheel OFF keeps the normal sequence's existing down-phase action.

Right-click cancellation has two supported hardware routes: a protected full-viewport button while the hold is active, plus temporary secure BUTTON2 overrides for every Ctrl/Alt/Shift combination. Escape receives the same modifier coverage. The catcher exists from key down, including the visual delay, and registers only right-button clicks; native pass-through preserves left/middle/side-button input. It is hidden outside the gesture. Coverage is the game viewport; another addon's exclusive modal input and OS windows are outside this control.

The restricted reset clears held state, macro and transient bindings, hides the catcher and stops presentation before a later Place-key release can act. Clear, native UI hide and existing context/editor/placement suppression retain their cleanup paths. Motion-only aim frames are unnecessary now that every center release cancels and have been removed. Sector calculation still runs in the restricted hardware release; visual cursor feedback is presentation only.

## Ground targeting

The owner-selected flow is: hold the Place key, choose a sector, release to open Blizzard’s normal ground-targeting reticle, then left-click the intended ground point. The restricted release fully closes/resets the wheel before issuing `/wm N`. Right-click or Escape cancels Blizzard’s targeting after the wheel closes. Center/no-sector releases still do nothing. The normal non-wheel sequence retains its existing instant `/wm [@cursor] N` action.

No addon reticle/completion state, direct targeting API call, cursor movement, synthetic click or target-completion polling is added. The native client owns the reticle, the genuine ground click and cancellation; terrain and permissions remain Blizzard checks.

No supported saved-ground-coordinate action was found. Blizzard documents `PlaceRaidMarker(index, optional token)` and its secure worldmarker action passes a marker index, without a coordinate argument. Restricted `$cursor` anchoring snapshots a two-dimensional UI location, not a ground raycast. No OS cursor movement, synthetic click, coordinate injection or provisional marker is used.

Quick-tap random placement is removed in wheel mode because the restricted environment exposes no clock/timer for classifying it. The ordinary visual delay cannot safely write secure action state in combat. No protected state is changed by presentation Lua, and no saved keybind is changed.

Primary Blizzard source inspected at `b9be9379719047977fca4dba1bb1d9988e8840b3`:

- [Secure slash command](https://github.com/Gethe/wow-ui-source/blob/b9be9379719047977fca4dba1bb1d9988e8840b3/Interface/AddOns/Blizzard_ChatFrameBase/Shared/SlashCommands.lua) parses the marker and optional targeting token before Blizzard calls its protected marker API.
- [Marker arguments](https://github.com/Gethe/wow-ui-source/blob/b9be9379719047977fca4dba1bb1d9988e8840b3/Interface/AddOns/Blizzard_APIDocumentationGenerated/RaidMarkersDocumentation.lua).
- [Secure worldmarker action](https://github.com/Gethe/wow-ui-source/blob/b9be9379719047977fca4dba1bb1d9988e8840b3/Interface/AddOns/Blizzard_FrameXML/SecureTemplates.lua).
- [Restricted functions](https://github.com/Gethe/wow-ui-source/blob/b9be9379719047977fca4dba1bb1d9988e8840b3/Interface/AddOns/Blizzard_RestrictedAddOnEnvironment/RestrictedEnvironment.lua), [frame cursor/binding operations](https://github.com/Gethe/wow-ui-source/blob/b9be9379719047977fca4dba1bb1d9988e8840b3/Interface/AddOns/Blizzard_RestrictedAddOnEnvironment/RestrictedFrames.lua), and [supported event wrappers](https://github.com/Gethe/wow-ui-source/blob/b9be9379719047977fca4dba1bb1d9988e8840b3/Interface/AddOns/Blizzard_RestrictedAddOnEnvironment/SecureHandlers.lua).
- [Protected pass-through API](https://github.com/Gethe/wow-ui-source/blob/b9be9379719047977fca4dba1bb1d9988e8840b3/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScriptRegionAPIDocumentation.lua), configured only outside combat.

## Native acceptance

Offline actual-module/snippet checks cover center/tap/long-hold/center-return, all eight sectors, cancel modifier combinations, direct right-click before/after visual display and outside the wheel, side-button pass-through, repeated release, stale timer, clear/context/editor cleanup, normal sequence behavior and unchanged binding identities. Alpha.15 checks all eight `/wm N` selections, wheel cleanup before the protected action and no input capture or restarted timer afterward. They cannot prove native focus, camera/mouse-look routing, terrain, permissions, combat taint or OS behavior.

After reviewed delivery, update the existing Windows checkout with **Fetch origin → Pull origin → full WoW restart**, without reinstalling, resetting settings or changing the junction. Test right-click while Ctrl/Alt/Shift remain held, at center/selected sectors/view edges and during the visual delay; release the Place key afterward and verify no marker. Select each sector and release: the wheel must close and the native reticle must appear, with no immediate marker. Left-click a deliberate ground point to place; repeat and cancel with native right-click and Escape. Check center releases and quick taps, side-button bindings, all sectors and instant normal sequence with wheel OFF, both native action-keydown settings, combat and mouse-look released before choosing. Native acceptance of these input changes remains pending. CurseForge remains held.

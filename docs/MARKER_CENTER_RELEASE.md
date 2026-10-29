# Instant placement and a separate wheel (alpha.26)

**Place next is always instant on key down.** It uses the existing `CLICK RCPArsenalWorldMarkerCycle:LeftButton` binding and `/wm [@cursor] N` path. Its release does nothing. Mouse movement, the optional wheel setting and the old saved `radialEnabled=true` choice cannot turn it into a wheel gesture. Clear keeps its existing binding identity. No existing key is reassigned.

The new `CLICK RCPArsenalWorldMarkerWheel:LeftButton` action starts **Unbound** and appears in the inline binding editor and normal WoW AddOn keybinds. Enable the optional wheel and choose one physical key different from Place next/Clear. Two modifier aliases of that same physical wheel key are supported; two different physical wheel keys are not. Conflicting, unsupported or unreadable setups disable only the wheel and show a reason. No key is copied, chosen or overwritten automatically.

Hold the separate wheel key, swipe toward a marker and release to open the native ground-targeting reticle. Perform a separate real ground click to place it. Center release cancels. Right-click/Escape cancels the held wheel; after the reticle arms those inputs return to Blizzard's native targeting cancellation. The wheel uses decorative, non-clickable icons. It has no clickable alpha.25 icon hitboxes or persistent binding router, and it does not classify quick versus long presses.

| Clockwise from the top | World-marker ID | Artwork |
| --- | --- | --- |
| North | 1 | Blue square |
| Northeast | 2 | Green triangle |
| East | 3 | Purple diamond |
| Southeast | 4 | Red cross |
| South | 5 | Yellow star |
| Southwest | 6 | Orange circle |
| West | 7 | Silver moon |
| Northwest | 8 | White skull |

The displayed icon positions, cosmetic highlight and restricted release formula use that order. The circular center-cancel radius is 28 UI units plus 0.01 unit numeric tolerance. A visible rounded center region shares that size. The origin is captured from normalized root mouse coordinates and the root's UI rectangle; decorative artwork is anchored to that same root-local point. Preview converts raw cursor pixels with the captured effective scale. No independent clamping moves the artwork away from the authoritative origin, so a wheel opened near an edge can be clipped. An outside-window release cancels. Root position, width, height or scale changes during a hold reject selection and clear preview highlights.

Only wheel down installs temporary routes: its one physical key's modifier variants plus Escape/right-click. Place next/Clear keys are excluded by the configuration guard. Cancellation hides the wheel, drops cancel/mouse capture and keeps only the wheel's release routes until key-up, suppressing repeats. Normal release clears every wheel capture before issuing the final macro from the separate, still-shown action button. Configuration/profile/binding changes clean up outside combat. There is no ordinary protected timer cleanup in combat. A native lost release cannot be promised to self-heal; right-click/Escape is the explicit recovery path. Cosmetic preview stops polling after ten seconds, clears highlights and states that the wheel is still armed, without changing secure selection permission.

Alpha.25 coupled instant placement to a primary-key popup and a persistent source-tagging router, and native owner acceptance failed. Those mechanisms are removed. Offline tests establish source behavior and controlled geometry; they do not prove the original native stuck-popup or incorrect-icon cause. Fully restart or reload WoW after updating so prior alpha.25 frames/routes are discarded.

Automatic selection retains inactive-first order, all-active wrap/reuse, custom/empty orders, local issued/pending history and Clear. Readable activity resync remains bounded and outside known combat. All eight results must be ordinary booleans before any snapshot attribute changes; unavailable/secret results keep the prior snapshot. Combat/unreadable state uses the last snapshot and local reservations until safe resync. An issued macro or armed reticle is not placement acknowledgment. A manual world marker can guide the next configured position without changing saved order. `/dump RCPArsenal.WorldMarkers:GetLastAction()` reports only the latest owned request/no-op.

Primary-source contracts reviewed October 28: Retail 12.1.5 build 70575 at `15881d522c44cd106d3d8660106ec9f9d2f44167`: [restricted geometry and binding methods](https://github.com/Gethe/wow-ui-source/blob/15881d522c44cd106d3d8660106ec9f9d2f44167/Interface/AddOns/Blizzard_RestrictedAddOnEnvironment/RestrictedFrames.lua), [secure click phases](https://github.com/Gethe/wow-ui-source/blob/15881d522c44cd106d3d8660106ec9f9d2f44167/Interface/AddOns/Blizzard_FrameXML/SecureTemplates.lua), and [secure wrapper dispatch](https://github.com/Gethe/wow-ui-source/blob/15881d522c44cd106d3d8660106ec9f9d2f44167/Interface/AddOns/Blizzard_RestrictedAddOnEnvironment/SecureHandlers.lua).

## Native owner checks

Confirm existing Place next/Clear keys are preserved and the new wheel key is Unbound. Test moving primary taps with the legacy wheel setting on, optional wheel unbound/bound/disabled, and while holding the separate wheel. Verify down-phase instant requests and no primary popup. Then test every rendered wheel icon/sector across UI scales and screen locations, center release, modifiers, side buttons, cancellation, repeats, Clear, context/focus changes, root/scale changes and the paused-preview recovery cue. Test binding conflicts without overwriting keys and a real ground click after each reticle. Check combat, native action-keydown CVar settings, authority, terrain, mouselook, other UI/addon overrides and taint. Retest active Diamond, custom/empty/all-active orders and activity-readability limits. Native acceptance remains open; these checks are not satisfied by assertion volume.

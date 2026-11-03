# Defensive availability capture

Alpha.51 adds a guarded native cooldown-widget observation to the existing
Death Log recorder. Successful casts and availability remain separate facts.
There is no layout change or new polling loop.

Alpha.52 fixes the availability audit dropping the `nativeCooldown*` and
`ownCooldown*` evidence when projecting a frozen check for the readable
`/rcp recapfacts` report. The report now uses the same classification inputs
as the badges, including for saved alpha.51 captures. Regression checks
compare the shelf, audit, readable report and saved/reloaded report for both
ready and unavailable results, while retaining unconfirmed failures.

## Problem and approach

An ordinary spell can return a public active-cooldown flag without an
event-qualified global-cooldown flag. Charged spells can hide their remaining
count. Neither successful use nor an active recharge alone proves that the
spell was unavailable at death.

When those ordinary observations cannot establish availability, the recorder
requests `C_Spell.GetSpellCooldownDuration(spellID, true)` (ignore global
cooldown). A private, unprotected `Cooldown` child receives that duration via
`SetCooldownFromDurationObject`. Its parent stays hidden. Only a **public
boolean** returned by the child's `IsShown` can become a recorded fact.
Protected returns are rejected before comparisons.

The child is first primed with a known active public cooldown, then fed the
real duration. It is cleared and fed the same duration again. Both reads must
be public and agree. This rejects stale widget state, no-op setters, errors,
and expiration during the observation. The child is cleared afterward and
the duration object is discarded. One parent/child pair is reused; nothing
is attached to Blizzard's cooldown viewer or action bars.

The frozen boolean, check time, source and status are saved with the death.
History loading uses those fields without querying the player's new state.
Existing pending-cast, identity-change and stopped-recording checks still
invalidate readiness. Explicit readable charge counts retain precedence.

## Evidence and limits

- Blizzard's generated [cooldown widget API](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/FrameAPICooldownDocumentation.lua)
  documents duration-object assignment and clearing a zero duration.
- The [shown-state getter](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua)
  may itself return a secret. That is a failed observation, never a saved
  ready/unready guess.
- [GloomsAuras' native investigation, section 9.3](https://github.com/GloomSuite/GloomsAuras/blob/main/docs/API-NOTES.md)
  reports that the main cooldown widget is hidden at both two and one Aimed
  Shot charges, and shown at zero. This is a useful independent native
  observation, not proof for every client, spell or instance restriction.

Offline tests verify transport guards, both charge outcomes, global cooldown
separation, pending-cast invalidation, expiration/recharge replacement,
serialization and reload. They do **not** implement or certify Retail's
native secrecy, duration selection or widget behavior.

Before calling the new path verified, check Arcane Mage in the native client:
one Barrier charge remaining must be available; zero must be unavailable;
Mirror Image immediately after use must be unavailable. Reopen the same
death after `/reload` and compare the results. Use `/rcp recapfacts` for the
readable report; `/rcp recapdebug` includes `nativeCooldown*` provenance if
the native check needs investigation. Repeat in a raid or dungeon before
claiming that restriction context is validated.

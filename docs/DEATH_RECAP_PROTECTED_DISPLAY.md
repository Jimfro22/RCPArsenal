# Protected incoming display test

Alpha.61 repairs an explicitly armed experiment, separate from the normal Death Log.
One owner dungeon capture confirmed visible protected amounts after death.
Alpha.62 integrates that route into the [normal incoming view](DEATH_RECAP_NATIVE_INCOMING.md);
this manual probe remains useful for diagnosis.
It tests whether protected incoming amounts can remain visible through native
widgets after the player's death. Native acceptance is pending.

## Owner test

1. Update to alpha.61 and `/reload` **before** the test. Enable Personal Tools > Death Recap.
2. Inside a dungeon or raid, while alive and outside combat, run `/rcp recapdebug display start`.
3. Enter combat and die within two minutes. Receive healing during the fight if possible so both event types can be inspected.
4. A simple test window freezes the last eight seconds, newest receipts first. Screenshot its rows and counts. Scroll one row per wheel notch to inspect more of the capture.
5. Click **COPY STATUS**, then **SELECT ALL**, and copy the report. Send the report with the screenshot **before reloading**.

The useful case has **Protected > 0**, readable amount labels, and corresponding
bars. Successful setter calls alone do not prove visible pixels. `(blocked)`
labels or missing bars are a negative result. A capture with no protected inputs
does not validate the protected path.

`/rcp recapdebug display` reopens this login's test. `display report` opens its
public status report. `display stop`, the explicit CLOSE button, profile reset or module
disable, world transition, and the two-minute deadline stop recording. An
ordinary combat-session reset or an externally hidden window does not clear
the capture. The armed window is excluded from generic close-all-windows. If
it disappears, reopen it with `display` and use `display report` for its state. After
death all test event subscriptions and the expiry timer stop. Closing a frozen
window retains that login's capture for review; starting another test replaces it.

## Boundaries

- The test is off on every login. No frames, timers, native event subscriptions,
  inventory scans, or periodic work are created by loading its module.
- An armed test uses only the player's `UNIT_COMBAT` receipts and lifecycle
  events. It retains at most 256 receipts and only the final eight seconds at death.
  A newer combat entry replaces an unfinished earlier fight's receipts.
- Values go directly to `StatusBar:SetValue` and `FontString:SetFormattedText`.
  Lua does not inspect, calculate with, rank, stringify, or read back protected
  amounts. Visible rows use a fixed pool of 16 native bars and text regions.
- Bars cap at the maximum-health reference obtained when arming. Amount labels
  are the raw reported amounts; no inference about effective healing is made.
- Times are local receipt times, not proven server hit times. Delayed feedback
  after the death notice is excluded. Spell names and attackers are not supplied.
- Protected values remain in session memory, outside normal history, debug
  exports and chat. They disappear on reload. The copy report contains public
  metadata, counts and widget-call results, never the protected amounts.
- The regular recap, readiness checks, bindings and action bars are unchanged.
  This experiment does not expand Blizzard's named recap or establish a clock
  bridge between the two sources.

## Lifecycle regression

The first alpha.60 owner attempt did not remain usable after death. An offline
integration of the real Core, recorder, and probe reproduced a definite defect:
the recorder emits `reset` when combat starts, and the probe treated it as a
cancellation. Alpha.61 ignores this ordinary session signal, stops explicitly
on profile reset/disable, and preserves evidence when another UI hides its
window. The previous module fails the same integration regression. Both the
full lifecycle test and opaque-input tests pass with the fix; native protected
rendering still needs the owner check above.

## Evidence

Blizzard's generated widget documentation explicitly permits protected input
to [status bar setters](https://github.com/Gethe/wow-ui-source/blob/15881d522c44cd106d3d8660106ec9f9d2f44167/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleStatusBarAPIDocumentation.lua)
and [formatted text](https://github.com/Gethe/wow-ui-source/blob/15881d522c44cd106d3d8660106ec9f9d2f44167/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontStringAPIDocumentation.lua).
Their getters preserve the corresponding secret aspects; rendering does not
make those values public. Offline tests exercise dataflow and lifecycle with
opaque mock inputs. They cannot establish native secret-value lifetime, actual
pixels, combat behavior, or performance.

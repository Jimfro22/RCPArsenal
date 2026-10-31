# Death Log — alpha.31 test build

Enable **Personal Tools → Death Recap** before a new pull. Recording starts OFF;
Preview, View last and opening settings do not enable it. `/rcp recappreview`
opens an isolated **Preview** Arcane Mage / The Coiled Altar / Mythic page.
Its amounts, selected-time states, health curve, heals, durations and healing
debt are fictional. `/rcp recap` opens the one retained personal page this login.

The 880×440 display has one native time rail, grouped damage below it, support
above it and a shallow HP graph. A collision tier adds100px; extra known shelf
rows add38px each. It scales to the viewport. Hover a group span to select the
nearest actual member; scroll to reach every member, including equal times.
Ambiguous positive spans and equal-time ticks keep true brackets but use icon/amount
scrolling, with no overlapping invisible mouse targets. Tooltip distinguishes the
combined amount from the selected event. Normal
click opens a verified Journal entry; it never cycles events. There is no raw
panel, toggle, instructional subheader or Details placeholder.

Alpha.31 keeps the default Sever selection and retains it on leave. The selected
HP uses a ring and percentage, the guide is dashed, and quiet graph marks preserve
actual event positions. Count and recorded absorption badges have readable
backing; the selected border remains distinct from the fatal-hit border. Native
spell/item descriptions remain in tooltips, followed by compact recap details.
Placement prefers outside the recap, with bounded edge/effective-scale fallback
that protects the hovered target and HP/shelf where space allows. Geometry checks
read only public UI bounds, never tooltip text or health widget values. Preview
uses one provenance label; its reminder/chat actions stay inert and explain why.
Synthetic healing debt uses clipped, explicitly layered native hatch lines while
raw HP stays in its usual position. Native pixels, tooltip reflow and taint still
require owner acceptance.

Only confirmed same-spell/source-instance bursts merge semantically, with a
provisional0.6s adjacent gap and1.5s total span. Other spells may interleave.
Known transitions split groups. Fatal and largest retained preceding damage
remain separate. Crowded unconfirmed/mixed events use neutral counted summaries,
never a combined amount under one spell icon. Raw timestamps/order are retained;
rounded timestamps, names and amounts are never deduplication keys. Native
sourceName is display evidence, not a stable instance ID. No native sourceGUID
contract has been established. Group spans/cursors keep true time coordinates
when artwork is packed into two tiers.

Real data and selected-time limitations
--------------------------------------
The existing explicit own recap-ID/session association is preserved. The default
selected recap is never trusted. Up to64 normalized public native rows are kept;
a larger input is marked partial. Original index1 remains the killing identity,
independently of maximum timestamp. Amount, absorbed, overkill, resisted and
blocked stay separate recorded fields. They do not establish exact HP loss,
shield provider, a defensive the player used, or a complete heal stream.

Public finite event HP and one positive finite recap maximum support raw selected
health and discrete graph marks. Known zero stays zero. Missing selection clears
the previous value; above-max raw HP stays readable without a clamped bar. The
maximum is a fixed recap reference. Before/after-hit semantics are unspecified.
Real history is not connected, filled or reconstructed from damage, absorbs or
HP deltas. No heal or forced zero endpoint is invented.

**The native recap clock has no validated local GetTime conversion.** Real shelf
heading is **Last recorded check**, with actual check ages relative to the death
notice. It is not a snapshot at the selected native hit. Its hover identifies
independent cooldown/charge/stock observations and pending/coverage gaps. Cast
receipts remain inspectable as untimed icons; no guessed native connector or
effect duration is attached. The Example alone demonstrates one shared synthetic
clock and complete selected-time state. Full local histories, aura lifecycle and
boss-heal-absorb collection are deferred until useful alignment/capability passes.

Remaining boss healing debt is different from protective damage absorption.
Example uses an amber hatch inside the HP track, including a no-heal interval;
it is never additional HP. Real historical quantity/presence is not supplied by
this build. UnitGetTotalHealAbsorbs can be secret; a live render does not prove
historical scalar access or boss attribution. No opaque values, widget readback,
combat-log parsing, aggregate differencing or new absorb/aura subscriptions ship.

Recorded check quality
----------------------
A30-second history window is not a state-expiration rule. Unchanged cached bag
or inactive cooldown facts retain their actual query time. Two guarded item
queries separately retain physical count and remaining uses for each existing
verified candidate. Fresh positive stock is not erased by an older bag scan.
Zero uses alone is not absence; zero count concerns that exact item. Family
absence needs complete readable family evidence. Generic usability is outside
the shelf and no longer gates the off-cooldown label. The shared reminder/cache
behavior remains independent; cache generation records actual invalidation.

Public cooldown flags survive a restricted charge count. On hold, active,
inactive, positive charges, zero charges, stock and missing dimensions remain
distinct. GCD flags are trusted only on a direct cooldown event; no full
castability or survival verdict follows. Casts and pending coalesced updates mark
an explicit gap until checked. Combat end marks ended coverage. Missing data has
precise restricted/unrecorded/unavailable provenance; it is never silently ready,
zero, empty or unused. State is frozen; no historical countdown runs.

Budget and diagnostics
----------------------
OFF releases optional subscriptions, cache consumer and owned timers. Enabled
idle adds no observation ticker. Existing active-cooldown reconciliation stays
0.5s and skips unchanged inactive spells. No all-spec/per-frame collection is
added. Supply scans remain event-invalidated, six bags×100slots maximum,32
candidates, shared with the reminder. At existing observations there are at most
64 direct stock scalar queries,32 item cooldown queries and32 eligible spell
cooldown/charge pairs. Only the known active catalog subset is observed.

Retention is one last-alive sample, one separate death-notification sample,
64 own cast receipts from30s and64 native rows; no new full state history.
There are at most3 native attempts,1 extra recap-max getter and2 guarded GetTime
reads per actual native event read. The accepted page stores one scalar clock
summary. Presentation examines at most256 inputs for oversize triage, retains64,
protects the inspected fatal/largest hit, and reports truncation/unexamined input.
Native normalized input is already capped64. Semantic/collision work is bounded
by the small input; pooled drawing objects are reused. Only an actively hovered
span has a pointer-motion callback, removed on leave/hide. It changes selection
only after horizontal movement; it never captures, regroups or polls game state.
Local fixture timings are not measurements of WoW CPU, RAM, taint or frame spikes.

`/rcp recapstatus` includes existing safe counters plus the accepted page's local
session/death notice/read brackets and native first/min/max/fatal timestamps.
These are independent public scalars, not a clock conversion. Compare immediately
after death during the ongoing pull and after combat. Correlation is evidence
for review, never an automatic offset or native acceptance certificate.

Actions and acceptance
----------------------
Reminder `!` preserves the existing confirmation and child preferences. Post to
chat prepares only the normal native composer with channel/recipient/restriction
guards; the user submits. Preview cannot run live Share/reminder callbacks.

Four private Coiled Altar Example Journal relationships are verified in current
client data. Click checks private page identity, out-of-combat status, instance1320,
Mythic16, encounter2883/dungeon3429/map3004, root35058, reachable section and exact
sectionSpellID. Damage IDs may differ from section spell IDs. Combat, stale or
unverified clicks fail without queued navigation. Real mappings remain unchanged.

Native owner test: pull main, restart WoW, verify alpha.31; inspect Arcane preview
and group scrub/wheel/Journal. With recording enabled before a clean pull, compare
own real rows/fatal/HP with Blizzard recap during ongoing combat and afterward;
record `/rcp recapstatus` both times. Validate nil/secret/zero/out-of-scale values,
charges/resets/pending changes, cache ages, context transitions, fit/scales/fonts,
tooltips, input/taint and actual CPU/memory/frame spikes. Screenshot QA preserves
54 incoming rows and29 separate shield credits across three references; rounded
screenshot values are not native packets or exact HP loss. No actual-log/API parity
or native acceptance is claimed. GitHub test delivery only; noCF/tag/release work.

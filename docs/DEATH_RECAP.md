# Death Log — alpha.34 complete reports and composition test build

Enable **Personal Tools → Death Recap** before a new pull. Recording starts OFF;
Preview, View last and opening settings do not enable it. `/rcp recappreview`
opens an isolated **Preview** Arcane Mage / The Coiled Altar / Mythic page.
Its amounts, selected-time states, health curve, heals, durations and healing
debt are fictional. `/rcp recap` opens the one retained personal page this login.

The compact 880×428 base display has grouped damage below its native time rail,
support above it and a shallow HP graph. A collision tier adds 100px; extra known
shelf rows add 38px each. The visible encounter context, Health row and CDs use a
shared alignment grid. Health has no timestamp suffix. Values align to the left
of the 324px bar; healing debt aligns to its right. Seven CD icons share a row.

Damage hover focuses the icon center. The top health value uses one stable group
representative: fatal member if present, otherwise the member nearest the time
midpoint, with earlier time/order breaking ties. The tooltip identifies that
member and contains every original hit. Span motion and wheel change only the
inspected tooltip constituent; dense lists scroll within a bounded companion.
They do not move the focus line, health, shelf or border. Support and CD hovers
are tooltip-only. Normal click retains verified Journal navigation.

The focus line is not a timestamp: packed artwork can differ from its event
positions. Actual graph samples never move. The ring/percentage appears only
when the representative's actual point aligns within one physical pixel of the
focus line. Real HP remains discrete. Preview uses consistent 2-unit step
strokes, complete event-colored plateaus and subdued fill; defensive durations
use stronger 4-unit strokes and end caps. The smaller tombstone sits clear of
the actual known fatal HP point; unknown HP gets no invented graph endpoint.

Native spell/item descriptions remain intact beside the bounded recap companion.
Pooled rows clear old height before wrapping and measuring. One ordinary help
card, screen-aware placement and ownership-safe cleanup remain. Reminder changes
the actual master setting through explicit clicks and preserves child settings.
Preview stays fictional, isolated from recording and frozen at its death shelf.
Native font rasterization, tooltip behavior and taint remain client acceptance.

Only confirmed same-spell/source-instance bursts merge semantically, with a
provisional0.6s adjacent gap and1.5s total span. Other spells may interleave.
Known transitions split groups. Fatal and largest retained preceding damage
remain separate. Crowded unconfirmed/mixed events use neutral counted summaries,
never a combined amount under one spell icon. Raw timestamps/order are retained;
rounded timestamps, names and amounts are never deduplication keys. Native
sourceName is display evidence, not a stable instance ID. No native sourceGUID
contract has been established. Group spans keep true time coordinates when artwork packs into two tiers; the
visual group-focus locator follows the icon center without moving data points.

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
clock; its CD shelf is fixed to death while health/event selection changes. Full local histories, aura lifecycle and
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
64 own cast receipts from30s and64 native rows. A separate at-most32-entry
observed-use map retains count and first/last successful activation for this
coverage epoch. No full state history is added.
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
Reminder `!` opens an explicit on/off action; the adjacent Reminder switch stays
synchronized with the real Personal Tools setting and preserves child preferences.
Post to chat opens a centered 600×396 dialog with a read-only, scrollable snapshot
of the exact outgoing plain-text messages. SELECT TEXT exposes the same immutable
text for manual copying. Destination, recipient, message count and submission
progress remain visible; no opening/hover/channel selection sends anything.

Every retained original hit appears separately in chronological order, even when
the chart groups it as ×3. Absorption stays on its originating hit and is counted
once. Preview interleaves its recorded fixture heals, defensive activations and
explicit death with a single fictional fight clock. Real native rows remain in
a clearly labelled latest-native-event-relative section; local cast/death
observations have their own clock section. Native zero is not necessarily the
fatal event. No local/native time bridge, missing live heal, aura duration,
readiness or cast from a summary count is invented. Reports describe retained
capture, not complete encounter history.

An explicit send click starts one ordinary-chat queue for PARTY, RAID or WHISPER,
with one next timer at a time and one-second spacing. SAY requires a separate
visible click per line. Every call rechecks public out-of-combat status, chat
lockdown, social permission and destination membership. Payload and destination
freeze at the click. Messages are at most 255 UTF-8 bytes, split at code-point
boundaries; the full report is retained, with a finite 256-message ceiling that
fails visibly rather than truncating. These are application limits, not a server
throttle guarantee. Progress says submitted, never delivered.

Cancel stops unsent lines and retains partial progress. Close/X, Escape, backdrop,
page replacement, feature disable/profile reset, combat/encounter start, world
transition/logout, changed group context, restrictions or errors invalidate queued
callbacks. There is no automatic resume, retry, redirect or duplicate resubmission.
Submission expires after the bounded queue duration plus margin (at least 30s);
manual SAY expires after ten minutes without an idle ticker. Nothing posts on
Preview open or recording events. No native chat was sent during tooling tests.

Four private Coiled Altar Example Journal relationships are verified in current
client data. Click checks private page identity, out-of-combat status, instance1320,
Mythic16, encounter2883/dungeon3429/map3004, root35058, reachable section and exact
sectionSpellID. Damage IDs may differ from section spell IDs. Combat, stale or
unverified clicks fail without queued navigation. Real mappings remain unchanged.

Native owner test: pull main, restart WoW, verify alpha.34; inspect Arcane preview
and stable group focus, tooltip-detail wheel and Journal. With recording enabled before a clean pull, compare
own real rows/fatal/HP with Blizzard recap during ongoing combat and afterward;
record `/rcp recapstatus` both times. Validate nil/secret/zero/out-of-scale values,
charges/resets/pending changes, cache ages, context transitions, fit/scales/fonts,
tooltips, input/taint and actual CPU/memory/frame spikes. Screenshot QA preserves
54 incoming rows and29 separate shield credits across three references; rounded
screenshot values are not native packets or exact HP loss. No actual-log/API parity
or native acceptance is claimed. GitHub test delivery only; noCF/tag/release work.

Defensive-use and availability audit
------------------------------------
`/rcp recapaudit` prints local captured facts only; it sends no report. It includes
client/spec/death identity, witnessed combat-entry coverage, ended/rejected/late
receipt gaps, per-spell observed use, the displayed last-alive verdict and the
separate fresh death-notification query, field/charge status, pending changes and
latest direct cooldown/charge event context. Reopening uses frozen observations;
no live countdown or static base-cooldown estimate is substituted. The metadata
can include a later matching encounter-end observation without changing frozen
spell/item/HP facts. A successful use two minutes earlier stays in the bounded
summary after it expires from the short timeline. No receipt means no observed
use in that coverage, never proof of unused.

Current learned Arcane candidates include Barrier, Alter Time, Block or Cold,
Mirror Image and Greater Invisibility. Actual known/override/non-passive checks
decide the roster. Trigger110960 and Alter Time return342247 are not counted as
initial activation families. No fixed damage-reduction or effect-duration claim
is added for the new utility candidates.

During normal play, compare all learned candidates with independent action-bar
and bag evidence: unused ready, immediate use, earlier use that recovered, GCD,
Alter Time phases, current Block/Cold identity, and item stock/uses/cooldown.
Compare the two local checks while dead in the ongoing pull and after combat.
Post-death flags are not automatically the final pre-hit state. Score false-ready,
false-unavailable and missing coverage separately over all eligible observations.
Offline checks and a compatibility pilot do not establish the requested90% native
use/availability accuracy. Native rendering, tooltip reflow, event ordering and
performance remain owner/client acceptance gates.

Alpha.34 visual proof and native acceptance
-------------------------------------------
Before delivery, review source-derived normal/death, single-hit, grouped-detail,
CD-hover and full-report dialog renders at the owner's screenshot scale against
the approved image. Bind the rendered source hash and assets to the candidate.
These images catch composition and layering defects before the owner sees them;
they do not emulate WoW's font rasterizer, tooltip backend or protected input.

Native checks still cover short/long/dense tooltip reflow after font refresh,
edge/scale behavior, modal input isolation, actual chat restrictions and paced
submission/cancellation on an authorized test destination. Exact merged real
fight timestamps remain unavailable until independent native clock evidence
establishes the relationship. The recorder, association, catalog, observed-use
retention and all media remain unchanged in this pass.

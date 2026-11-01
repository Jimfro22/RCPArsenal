# Death Log — alpha.37 sharing and recorded evidence

Enable **Personal Tools → Death Recap** before a new pull. Recording starts OFF;
Preview, View last and opening settings do not enable it. `/rcp recappreview`
opens an isolated **Preview** Arcane Mage / The Coiled Altar / Mythic page.
Its amounts, selected-time states, health curve, heals, durations and healing
debt are fictional. `/rcp recap` opens the one retained personal page this login.

Automatic opening defaults OFF. The small RCP Death Log entry beside the visible
Blizzard death dialog opens the current captured death, including a pending page.
It disappears while the log is open and on release/resurrection/reset. Legacy
unmarked auto-open settings migrate OFF once; later explicit choices persist.
The optional Open after my death setting still enables automatic opening.

The compact 880×428 base display has grouped damage below its native time rail,
support above it and a shallow HP graph. A collision tier adds 100px; extra known
shelf rows add 38px each. Encounter context stays in help and the complete report
without a visible context subline. The health percentage, 324px bar, raw amount
and healing debt move left together; the redundant Health label is removed.
Their widths and the seven-CD row remain unchanged.

Damage hover focuses the icon center. The top health value uses one stable group
representative: fatal member if present, otherwise the member nearest the time
midpoint, with earlier time/order breaking ties. The tooltip identifies that
member and contains every original hit. Span motion and wheel change only the
inspected tooltip constituent; dense lists scroll within a bounded companion.
They do not move the focus line, health, shelf or border. Support and CD hovers
are tooltip-only. Normal click retains verified Journal navigation.

The focus line is not a timestamp: packed artwork can differ from its event
positions. Actual graph samples never move. The selected mark/percentage appears only
when the representative's actual point aligns within one physical pixel of the
focus line. Preview retains its ring; live selection uses a thin tick so nearby
tied samples stay visible. Real HP uses compact 6×2-unit sample ticks and neutral dashed joins between unambiguous
adjacent samples; gaps and equal-time ambiguity break the joins. Preview uses consistent 2-unit step
strokes, complete event-colored plateaus and subdued fill; defensive durations
use stronger 4-unit strokes and end caps. The smaller tombstone sits clear of
the actual known fatal HP point; unknown HP gets no invented graph endpoint.

Blue shield absorption uses compact positive text such as **+20k**. Its Shield
help says how much damage a shield absorbed, without identifying an unrecorded
shield source. It does not add health or describe remaining shield capacity.
Green healing and the amber **heal absorb remaining** annotation keep their
separate meanings. The full report still records the exact absorbed amount.

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
Association uses the authoritative Current personal recap-ID set within a witnessed
clean meter epoch. Update events are dirty hints, never explicit-session bindings. The default
selected recap is never trusted. Up to64 normalized public native rows are kept;
a larger input is marked partial. Original index1 remains the killing identity,
independently of maximum timestamp. Amount, absorbed, overkill, resisted and
blocked stay separate recorded fields. They do not establish exact HP loss,
shield provider, a defensive the player used, or a complete heal stream.

Public finite event HP and one positive finite recap maximum support raw selected
health and discrete graph marks. Known zero stays zero. Missing selection clears
the previous value; above-max raw HP stays readable without a clamped bar. The
maximum is a fixed recap reference. The live graph uses a labelled zero-based
percentage range, rounded up to the next ten percentage points from all valid
page samples, bounded from 10% to 100%. The range is fixed for that page, including
selection changes; the top health bar always uses the true 0–100% maximum.
The native-window hit count and span describe only the retained native rows.
Before/after-hit semantics are unspecified.
Dashed lines connect recorded samples as visual joins only; health between them
is unknown. No fill, damage/absorb reconstruction, inferred heal or forced zero
endpoint is added.

**The native recap clock has no validated local GetTime conversion.** Real shelf
heading is **Last recorded check**, with actual check ages relative to the death
notice. It is not a snapshot at the selected native hit. Its hover identifies
independent cooldown/charge/stock observations and pending/coverage gaps. Cast
receipts appear in a separate Used before death row, grouped into compact chips
with ability names, counts and latest local death-notice ages. Hover retains every
individual receipt and bounded overflow exposes the remaining groups;
no guessed native connector or
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
A fixed potion icon and the existing switch form one reminder click target.
Click either part to toggle the real consumable-reminder master. Its hover
explains Healthstone and healing-potion alerts and updates the on/off state
immediately. The switch stays synchronized with external setting changes and
preserves child preferences. The former exclamation and redundant dialog are
removed. Encounter help remains next to the title/Preview row.
Post to chat opens a compact destination chooser and freezes the complete report.
A destination click starts submission directly. Whisper displays the current
public player target, revalidates its identity at the click, and freezes it for
all queued messages. A target change during the press cancels that activation.
Missing, NPC or restricted targets cannot be used. Party, Raid and Instance group
use their explicit group categories. Say is labelled as one line per click.
View/copy report opens a read-only scrollable plain-text view, including when
chat preparation fails. Opening, hovering and target refresh send nothing.

Every retained original hit appears separately in chronological order, even when
the chart groups it as ×3. Absorption stays on its originating hit and is counted
once. Preview interleaves its recorded fixture heals, defensive activations and
explicit death with a single fictional fight clock. Real native rows remain in
a clearly labelled latest-native-event-relative section; local cast/death
observations have their own clock section. Native zero is not necessarily the
fatal event. No local/native time bridge, missing live heal, aura duration,
readiness or cast from a summary count is invented. Reports describe retained
capture, not complete encounter history.

A destination click starts one ordinary-chat queue for PARTY, RAID, INSTANCE_CHAT or WHISPER,
with one next timer at a time and one-second spacing. SAY requires a separate
visible click per line. Every call rechecks public out-of-combat status, chat
lockdown, social permission and destination membership. Payload and destination
freeze at the click. Messages are at most 255 raw UTF-8 bytes including prefixes and complete native
spell-link markup. Validated generated spell links are atomic; other text splits
at code-point boundaries; the full report is retained, with a finite 256-message ceiling that
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

Native owner test: use the reviewed test candidate, restart WoW, verify alpha.37; inspect Arcane preview
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

Alpha.36 native comparison and bounded evidence
----------------------------------------------
`/rcp recapblizzard` requests Blizzard's view of the accepted frozen recap ID.
`/rcp recapdebug` opens a copyable frozen diagnostic packet without capture reads.
`/rcp recapdebug reread` explicitly performs one bounded read of that same ID and
shows index-wise differences without replacing the original page. These commands
never substitute Blizzard's default record. The outdoor screenshot fatal mismatch
remains an exact-ID diagnostic question; the largest hit is not fatal evidence.

Absorb clusters show exact summed public credits and retain each original member
for wheel inspection, with no shield attribution. The two item-family shelf slots
retain individual stock/cooldown/check ages in their inspectable details. Direct
cooldown snapshots keep event context and old timestamps; generic active checks
without trustworthy GCD context and pending/restricted charges remain unknown.
Charge-based verdicts use the charge check's age. Unchanged tracked spell rosters
preserve use history. Spell-only updates do not rescan supplies.

If a guarded Current read fails after a meter update, it does not invalidate an
already witnessed clean alive baseline. This conditional failure handling does
not establish that combat normally makes the meter unreadable. A newly reported
Current epoch with no readable alive baseline
remains unavailable; later data cannot reconstruct that prior observation.
Accepted IDs cannot repeat across meter epochs within an enable cycle; the bounded
256-ID retention limit fails unavailable rather than dropping anti-reuse evidence.

Loading, unavailable and empty native pages hide the time rail, ticks and death
axis labels until recorded events arrive. Recorded uses and the last-check shelf
remain available independently. Preview keeps its fictional timeline and stepped
health curve, described separately in its graph help.

Alpha.37 diagnostics
--------------------
The frozen debug export includes the ordered retained own-cast receipts, including
recorded potion uses, and public source/name provenance. Its loaded addon build
is explicitly separate from capture-time metadata. Incoming spell identity is
not shield-provider identity. Absorb tooltips retain each member, exact amounts
and tenths of seconds relative to the final recorded hit; an unidentified shield
says **Shield not identified**. Successful-use ages and independent cooldown or
charge-check ages remain separate. Missing GCD evidence stays uncertain even
inside a direct cooldown callback.

`/rcp recapdebug cooldowns start` explicitly arms a 20-second diagnostic for the
current learned Mirror Image entry. It uses existing direct cooldown callbacks
only, with at most 32 duration-query attempts and one timeout that finalizes
without sampling. `/rcp recapdebug cooldowns stop` ends capture and opens the
copyable result; `/rcp recapdebug cooldowns` shows the latest result without
restarting. No death is required. Use an ordinary GCD while Mirror Image is off
its own cooldown, then cast Mirror Image normally; the report does not infer that
the baseline was ready or that both states were captured.

The report records immediate guarded scalar results/statuses from the GCD-ignored
cooldown query, original event context, build and local query times. Only public
userdata and independently guarded Boolean method results are accepted. Secret,
missing, wrong-type and failed results stay explicit. Duration objects are
never retained. The diagnostic does not change readiness, query from cast
receipts, add a ticker or reconstruct historical cooldowns. It ends on its
bound, explicit stop, death, combat end, world/profile/roster change or disable.

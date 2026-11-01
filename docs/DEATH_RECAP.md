# Death Log and Death Summary — alpha.41

## Core recording verification

`/rcp recapfacts` opens a plain readout of the selected death's defensive uses,
consumable uses, last living checks and death-notice checks. It reads frozen data;
opening it never queries current cooldowns or bags. Use receipts do not imply
remaining availability, and a missing receipt does not prove an ability was unused.
Restricted charge counts remain explicitly unresolved in the public text report.

Defensive and consumable use counts now both survive beyond the short timeline
ring for this recording session. The ledger keeps count, first and last successful
use for each tracked spell; it does not reconstruct discarded individual events.
Those item summaries are included in diagnostics and the five saved deaths.
Recent own-player successful uses before pulling are retained in a bounded
64-receipt / 30-second buffer and handed to the matching combat session. A prior
life, changed identity or stale receipt cannot be imported. This adds no idle
timer, bag scan or cooldown query. Combat entry and earlier receipt coverage keep
their separate timestamps.

The Arcane Mage recorder tests cover spending one or both Barrier charges,
recharging after use, restricted counts, and death before a charge callback.
They supply API answers and test actual recorder callbacks; they do not establish
live Retail availability accuracy. The owner's captured native recap remains the
source for the damage regression fixture. No 90% availability claim is established.

The examined Osso simulator v0.1.39 starts on this Mac but does not expose
`C_DeathRecap.GetRecapEvents`. Its charge model requires explicit state; automatic
spending/recharge is outside its documented scope. Its tainted secret-number
`SetFormattedText` probe also fails, despite the current Blizzard API declaring
secret arguments allowed. Simulator rejection is not proof of native rejection.
The restricted-count display below remains a native-testable prototype.

## Existing alpha.41 work

Death Summary above the native death dialog now shows every tracked defensive and
both item families in the same bounded order as the expanded CDs shelf. Lit/check,
dim/red X, and muted question-mark states describe frozen availability evidence.
Unknown is never converted to unavailable. Both surfaces use one projection and
one badge painter; item artwork and check age follow the actual representative
candidate, with the individual family checks retained in the expanded hover.
The small card opens Death Log. Its historical snapshot stays fixed as native hit
details arrive. The Summary on login never represents an old saved death.

Drag the expanded header to move the window outside combat. The position is saved
in the local profile using the existing UIParent top-left convention. Reopening,
height changes, UI scale and display changes retain/clamp it. **Reset position**
in Death Recap settings clears the saved anchor; interrupted drags do not save.

The header selector and arrows switch among the five latest recorded deaths.
The account-saved list keeps at most five public snapshots across reloads, with
captured player, encounter, checks, baseline, casts and native rows. A sixth evicts
only the oldest. Selection is separate from the current death's Summary/native
association. Sharing and ordinary debug use the selected record; a restored death
cannot reread a current-login native recap ID. Only explicitly allowlisted scalar
fields and bounded arrays are saved; no association state, native objects,
callbacks, chat targets or link tokens enter history.

While enabled and alive outside combat, existing life/spec/bag/cooldown/charge
observations refresh a bounded own-character baseline without idle polling.
**Check character** or `/rcp recapcheck` refreshes and displays **Before combat**;
it requires recording enabled and never enables it automatically. The panel
closes on combat entry. Combat freezes the actual earlier baseline with its
identity and timestamps separately from living checks. An unresolved death check
can show its historical precombat check in hover, but never inherits its ready
verdict. Trait/role qualification changes invalidate the previous capture identity.

Ambiguous current **noncharge** spells can query their own cooldown with the
supported ignore-GCD duration API. Only guarded public userdata predicates with
`IsActive=false, IsZero=true` establish inactive, or `true,false` establish active.
Held, pending, ended coverage and known charge spells retain their existing gates.
Errors, restricted predicates and conflicting results remain unconfirmed. This
path does not resolve Ice Cold/Barrier when their actual charge count is opaque.

A restricted captured charge count can instead be passed directly to native
`FontString:SetFormattedText("%d", count)`. It appears as a neutral charge badge;
Lua never compares, formats, reads back or exports the opaque count. The value
lives only in a bounded volatile witness keyed by captured rows and is omitted
from public page data, debug and saved history. Later queries cannot change an
older witness; pending/ended observations cannot display it. Restored history
explicitly discloses that opaque counts were not saved. Native formatter failure
keeps the question mark. This is a native-testable prototype, not a native pass.
Primary contract: [Blizzard FontString API, pinned70688 UI source](https://github.com/Gethe/wow-ui-source/blob/d07eb00237d8891f153215db98a5df880a26cfe5/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontStringAPIDocumentation.lua#L516).

The owner's ten native amounts reconcile the displayed grouped totals:
16,298;54,247=47,369+6,878;55,730=39,432+16,298;
138,217=38,547+6,792+76,580+16,298; fatal77,049.
Screenshots do not provide raw timestamps. The visible gap remains unchanged
pending a matched native reread; no timing or missing-hit claim is inferred.

The preceding alpha.40 behavior and native acceptance details follow.

## Alpha.40 retained behavior

Enable **Personal Tools → Death Recap** before a new pull. Recording starts OFF;
Preview, View last and opening settings do not enable it. `/rcp recappreview`
opens an isolated **Preview** Arcane Mage / The Coiled Altar / Mythic page.
Its amounts, selected health, heals and effect durations are fictional.
`/rcp recap` opens the one retained personal page this login.

Automatic opening defaults OFF. The compact availability card above the
visible Blizzard death dialog opens the current captured death, including a
pending page. It disappears while the log is open and on release, resurrection
or reset. `/rcp recapentrypreview` shows its separate labelled sample outside
combat. Its availability evidence remains frozen.

The header shows the player name captured once at the start of the recording
session, using the captured class's static color. Long names stay on one line;
the info hover retains the full captured name and realm. Old pages without a
name keep the original header. Opening a page never queries the current player
identity. The Preview uses an explicitly fictional identity.

The 880×360 base display aligns the native timeline and bottom health bar at
x48–832. Additional damage lanes add84 units, shelf rows add38, and approximate
cast lanes add48. The former recorded-HP graph is removed. Percentage, raw
current/max and a full-width0–100% bar describe the **selected member**. Missing
health clears the old value; known zero remains zero; above-max raw health stays
readable without a clamped bar. Native HP before/after-hit semantics remain
unspecified. No damage subtraction or forced fatal zero is used.

Damage clusters use a fixed **0.5-second window anchored at the first hit**.
They may combine different sources and abilities. Unknown event types and known
Preview transitions split clusters; density never merges distant hits. The tile
shows total damage, ×count and the largest known individual hit's artwork. A
partial known total is a lower bound, including ≥0; all-unknown amounts show an
unavailable value. Artwork is representative, never a claim that one ability
caused the whole total. Unknown amounts cannot establish a definitive largest
hit. Killing-blow identity stays with original native index1 and is qualified
as a death record when its event type is unknown.

Hover, span motion and wheel inspection select the actual member's HP while the
artwork remains fixed. Every original member keeps its own name, exact retained
time (shown to one decimal), visible source and killing-blow identity in the bounded companion. The
selection guide follows the packed tile and stops above the health readout;
true-time brackets remain on the rail. Native spell/item descriptions, verified
Journal actions, screen-aware companion placement and modal guards remain.

The default viewport is **−5s to the latest native event**. Within the last eight
seconds, a known positive nonfatal hit is important when it is at least20% of
the recorded maximum health **or** at least50% of the largest known nonfatal hit
in that interval. The earliest qualifying hit older than five seconds extends
the view outward to a whole second, capped at−8s. Without a valid maximum, the
relative criterion still applies. Valid approximately aligned use receipts can
also extend the view to their projected native offset, rounded outward to a whole
second and capped at eight seconds. Uses at5.6s and6.5s therefore open a seven-second
view even when damage spans less than a second. Missing/stale alignment and uses
projected earlier than−8s stay in the fallback chips and full report. Without a
qualifying hit or aligned use, the window stays five seconds. Filtering is
presentation-only: older retained events remain
in the full report, and encounter info discloses the omitted count. No old event
is clamped onto the left edge or silently assigned a new time.

Blue absorption labels remain damage absorbed by an unidentified shield. They
never add health or establish healing. Only the controlled Preview currently has
effective-healing and post-heal HP evidence; hovering a Preview heal can show its
green gained-health segment. Live pages have no verified effective-healing stream,
so receive no green segment. Shield and healing-debt overlays are removed from
the health bar.

Real data and timing boundaries
------------------------------
Association still uses the authoritative Current personal recap-ID set within a
witnessed clean meter epoch. Update events are dirty hints; the selected native
recap is never trusted. Up to64 normalized public rows retain independent amount,
absorbed, overkill, resisted, blocked and health fields.

**Cast-marker timing is approximate.** A captured successful-use receipt is placed
at `observedAt - diedAt + nativeFatalTimestamp - nativeMaximumTimestamp`, aligning
the frozen local death notification to the native fatal event. The visible `~`
age and hover explain this approximation; notification delay is not measured.
There is no validated exact conversion between native time and GetTime. Missing,
stale or unreadable anchors leave the factual receipt unaligned rather than
placing it at zero. Repeated receipts remain distinct. Recorded-use chips and
bounded overflow preserve individual details, including uses outside the visible
window. Utility uses are labelled as utility and excluded from the defensive
availability shelf and entry card. No active-effect duration or readiness verdict
follows from a cast.

CDs show drawn checks and crosses only for proven available or unavailable frozen
states; unresolved checks keep a question mark. The visible check-age caption is
removed, while each hover preserves its check age and historical meaning. A
Healthstone requires positively recorded remaining uses for a check mark. The
shelf stays independent of timeline selection and approximate cast markers.

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

Fresh independent inactive/held facts keep their new query time even when the
flags agree with an older direct event. That event's GCD context remains separate;
an event-dependent interpretation does not gain a newer timestamp. Eligible
cooldown callbacks read charges for the affected known spells immediately, so a
death before deferred reconciliation can retain an actual readable charge count.
Unreadable or missing counts replace the old observation rather than borrowing
it. Accepted own cast receipts request the existing coalesced reconciliation
after invalidation. No new polling or inferred charge regeneration is added.

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
protects the retained fatal/largest hit, and reports truncation/unexamined input.
Native normalized input is already capped64. Semantic/collision work is bounded
by the small input; pooled drawing objects are reused. Only an actively hovered
span has a pointer-motion callback, removed on leave/hide. It changes selection
only after horizontal movement; it never captures, regroups or polls game state.
Local fixture timings are not measurements of WoW CPU, RAM, taint or frame spikes.

`/rcp recapstatus` includes existing safe counters plus the accepted page's local
session/death notice/read brackets and native first/min/max/fatal timestamps.
These are independent public scalars, not a clock conversion. Compare immediately
after death during the ongoing pull and after combat. The display uses only the explicitly approximate death-notice alignment above;
these diagnostics do not certify exact synchronization or native acceptance.

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
fatal event. The report keeps its original clock sections even when the display shows an
approximate marker. No missing live heal, aura duration, readiness or cast from
a summary count is invented. Reports describe retained
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

Native owner test: use the reviewed test candidate, restart WoW, verify alpha.40; inspect Arcane Preview,
selected-member health, fixed artwork, tooltip wheel, healing highlight and Journal.
Compare approximate cast-marker ages with their actual recorded-use details. With recording enabled before a clean pull, compare
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
decide capture eligibility. Greater Invisibility is utility: retain its eligible
successful-use receipts, but omit it from defensive availability displays and
both previews. Mirror Image qualifies as defensive only for Arcane with publicly
learned Refractive Images1309497, using the existing required-talent gate. Other
accepted Mirror uses remain utility, including legacy captures without that
frozen qualification. Refractive Images delays damage; no damage reduction,
healing, absorption, duration at death or prevention claim is inferred. Both
fictional previews deliberately model the selected talent. Passive1309497 and
effect1309793/1309787 never become cast receipts. Trigger110960 and Alter Time
return342247 are not counted as
initial activation families. No ordinary Invisibility66 alias, fixed
damage-reduction value or effect-duration claim is inferred from a receipt.

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
remain available independently. Alpha.39 replaces the former graph with the
selected-health bar in both live and fictional Preview pages.

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

Alpha.40 entry card
------------------
The compact Death Log card sits centered above Blizzard's death popup with an
8-pixel logical gap. The entire card, including its unframed icons, opens the
captured log. It does not cast spells or use items. Only confidently available
frozen living checks appear: major defensives, minor defensives, then a spaced
Healthstone/potion group. All confirmed checks stay visible; unusually long lists
wrap onto additional icon rows. The card is160–280 units wide and56 units high
for one icon row, with22-unit icons and26 units per extra row. With no confirmed
icons, only its32-unit header remains. Preview is visibly labelled.

The visible availability caption has been removed. **Available when checked**
remains in each icon's hover as historical evidence, not an assertion of readiness
at death. Each icon gives the age of its actual positive check before the local
death notice. Item-family ages never borrow another candidate's timestamp.
Healthstone additionally requires a recorded positive remaining-use count; stock
and an inactive cooldown alone do not establish remaining uses. Unknown or
pending checks are omitted, never labelled unavailable. With no positive checks
the card hover says **No availability confirmed**; a missing living snapshot says
**Availability was not recorded** in that hover.

The strip is copied once per captured death and does not change when native hit
data arrives. Existing lifecycle gates remove it when the native popup disappears,
the player revives/releases, the page changes, or the feature/profile is reset.
When the full card does not fit above the popup, it uses a centered-below fallback
or hides if neither position fits, without moving native frames. No scanner,
timer, ticker or availability API query is added. Spell artwork
uses the existing asset broker.

`/rcp recapentrypreview` toggles a clearly labelled synthetic card outside combat.
Its close control exits the preview; clicking the card or a sample icon opens the
existing sample Death Log. It does not alter a real death's frozen evidence or
mark that real death as viewed. Validate actual client anchoring, hover/click
behavior and protected-state handling before considering native acceptance done.

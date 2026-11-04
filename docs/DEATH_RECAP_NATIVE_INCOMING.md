# Native incoming events in Death Log

Alpha.63 uses the successful standalone display technique in the normal Death
Log. Enable Personal Tools > Death Recap before combat. It is still off by
default; no extra arming command is required for the integrated view.

## Owner check

1. Update to alpha.64 and reload before combat. In a dungeon/raid, receive damage
   and healing, then open Death Log from Death Summary or `/recap` after death.
2. On **8-second history**, inspect the red damage and green healing bars. Each
   narrow bar represents one receipt, grouped into half-second columns. Hover
   a column for exact native amounts; scroll over it to browse each receipt.
   Bars cap at a public maximum-health reference captured outside combat, or a
   fixed one-million fallback. Amount labels are not capped or calculated.
3. Switch **Named hits** and back, close/reopen the log, and switch between two
   deaths. The corresponding live events should remain separate and intact.
4. If **Received after death** appears, hover it before reloading. Its amounts
   were delivered after the death notice; they are not backdated into the chart
   or identified as the killing blow. Send that hover screenshot and
   `/rcp recapfacts`. There may be no delayed events in a given death.
5. After reload, the named recap/readiness and public facts remain saved. A death
   that depended on protected values explains that its live amounts were not
   saved, rather than presenting its remaining public events as a complete view.

## Meaning and limits

- Blizzard's native widgets display protected amounts directly. Lua does not
  convert, sum, compare, rank, read back or export them. Event counts and local
  receipt timestamps are public metadata. No totals appear on this path.
- Public-only captures keep their existing calculated chart and saved history.
- Protected and public receipts from the same incoming stream can share its
  private display packet. This is not a merge with Blizzard's named recap.
- Spell names and attackers are absent from incoming receipts. **Named hits**
  retains Blizzard's separate named records, often fewer than eight seconds.
- Timestamps measure delivery to the addon. They do not establish server hit
  times, match a named hit, identify a killing blow or prove effective healing.
- The existing one-second post-death window retains up to 32 late receipts,
  including protected amounts. **Received after death** uses native labels for
  those amounts and positive delivery-time offsets. Public-only late reports
  keep their existing view. They are separate from chart and chat totals.
  After reload, public delayed amounts survive; cleared protected amounts are
  explicitly counted as not retained. No callback is labeled a killing blow
  based on its delivery time or amount.
- Chat still uses the compact named-hit report. A healing total is omitted if
  protected receipts prevent a complete calculation; zero is not substituted.

## Lifetime and cost

The store receives the existing player-only event dispatch; it creates no
additional listener, timer, polling loop or per-frame script. Nothing records
when Death Recap is off. One active ring retains at most 256 receipts. The existing one-second deadline
adds at most 32 late receipts per death and no additional timer. At death,
only the last eight seconds are kept, with an explicit capacity-loss marker.
Private packets are bounded to five deaths, drop as those deaths leave recent
history, and clear on disable/profile reset.

The chart reuses at most 256 native status bars, 32 column inspection targets
and 12 visible tooltip rows. It allocates these on demand. Closing or switching
views clears their native values without reading them back. Neither private
packet containers nor raw protected values are attached to public pages,
saved variables, debug output or chat. Public history stores only a small
session-only-display marker to explain the reload boundary.

Offline tests cover opaque dataflow, full recorder/UI integration, 256-event
windows, every tooltip receipt, five-death retention, stale callbacks, view
switching, chat and persistence boundaries. A standalone owner capture proved
horizontal native widgets can visibly show protected amounts after death.
An owner alpha.62 dungeon capture confirmed the integrated vertical bars and
native hover labels for 14 protected receipts. It also exposed one protected
late callback that was not retained; alpha.63 closes that separate gap.
An alpha.63 owner screenshot confirmed five protected late amounts in the
separate hover panel. Lifetime through reopening/history switching and native
performance still require acceptance; mock tests do not establish those facts.

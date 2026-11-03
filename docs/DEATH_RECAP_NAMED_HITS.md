# Alpha.54: Journal links and named-hit investigation

## What changed

Real recorded boss deaths no longer require a manually populated Journal map.
Clicking a retained damage icon outside combat loads the native Journal and
finds the captured combat encounter ID. It selects the recorded difficulty,
verifies the boss/instance relationship, then searches that boss's visible
section tree. The matching native spell ID takes priority. A different damage
tick ID can use a unique, exact ability title within that boss. Duplicate or
approximate titles do not choose a section. A normal mob or self-inflicted
ability may have no separate boss Journal entry.

New boss captures retain their public game-map ID to make lookup faster.
Older saved boss deaths can still resolve through native instance/tier lists.
Positive encounter results are cached for the retained page, but the section
relationship and difficulty are revalidated on every click. Lookup is bounded
and only runs on a click; it adds no combat listener, timer or startup scan.
Failure restores the previous Journal selection. Navigation is blocked in
combat and when the selected row/death is no longer retained.

Hover **Named hits** to see the count and actual span of Blizzard's supplied
records. Blue plus amounts in this view are **absorbed damage**. Green healing
amounts remain in **8-second history**.

## What is still unresolved

The two views have different sources:

| View | Data supplied | Time reference |
| --- | --- | --- |
| 8-second history | Own incoming damage/healing amounts and schools; no spell names or attackers | Local callback receipt times before the death notice |
| Named hits | Blizzard's retained death-recap records, including damage spell/source, event-associated HP and absorbed amounts when public | Native event timestamps relative to the final retained event |

The named API has returned ten records in the reviewed client exports, sometimes
covering only a few seconds. Its public signature has no requested-duration,
row-count or pagination argument. This is an observed result, **not a documented
universal ten-record limit**. Arsenal accepts up to 64 supplied rows; regression
checks feed 10, 20 and 64 rows through the actual recorder, saved snapshot,
viewport and grouping without losing or renaming any. A 65-row packet explicitly
reports the 64-row retention bound. Offline mocks do not prove native access.

The current native records contain damage and absorption, not healing events.
Anonymous incoming receipts cannot safely become named spells by matching
amounts, school or nearby times. Their receipt clock is not a verified exact
bridge to native event timestamps; casts shown in Named hits remain explicitly
approximate. This update does not manufacture earlier hits or put heals at
guessed native times. A complete eight-second named/healing timeline remains
an open data-access problem.

Primary native UI/API references inspected:

- [DeathRecap API](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/DeathRecapDocumentation.lua)
- [Blizzard's death-recap renderer](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_DeathRecap/Blizzard_DeathRecap.lua)
- [Journal section fields](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/EncounterJournalDocumentation.lua)
- [Native Journal navigation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_EncounterJournal/Mainline/Blizzard_EncounterJournal.lua)

## Native check

No new death is required for the first check. Update, open `/recap`, choose a
saved boss death, and select **Named hits**. Outside combat, hover a boss ability
and click its icon. If a grouped icon contains several abilities, scroll its
tooltip to select the intended hit before clicking. The Journal should open
that boss, difficulty and ability. If a spell isn't a separate Journal entry,
the message says so without opening an unrelated ability. An actual client
click is still needed to validate native navigation and content coverage.

Hover the Named hits tab and check its supplied count/span against the raw
`/rcp recapdebug` record. Earlier blank time does not mean zero damage occurred.
Use 8-second history to review captured healing while named-healing access is
unresolved. Existing cooldown/consumable badges and the supplemental alpha.53
checks continue to apply.

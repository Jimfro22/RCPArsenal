# RCP Arsenal v0.13 Catalog Notes

## Capability catalog version

```text
RA.CATALOG_VERSION = 6
```

v0.13 changes UI, raid-management interactions, settings, and presentation only. It does not insert/remove/reorder capability catalog entries, so existing verified capability reports are not intentionally invalidated.

## Capability evidence model

Remote capabilities may be supported by:

- `SELECTED_TALENT`
- `BASELINE_SPEC`
- `GUARANTEED_CLASS`

Selected talent evidence takes priority. Specialization-display spells cannot override a supported mutually exclusive choice node.

## Supported choice groups

| Choice group | Members |
|---|---|
| `HOLY_WINGS` | Avenging Wrath, Avenging Crusader |
| `DISC_MAJOR` | Power Word: Barrier, Ultimate Penitence |
| `MISTWEAVER_REVIVAL` | Revival, Restoral |
| `MISTWEAVER_CELESTIAL` | Invoke Yu'lon, Invoke Chi-Ji |
| `PALADIN_PROTECTION_BLESSING` | Blessing of Protection, Blessing of Spellwarding |

## Class-specific report revisions

Current non-default revisions remain:

- Paladin: 2
- Priest: 2
- Monk: 2

A class interpretation correction should increment only that class revision when possible. Capability index insertion/deletion/reordering requires a catalog-version increment.

## Missing-coverage composition map

The Quick Bar's missing-major-buff/debuff list is intentionally separate from the encoded capability catalog.

| Type | Effect | Provider class | Spell ID |
|---|---|---|---:|
| Buff | Mark of the Wild | Druid | 1126 |
| Buff | Blessing of the Bronze | Evoker | 364342 |
| Buff | Devotion Aura | Paladin | 465 |
| Buff | Arcane Intellect | Mage | 1459 |
| Buff | Power Word: Fortitude | Priest | 21562 |
| Buff | Skyfury | Shaman | 462854 |
| Buff | Battle Shout | Warrior | 6673 |
| Debuff | Hunter's Mark | Hunter | 257284 |
| Debuff | Chaos Brand | Demon Hunter | 1490 |
| Debuff | Mystic Touch | Monk | 113746 |
| Debuff | Atrophic Poison | Rogue | 381637 |

Coverage means an online provider class is present in a tracked raid group. It does not mean an aura/debuff is currently active.
Rogue presence does not confirm its talent choice or an active Atrophic Poison.

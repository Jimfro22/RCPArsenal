from pathlib import Path
import json
import runpy
import unittest

ROOT=Path(__file__).resolve().parents[1]


class DeathRecapCatalogTests(unittest.TestCase):
    def test_audited_catalog_export_is_reproducible_and_runtime_gated(self):
        build=runpy.run_path(str(ROOT/'tools/build_death_recap_catalog.py'))['build']
        self.assertEqual(build(),(ROOT/'RCPArsenal/DeathRecapCatalog.lua').read_text())
        data=json.loads((ROOT/'provenance/death-recap/catalog.json').read_text())
        active=[e for e in data['entries'] if e['verified']]
        self.assertEqual(len(active),70)
        mage={e['spellID']:e for e in active if e['class']=='MAGE'}
        for spell_id in (55342,110959):
            self.assertIn(62,mage[spell_id]['specs'])
            self.assertEqual(mage[spell_id]['knownSpellIDs'],[spell_id])
            self.assertEqual(mage[spell_id]['verificationBuild'],'12.1.5.70688')
        self.assertEqual(len(data['coverage']['perSpec']),40)
        for row in data['coverage']['perSpec']:
            self.assertLessEqual(row['verifiedUniqueSpellCount'],32)
        self.assertFalse(data['coverage']['exhaustive'])
        source=(ROOT/'RCPArsenal/DeathRecap.lua').read_text()
        self.assertIn('entry.requiredTalentSpellIDs',source)
        self.assertIn('C_SpellBook.IsSpellKnown',source)
        self.assertIn('C_Spell.IsSpellPassive',source)
        self.assertIn('C_Spell.GetOverrideSpell',source)


if __name__=='__main__':unittest.main()

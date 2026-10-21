"""Pure Python counterexamples and fixture contracts; never compiles or runs AIR."""
import copy
import hashlib
import json
from pathlib import Path
import re
import unittest

import verify_results as verifier
import generate

HERE=Path(__file__).resolve().parent


def example(source=True,water=False):
    rows=[]
    for i in range(2):
        x=180+i*40
        rows.append(dict(id=i,x=x,y=320,bornFrame=5,bornAt=100,mliv=110,firstLiv=109,
            removedFrame=115,removedAt=4000,finalLiv=0,detached=True,stable=True,
            partClass='fe.graph::Part',visualClass='visualAcid',animated=True,alphaMin=.1,alphaMax=1,
            surface=dict(ty=8,x=x,y=320,phis=1,shelf=False,zForm=0,above=0,water=1 if water else 0)))
    return dict(source=source,id='acidgr',water=water,explosion=dict(water=water,x=200,y=300),
        shots=1 if source else 0,inputReleased=6 if source else 0,unexpected=0,flight=10,
        proof=dict(rows=rows,overflow=False,allEnded=True,pixel=dict(pixels=100,at=1000),readbackAt=4100))


class VerifierChecks(unittest.TestCase):
    def invalid(self,edit,source=True,water=False):
        value=example(source,water);edit(value)
        self.assertTrue(verifier.validate(value,source,water))

    def test_valid_dry_and_water_both_roles(self):
        for source in (True,False):
            for water in (True,False):self.assertEqual(verifier.validate(example(source,water),source,water),[])

    def test_flash_without_ground_fails(self):
        self.invalid(lambda v:v['proof'].update(rows=[]))

    def test_wrong_resource_fails(self):
        self.invalid(lambda v:v['proof']['rows'][0].update(visualClass='visualAcidExpl'))

    def test_plain_sprite_fails(self):
        self.invalid(lambda v:v['proof']['rows'][0].update(partClass='flash.display::Sprite'))

    def test_wrong_water_branch_fails(self):
        self.invalid(lambda v:v['explosion'].update(water=False),water=True)

    def test_native_lifetime_required(self):
        for key,value in [('mliv',99),('mliv',130),('firstLiv',0),('finalLiv',2),('detached',False),('removedFrame',5)]:
            self.invalid(lambda v,k=key,n=value:v['proof']['rows'][0].update({k:n}))

    def test_ground_must_be_stationary(self):
        self.invalid(lambda v:v['proof']['rows'][0].update(stable=False))

    def test_early_readback_rejected(self):
        self.invalid(lambda v:v['proof'].update(readbackAt=3999))

    def test_without_real_pixels_fails(self):
        self.invalid(lambda v:v['proof']['pixel'].update(pixels=0))

    def test_missing_terminal_rejected(self):
        self.invalid(lambda v:v['proof'].update(allEnded=False))

    def test_overflow_rejected(self):
        self.invalid(lambda v:v['proof'].update(overflow=True))

    def test_wrong_source_surface_and_fire_offset_fail(self):
        self.invalid(lambda v:v['proof']['rows'][0]['surface'].update(above=1))
        self.invalid(lambda v:v['proof']['rows'][0].update(y=287))

    def test_repeated_throw_or_held_input_fail(self):
        self.invalid(lambda v:v.update(shots=2))
        self.invalid(lambda v:v.update(inputReleased=0))

    def test_receiver_damaging_projectile_fails(self):
        self.invalid(lambda v:v.update(unexpected=1),source=False)

    def test_no_animation_or_no_alpha_change_fail(self):
        self.invalid(lambda v:[r.update(animated=False) for r in v['proof']['rows']])
        self.invalid(lambda v:[r.update(alphaMin=1) for r in v['proof']['rows']])

    def test_duplicate_local_part_identity_fails(self):
        self.invalid(lambda v:v['proof']['rows'][1].update(id=0))

    def test_footprint_strict_four_pixel_limit(self):
        a=example();b=example(False)
        for r in b['proof']['rows']:r['x']+=4
        self.assertTrue(verifier.footprint(a,b)[0])
        b['proof']['rows'][0]['x']+=.0001
        self.assertFalse(verifier.footprint(a,b)[0])

    def test_missing_extra_and_duplicate_footprint_fail(self):
        a=example();b=example(False)
        b['proof']['rows'].pop();self.assertFalse(verifier.footprint(a,b)[0])
        b=example(False);b['proof']['rows'].append(copy.deepcopy(b['proof']['rows'][0]))
        self.assertFalse(verifier.footprint(a,b)[0])
        b=example(False);b['proof']['rows'][1].update(x=180)
        self.assertFalse(verifier.footprint(a,b)[0])

    def test_nonfinite_position_fails(self):
        self.invalid(lambda v:v['proof']['rows'][0].update(x=float('nan')))

    def logs(self,missing=False,duplicate=False,coopfail=False):
        class TextLog:
            def __init__(self,text):self.text=text
            def read_text(self,**kwargs):return self.text
        logs={}
        for role in ('host','join'):
            lines=[]
            for n in range(4):
                if missing and role=='join' and n==3:continue
                record=dict(round=n,role=role,value=example((role=='host')==(n%2==0),n>=2))
                lines.append('ACID GROUND RESULT '+json.dumps(record))
            if duplicate and role=='join':lines.append(lines[-1])
            if coopfail and role=='host':lines.append('COOP FAIL acid-ground-native actual source input')
            logs[role]=TextLog('\n'.join(lines))
        return verifier.analyze(logs['host'],logs['join'])

    def test_all_eight_results_and_four_comparisons_required(self):
        result=self.logs();self.assertTrue(result['passed']);self.assertEqual(result['observed_results'],8)
        self.assertEqual(len(result['comparisons']),4);self.assertFalse(result['performance_qualified'])

    def test_missing_round_fails(self):
        self.assertFalse(self.logs(missing=True)['passed'])

    def test_duplicate_round_fails(self):
        self.assertFalse(self.logs(duplicate=True)['passed'])

    def test_existing_coop_failure_preserved(self):
        r=self.logs(coopfail=True);self.assertFalse(r['passed'])
        self.assertTrue(any('COOP FAIL' in e for e in r['errors']))


class SourceChecks(unittest.TestCase):
    def test_owned_equipment_and_native_quick_slot(self):
        doc=(HERE/'native/AcidGroundNativeTestDoc.as').read_text(encoding='utf-8')
        setup=generate.body(doc,'setup');round_prepare=generate.body(doc,'prepare')
        self.assertIn('standby=g.invent.addWeapon("lmg");g.changeWeapon("lmg",true);',setup)
        self.assertIn('g.childObjs=g.childObjs.concat();g.changeWeapon("not",true);',setup)
        self.assertNotIn('g.currentWeapon=standby',setup)
        self.assertIn('gun=g.invent.addWeapon(spec.id)',round_prepare)
        self.assertIn('g.invent.favItem(spec.id,29);',round_prepare)
        self.assertNotIn('wc.create(',doc)

    def test_inventory_arrays_and_equipment_restored(self):
        doc=(HERE/'native/AcidGroundNativeTestDoc.as').read_text(encoding='utf-8')
        setup=generate.body(doc,'setup');finish=generate.body(doc,'finish')
        for field in ('weapons','fav','favIds'):
            self.assertIn('g.invent.'+field+'=copyArray(g.invent.'+field+')',setup)
            self.assertIn('g.invent.'+field+'=originalInventory.'+field,finish)
        self.assertLess(finish.index('g.changeWeapon("not",true);'),finish.index('g.invent.weapons=originalInventory.weapons'))
        self.assertIn('if(oldGun!=null)g.changeWeapon(oldGun.id,true);',finish)
        restore=generate.body(doc,'restoreWeapon')
        self.assertIn('if(g.throwWeapon===gun)g.invent.favItem(gun.id,29);',restore)

    def test_frozen02_boot_methods_unchanged(self):
        frozen=HERE.parents[1]/'build/m52/recovery-acid-drivers-02/tests/AcidGroundNativeTestDoc.as'
        before=frozen.read_text(encoding='utf-8-sig')
        after=(HERE/'native/AcidGroundNativeTestDoc.as').read_text(encoding='utf-8-sig')
        for name in ('bootState','bootWorldReady','bootFrame','prepareBootActor','tick'):
            self.assertEqual(generate.body(before,name),generate.body(after,name),name)

    def test_frozen01_round_and_particle_criteria_unchanged(self):
        frozen=HERE.parents[1]/'build/m52/recovery-acid-drivers-01/tests'
        before=(frozen/'AcidGroundNativeTestDoc.as').read_text(encoding='utf-8-sig')
        after=(HERE/'native/AcidGroundNativeTestDoc.as').read_text(encoding='utf-8-sig')
        for name in ('complete','advance','render','before','sampleFlight'):
            self.assertEqual(generate.body(before,name),generate.body(after,name),name)
        self.assertEqual((frozen/'AcidGroundProbe.as').read_bytes(),(HERE/'native/AcidGroundProbe.as').read_bytes())

    def test_boot_real_ready_replaces_timer_count_and_does_not_revive(self):
        doc=(HERE/'native/AcidGroundNativeTestDoc.as').read_text(encoding='utf-8')
        self.assertIn('phase=="boot"?180000:26000',doc)
        self.assertNotIn('t.currentCount>130',doc)
        self.assertIn('bootFrames>=2 && bootWorldReady()',doc)
        gate=generate.body(doc,'bootWorldReady')
        for required in ('int(g.sost)==1','Number(g.hp)>0','!g.pers.dead','!mod.game.isTransitioning()',
                         '!mod.session.rooms.busy','!w.onPause','w.vblack.alpha','g.vis.stage!=null'):
            self.assertIn(required,gate)
        prep=generate.body(doc,'prepareBootActor')
        self.assertLess(prep.index('if(!bootWorldReady())return;'),prep.index('g.anim();g.controlOn();'))
        self.assertNotRegex(prep,r'\b(?:hp|sost|t_die|animOff)\s*=')
        frame=generate.body(doc,'bootFrame')
        self.assertIn('else bootFrames=0;',frame)
        self.assertIn('g.vis.osn.currentLabel!="die"',frame)

    def test_plan_binds_both_as_inputs_and_generator(self):
        p=json.loads((HERE/'native-plan.json').read_text(encoding='utf-8'))
        self.assertEqual(set(p['files']),{'AcidGroundNativeTestDoc.as','AcidGroundProbe.as'})
        for name,digest in p['files'].items():self.assertEqual(hashlib.sha256((HERE/'native'/name).read_bytes()).hexdigest(),digest)
        self.assertEqual(hashlib.sha256((HERE/'generate.py').read_bytes()).hexdigest(),p['generator_sha256'])
        self.assertEqual(p['position_tolerance_px'],4)

    def test_no_fabricated_production_effect_calls(self):
        text='\n'.join(p.read_text(encoding='utf-8') for p in (HERE/'native').glob('*.as'))
        clean=re.sub(r'//[^\n]*|/\*[\s\S]*?\*/','',text)
        for forbidden in ['.emit(','.explosion(','.explLiquid(','.step(','.playGround(','.receive(']:
            self.assertNotIn(forbidden,clean)
        self.assertIn('ctr.keyGrenad=true',clean)
        self.assertIn('nativeBullet=gun.b',clean)

    def test_readback_and_writes_are_not_render_work(self):
        text=(HERE/'native/AcidGroundProbe.as').read_text(encoding='utf-8')
        scan=text[text.index('public function scan('):text.index('private function write(')]
        self.assertNotIn('.getVector(',scan);self.assertNotIn('.encode(',scan);self.assertNotIn('FileMode.',scan)
        self.assertIn('finally {v.visible=visible;}',scan)
        doc=(HERE/'native/AcidGroundNativeTestDoc.as').read_text(encoding='utf-8')
        render=doc[doc.index('private function render('):doc.index('private function complete(')]
        self.assertNotIn('ground.result()',render)

    def test_appid_and_explicit_single_entry(self):
        pattern=re.compile(r'^pfe-modsettings-rconnect-coop-(host|join)-[a-f0-9]{10}$')
        self.assertRegex('pfe-modsettings-rconnect-coop-host-123456abcd',pattern)
        for other in ['remains','rconnect-coop-host-123456abcd','pfe-modsettings-rconnect-coop-host-123','evil-rconnect-coop-host-123456abcd']:
            self.assertNotRegex(other,pattern)
        code=(HERE/'native_tool.py').read_text(encoding='utf-8')
        self.assertIn("prepare.COMPONENTS={}",code);self.assertIn('EXPECTED_INSTALLATION_FILES==22',code)
        self.assertIn("prepare.freeze(source,out,entry_names=[ENTRY])",code)
        self.assertIn("run.main()",code);self.assertIn("['--control'] if args.control",code)
        self.assertIn("len(artifacts)!=24",code)


if __name__=='__main__':unittest.main(verbosity=2)

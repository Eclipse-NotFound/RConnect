"""Reuse the registered external density build; freeze a setup-only corridor02 delta."""
import hashlib
import importlib.util
from pathlib import Path
import shutil
import sys
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
M52=ROOT/'build/m52'
FIXED=ROOT/'experimental/recovery-density-fixture'
PINNED={
    'prepare.py':'99249ad83c9adc2d4073d614e0dc4952c22ec647b228c363c5bcbd4220dd7cad',
    'run.py':'7d6bee96c9aa4d817754894f1e623ba4a081bd0a193960ddf65217162993b598',
    'audit.py':'293d8e60c53e47dc946c03726bb4ea5cf57ec3e785a1413a00ee840e83545abe',
}

def load_helper(name):
    path=FIXED/name
    assert hashlib.sha256(path.read_bytes()).hexdigest()==PINNED[name],name
    spec=importlib.util.spec_from_file_location('readyfix_base_'+path.stem,path)
    mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod);return mod

base=load_helper('prepare.py');base.HERE=HERE
sha,read,save,verify=base.sha,base.read,base.save,base.verify
original_check,original_freeze=base.check_source,base.freeze
from generate import BASE,MANIFEST,expected_source

def check_source():
    required=original_check()
    assert sha(BASE/'prepared.json')==MANIFEST
    meta=read(BASE/'prepared.json')
    for source in sorted((BASE/'tests').rglob('*.as')):
        rel=source.relative_to(BASE).as_posix();assert sha(source)==meta['files'][rel]
        target=HERE/rel
        if rel=='tests/SustainedDensityTestDoc.as':
            assert target.read_text(encoding='utf-8-sig')==expected_source()
        else:assert sha(target)==sha(source),rel
    assert sha(HERE/'audit.py')==meta['files']['recipe/audit.py']
    assert sha(HERE/'run.py')==meta['files']['recipe/run.py']
    before=(BASE/'tests/SustainedDensityTestDoc.as').read_text(encoding='utf-8-sig')
    after=(HERE/'tests/SustainedDensityTestDoc.as').read_text(encoding='utf-8-sig')
    for first,last in [('      private function tick(','      private function nextPhase('),
                       ('      private function nextPhase(',None)]:
        def block(s):return s[s.index(first):] if last is None else s[s.index(first):s.index(last)]
        assert block(before)==block(after),'Timed method changed: '+first
    assert 'DensityWeaponPreparation' not in after[after.index('      private function tick('):]
    return required

def freeze(out,diagnostic):
    meta=original_freeze(out,diagnostic)
    for name in ('edits.json','static-check.json','handoff.json','README.md'):
        source=HERE/name;target=out/'recipe'/name
        shutil.copyfile(source,target)
        meta['originals'][str(source)]=sha(source);meta['inputs'][target.relative_to(out).as_posix()]=sha(target)
    for name,digest in PINNED.items():
        assert sha(FIXED/name)==digest;meta['originals'][str(FIXED/name)]=digest
    for source in [BASE/'prepared.json',*sorted((BASE/'tests').rglob('*.as'))]:
        meta['originals'][str(source)]=sha(source)
    meta.update(fixture='native-open-corridor-v1',source_corridor_driver=str(BASE),
        source_corridor_manifest=MANIFEST,native_flight_unmodified=True,native_visual_restore=True,
        one_time_weapon_preparation=True,product_parameter_sync_verified=False,
        purpose='Once-only real weapon fixture parameters before ready; same seven timed windows and strict audit')
    save(out/'prepared.json',meta);verify(out);return meta

base.check_source,base.freeze=check_source,freeze
if __name__=='__main__':base.main()

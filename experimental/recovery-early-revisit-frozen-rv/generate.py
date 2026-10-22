"""Explicit adapters for the one RV install transition; no original file changes."""
from pathlib import Path
import hashlib,json,difflib
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
BASE=HERE.parent/'recovery-early-sandy-native';PROBE=HERE.parent/'recovery-early-revisit-probe'
DRIVER=ROOT/'build/m52/recovery-early-sandy-scene-driver-01'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def replace(s,a,b):
    assert s.count(a)==1,(a,s.count(a))
    return s.replace(a,b,1)
def write(p,s):p.write_text(s,encoding='utf-8',newline='\n')
def adapt(name,original,new):
    write(HERE/name,new)
    write(HERE/(name+'.patch'),''.join(difflib.unified_diff(original.splitlines(True),new.splitlines(True),fromfile='frozen-original/'+name,tofile='explicit-rv-transition/'+name)))
def main():
    old=(BASE/'native_inputs.py').read_text(encoding='utf-8-sig')
    new=replace(old,'from run_security_terminals import installation','from run_security_terminals import installation\nfrom baseline import assert_current,frozen_vision,RV_KEY,RV_OLD,RV_NEW')
    new=replace(new,"    assert intent['installation_before']==installed","    assert_current(installed,intent['installation_before'])\n    frozen_vision()")
    new=replace(new,"recipe=ROOT/'experimental/recovery-early-host-review/recheck.py'","recipe=HERE/'host_recheck.py'")
    new=replace(new,"    assert actual==read(receipt) and actual['validated'] is True","    prior=read(receipt)\n    assert prior['recipe_sha256']==sha(ROOT/'experimental/recovery-early-host-review/recheck.py')\n    prior=dict(prior);prior['recipe_sha256']=sha(recipe)\n    assert actual==prior and actual['validated'] is True")
    new=new[:new.index('def verify_driver(')]+'''def verify_original_driver():
    path=M52/'recovery-early-sandy-scene-driver-01'
    pins=read(HERE/'inputs.json');assert sha(path/'prepared.json')==pins['driver_manifest']
    meta=read(path/'prepared.json')
    assert meta['kind']=='scene-native-input-early-sandy-driver' and meta['compiled'] is True
    assert meta['sand_mode']=='bridge' and meta['diagnostic_only'] is False
    assert_current(installation(),meta['installation_before'])
    for n,h in meta['source_inputs'].items():assert sha(n)==h,n
    for n,h in meta['files'].items():assert sha(path/n)==h,n
    return path,meta

def verify_driver(path,meta,scenario):
    verify_tools();base,old=verify_original_driver()
    assert scenario=='scene' and meta['kind']=='scene-native-input-early-revisit-frozen-rv-driver'
    assert meta['compiled'] is True and meta['external'] is True and meta['diagnostic_only'] is True
    assert meta['diagnostic_kind']=='early-revisit' and meta['sand_mode']=='bridge'
    assert meta['installation_unchanged'] is True and installation()==meta['installation_before']
    assert meta['original_scene_driver_manifest']==DRIVER12_MANIFEST
    assert meta['original_early_driver_manifest']==sha(base/'prepared.json')
    for n,h in meta['source_inputs'].items():assert sha(n)==h,n
    for n,h in meta['files'].items():assert sha(path/n)==h,n
    assert read(path/'original-prepared.json')==old
    for n in meta['copied_original_files']:
        assert n!='tests/FirstRasterSceneProbe.as' and sha(path/n)==old['files'][n],n
    probe=HERE.parent/'recovery-early-revisit-probe/tests/FirstRasterSceneProbe.as'
    assert sha(path/'tests/FirstRasterSceneProbe.as')==sha(probe)
'''
    adapt('native_inputs.py',old,new)
    path=ROOT/'experimental/recovery-early-host-review/recheck.py';old=path.read_text(encoding='utf-8-sig')
    new=replace(old,'import sys','import sys\nfrom baseline import assert_current')
    new=replace(new,"    assert len(installed) == 22 and installed == meta['installation_before']","    assert_current(installed,meta['installation_before'])")
    adapt('host_recheck.py',old,new)
    old=(BASE/'native_runner.py').read_text(encoding='utf-8-sig')
    new=replace(old,'    if args.sandy_candidate:\n        from native_inputs import sandy_input','    from native_inputs import frozen_vision,sandy_input\n    assert args.sandy_candidate and args.vision_candidate\n    assert args.vision_candidate.resolve()==frozen_vision().resolve()\n    if args.sandy_candidate:')
    adapt('native_runner.py',old,new)
    old=(PROBE/'run_native.py').read_text(encoding='utf-8-sig')
    new=replace(old,'verify_driver,sandy_input','verify_driver,sandy_input,frozen_vision,RV_KEY,RV_OLD,RV_NEW')
    new=replace(new,'RUNNER=Path(__file__).resolve().parent.parent/"recovery-early-sandy-native/native_runner.py"','RUNNER=Path(__file__).with_name("native_runner.py")')
    new=replace(new,'    sand=sandy_input(a.sand_mode)','    sand=sandy_input(a.sand_mode)\n    assert a.sand_mode=="bridge" and not a.solo\n    rv=frozen_vision()')
    new=replace(new,"native_host=host_intent,sandy=sand))","native_host=host_intent,sandy=sand,rv_candidate=str(rv),rv_sha256=RV_OLD,installed_rv_sha256=RV_NEW))")
    new=replace(new,"    if a.sand_mode=='bridge':cmd+=['--sandy-candidate',sand['candidate']]","    if a.sand_mode=='bridge':cmd+=['--sandy-candidate',sand['candidate']]\n    cmd+=['--vision-candidate',str(rv)]")
    new=replace(new,"            assert modules['mods/sandevistan/release/sandevistanmod.swf']==sand['candidate_sha256']","            assert modules['mods/sandevistan/release/sandevistanmod.swf']==sand['candidate_sha256']\n            assert modules[RV_KEY.lower()]==RV_OLD and inp['vision']==RV_OLD\n            assert before[RV_KEY]==after[RV_KEY]==RV_NEW")
    new=replace(new,"    result['sandy']=sand","    result['sandy']=sand\n    result['rv_candidate_sha256']=RV_OLD;result['installed_rv_sha256']=RV_NEW\n    assert frozen_vision()==rv")
    adapt('run_native.py',old,new)
    old=(PROBE/'prepare.py').read_text(encoding='utf-8-sig')
    new=replace(old,'from native_inputs import verify_tools,sha,original,HERE,BASE','from native_inputs import verify_tools,sha,read,installation,HERE,verify_original_driver,sandy_input\nPROBE=HERE.parent/"recovery-early-revisit-probe"')
    new=new.replace('original.installation()','installation()').replace('original.read(', 'read(')
    a=new.index('    # The original preparer verifies')
    b=new.index('    pins=',a)
    new=new[:a]+'''    base,old=verify_original_driver();sandy_input('bridge')
    copied=[n for n in old['files'] if n.startswith('tests/') and n!='tests/FirstRasterSceneProbe.as']
    copied+=['GameCombatStubs.swc','ProductionDeclarations.swc','scene/EffectsHarness.swf']
    (out/'tests').mkdir(parents=True);(out/'scene').mkdir()
    for n in copied:shutil.copyfile(base/n,out/n)
    shutil.copyfile(base/'prepared.json',out/'original-prepared.json')
    shutil.copyfile(PROBE/'tests/FirstRasterSceneProbe.as',out/'tests/FirstRasterSceneProbe.as')
    shutil.copyfile(Path(__file__),out/'revisit-prepare.py')
    shutil.copyfile(HERE/'inputs.json',out/'revisit-inputs.json')
'''+new[b:]
    new=replace(new,"kind='scene-native-input-early-revisit-driver'","kind='scene-native-input-early-revisit-frozen-rv-driver'")
    new=replace(new,"original_early_driver_manifest=sha(out/'original-prepared.json'),","original_early_driver_manifest=sha(out/'original-prepared.json'),copied_original_files=copied,")
    adapt('prepare.py',old,new)
    originals={}
    for folder in (BASE,PROBE):
        pins=read(folder/'inputs.json')
        originals.update(pins['originals'])
        originals.update({str(folder/n):h for n,h in pins['sources'].items()})
        originals[str(folder/'inputs.json')]=sha(folder/'inputs.json')
    from baseline import RV_PATH,DEPLOYMENT
    for p in (DRIVER/'prepared.json',RV_PATH,DEPLOYMENT):originals[str(p)]=sha(p)
    inputs={'driver_manifest':sha(DRIVER/'prepared.json'),'originals':originals,
        'sources':{p.relative_to(HERE).as_posix():sha(p) for p in sorted(HERE.rglob('*')) if p.is_file() and p.name not in ('inputs.json','check-result.json') and '__pycache__' not in str(p)}}
    write(HERE/'inputs.json',json.dumps(inputs,indent=2)+'\n')
if __name__=='__main__':main()

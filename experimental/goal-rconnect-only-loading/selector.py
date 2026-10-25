"""Existing official-selector isolation, narrowed to RConnect alone plus a DONE gate."""
from pathlib import Path
import difflib,hashlib,importlib.util,json,shutil,sys
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
OLD=HERE.parent/'recovery-room-reduced-runtime/launcher.py'
OLD_SHA='a5d3a120216c7573a4c26c6c923b821b53dbfeb9608ca3a4d5a93f017ab72601'
UI_RECIPE=HERE.parent/'goal-native-loading-native/recipe.py'
DISABLED={'AddictionSystemMod','ContinuousSceneMod','FirearmAttachmentsMod','LightAndDarknessMod',
          'LootEditorMod','ModLoaderMod','MoreSkillsWeaponsMod','PermanentInjuryMod','RandomRoomsMod',
          'RealisticVisionMod','SandevistanMod','TDFCMod','WallBlendMod'}
HOST=ROOT/'build/m52/goal-native-loading-host-03/pfe.swf'
HOST_SHA='2db0b4eb542661c45e5fa0056e7de44e730fee3cf1eac642f6f147f3ce1c2b82'
MARKER='NATIVE LOADING PROBE DONE '
_registered=None
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def load(p,n):
    s=importlib.util.spec_from_file_location(n,p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def replace(text,old,new,count=1):
    assert text.count(old)==count,old
    return text.replace(old,new)
def expanded_selector():
    assert sha(OLD)==OLD_SHA
    text=OLD.read_text('utf8')
    text=replace(text,"DISABLED = {'LightAndDarknessMod', 'RealisticVisionMod', 'ContinuousSceneMod'}",'DISABLED = '+repr(set(sorted(DISABLED))))
    # Use a sorted literal to keep the expanded source byte-stable across processes.
    text=text.replace('DISABLED = '+repr(set(sorted(DISABLED))), 'DISABLED = set('+repr(sorted(DISABLED))+')')
    text=replace(text,"    assert 'RConnectMod' in enabled and 'ModLoaderMod' in enabled","    assert enabled == {'RConnectMod'}")
    text=replace(text,'args.game_candidate is None','valid_game_candidate(args.game_candidate)')
    text=replace(text,"        assert args.seconds == 600 and args.game_root.resolve() == GAME.resolve() and valid_game_candidate(args.game_candidate)",
                      "        assert args.seconds == 600 and args.done == ONLY_RC_DONE and args.game_root.resolve() == GAME.resolve() and valid_game_candidate(args.game_candidate)")
    text=replace(text,'replacements=2','replacements=4',2)
    text=replace(text,'    runner.run_registered = registered\n    runner.main()\n',
                      '    bind_registered(registered)\n    runner.run_registered = invoke_registered\n    runner.main()\n')
    return text
def valid_host(p):return p is None or (Path(p).resolve()==HOST and sha(HOST)==HOST_SHA)
def module():
    text=expanded_selector()
    spec=importlib.util.spec_from_loader('only_rc_existing_selector',loader=None)
    m=importlib.util.module_from_spec(spec);m.__file__=str(OLD)
    m.valid_game_candidate=valid_host;m.ONLY_RC_DONE=MARKER
    exec(compile(text,str(HERE/'adapted-selector.py.txt'),'exec'),m.__dict__)
    recipe=load(UI_RECIPE,'only_rc_done_recipe');recipe.check()
    original_source=m.source
    def source():
        value,_=original_source()
        for old,new,count in recipe.RUNNER_EDITS:value=replace(value,old,new,count)
        return value,''.join(difflib.unified_diff(m.ORIGINAL.read_text('utf8').splitlines(True),value.splitlines(True),
                 fromfile='original/run_coop_regression.py',tofile='only-rconnect/run_coop_regression.py'))
    m.source=source
    return m
def source_texts():
    m=module();return {'adapted-selector.py.txt':expanded_selector(),'adapted-runner.py.txt':m.source()[0]}
def run_registered(*args,**kwargs):
    assert _registered is not None
    return _registered(*args,**kwargs)
def main():
    global _registered
    m=module()
    own=json.loads((HERE/'runtime-manifest.json').read_text('utf8'))
    for name,digest in own['files'].items():assert sha(HERE/name)==digest,name
    m.PINS.update({HERE/n:h for n,h in own['files'].items()})
    m.PINS[HERE/'runtime-manifest.json']=sha(HERE/'runtime-manifest.json')
    def bind(fn):
        global _registered
        assert _registered is None;_registered=fn
    m.bind_registered=bind;m.invoke_registered=lambda *a,**kw:run_registered(*a,**kw)
    try:return m.main()
    finally:_registered=None
if __name__=='__main__':main()

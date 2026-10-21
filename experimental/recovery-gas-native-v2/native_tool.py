"""Gas v2 external fixture; unchanged shared compile/runtime gates."""
import argparse
import importlib.util
import os
from pathlib import Path
import shutil
import sys

HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
GENERIC=ROOT/'experimental/recovery-tests'
sys.path.insert(0,str(GENERIC))
import prepare
assert Path(prepare.__file__).resolve()==GENERIC/'prepare.py'
ENTRY='GasPulseNativeTestDoc'
prepare.ENTRIES[ENTRY]=(4,360,'双向真实G单颗/重叠双颗气体Part、生产增量、显示及终末')
prepare.COMPONENTS={}


def tools():
    return {str(p):prepare.sha(p) for p in [Path(__file__).resolve(),GENERIC/'prepare.py',GENERIC/'run.py']}


def main():
    ap=argparse.ArgumentParser(description=__doc__);m=ap.add_subparsers(dest='mode',required=True)
    p=m.add_parser('prepare');p.add_argument('--source',type=Path,required=True);p.add_argument('--build',action='store_true')
    r=m.add_parser('run');r.add_argument('--drivers',type=Path,required=True);r.add_argument('--control',action='store_true')
    r.add_argument('--entry',choices=[ENTRY],default=ENTRY)
    for p in (p,r):p.add_argument('--output',type=Path,required=True);p.add_argument('--registry-wait',type=float,default=900)
    args=ap.parse_args();out=(ROOT/args.output).resolve()
    assert out.parent==(ROOT/'build/m52').resolve() and args.registry_wait>=0
    if args.mode=='prepare':
        source=(ROOT/args.source).resolve();assert source.is_relative_to(ROOT/'build') and source.name=='src'
        bridge=(source/'rconnect/game/GameBridge.as').read_text(encoding='utf-8')
        assert 'st.addEventListener(Event.ENTER_FRAME, onPerceptionFrame, false, 90000, true);' in bridge
        assert bridge.count('_sampleAt=getTimer();')==1,'Re-audit source-frame observation brackets for this candidate'
        plan=prepare.read(HERE/'native-plan.json')
        for name,digest in plan['files'].items():assert prepare.sha(HERE/'native'/name)==digest
        if out.exists():
            assert args.build
            manifest=prepare.verify(out,source)
            assert manifest['extension']['kind']=='gas-pulse-native-v2' and manifest['extension']['tools']==tools()
        else:
            manifest=prepare.freeze(source,out,entry_names=[ENTRY])
            for original,dest in [(HERE/'native'/name,'tests/'+name) for name in plan['files']] + \
                [(HERE/name,'inputs/gas-native-v2/'+name) for name in
                 ('native_tool.py','native-plan.json','verify_results.py','generate.py','driver.patch','README.md',
                  'check.py','offline-checks.json','counterexamples-recheck.json','diagnostic-plan.md')]:
                target=out/dest;assert not target.exists();target.parent.mkdir(parents=True,exist_ok=True)
                shutil.copyfile(original,target);manifest['inputs'][dest]=prepare.sha(target)
                manifest['originals'][str(original)]=prepare.sha(original)
            manifest['extension']=dict(kind='gas-pulse-native-v2',tools=tools(),entry=ENTRY)
            prepare.save(out/'prepared.json',manifest);prepare.verify(out,source)
        assert set(manifest['entries'])=={ENTRY} and manifest['components']=={}
        if args.build:prepare.build(source,out,args.registry_wait)
        assert manifest['extension']['tools']==tools(),'Entry adapter or shared tools changed during preparation'
        print(out);return 0
    assert not out.exists()
    drivers=(ROOT/args.drivers).resolve();assert drivers.parent==(ROOT/'build/m52').resolve()
    manifest=prepare.read(drivers/'prepared.json')
    assert manifest['extension']['kind']=='gas-pulse-native-v2' and manifest['extension']['tools']==tools()
    assert set(manifest['entries'])=={ENTRY} and not manifest['components']
    import run
    assert Path(run.__file__).resolve()==GENERIC/'run.py' and run.EXPECTED_INSTALLATION_FILES==22
    run.SUITES[ENTRY]='gas-pulse-native'
    prior=run.runtime_tools;run.runtime_tools=lambda:dict(prior(),**manifest['extension']['tools'])
    sys.argv=[sys.argv[0],'native','--drivers',str(drivers),'--output',str(out),'--entry',ENTRY,
              '--registry-wait',str(args.registry_wait)]+(['--control'] if args.control else [])
    code=run.main()
    assert manifest['extension']['tools']==tools()
    result=prepare.read(out/'result.json');native_run=result.get('run')
    if not native_run:return code or 1
    folder=Path(native_run).resolve();assert folder.parent==(ROOT/'build/cooperation').resolve()
    script=drivers/'inputs/gas-native-v2/verify_results.py'
    assert prepare.sha(script)==manifest['inputs']['inputs/gas-native-v2/verify_results.py']
    spec=importlib.util.spec_from_file_location('frozen_gas_verifier',script)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    verified=module.analyze(folder/'host.log',folder/'join.log')
    artifacts={}
    for role in ('host','join'):
        storage=Path(os.environ['APPDATA'])/('pfe-modsettings-rconnect-coop-'+role+'-'+folder.name)/'Local Store/gas-pulse-proof'
        for n in range(4):
            for suffix in ('proof.json','with.png','without.png'):
                name='round-'+str(n)+'-'+suffix;original=storage/name
                if not original.is_file():continue
                assert original.stat().st_size<=1024*1024,'Oversized diagnostic artifact'
                target=out/'gas-proof'/role/name;target.parent.mkdir(parents=True,exist_ok=True)
                assert not target.exists();shutil.copyfile(original,target)
                artifacts[target.relative_to(out).as_posix()]=prepare.sha(target)
    if len(artifacts)!=24:
        verified['passed']=False;verified['errors'].append('Missing saved gas evidence: expected 24 PNG/JSON artifacts')
    artifact_report=module.verify_artifacts(folder/'host.log',folder/'join.log',out/'gas-proof')
    verified['artifact_checks']=artifact_report
    verified['errors'].extend(artifact_report['errors'])
    verified['trajectory_checks_passed']=verified['passed']
    verified['passed']=verified['passed'] and artifact_report['passed'] and result['passed'] and code==0
    verified['sampledTrajectoryQualified']=verified['passed']
    verified.update(artifacts=artifacts,native_runner_passed=result['passed'],control=args.control,
                    installed=False,source_analyzer_sha256=prepare.sha(script))
    prepare.save(out/'gas-verification.json',verified)
    return 0 if code==0 and verified['passed'] else 1


if __name__=='__main__':raise SystemExit(main())

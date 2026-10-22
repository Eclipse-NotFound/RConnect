"""Thin wall-surface adapter over the registered recovery external framework.

The native function is reused with five exact binding substitutions only:
selected audited RC, its digest, a byte-identical driver binding, its VERSION,
and the accurately reverified FD92 native host.
No startup, timeout, memory, 22-input, ERROR or DONE check is replaced.
The explicit wall-bridge host must pass its preserved independent readback.
The default negative control still uses FD92, not BEFC.
"""
import argparse
import importlib.util
import inspect
import os
from pathlib import Path
import shutil
import sys

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
GENERIC=ROOT/'experimental/recovery-tests'
sys.path.insert(0,str(GENERIC))
import prepare
assert Path(prepare.__file__).resolve()==GENERIC/'prepare.py'
ENTRY='LargeWallSurfaceTestDoc'
prepare.ENTRIES[ENTRY]=(4,600,'大图真实原生墙痕：双向普通枪/速射等离子、世界像素与首次显示')
prepare.COMPONENTS={}
BASE14_SHA='225a794040c71f2a55ff433366a7969201ac3a58ffaab0a655cee1e4eefbe5f7'
HOST_DIR=ROOT/'build/m52/recovery-first-raster-host-03'
HOST_RECHECK=ROOT/'build/m52/recovery-first-raster-host-recheck-03/receipt.json'
HOST_RECIPE=ROOT/'experimental/recovery-first-raster-native'
WALL_HOST=ROOT/'build/m52/recovery-wall-surfaces-host-01'
WALL_RECHECK=ROOT/'build/m52/recovery-wall-surfaces-host-recheck-01/receipt.json'
WALL_RECIPE=ROOT/'experimental/recovery-wall-surfaces-host'
WALL_SHA='acc336b5f28012a5f0d2ef57d0a3bf46be46f72f1e4c3a69a2f063cae0535dfd'


def tools():
    result={str(p):prepare.sha(p) for p in [Path(__file__).resolve(),GENERIC/'prepare.py',GENERIC/'run.py',HERE/'verify_results.py',
        HOST_RECIPE/'reverify_host.py',HOST_RECIPE/'readback.py',HOST_RECIPE/'test_readback.py',HOST_RECHECK,
        HOST_DIR/'prepared.json',HOST_DIR/'pfe.swf',WALL_RECIPE/'recheck.py',WALL_RECHECK,
        WALL_HOST/'prepared.json',WALL_HOST/'native-input.json',WALL_HOST/'pfe.swf']}
    meta=prepare.read(WALL_HOST/'prepared.json')
    result.update(meta['inputs'])
    result.update({str(WALL_HOST/name):digest for name,digest in meta['readback_files'].items()})
    result.update({str(WALL_HOST/'import'/name):digest for name,digest in meta['import_sources'].items()})
    assert all(prepare.sha(Path(path))==digest for path,digest in result.items()),'Wall host provenance changed'
    return result


def host_evidence(host_dir=HOST_DIR):
    host_dir=Path(host_dir).resolve()
    assert host_dir in (HOST_DIR.resolve(),WALL_HOST.resolve()),'Only exact FD92 or audited ACC host is accepted'
    if host_dir==WALL_HOST.resolve():
        sys.path.insert(0,str(WALL_RECIPE))
        import recheck
        assert Path(recheck.__file__).resolve()==WALL_RECIPE/'recheck.py'
        assert Path(recheck.h.__file__).resolve()==WALL_RECIPE/'prepare_host.py'
        value=recheck.verify_prepared(host_dir)
        assert value==prepare.read(WALL_RECHECK),'Wall host independent recheck differs from saved receipt'
        assert value['candidate_sha256']==WALL_SHA==prepare.sha(host_dir/'pfe.swf')
        assert value['validated'] and value['original_failed_receipt_preserved']
        meta=prepare.read(host_dir/'prepared.json')
        installation=recheck.h.helpers()[2]()
        assert len(installation)==22 and installation==meta['installation_before']==meta['installation_after']
        return dict(value,installation=installation)
    sys.path.insert(0,str(HOST_RECIPE))
    import reverify_host
    assert Path(reverify_host.__file__).resolve()==HOST_RECIPE/'reverify_host.py'
    value=reverify_host.verify()
    assert value==prepare.read(HOST_RECHECK), 'FD92 independent recheck differs from preserved receipt'
    assert value['original_receipt_preserved'] and value['validated'] and value['passed']
    return value


def adapted_native(run):
    source=inspect.getsource(run.native)
    edits=[
        ("candidate = prepare.BASE if args.control else Path(manifest['source_root']).parent / 'RConnectMod.swf'", "candidate = _wall_candidate / 'RConnectMod.swf'"),
        ("digest = manifest['control_sha256'] if args.control else manifest['candidate_sha256']", "digest = sha(candidate)"),
        ("driver_path = drivers / ('controls' if args.control else 'drivers') / entry", "driver_path = _wall_binding(out, drivers, entry, digest)"),
        ("version_source = candidate.parent / 'src/RConnectMod.as' if args.control else drivers / 'production/RConnectMod.as'", "version_source = candidate.parent / 'src/RConnectMod.as'"),
        ("intent.update(command=command, entry=entry, purpose=spec['purpose'], control=args.control,",
         "command += ['--game-candidate', str(_wall_host / 'pfe.swf')]\n    intent.update(native_host=_wall_host_evidence)\n    intent.update(command=command, entry=entry, purpose=spec['purpose'], control=args.control,"),
    ]
    for before,after in edits:
        assert source.count(before)==1, 'Shared native adapter anchor changed'
        source=source.replace(before,after)
    # Only the existing native function is compiled as Python, never AS/JVM.
    scope=dict(run.__dict__)
    exec(compile(source,'<large-wall exact five-anchor adapter>','exec'),scope)
    return scope['native'],source,scope


def bind(out,drivers,entry,digest):
    original=drivers/'drivers'/entry;folder=out/'wall-driver-binding';folder.mkdir()
    old=prepare.read(original/'driver-input.json')
    assert old['entry']==entry and old['driver_sha256']==prepare.sha(original/'EffectsDriver.swf')
    for name in ('EffectsDriver.swf','EffectsHarness.swf'):shutil.copyfile(original/name,folder/name)
    prepare.save(folder/'driver-input.json',dict(entry=entry,candidate_sha256=digest,
        driver_sha256=old['driver_sha256'],original_binding_sha256=prepare.sha(original/'driver-input.json')))
    return folder


def main():
    ap=argparse.ArgumentParser(description=__doc__);sub=ap.add_subparsers(dest='mode',required=True)
    p=sub.add_parser('prepare');p.add_argument('--source',type=Path,required=True);p.add_argument('--build',action='store_true')
    r=sub.add_parser('run');r.add_argument('--candidate',type=Path,required=True);r.add_argument('--drivers',type=Path,required=True)
    r.add_argument('--game-candidate',type=Path,default=HOST_DIR,help='Exact audited host directory; default FD92, explicit wall host ACC only')
    for q in (p,r):q.add_argument('--output',type=Path,required=True);q.add_argument('--registry-wait',type=float,default=900)
    args=ap.parse_args();out=(ROOT/args.output).resolve()
    assert out.parent==(ROOT/'build/m52').resolve() and args.registry_wait>=0
    handoff=prepare.read(HERE/'handoff.json')
    for name,digest in handoff['files'].items():assert prepare.sha(HERE/name)==digest,name
    if args.mode=='prepare':
        source=(ROOT/args.source).resolve()
        assert source==(ROOT/'build/m52/recovery-14/src').resolve()
        assert prepare.sha(source.parent/'RConnectMod.swf')==BASE14_SHA
        if out.exists():
            assert args.build;meta=prepare.verify(out,source)
            assert meta['extension']['kind']=='large-native-wall-surfaces' and meta['extension']['tools']==tools()
        else:
            meta=prepare.freeze(source,out,entry_names=[ENTRY])
            for name in [*handoff['files'],'handoff.json']:
                origin=HERE/name;dest=out/(name if name.startswith('tests/') else 'inputs/large-wall/'+name)
                assert not dest.exists();dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(origin,dest)
                meta['inputs'][dest.relative_to(out).as_posix()]=prepare.sha(dest);meta['originals'][str(origin)]=prepare.sha(origin)
            meta['entries'][ENTRY]['land']='rbl'
            meta['extension']=dict(kind='large-native-wall-surfaces',tools=tools(),entry=ENTRY,
                handoff_sha256=prepare.sha(HERE/'handoff.json'),same_driver_cross_candidate=True)
            prepare.save(out/'prepared.json',meta);prepare.verify(out,source)
        if args.build:prepare.build(source,out,args.registry_wait)
        assert meta['extension']['tools']==tools();print(out);return 0
    assert not out.exists()
    drivers=(ROOT/args.drivers).resolve();candidate=(ROOT/args.candidate).resolve()
    assert drivers.parent==candidate.parent==(ROOT/'build/m52').resolve()
    meta=prepare.read(drivers/'prepared.json')
    assert meta['extension']['kind']=='large-native-wall-surfaces' and meta['extension']['tools']==tools()
    assert set(meta['entries'])=={ENTRY} and not meta['components'] and meta['entries'][ENTRY]['land']=='rbl'
    sys.path.insert(0,str(ROOT/'tools/validation'))
    from audit_room_entry_candidate import audit
    audit(candidate)
    host_dir=(ROOT/args.game_candidate).resolve();native_host=host_evidence(host_dir)
    pinned={str(candidate/name):prepare.sha(candidate/name) for name in ('prepared.json','RConnectMod.swf','src/RConnectMod.as')}
    import run
    assert Path(run.__file__).resolve()==GENERIC/'run.py' and run.EXPECTED_INSTALLATION_FILES==22
    run.SUITES[ENTRY]='large-wall-surfaces'
    native,source,scope=adapted_native(run)
    scope.update(_wall_candidate=candidate,_wall_binding=bind,_wall_host=host_dir,_wall_host_evidence=native_host)
    run.native=native
    original_inputs=run.native_inputs
    def native_inputs(folder,info,intent,spec):
        # Existing audit hashes ALL 22 files. Only its expected host digest is
        # substituted with the exact independently reverified isolated host;
        # the outer before/after installation inventory remains the real BEFC.
        assert intent['installation_before']==native_host['installation']
        adjusted=dict(intent,installation_before=dict(intent['installation_before']))
        adjusted['installation_before']['pfe.swf']=native_host['candidate_sha256']
        result=original_inputs(folder,info,adjusted,spec)
        for role in ('host','join'):
            result[role]['pfe.swf']['installed']=intent['installation_before']['pfe.swf']
            result[role]['pfe.swf']['override']='Exact independently reverified isolated '+host_dir.name+'; original failed receipt preserved'
        return result
    # The compiled native function has its own dictionary, so set both.
    run.native_inputs=native_inputs;scope['native_inputs']=native_inputs
    prior=run.runtime_tools;run.runtime_tools=lambda:dict(prior(),**tools(),**pinned)
    sys.argv=[sys.argv[0],'native','--drivers',str(drivers),'--output',str(out),'--entry',ENTRY,'--registry-wait',str(args.registry_wait)]
    code=run.main()
    # Do not rewrite the original framework result, including failed controls.
    (out/'framework-adapted-native.py').write_text(source,encoding='utf-8')
    audit(candidate)
    assert host_evidence(host_dir)==native_host
    assert all(prepare.sha(Path(p))==digest for p,digest in pinned.items())
    framework=prepare.read(out/'result.json');run_path=framework.get('run')
    if not run_path:return code or 1
    folder=Path(run_path).resolve();assert folder.parent==(ROOT/'build/cooperation').resolve()
    for role in ('host','join'):
        storage=Path(os.environ['APPDATA'])/('pfe-modsettings-rconnect-coop-'+role+'-'+folder.name)/'Local Store/large-wall-proof'
        for n in range(4):
            for suffix in ('proof.json','before-native.png','after-native.png','before-display.png','after-display.png'):
                file=storage/f'round-{n}-{suffix}'
                if not file.is_file():continue
                assert file.stat().st_size<=32*1024**2,'Oversized bounded crop evidence'
                dest=out/'wall-proof'/role/file.name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(file,dest)
    path=drivers/'inputs/large-wall/verify_results.py'
    assert prepare.sha(path)==meta['inputs']['inputs/large-wall/verify_results.py']
    spec=importlib.util.spec_from_file_location('frozen_wall_surface_analyzer',path)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    result=module.analyze(out/'wall-proof',{role:folder/(role+'.log') for role in ('host','join')})
    result.update(framework_passed=framework['passed'],framework_sha256=prepare.sha(out/'result.json'),
        native_run=str(folder),candidate_sha256=pinned[str(candidate/'RConnectMod.swf')],
        native_host_sha256=native_host['candidate_sha256'],native_host_directory=str(host_dir),
        source_analyzer_sha256=prepare.sha(path),installed=False)
    result['passed']=bool(framework['passed'] and result['passed'])
    prepare.save(out/'wall-surface-result.json',result)
    print(result['passed'],result['errors']);return 0 if code==0 and result['passed'] else 1


if __name__=='__main__':raise SystemExit(main())

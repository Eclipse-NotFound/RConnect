"""Freeze recovery22 + four wall-sv classes. Compilation requires explicit --build."""
from pathlib import Path
import argparse, difflib, hashlib, importlib.util, json, re, subprocess, sys, types

sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];GAME=ROOT.parents[1]
M52=ROOT/'build/m52';BASE=M52/'recovery-22';COMPONENT=M52/'recovery-ordinary-wall-sv-component-02'
DEFAULT=M52/'recovery-ordinary-wall-sv-production-01'
VERSION='0.2.24-wallsv1'
BASE_SHA='746eef5713985f23fe13a57792516789bebd37a5e4142639ba8cc8b6590b3e93'
MANIFEST_SHA='cada3af2e49459a3fe7c3b53ddca0e31392ab8b8fd1589ad0c4b05aa0a3042ce'
BASE_INTEGRATION_SHA='63b2f0cc1d06a0be68b9f883430255b5ef500d624cce341e5184cef04a632a0a'
OLD_VERSION=b'public static const VERSION:String = "0.2.24-recovery22";'
NEW_VERSION=b'public static const VERSION:String = "0.2.24-wallsv1";'
OVERLAY={
 'src/rconnect/game/WallImpactVisuals.as':'12682bff279d35d3dc2181d4832a9d948f9ee68fcfdcf5188ee53dec2c91ff72',
 'src/rconnect/game/WallSurfaceBridge.as':'3ab09a56064de874c869d2900ec936c6f41799f4f0b293a4941d6973c9eda324',
 'src/rconnect/game/GameBridge.as':'10d0b43f988d86dc4f2d0fdd5848f451f94aef47eaed49ee42132f356e75e88a',
 'src/rconnect/core/RoomSync.as':'f8d9449de1b9ba10b049013b21215efeb15658562b395d014f85e63f11d7a30f'}
TERRAIN='src/rconnect/game/TerrainSync.as'
TERRAIN_SHA='317c9658b0632f3bb8333c11cd302c68ef45e7a9f2f54ed6b6c631b6c1b92b44'
EVIDENCE={
 'intent.json':'f37acbaff091522b744bd72cbfce3e4c0a5c4b455637b686d4c33e455d03deda',
 'receipt.json':'6ef676e63648ee49101c9ed28c98df682a5e52f682ed5862efe7ac160532cf41',
 'component-result.json':'a148bc5fcfeca83e10f99a8313e19ad6c19fc3e6d3f104306adfbbf930da02b8'}
JAVA=Path('C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe')
SDK=ROOT.parent/'Sandevistan/build/tools/flexsdk'
PINS={
 JAVA:'9fcc7d5d43918e389df240d44601c98a4d3aa9e7d0cbbd6d208304e0b574c7e2',
 SDK/'lib/mxmlc.jar':'cc07d749e376715e650271a9875289e49d94234902fff5e5fae287c478c8557b',
 SDK/'lib/compc.jar':'843b4f9728d168abf3342585b47959d6120fa89718368e5d9acf636b2e7c6946',
 SDK/'frameworks/air-config.xml':'32e0c27a7135fe731e6fbc24152da18195b4738ea6e187ff6d1742ab1fd36680',
 SDK/'frameworks/flex-config.xml':'08cc21404b146d3f623f4176a8e19734d35e81ea852d802283748708511d4fca',
 SDK/'frameworks/libs/air/airglobal.swc':'e0f81fdb2029d2bb16e6987c8d85d4eba5eedfa3a23ed6e7f780bf6eb67b0546',
 ROOT/'tools/validation/runtime_memory.py':'d4894962771929b5b88f1d123c3603221dab06294657d33bc6229a2282fbf8f6',
 ROOT.parent/'ModLoader/tools/test_registry.py':'58db3a594f34e9906d55992f769b3e154970d8fa37fda1c2f43ae1f6751b0033'}

def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def read(path):return json.loads(Path(path).read_text(encoding='utf-8-sig'))
def save(path,value):
    with Path(path).open('x',encoding='utf-8',newline='\n') as stream:
        json.dump(value,stream,ensure_ascii=False,indent=2);stream.write('\n')
def inventory(folder,base):
    return {p.relative_to(base).as_posix():sha(p) for p in sorted(folder.rglob('*')) if p.is_file()}
def target(path):
    path=(ROOT/Path(path)).resolve()
    assert path.parent==M52.resolve() and re.fullmatch(r'recovery-ordinary-wall-sv-production-\d{2,}',path.name)
    return path

def installation():
    # The successful component's pinned intent fixes all 22 current inputs;
    # recovery22 was built with older unrelated inputs and cannot replace them.
    assert sha(COMPONENT/'intent.json')==EVIDENCE['intent.json']
    expected=read(COMPONENT/'intent.json')['installation_before']
    assert len(expected)==22
    assert sha(GAME/'mods/loader-manifest.txt')==expected['mods/loader-manifest.txt']
    files={GAME/'pfe.swf',GAME/'mods/loader-manifest.txt'}
    for line in (GAME/'mods/loader-manifest.txt').read_text(encoding='utf-8-sig').splitlines():
        if line.startswith('#') or '|' not in line:continue
        directory,entry=line.split('|')[:2]
        for name in [entry+'.swf','config.txt','config.json']+(['scene.xml'] if directory.lower()=='continuousscene' else []):
            path=GAME/'mods'/directory/'release'/name
            if path.is_file():files.add(path)
    result={p.relative_to(GAME).as_posix():sha(p) for p in sorted(files)}
    assert result==expected,'Current 22 installation inputs differ from pinned component-02 inputs'
    return result

def reviewed_inputs():
    assert sha(BASE/'prepared.json')==MANIFEST_SHA and sha(BASE/'RConnectMod.swf')==BASE_SHA
    assert sha(BASE/'integration.json')==BASE_INTEGRATION_SHA
    meta=read(BASE/'prepared.json')
    assert meta['compiled'] is True and meta['compile_exit']==0 and meta['candidate_sha256']==meta['sha256']==BASE_SHA
    source={'src/'+n:h for n,h in meta['source'].items()};inputs={'tools/'+n:h for n,h in meta['inputs'].items()}
    assert len(source)==90 and len(inputs)==71
    assert inventory(BASE/'src',BASE)==source and inventory(BASE/'tools',BASE)==inputs
    assert inventory(HERE/'src',HERE)==dict(OVERLAY,**{TERRAIN:TERRAIN_SHA})
    assert source[TERRAIN]==TERRAIN_SHA
    for name,digest in OVERLAY.items():
        assert name in source and source[name]!=digest and sha(HERE/name)==digest,name
    for name,digest in EVIDENCE.items():assert sha(COMPONENT/name)==digest,name
    receipt=read(COMPONENT/'receipt.json');checks=read(COMPONENT/'component-result.json');intent=read(COMPONENT/'intent.json')
    assert receipt['passed'] is True and receipt['observed_checks']==153 and receipt['checks_failed']==0 and receipt['exit_code']==0
    assert receipt['installation_unchanged'] is True and receipt['source_unchanged'] is True
    assert checks['passed'] is True and checks['count']==153 and checks['failed']==0
    for name in ('rconnect/game/WallImpactVisuals.as','rconnect/game/WallSurfaceBridge.as'):
        assert intent['sources'][name]==OVERLAY['src/'+name]==sha(HERE/'components'/name)
    for path,digest in PINS.items():assert sha(path)==digest,str(path)
    return source,inputs

def source_bytes(name):
    data=(HERE/name if name in OVERLAY else BASE/name).read_bytes()
    if name=='src/RConnectMod.as':
        assert data.count(OLD_VERSION)==1;data=data.replace(OLD_VERSION,NEW_VERSION,1)
    return data

def proposal_patch(source):
    lines=[]
    for name in sorted(set(OVERLAY)|{'src/RConnectMod.as'}):
        lines.extend(difflib.unified_diff((BASE/name).read_text(encoding='utf-8').splitlines(True),
            source_bytes(name).decode('utf-8').splitlines(True),fromfile='recovery22/'+name,tofile=VERSION+'/'+name))
    return ''.join(lines).encode('utf-8')

def verify(folder):
    out=target(folder);source,inputs=reviewed_inputs();meta=read(out/'prepared.json')
    assert meta['kind']=='isolated-ordinary-wall-sv-production' and meta['version']==VERSION
    assert meta['recipe_sha256']==sha(__file__) and meta['base_manifest_sha256']==MANIFEST_SHA and meta['base_sha256']==BASE_SHA
    assert meta['base_integration_sha256']==BASE_INTEGRATION_SHA and meta['terrain_unchanged'] is True
    assert meta['base_source']==source and meta['overlay']==OVERLAY and meta['component_evidence']==EVIDENCE
    assert inventory(out/'tools',out)==meta['inputs']==inputs
    assert len(meta['source'])==90 and inventory(out/'src',out)==meta['source']
    assert sorted(n for n in source if source[n]!=meta['source'][n])==sorted(list(OVERLAY)+['src/RConnectMod.as'])
    for name in source:assert (out/name).read_bytes()==source_bytes(name),name
    assert (out/'wall-sv.patch').read_bytes()==proposal_patch(source) and sha(out/'wall-sv.patch')==meta['patch_sha256']
    assert meta['toolchain_inputs']=={str(p):h for p,h in PINS.items()}
    assert meta['installation_before']==installation() and meta['installation_unchanged'] is True
    assert meta['compiled'] is False and meta['air_started'] is False and meta['installed'] is False
    if (out/'compile.json').exists():
        result=read(out/'compile.json')
        assert result['compiled'] is True and result['compile_exit']==0
        assert result['prepared_sha256']==sha(out/'prepared.json')
        assert result['installation_before']==result['installation_after']==meta['installation_before']
        assert result['installation_unchanged'] is True and result['sources_unchanged'] is True
        assert result['candidate_sha256']==sha(out/'RConnectMod.swf')
        assert result['air_started'] is False and result['installed'] is False
        for name,digest in result['artifacts'].items():assert sha(out/name)==digest,name
    return meta

def prepare(folder):
    out=target(folder);assert not out.exists(),'Existing candidate is preserved; verify or use a new output'
    source,inputs=reviewed_inputs();before=installation();out.mkdir()
    save(out/'prepare-start.json',dict(version=VERSION,recipe_sha256=sha(__file__),installation_before=before))
    try:
        for name in sorted(source):
            dest=out/name;dest.parent.mkdir(parents=True,exist_ok=True)
            with dest.open('xb') as stream:stream.write(source_bytes(name))
        for name,digest in sorted(inputs.items()):
            assert sha(BASE/name)==digest
            dest=out/name;dest.parent.mkdir(parents=True,exist_ok=True)
            with dest.open('xb') as stream:stream.write((BASE/name).read_bytes())
        with (out/'wall-sv.patch').open('xb') as stream:stream.write(proposal_patch(source))
        reviewed_inputs();assert installation()==before
        meta=dict(kind='isolated-ordinary-wall-sv-production',version=VERSION,base_sha256=BASE_SHA,base_manifest_sha256=MANIFEST_SHA,
            base_integration_sha256=BASE_INTEGRATION_SHA,base_source=source,overlay=OVERLAY,component_evidence=EVIDENCE,
            source=inventory(out/'src',out),inputs=inventory(out/'tools',out),changed=sorted(list(OVERLAY)+['src/RConnectMod.as']),
            terrain_unchanged=True,recipe_sha256=sha(__file__),patch_sha256=sha(out/'wall-sv.patch'),
            toolchain_inputs={str(p):h for p,h in PINS.items()},installation_before=before,installation_unchanged=True,
            compiled=False,air_started=False,installed=False,gameplay_qualified=False,performance_qualified=False)
        save(out/'prepared.json',meta);return verify(out)
    except BaseException as exc:
        save(out/'prepare-failure.json',dict(error_type=type(exc).__name__,error=str(exc),compiled=False,air_started=False,installed=False))
        raise

def build(folder,wait):
    # Same two Java calls as recovery-offline-production/prepare.py. Only the
    # privately loaded original build_mod module receives the owned supervisor.
    out=target(folder);meta=verify(out)
    assert not any((out/n).exists() for n in ('compile-start.json','compile.json','compile.log','RConnectMod.swf','build','release')),'A build is single-use; preserve prior artifacts'
    before=installation();prepared_hash=sha(out/'prepared.json')
    save(out/'compile-start.json',dict(prepared_sha256=prepared_hash,installation_before=before))
    result=dict(compiled=False,compile_exit=None,prepared_sha256=prepared_hash,installation_before=before,
        air_started=False,installed=False,gameplay_qualified=False,performance_qualified=False,commands=[])
    sys.path.insert(0,str(ROOT.parent/'ModLoader/tools'));sys.path.insert(0,str(ROOT/'tools/validation'))
    from test_registry import Registration
    from runtime_memory import snapshot,wait_owned
    error=None
    try:
        with Registration(owner='RConnect / 普通墙沿生产候选',resource='game',purpose=VERSION+' isolated compile only',
                run_dir=out,evidence=out/'compile.json',wait=wait) as record:
            verify(out);assert installation()==before
            assert snapshot()['free_commit_bytes']>=1024**3,'Less than 1 GiB before compiler'
            path=out/'tools/build_mod.py';assert sha(path)=='b386f55f5e19886ec70905794d9a2237d29ee413fabe5229aefb158249832fa6'
            spec=importlib.util.spec_from_file_location('wall_sv_original_build_mod',path)
            module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
            with (out/'compile.log').open('x',encoding='utf-8') as log:
                def owned_run(command,env=None,check=False):
                    index=len(result['commands']);assert index<2
                    expected=SDK/('lib/compc.jar' if index==0 else 'lib/mxmlc.jar')
                    assert command[0]==str(JAVA) and '-Xmx384m' in command
                    assert Path(command[command.index('-jar')+1]).resolve()==expected.resolve()
                    assert snapshot()['free_commit_bytes']>=1024**3,'Less than 1 GiB before Java'
                    item=dict(command=command,pid=None,exit_code=None,reaped=False);result['commands'].append(item)
                    log.write(json.dumps(command,ensure_ascii=False)+'\n');log.flush();process=None
                    try:
                        record.before_launch('Original '+expected.name)
                        process=subprocess.Popen(command,cwd=out,env=env,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
                        item['pid']=process.pid;record.child(process.pid)
                        code=wait_owned(process,300,out/('compile-memory-'+str(index+1)+'.json'));item['exit_code']=code
                    finally:
                        if process is not None:
                            if process.poll() is None:process.kill()
                            process.wait();item['reaped']=process.poll() is not None
                        record.child_stopped()
                    if check and code:raise subprocess.CalledProcessError(code,command)
                    return subprocess.CompletedProcess(command,code)
                module.subprocess=types.SimpleNamespace(run=owned_run)
                previous_argv=sys.argv
                try:
                    sys.argv=[str(path),'--java',str(JAVA),'--amxmlc',str(SDK/'bin/amxmlc.bat'),'--output',str(out/'RConnectMod.swf')]
                    module.main()
                finally:sys.argv=previous_argv
            assert len(result['commands'])==2 and all(c['exit_code']==0 and c['reaped'] for c in result['commands'])
            verify(out);assert installation()==before and sha(out/'prepared.json')==prepared_hash
            assert (out/'RConnectMod.swf').read_bytes()[:3] in (b'FWS',b'CWS',b'ZWS')
            result.update(compiled=True,compile_exit=0,candidate_sha256=sha(out/'RConnectMod.swf'))
            record.outcome='passed';record.note='Only isolated compilation passed; native gameplay and performance pending'
    except BaseException as exc:
        error=exc;result.update(error_type=type(exc).__name__,error=str(exc))
        if isinstance(exc,SystemExit):result['compile_exit']=exc.code
        elif isinstance(exc,subprocess.CalledProcessError):result['compile_exit']=exc.returncode
    finally:
        try:
            result['installation_after']=installation();result['installation_unchanged']=result['installation_after']==before
            result['sources_unchanged']=inventory(out/'src',out)==meta['source'] and inventory(out/'tools',out)==meta['inputs'] and sha(out/'prepared.json')==prepared_hash
            result['artifacts']={n:sha(out/n) for n in ('RConnectMod.swf','build/GameCombatStubs.swc','compile.log','compile-memory-1.json','compile-memory-2.json') if (out/n).exists()}
            if not result['installation_unchanged'] or not result['sources_unchanged']:result['compiled']=False
        except BaseException as exc:
            result.update(compiled=False,final_check_error=str(exc));error=error or exc
        save(out/'compile.json',result)
    if error is not None:raise error
    verify(out);return result

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,default=DEFAULT)
    group=parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--prepare',action='store_true');group.add_argument('--verify',action='store_true');group.add_argument('--build',action='store_true')
    parser.add_argument('--registry-wait',type=float,default=900);args=parser.parse_args();out=target(args.output)
    if args.prepare:prepare(out)
    elif args.verify:verify(out)
    else:build(out,args.registry_wait)
    result=read(out/'compile.json') if (out/'compile.json').exists() else read(out/'prepared.json')
    print(json.dumps(dict(output=str(out),version=VERSION,compiled=result['compiled'],candidate_sha256=result.get('candidate_sha256'),air_started=False,installed=False)))
if __name__=='__main__':main()

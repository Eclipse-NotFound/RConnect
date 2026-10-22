"""Freeze the reviewed 574D offline proposal; compile only with explicit --build."""
from pathlib import Path
import argparse,difflib,hashlib,importlib.util,json,os,re,subprocess,sys,types

HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];GAME=ROOT.parents[1]
M52=ROOT/'build/m52';BASE=M52/'coop-bundle-04'
PROPOSAL=ROOT.parent/'ContinuousScene/build/generated/rc-offline-production-proposal-20261023-r1'
DEFAULT=M52/'recovery-offline-production-01'
VERSION='0.2.24-offline1'
BASE_SHA='574d2b51490ae8b25a1396555600f56a301f8a20ae50104c0e35cf2796441afe'
MANIFEST_SHA='4d0743b2fdd61586b22193c431e5d5fba534d77ca33e0bc5483b2f286ae112b1'
PROOF_SHA='ec95927aa31e0517b17850eaed2150b93530c1c59ec4da420b3c445f572dd045'
PATCH_SHA='d17c2e92271cebdd57527b4dc4273dcf620d22d72e25074648939fadb2a06f23'
CHANGED=['src/RConnectMod.as','src/rconnect/core/Session.as','src/rconnect/game/GameBridge.as']
OLD_VERSION=b'public static const VERSION:String = "0.2.23-coop-bundle2";'
NEW_VERSION=b'public static const VERSION:String = "0.2.24-offline1";'
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
    with Path(path).open('x',encoding='utf-8',newline='\n') as stream:json.dump(value,stream,ensure_ascii=False,indent=2);stream.write('\n')
def inventory(folder,base):
    return {p.relative_to(base).as_posix():sha(p) for p in sorted(folder.rglob('*')) if p.is_file()}
def target(path):
    path=(ROOT/Path(path)).resolve()
    assert path.parent==M52.resolve() and re.fullmatch(r'recovery-offline-production-\d{2,}',path.name)
    return path
def installation():
    files={GAME/'pfe.swf',GAME/'mods/loader-manifest.txt'}
    for line in (GAME/'mods/loader-manifest.txt').read_text(encoding='utf-8-sig').splitlines():
        if line.startswith('#') or '|' not in line:continue
        directory,entry=line.split('|')[:2]
        names=[entry+'.swf','config.txt','config.json']+(['scene.xml'] if directory.lower()=='continuousscene' else [])
        for name in names:
            path=GAME/'mods'/directory/'release'/name
            if path.is_file():files.add(path)
    result={p.relative_to(GAME).as_posix():sha(p) for p in sorted(files)}
    assert len(result)==22 and result['mods/Rconnect/release/RConnectMod.swf']==BASE_SHA
    return result

def reviewed_inputs():
    """Read-only byte proof, including exact edits and the 75 untouched sources."""
    assert sha(BASE/'prepared.json')==MANIFEST_SHA and sha(BASE/'RConnectMod.swf')==BASE_SHA
    assert sha(PROPOSAL/'source-provenance.json')==PROOF_SHA and sha(PROPOSAL/'production.patch')==PATCH_SHA
    base=read(BASE/'prepared.json');proof=read(PROPOSAL/'source-provenance.json')
    assert base['compiled'] is True and base['candidate_sha256']==base['sha256']==BASE_SHA
    assert len(base['source'])==78 and len(base['inputs'])==71
    assert inventory(BASE/'src',BASE)==base['source'] and inventory(BASE/'tools',BASE)==base['inputs']
    before={n:h.lower() for n,h in proof['before'].items()};after={n:h.lower() for n,h in proof['after'].items()}
    assert before==base['source'] and inventory(PROPOSAL/'src',PROPOSAL)==after
    assert proof['sourceBinary'].lower()==BASE_SHA and proof['sourceManifestSHA'].lower()==MANIFEST_SHA
    assert proof['changed']==CHANGED and sorted(proof['edits'])==CHANGED
    assert proof['productionPatchSHA'].lower()==PATCH_SHA and proof['reverseByteReconstruction'] is True
    assert proof['sourceCount']==78 and proof['unchangedSourceCount']==75
    assert sorted(n for n in before if before[n]!=after[n])==CHANGED
    assert sum(before[n]==after[n] for n in before)==75 and set(before)==set(after)
    patch=[]
    for name in CHANGED:
        original=(BASE/name).read_bytes();value=original.decode('utf-8')
        for edit in proof['edits'][name]:
            assert value.count(edit['before'])==1
            value=value.replace(edit['before'],edit['after'],1)
        assert value.encode('utf-8')==(PROPOSAL/name).read_bytes()
        patch.extend(difflib.unified_diff(original.decode('utf-8').splitlines(True),value.splitlines(True),
            fromfile='574D/'+name,tofile='proposal/'+name))
    assert ''.join(patch)==(PROPOSAL/'production.patch').read_text(encoding='utf-8')
    for path,digest in PINS.items():assert sha(path)==digest,str(path)
    return base,after

def verify(folder):
    """No writes. A present compile receipt must describe matching successful output."""
    out=target(folder);base,proposal=reviewed_inputs();meta=read(out/'prepared.json')
    assert meta['kind']=='isolated-offline-production' and meta['version']==VERSION
    assert meta['base_sha256']==BASE_SHA and meta['proposal_proof_sha256']==PROOF_SHA and meta['proposal_patch_sha256']==PATCH_SHA
    assert meta['recipe_sha256']==sha(__file__) and meta['readme_sha256']==sha(HERE/'README.md')
    assert meta['base_manifest_sha256']==MANIFEST_SHA and meta['proposal_source']==proposal
    assert meta['inputs']==base['inputs']==inventory(out/'tools',out)
    assert len(meta['source'])==78 and inventory(out/'src',out)==meta['source']
    assert sorted(n for n in proposal if proposal[n]!=meta['source'][n])==['src/RConnectMod.as']
    code=(PROPOSAL/'src/RConnectMod.as').read_bytes();assert code.count(OLD_VERSION)==1
    assert (out/'src/RConnectMod.as').read_bytes()==code.replace(OLD_VERSION,NEW_VERSION,1)
    assert (out/'proposal.patch').read_bytes()==(PROPOSAL/'production.patch').read_bytes()
    assert (out/'proposal-proof.json').read_bytes()==(PROPOSAL/'source-provenance.json').read_bytes()
    assert meta['toolchain_inputs']=={str(p):h for p,h in PINS.items()}
    assert meta['installation_unchanged'] is True and installation()==meta['installation_before']
    assert meta['compiled'] is False and meta['installed'] is False and meta['air_started'] is False
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
    out=target(folder);assert not out.exists(),'Preserve existing candidate; use verify or a new output'
    before=installation();base,proposal=reviewed_inputs();out.mkdir()
    for name in sorted(proposal):
        source=PROPOSAL/name;data=source.read_bytes()
        if name=='src/RConnectMod.as':
            assert data.count(OLD_VERSION)==1;data=data.replace(OLD_VERSION,NEW_VERSION,1)
        dest=out/name;dest.parent.mkdir(parents=True,exist_ok=True)
        with dest.open('xb') as stream:stream.write(data)
    for name,digest in sorted(base['inputs'].items()):
        assert name.startswith('tools/') and (BASE/name).resolve().is_relative_to(BASE.resolve())
        assert sha(BASE/name)==digest
        dest=out/name;dest.parent.mkdir(parents=True,exist_ok=True)
        with dest.open('xb') as stream:stream.write((BASE/name).read_bytes())
    for source,name in ((PROPOSAL/'production.patch','proposal.patch'),(PROPOSAL/'source-provenance.json','proposal-proof.json')):
        with (out/name).open('xb') as stream:stream.write(source.read_bytes())
    reviewed_inputs();assert installation()==before
    meta=dict(kind='isolated-offline-production',version=VERSION,base_sha256=BASE_SHA,base_manifest_sha256=MANIFEST_SHA,
        source=inventory(out/'src',out),inputs=inventory(out/'tools',out),proposal_source=proposal,
        proposal_proof_sha256=PROOF_SHA,proposal_patch_sha256=PATCH_SHA,changed=CHANGED,
        recipe_sha256=sha(__file__),readme_sha256=sha(HERE/'README.md'),toolchain_inputs={str(p):h for p,h in PINS.items()},
        installation_before=before,installation_unchanged=True,compiled=False,air_started=False,installed=False,
        gameplay_qualified=False,performance_qualified=False)
    save(out/'prepared.json',meta);return verify(out)

def build(folder,wait):
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
        with Registration(owner='RConnect / 离线采集生产候选',resource='game',purpose=VERSION+' isolated compile only',
                run_dir=out,evidence=out/'compile.json',wait=wait) as record:
            verify(out);assert installation()==before
            assert snapshot()['free_commit_bytes']>=1024**3,'Less than 1 GiB before compiler'
            path=out/'tools/build_mod.py'
            assert sha(path)=='b386f55f5e19886ec70905794d9a2237d29ee413fabe5229aefb158249832fa6'
            spec=importlib.util.spec_from_file_location('offline_original_build_mod',path)
            module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
            with (out/'compile.log').open('x',encoding='utf-8') as log:
                def owned_run(command,env=None,check=False):
                    index=len(result['commands']);assert index<2
                    expected=SDK/('lib/compc.jar' if index==0 else 'lib/mxmlc.jar')
                    assert command[0]==str(JAVA) and '-Xmx384m' in command
                    assert Path(command[command.index('-jar')+1]).resolve()==expected.resolve()
                    assert snapshot()['free_commit_bytes']>=1024**3,'Less than 1 GiB before Java'
                    item=dict(command=command,pid=None,exit_code=None,reaped=False);result['commands'].append(item)
                    log.write(json.dumps(command,ensure_ascii=False)+'\n');log.flush()
                    process=None
                    try:
                        record.before_launch('Original '+expected.name)
                        process=subprocess.Popen(command,cwd=out,env=env,stdout=log,stderr=subprocess.STDOUT,
                            creationflags=subprocess.CREATE_NO_WINDOW)
                        item['pid']=process.pid;record.child(process.pid)
                        code=wait_owned(process,300,out/('compile-memory-'+str(index+1)+'.json'))
                        item['exit_code']=code
                    finally:
                        if process is not None:
                            if process.poll() is None:process.kill()
                            process.wait();item['reaped']=process.poll() is not None
                        record.child_stopped()
                    if check and code:raise subprocess.CalledProcessError(code,command)
                    return subprocess.CompletedProcess(command,code)
                # Only this loaded module receives the supervisor. No global monkeypatch.
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
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output',type=Path,default=DEFAULT)
    group=ap.add_mutually_exclusive_group();group.add_argument('--build',action='store_true');group.add_argument('--verify',action='store_true')
    ap.add_argument('--registry-wait',type=float,default=900)
    args=ap.parse_args();out=target(args.output)
    if args.verify:verify(out)
    elif args.build:
        if not out.exists():prepare(out)
        build(out,args.registry_wait)
    else:prepare(out)
    result=read(out/'compile.json') if (out/'compile.json').exists() else read(out/'prepared.json')
    print(json.dumps(dict(output=str(out),compiled=result['compiled'],candidate_sha256=result.get('candidate_sha256'),air_started=False,installed=False)))
if __name__=='__main__':main()

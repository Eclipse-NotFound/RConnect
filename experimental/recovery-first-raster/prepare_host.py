"""Freeze one Grafon import on pinned E159; --build explicitly runs FFDec.

Reuse existing registry, toolchain, SWF tag/header and normalization helpers.
No AIR, loader change, source patching outside this proposal, or deployment.
"""
import argparse,hashlib,json,re,subprocess,sys
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
GAME=ROOT.parents[1]
HOST=ROOT/'build/m52/recovery-native-travel-host-01/pfe.swf'
PIN='e159fe0f0a1cbb34596d18b9979f439e80823fbeda369be7b2220a42e8e5d30c'
REL='fe/graph/Grafon.as'
REPRESENTATIVES=('MainFE','fe.World','fe.loc.Game','fe.loc.Land','fe.loc.Location','fe.inter.Camera','fe.inter.GUI')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def body(s,name):
    m=re.search(r'function\s+(?:get\s+)?'+name+r'\([^\n]*\)[^{]*\{',s);assert m,name
    i=m.end();depth=1
    while depth:
        depth+=(s[i]=='{')-(s[i]=='}');i+=1
    return re.sub(r'\s+','',s[m.end():i-1])
def verify_grafon(s):
    assert 'rconnectRasterBridge:Function' in s and 'rconnectRasterTicket:Object' in s
    opened=body(s,'sceneOpen');last=-1
    for call in ('rconnectRasterBridge(','sceneSyncRegionLighting(','sceneClear(',
                 'sceneConfigureBorders(','scenePrepare(','setLight(','sceneIndexBackdrops(',
                 'sceneEnsure(','drawAllObjs(','rconnectRasterPainted('):
        found=opened.index(call);assert found>last,call;last=found
    for name in ('sceneEnsure','sceneTick','sceneViewReady'):
        assert body(s,name).startswith('if(this.rconnectRasterWaiting())return'),name
    assert '.unpainted=false;' in body(s,'rconnectRasterPainted')
    assert 'sceneResident>0' in body(s,'rconnectRasterPainted')
    assert 'if(!this.sceneRasterizing)this.rconnectRasterTicket=null;' in body(s,'drawLoc')
    assert not re.search(r'\.\s*\(\s*@',s),'Unexpected E4X import hazard'
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output',type=Path);parser.add_argument('--build',action='store_true')
    parser.add_argument('--registry-wait',type=float,default=900);a=parser.parse_args()
    out=(ROOT/a.output).resolve();assert out.parent==ROOT/'build/m52' and not out.exists()
    assert sha(HOST)==PIN
    source=HERE/'native'/REL;s=source.read_text(encoding='utf-8');verify_grafon(s)
    assert '§§' not in s,'Unsupported FFDec pseudo-instruction in import source'
    meta=json.loads((HERE/'integration.json').read_text(encoding='utf-8'))
    assert sha(source)==meta['overlays']['native/'+REL]
    reference=ROOT/'build/m52/recovery-native-travel-host-01/after/scripts'/REL
    assert sha(reference)=='09ff2387e744acb9716ae6760de2f8a1c49963da76ae97d072d1bcb759ab6ef3'
    sys.path.insert(0,str(ROOT/'tools/validation'))
    from prepare_recovery_native_travel import normalized,movie_header
    from run_security_terminals import installation
    sys.path.insert(0,str(ROOT/'tools/host_authority'))
    from common import JAVA,FFDEC
    from patch_native import swf_tags
    sys.path.insert(0,str(GAME/'mods/ModLoader/tools'))
    from test_registry import Registration
    inputs={str(p):sha(p) for p in (HOST,source,reference,HERE/'integration.json',Path(__file__),JAVA,FFDEC,
        ROOT/'tools/validation/prepare_recovery_native_travel.py',ROOT/'tools/host_authority/patch_native.py',
        GAME/'mods/ModLoader/tools/test_registry.py')}
    installed=installation();assert len(installed)==22
    target=out/'import'/REL;target.parent.mkdir(parents=True);target.write_bytes(source.read_bytes())
    receipt=dict(kind='isolated-first-raster-host',base_sha256=PIN,patched_classes=['fe.graph.Grafon'],
        inputs=inputs,import_sources={REL:sha(target)},installation_before=installed,compiled=False,validated=False,
        air_started=False,installed=False,gameplay_qualified=False,performance_qualified=False,
        audit_scope='Grafon bridge/readback anchors, unchanged representatives, class list/header/non-code tags; not all ABC semantics')
    names=','.join(('fe.graph.Grafon',*REPRESENTATIVES))
    commands=[(['-selectclass',names,'-export','script',out/'before',HOST],'before.log'),
              (['-importScript',HOST,out/'pfe.swf',out/'import'],'import.log'),
              (['-selectclass',names,'-export','script',out/'after',out/'pfe.swf'],'after.log'),
              (['-dumpAS3',HOST],'before-classes.txt'),(['-dumpAS3',out/'pfe.swf'],'after-classes.txt')]
    save(out/'commands.json',[[str(JAVA),'-Xmx512m','-jar',str(FFDEC),*map(str,args)] for args,_ in commands])
    save(out/'prepared.json',receipt)
    def verify():
        assert all(sha(Path(p))==h for p,h in inputs.items()),'Source, recipe or tool changed'
        assert sha(target)==receipt['import_sources'][REL] and installation()==installed
    if a.build:
        try:
            with Registration(owner='RConnect / 首次栅格 Grafon 隔离补丁',resource='game',
                              purpose='E159 Grafon only; FFDec, no AIR',run_dir=out,
                              evidence=out/'prepared.json',wait=a.registry_wait) as record:
                for args,name in commands:
                    verify()
                    with (out/name).open('x',encoding='utf-8') as log,(out/(name+'.stderr.log')).open('x',encoding='utf-8') as err:
                        process=None
                        try:
                            record.before_launch('FFDec '+name)
                            process=subprocess.Popen([str(JAVA),'-Xmx512m','-jar',str(FFDEC),*map(str,args)],
                                stdout=log,stderr=err,cwd=out)
                            record.child(process.pid);code=process.wait(timeout=240);assert code==0,(name,code)
                        finally:
                            if process is not None and process.poll() is None:process.kill();process.wait()
                            record.child_stopped()
                    if name=='import.log':receipt.update(compiled=True,candidate_sha256=sha(out/'pfe.swf'))
                verify()
                assert normalized((out/'before/scripts'/REL).read_text(encoding='utf-8-sig'))==normalized(reference.read_text(encoding='utf-8-sig'))
                verify_grafon((out/'after/scripts'/REL).read_text(encoding='utf-8-sig'))
                representatives={}
                for name in REPRESENTATIVES:
                    p=Path(*name.split('.')).with_suffix('.as')
                    before=normalized((out/'before/scripts'/p).read_text(encoding='utf-8-sig'))
                    after=normalized((out/'after/scripts'/p).read_text(encoding='utf-8-sig'))
                    assert before==after,name
                    representatives[name]=hashlib.sha256(before.encode()).hexdigest()
                old,new=swf_tags(HOST),swf_tags(out/'pfe.swf');assert len(old)==len(new)
                changed=[]
                for i,(x,y) in enumerate(zip(old,new)):
                    assert x[0]==y[0]
                    if x!=y:assert x[0] in (72,82);changed.append(i)
                assert changed and movie_header(HOST)==movie_header(out/'pfe.swf')
                assert normalized((out/'before-classes.txt').read_text(encoding='utf-8-sig'))==normalized((out/'after-classes.txt').read_text(encoding='utf-8-sig'))
                receipt.update(validated=True,representative_normalized_sha256=representatives,changed_code_tags=changed,
                               non_code_tags_unchanged=True,loader_unchanged=True,class_list_unchanged=True,movie_header_unchanged=True)
                record.outcome='passed';record.note='Grafon isolated compile/readback only; no runtime qualification'
        except BaseException as e:
            receipt.update(validated=False,error=repr(e));raise
        finally:
            receipt.update(installed_unchanged=installation()==installed,source_unchanged=all(sha(Path(p))==h for p,h in inputs.items()))
            if not receipt['installed_unchanged'] or not receipt['source_unchanged']:receipt['validated']=False
            save(out/'prepared.json',receipt)
    print(out)
if __name__=='__main__':main()

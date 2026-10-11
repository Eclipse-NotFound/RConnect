"""Build a reviewable Land-only game candidate; never writes an installation."""
import difflib, hashlib, json, struct, subprocess, sys, zlib
from pathlib import Path
from validation_baseline import ROOT, GAME, M51_BASELINE, read, sha
from run_final_regressions import JAVA

out=(ROOT/sys.argv[1]).resolve()
assert out.parent==ROOT/'build/m51' and out.name.startswith('map-seed-game-')
assert not (out/'pfe.swf').exists()
original=GAME/'pfe.swf'
baseline=read(ROOT/M51_BASELINE/'inputs.json')
assert sha(original)==baseline['protected']['pfe.swf']
ffdec=[JAVA,'-jar','D:/RemainsMod/mods/Sandevistan/build/tools/ffdec/ffdec-cli.jar']
out.mkdir(parents=True,exist_ok=True)
source=out/'export/scripts/fe/loc/Land.as'
if not source.exists(): subprocess.run(ffdec+['-selectclass','fe.loc.Land','-export','script',str(out/'export'),str(original)],check=True)
s=source.read_text(encoding='utf-8-sig')
old='            rndDeterm(rndSeedFor(this.act.id));'
assert s.count(old)==1 and 'rconnectSeedSource' not in s
new=s.replace('      public var act:LandAct;',
    '      public static var rconnectSeedSource:Function = null;\n\n'
    '      public var rconnectLayoutSeed:uint = 0;\n\n      public var act:LandAct;',1)
new=new.replace(old,
    '            this.rconnectLayoutSeed = rconnectSeedSource == null ? uint(1 + Math.floor(Math.random() * 4294967295)) : uint(rconnectSeedSource(this));\n'
    '            rndDeterm(this.rconnectLayoutSeed);\n'
    '            this.rconnectLayoutSeed = _rndSeed;',1)
dest=out/'import/fe/loc/Land.as';dest.parent.mkdir(parents=True,exist_ok=True);dest.write_text(new,encoding='utf-8')
(out/'land-seed.patch').write_text(''.join(difflib.unified_diff(s.splitlines(True),new.splitlines(True),fromfile='installed/fe/loc/Land.as',tofile='candidate/fe/loc/Land.as')),encoding='utf-8')
subprocess.run(ffdec+['-importScript',str(original),str(out/'pfe.swf'),str(out/'import')],check=True)
subprocess.run(ffdec+['-selectclass','fe.loc.Land,MainFE','-export','script',str(out/'verified'),str(out/'pfe.swf')],check=True)
subprocess.run(ffdec+['-selectclass','MainFE','-export','script',str(out/'original-loader'),str(original)],check=True)
after=(out/'verified/scripts/fe/loc/Land.as').read_text(encoding='utf-8-sig')
assert 'rconnectSeedSource(this)' in after and 'rndDeterm(this.rconnectLayoutSeed)' in after
assert 'rndDeterm(rndSeedFor(this.act.id))' not in after
assert (out/'verified/scripts/MainFE.as').read_bytes()==(out/'original-loader/scripts/MainFE.as').read_bytes()

def tags(p):
    data=p.read_bytes(); data=data[:8]+zlib.decompress(data[8:]) if data[:3]==b'CWS' else data
    assert data[:3] in (b'FWS',b'CWS')
    pos=8+(5+4*(data[8]>>3)+7)//8+4; result=[]
    while pos<len(data):
        head=struct.unpack_from('<H',data,pos)[0];pos+=2;size=head&63;kind=head>>6
        if size==63:size=struct.unpack_from('<I',data,pos)[0];pos+=4
        body=data[pos:pos+size];assert len(body)==size;result.append((kind,body));pos+=size
        if kind==0:break
    return result
a,b=tags(original),tags(out/'pfe.swf')
assert len(a)==len(b)
changed=[i for i,(x,y) in enumerate(zip(a,b)) if x!=y]
assert len(changed)==1 and a[changed[0]][0]==b[changed[0]][0]==82,changed
for name,p in [('before',original),('after',out/'pfe.swf')]:
    with (out/(name+'-classes.txt')).open('w',encoding='utf-8') as f:subprocess.run(ffdec+['-dumpAS3',str(p)],stdout=f,check=True)
assert (out/'before-classes.txt').read_bytes()==(out/'after-classes.txt').read_bytes()
receipt=dict(original_sha256=sha(original),candidate_sha256=sha(out/'pfe.swf'),
    sources={p.relative_to(out).as_posix():sha(p) for p in (source,dest)},
    script_sha256=sha(Path(__file__)),script=str(Path(__file__).relative_to(ROOT)),
    changed_swf_tags=changed,non_code_tags_unchanged=True,loader_source_unchanged=True,classes_unchanged=True,
    diagnostic_only=True,installation_modified=False)
(out/'game-input.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2),encoding='utf-8')
assert sha(original)==receipt['original_sha256']
print(json.dumps(receipt,ensure_ascii=False))

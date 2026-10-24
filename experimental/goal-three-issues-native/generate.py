"""Derive measurement-only sources from the exact old native fixtures.

No compiler, AIR or installed file changes. Only this new recipe directory is
written; old visual drivers and every original check remain intact.
"""
from pathlib import Path
import difflib, hashlib, json
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
BASE=ROOT/'build/m52/motion2-native-input-drivers-04'
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def replace(text,old,new):
    assert text.count(old)==1, old
    return text.replace(old,new)
def main():
    assert sha(BASE/'prepared.json')=='677fabc0191e7809d588d2ce3b64f02c8de119131e7db46b1624d314bfa22a5b'
    meta=json.loads((BASE/'prepared.json').read_text('utf-8-sig'))
    for name,digest in meta['files'].items(): assert sha(BASE/name)==digest,name
    changes={}
    name='NativeJumpNetworkTestDoc.as'; old=(BASE/'tests'/name).read_text('utf8'); s=old
    s=replace(s,'private var pictures:int=0;','private var pictures:int=0;\n      private var meter:NativeMotionProbe;')
    s=replace(s,'area=p;phase="settle";at=getTimer();','area=p;phase="settle";at=getTimer();meter=new NativeMotionProbe(mod,host);')
    s=replace(s,'phase="moving";at=frameAt;','phase="moving";at=frameAt;meter.begin("native-jump",0);')
    s=replace(s,'if(pictures<2&&age>3000+pictures*6000)picture();','// Measurement variant: PNG capture stays in the frozen visual driver.')
    s=replace(s,'if(age<18000)return;','if(age<18000)return;\n         meter.end("measurement-complete",true);')
    s=replace(s,'var p:Object=e.data,snap:Object=host?p.snap:null;','var p:Object=e.data,snap:Object=host?p.snap:null;\n         if(meter!=null)meter.receive(p);')
    s=replace(s,'Log.d("COOP EFFECTS DONE native-jump "+(host?"host":"join"));','if(meter!=null)meter.close();\n         Log.d("COOP EFFECTS DONE native-jump "+(host?"host":"join"));')
    changes[name]=(old,s)
    name='FastHeldTestDoc.as'; old=(BASE/'tests'/name).read_text('utf8'); s=old
    s=replace(s,'private var lifecycle:MovableGripLifecycle;','private var lifecycle:MovableGripLifecycle;\n      private var meter:NativeMotionProbe;')
    s=replace(s,'releaseKey();round=n;phase="settle";','if(meter==null)meter=new NativeMotionProbe(mod,host);\n         releaseKey();round=n;phase="settle";')
    s=replace(s,'phase="holding";at=now;inputAt=now;inputFrame=frame;startY=target.Y;','phase="holding";at=now;inputAt=now;inputFrame=frame;startY=target.Y;\n            meter.begin("fast-held",round,target,kind()=="box"?boxKey:"");')
    s=replace(s,'releaseAt=now;dropY=target.Y;','meter.end("measurement-complete");\n            releaseAt=now;dropY=target.Y;')
    s=replace(s,'var p:Object=e.data;','var p:Object=e.data;\n         if(meter!=null)meter.receive(p);')
    s=replace(s,'Log.d("COOP EFFECTS DONE tele-motion "+(host?"host":"join"));','if(meter!=null)meter.close();\n         Log.d("COOP EFFECTS DONE tele-motion "+(host?"host":"join"));')
    changes[name]=(old,s)
    diff=''
    for name,(old,new) in changes.items():
        assert old.count('check(')==new.count('check(')
        assert new.count('picture();')==0
        target=HERE/'tests'/name
        assert not target.exists()
        target.write_text(new,encoding='utf8',newline='\n')
        diff+=''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile='frozen/'+name,tofile='measurement/'+name))
    dependencies=['RemoteMotionPauseRegression.as','HeldMotionBufferRegression.as','MovableGripLifecycle.as','fe/unit/TelekinesisProbe.as']
    for name in dependencies:
        target=HERE/'tests'/name;target.parent.mkdir(parents=True,exist_ok=True)
        assert not target.exists();target.write_bytes((BASE/'tests'/name).read_bytes())
    (HERE/'source.diff').write_text(diff,encoding='utf8',newline='\n')
    manifest=dict(kind='native-motion-measurement-v1',original_prepared_sha256=sha(BASE/'prepared.json'),
        generator_sha256=sha(__file__),diff_sha256=sha(HERE/'source.diff'),
        original={n:sha(BASE/'tests'/n) for n in [*changes,*dependencies]},
        sources={p.relative_to(HERE/'tests').as_posix():sha(p) for p in (HERE/'tests').rglob('*.as')},
        runtimeValidated=False,smoothnessQualified=False)
    (HERE/'source-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf8')
if __name__=='__main__':main()

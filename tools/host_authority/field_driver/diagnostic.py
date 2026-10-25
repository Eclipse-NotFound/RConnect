"""Measure the current replica hot path; diagnostic bytes are never deployable."""
import shutil
from run import ROOT, read, save, sha, verify_files, inside_build

base=ROOT/'build/ab/b190-field6-build'
out=inside_build(ROOT/'build/ab/b190-field6-diagnostic-source-02')
manifest=read(base/'build-input.json');verify_files(base,manifest['sources'])
out.mkdir()
for name in ('src','stubs'):shutil.copytree(base/name,out/name)

def edit(name,old,new):
    path=out/'src'/name;s=path.read_text(encoding='utf-8')
    if s.count(old)!=1:raise ValueError('Unexpected diagnostic anchor: '+old)
    path.write_text(s.replace(old,new),encoding='utf-8')

edit('authority/BuildInfo.as',manifest['source_id'],'__SOURCE_HASH__')
edit('RConnectMod.as','B3-0.1-field1','B3-0.1-fielddiag')
edit('authority/ReplicaScene.as','NativeFields.apply(u,s.fields);u.loc=room;','var part:int=Timing.start();\n         NativeFields.apply(u,s.fields);u.loc=room;')
edit('authority/ReplicaScene.as','NativeFields.apply(u.inter,s.inter);','NativeFields.apply(u.inter,s.inter);\n         Timing.end("replica.unitFields",part);part=Timing.start();')
edit('authority/ReplicaScene.as','AuthorityAnimation.apply(u as Unit,s.blit);','Timing.end("replica.unitAttach",part);part=Timing.start();\n         AuthorityAnimation.apply(u as Unit,s.blit);\n         Timing.end("replica.unitBlit",part);part=Timing.start();')
edit('authority/ReplicaScene.as','VisualPose.apply(u.vis,s.pose);','Timing.end("replica.unitBarLayout",part);part=Timing.start();\n         VisualPose.apply(u.vis,s.pose);')
edit('authority/ReplicaScene.as','healthBar(u,s);','healthBar(u,s);\n         Timing.end("replica.unitPose",part);part=Timing.start();')
edit('authority/ReplicaScene.as','u.childObjs=rec.weapons;','u.childObjs=rec.weapons;\n         Timing.end("replica.unitWeapons",part);')
edit('authority/ClientReplica.as','scene.pointer();','var pointerAt:int=Timing.start();scene.pointer();Timing.end("client.pointer",pointerAt);')
save(out/'recipe.json',dict(base=manifest['candidate_sha256'],diagnostic_only=True,
    files={p.relative_to(out).as_posix():sha(p) for p in out.rglob('*.as')},script=sha(__file__)))
print(out)

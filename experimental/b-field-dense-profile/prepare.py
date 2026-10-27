"""Prepare diagnostic-only, sequential unit cost spans from the installed field22 source."""
from pathlib import Path
import difflib
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'build/ab/b190-field22-source'
OUT = ROOT / 'build/ab/b190-dense-profile01-source'

def replace(text, old, new):
    if text.count(old) != 1:
        raise ValueError('Non-unique insertion: ' + old[:120])
    return text.replace(old, new)

def main():
    if OUT.exists():
        raise FileExistsError(OUT)
    OUT.mkdir()
    for folder in ('src', 'stubs'):
        shutil.copytree(BASE / folder, OUT / folder)
    changes = {}
    name = 'src/authority/SceneSnapshot.as'
    path = OUT / name
    before = text = path.read_text(encoding='utf-8')
    text = replace(text, '            var burning:Boolean=AuthorityAnimation.burning(u as Unit);',
        '            var unitPart:int=Timing.start();\n            var burning:Boolean=AuthorityAnimation.burning(u as Unit);')
    text = replace(text, 'cls:getQualifiedClassName(u),fields:NativeFields.capture(u),inter:interaction(u.inter),pose:VisualPose.capture(u.vis,0,burning || replay),',
        'cls:getQualifiedClassName(u)};\n            Timing.end("capture.unit.metadata",unitPart);unitPart=Timing.start();\n'
        '            us.fields=NativeFields.capture(u);us.inter=interaction(u.inter);\n'
        '            Timing.end("capture.unit.fields",unitPart);unitPart=Timing.start();\n'
        '            us.pose=VisualPose.capture(u.vis,0,burning || replay);\n'
        '            Timing.end("capture.unit.body",unitPart);unitPart=Timing.start();\n            var rest:Object={')
    text = replace(text, '            us.healthBar=u.hpbar',
        '            for(var partKey:String in rest)us[partKey]=rest[partKey];\n'
        '            Timing.end("capture.unit.blit",unitPart);unitPart=Timing.start();\n            us.healthBar=u.hpbar')
    text = replace(text, '            for each(actor in actors)if(actor.unit.pet===u)',
        '            Timing.end("capture.unit.bar",unitPart);unitPart=Timing.start();\n            for each(actor in actors)if(actor.unit.pet===u)')
    text = replace(text, '            result.units.push(us);',
        '            Timing.end("capture.unit.weapons",unitPart);\n            result.units.push(us);')
    path.write_text(text, encoding='utf-8')
    changes[name] = (before, text)
    name = 'src/authority/ReplicaScene.as'
    path = OUT / name
    before = text = path.read_text(encoding='utf-8')
    text = replace(text, '      private function applyUnit(s:Object):void {',
        '      private function applyUnit(s:Object):void {\n         var unitPart:int=Timing.start();')
    text = replace(text, '         NativeFields.apply(u,s.fields);u.loc=room;',
        '         Timing.end("replica.unit.construct",unitPart);unitPart=Timing.start();\n         NativeFields.apply(u,s.fields);u.loc=room;')
    text = replace(text, '         if(s.attached)attach(u,s.layer);',
        '         Timing.end("replica.unit.fields",unitPart);unitPart=Timing.start();\n         if(s.attached)attach(u,s.layer);')
    text = replace(text, '         // Health bars are native render-only methods;',
        '         Timing.end("replica.unit.blit",unitPart);unitPart=Timing.start();\n         // Health bars are native render-only methods;')
    text = replace(text, '         VisualPose.apply(u.vis,s.pose);\n         healthBar(u,s);',
        '         Timing.end("replica.unit.barNative",unitPart);unitPart=Timing.start();\n'
        '         VisualPose.apply(u.vis,s.pose);\n'
        '         Timing.end("replica.unit.body",unitPart);unitPart=Timing.start();\n'
        '         healthBar(u,s);\n'
        '         Timing.end("replica.unit.barPose",unitPart);unitPart=Timing.start();')
    text = replace(text, '         u.childObjs=rec.weapons;',
        '         u.childObjs=rec.weapons;\n         Timing.end("replica.unit.weapons",unitPart);')
    path.write_text(text, encoding='utf-8')
    changes[name] = (before, text)
    folder = Path(__file__).parent
    (folder / 'diagnostic.patch').write_text(''.join(''.join(difflib.unified_diff(a.splitlines(True), b.splitlines(True), fromfile=n, tofile=n)) for n,(a,b) in changes.items()), encoding='utf-8')
    files = {str(p.relative_to(OUT)).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(OUT.rglob('*.as'))}
    (folder / 'source-plan.json').write_text(json.dumps(dict(base=str(BASE), output=str(OUT),diagnostic_only=True,files=files),indent=2)+'\n',encoding='utf-8')
    print(OUT)

if __name__ == '__main__':
    main()

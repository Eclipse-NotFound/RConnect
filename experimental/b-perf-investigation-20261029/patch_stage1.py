from pathlib import Path

ROOT = Path(__file__).resolve().parents[2] / 'build' / 'ab' / 'b-stage1-source-01' / 'src'

def patch(rel, pairs):
    p = ROOT / rel
    s = p.read_text(encoding='utf-8')
    for old, new in pairs:
        if s.count(old) != 1:
            raise SystemExit(f'{rel}: expected one occurrence, got {s.count(old)}: {old[:80]!r}')
        s = s.replace(old, new)
    p.write_text(s, encoding='utf-8')
    print('patched', rel)

patch('authority/SceneSnapshot.as', [
    ('import flash.utils.getQualifiedClassName;\n', ''),
    ('result.fields=NativeFields.capture(room);result.fon=room.land.act.fon;', 'result.fon=room.land.act.fon;'),
    ('         var unitsStarted:int=Timing.start();\n         for each(var u:Object in room.units)if(u!=null && !u.player) {\n            var burning:Boolean=AuthorityAnimation.burning(u as Unit);\n            var replay:Boolean=access.time!=null && access.time.phase=="replay";\n',
     '         var replay:Boolean=access.time!=null && access.time.phase=="replay";\n         var unitsStarted:int=Timing.start();\n         for each(var u:Object in room.units)if(u!=null && !u.player) {\n            var burning:Boolean=AuthorityAnimation.burning(u as Unit);\n'),
    ('var compact:Object=access.time!=null && access.time.phase=="replay"?null:decorations.capture(o);', 'var compact:Object=replay?null:decorations.capture(o);'),
])
s = (ROOT / 'authority/SceneSnapshot.as').read_text(encoding='utf-8')
s = s.replace('getQualifiedClassName(', 'ClassNames.of(')
(ROOT / 'authority/SceneSnapshot.as').write_text(s, encoding='utf-8')

for rel in ('authority/ReplicaScene.as', 'authority/RoomRuntime.as', 'authority/ClientReplica.as'):
    p = ROOT / rel
    s = p.read_text(encoding='utf-8')
    if 'getQualifiedClassName(' in s:
        s = s.replace('import flash.utils.getQualifiedClassName;\n', '')
        s = s.replace('getQualifiedClassName(', 'ClassNames.of(')
        p.write_text(s, encoding='utf-8')
        print('class-name cache', rel)

patch('authority/ClientReplica.as', [
    ('         VisualPose.apply(g.vis,state.visual);\n',
     '         if(interpolated)VisualPose.motion(g.vis,state.visual);else VisualPose.apply(g.vis,state.visual);\n'),
    ('            VisualPose.apply(v as DisplayObject,w.visual);\n',
     '            if(interpolated)VisualPose.motion(v as DisplayObject,w.visual);else VisualPose.apply(v as DisplayObject,w.visual);\n'),
    ('for each(p in frame.projectileEvents)if(p.ended && p.room===frame.room && present && !active[String(p.id)]) {',
     'for each(p in frame.projectileEvents)if(p.ended && p.clip!="" && p.room===frame.room && present && !active[String(p.id)]) {'),
])

patch('../RConnectMod.as', [
    ('               label.text="RConnect B · 开发测试 · "+role;\n', ''),
])
print('done')

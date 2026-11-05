from pathlib import Path
ROOT = Path(__file__).resolve().parents[2] / 'build' / 'ab' / 'b-j11-source-01' / 'src' / 'authority'
def patch(rel, pairs):
    p = ROOT / rel
    s = p.read_text(encoding='utf-8')
    for old, new in pairs:
        if s.count(old) != 1:
            raise SystemExit(f'{rel}: {s.count(old)} for {old[:90]!r}')
        s = s.replace(old, new)
    p.write_text(s, encoding='utf-8')
    print('patched', rel)

patch('NativeFields.as', [(
'''      public static function motion(value:Object,state:Object):void {''',
'''      /** Effective value of a scene unit/object field: sparse delta wins, then base. */
      public static function get(record:Object,key:String):* {
         if(record==null)return undefined;
         var delta:Object=record.fieldsDelta;if(delta!=null && delta.hasOwnProperty(key))return delta[key];
         var base:Object=record.fields;return base==null?undefined:base[key];
      }
      public static function has(record:Object,key:String):Boolean {
         if(record==null)return false;
         var delta:Object=record.fieldsDelta;if(delta!=null && delta.hasOwnProperty(key))return true;
         var base:Object=record.fields;return base!=null && base.hasOwnProperty(key);
      }
      public static function motion(value:Object,state:Object):void {''')])

patch('EnemyVisualProbe.as', [
('x=u.fields.X;y=u.fields.Y-u.fields.scY*.6;',
 'x=NativeFields.get(u,"X");y=NativeFields.get(u,"Y")-NativeFields.get(u,"scY")*.6;'),
('{key:u.key,id:u.fields.id,x:u.fields.X,y:u.fields.Y,hp:u.fields.hp,sost:u.fields.sost,player:u.fields.player}',
 '{key:u.key,id:NativeFields.get(u,"id"),x:NativeFields.get(u,"X"),y:NativeFields.get(u,"Y"),hp:NativeFields.get(u,"hp"),sost:NativeFields.get(u,"sost"),player:NativeFields.get(u,"player")}'),
])

patch('CooperationProbe.as', [
('confirmed.fields.dead===false', 'NativeFields.get(confirmed,"dead")===false'),
('o.fields.id=="door1b"', 'NativeFields.get(o,"id")=="door1b"'),
])

patch('LifecycleProbe.as', [
('!s.fields.disabled && s.fields.sost<3', '!NativeFields.get(s,"disabled") && NativeFields.get(s,"sost")<3'),
])

patch('SceneChecks.as', [
('var position:Boolean=s.fields.hasOwnProperty("X") && s.fields.hasOwnProperty("Y");',
 'var position:Boolean=NativeFields.has(s,"X") && NativeFields.has(s,"Y");'),
('var same:Boolean=u.loc===scene.room && u.hp===s.fields.hp && u.sost===s.fields.sost &&',
 'var same:Boolean=u.loc===scene.room && u.hp===NativeFields.get(s,"hp") && u.sost===NativeFields.get(s,"sost") &&'),
('(position?(u.X===s.fields.X && u.Y===s.fields.Y):(!s.attached && isNaN(u.X) && isNaN(u.Y)));',
 '(position?(u.X===NativeFields.get(s,"X") && u.Y===NativeFields.get(s,"Y")):(!s.attached && isNaN(u.X) && isNaN(u.Y)));'),
('source:[s.fields.hp,s.fields.sost,s.fields.X,s.fields.Y]',
 'source:[NativeFields.get(s,"hp"),NativeFields.get(s,"sost"),NativeFields.get(s,"X"),NativeFields.get(s,"Y")]'),
('!s.fields.disabled && s.fields.sost<3', '!NativeFields.get(s,"disabled") && NativeFields.get(s,"sost")<3'),
])
print('done')

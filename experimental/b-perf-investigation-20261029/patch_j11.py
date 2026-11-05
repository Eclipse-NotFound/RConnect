from pathlib import Path

ROOT = Path(__file__).resolve().parents[2] / 'build' / 'ab' / 'b-j11-source-01' / 'src'
def patch(rel, old, new):
    p = ROOT / rel
    s = p.read_text(encoding='utf-8')
    if s.count(old) != 1:
        raise SystemExit(f'{rel}: occurrence {s.count(old)} for {old[:100]!r}')
    p.write_text(s.replace(old, new), encoding='utf-8')
    print('patched', rel)

# 1. FrameDelta: sparse scene-unit/object fields + motion snapshots
patch('authority/FrameDelta.as',
'''            for each(var op:Array in packet.changes) {
               var path:Array=op[0];
               var grouped:Boolean=op[1]==2;
''',
'''            for each(var op:Array in packet.changes) {
               var path:Array=op[0];
               var grouped:Boolean=op[1]==2;
               // Sparse scene-unit/object fields: keep the immutable full base and
               // accumulate only this unit's changed keys. Avoids cloning the
               // complete (200+ key) native field record on every confirmation.
               if(grouped && isSceneFields(path)) {
                  var fieldLimit:int=path.length-1,fieldCommon:int=0;
                  while(fieldCommon<depth && fieldCommon<fieldLimit && prefix[fieldCommon]===path[fieldCommon])++fieldCommon;
                  var record:Object=parents[fieldCommon];
                  for(var fi:int=fieldCommon;fi<fieldLimit;fi++) {
                     var fieldChild:Object=record[path[fi]];
                     if(!writable[fieldChild]){fieldChild=branch(fieldChild);writable[fieldChild]=true;record[path[fi]]=fieldChild;}
                     record=fieldChild;prefix[fi]=path[fi];parents[fi+1]=record;
                  }
                  depth=fieldLimit;prefix.length=depth;parents.length=depth+1;
                  var priorDelta:Object=record["fieldsDelta"],sum:Object={};
                  if(priorDelta!=null)for(var pk:String in priorDelta)sum[pk]=priorDelta[pk];
                  var fieldUpdates:Object=op[2];if(fieldUpdates!=null)for(var fk:String in fieldUpdates)sum[fk]=fieldUpdates[fk];
                  var fieldRemoved:Array=op[3];if(fieldRemoved!=null)for each(var fr:String in fieldRemoved)delete sum[fr];
                  record["fieldsDelta"]=sum;
                  continue;
               }
''')
patch('authority/FrameDelta.as',
'''         serial=packet.serial;return prior;
      }
''',
'''         refreshMotion(prior);
         serial=packet.serial;return prior;
      }
      private static function isSceneFields(path:Array):Boolean {
         return path.length>=3 && String(path[0])=="scene" && (String(path[1])=="units" || String(path[1])=="objects") && String(path[path.length-1])=="fields";
      }
      private static function refreshMotion(frame:Object):void {
         var scene:Object=frame==null?null:frame.scene;if(scene==null || !(scene.units is Array))return;
         for each(var unit:Object in scene.units) {
            var base:Object=unit.fields,delta:Object=unit.fieldsDelta;if(base==null && delta==null)continue;
            var motion:Object={};
            for each(var key:String in NativeFields.MOTION)motion[key]=delta!=null && delta.hasOwnProperty(key)?delta[key]:(base==null?undefined:base[key]);
            unit.motion=motion;
         }
      }
''')

# 2. ReplicaScene: apply sparse deltas and interpolate by motion snapshot
patch('authority/ReplicaScene.as',
'''          NativeFields.apply(u,s.fields);u.loc=room;
''',
'''          NativeFields.apply(u,s.fields);if(s.fieldsDelta!=null)NativeFields.apply(u,s.fieldsDelta);u.loc=room;
''')
patch('authority/ReplicaScene.as',
'''            NativeFields.apply(gun,gs.fields);gun.loc=room;
''',
'''            NativeFields.apply(gun,gs.fields);if(gs.fieldsDelta!=null)NativeFields.apply(gun,gs.fieldsDelta);gun.loc=room;
''')
patch('authority/ReplicaScene.as',
'''          NativeFields.apply(o,s.fields);rec.inter=s.inter;rec.layer=int(s.fields.sloy);rec.attached=s.attached;
''',
'''          NativeFields.apply(o,s.fields);if(s.fieldsDelta!=null)NativeFields.apply(o,s.fieldsDelta);rec.inter=s.inter;rec.layer=int(s.fields.sloy);rec.attached=s.attached;
''')
patch('authority/ReplicaScene.as',
'''            var u:Object=rec.unit;NativeFields.motion(u,state.fields);VisualPose.motion(u.vis,state.pose);
''',
'''            var u:Object=rec.unit;NativeFields.motion(u,state.motion!=null?state.motion:state.fields);VisualPose.motion(u.vis,state.pose);
''')

# 3. PoseTween: scene unit tween from the per-frame motion snapshot
patch('authority/PoseTween.as',
'''                      if(p.fields!=null && q.fields!=null && close(p.fields,q.fields,"X","Y"))r.fields=fields(p.fields,q.fields,t);
''',
'''                      var pm:Object=p.motion!=null?p.motion:p.fields,qm:Object=q.motion!=null?q.motion:q.fields;
                      if(pm!=null && qm!=null && close(pm,qm,"X","Y"))r.motion=fields(pm,qm,t);
''')
print('done')

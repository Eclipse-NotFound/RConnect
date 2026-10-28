"""Prepare narrow source overlays from the deployed F14A source; no compiler/runtime."""
from pathlib import Path
import difflib
import hashlib
import json

HERE = Path(__file__).resolve().parent
RC = HERE.parents[1]
BASE = RC / 'build/m52/a-stutter-repair-02/src'

def replace_once(text, old, new):
    assert text.count(old) == 1, old[:100]
    return text.replace(old, new)

paths = ['rconnect/game/UnitPresentation.as', 'rconnect/game/WeaponDisplay.as', 'rconnect/game/MeleeVisuals.as']
manifest = {}
diff = []
for name in paths:
    before = (BASE / name).read_text(encoding='utf-8')
    after = before
    if name.endswith('UnitPresentation.as'):
        after = replace_once(after,
            'display:playerDisplay?WeaponDisplay.capture(u,w):null,',
            '// Enemy weapons need the native reflection too: aim/facing alone is insufficient.\n'
            '               display:WeaponDisplay.capture(u,w),')
        after = replace_once(after,
            'sampleTime:frameTime,events:events,\n',
            'sampleTime:frameTime,events:events,display:WeaponDisplay.capture(u,w),\n'
            '               melee:MeleeVisuals.captureMotion(u,w,frameTime,r),\n')
        after = replace_once(after,
            'var w:Object=gun.weapon,s:Object=gun.snapshot;',
            'var w:Object=gun.weapon,s:Object=gun.snapshot,visual:Object=s;')
        after = replace_once(after,
            'w.X=Number(u.X)+Number(pose.ox);w.Y=Number(u.Y)+Number(pose.oy);w.rot=Number(pose.rot);break;',
            'w.X=Number(u.X)+Number(pose.ox);w.Y=Number(u.Y)+Number(pose.oy);w.rot=Number(pose.rot);\n'
            '                        visual=pose;break;')
        after = replace_once(after,
            'melee.apply(u,w,s.melee,rec.clock==null?NaN:rec.clock.sourceTime);',
            '// The later pose contains the native in-between swing frames. Using\n'
            '               // only the last applied packet would stop at its history endpoint.\n'
            '               if(!melee.apply(u,w,visual.melee,rec.clock==null?NaN:rec.clock.sourceTime))\n'
            '                  WeaponDisplay.presentPose(u,w,visual.display);')
    elif name.endswith('WeaponDisplay.as'):
        before_apply = '      public function apply(u:Object,w:Object,s:Object,now:int,sourceTime:Number=NaN):void {'
        helper = '''      /** Use the captured native reflection/rotation in this receiver's actual
       * parent space. NPC weapons normally share the body world layer; some
       * weapons are children of a transformed body. Neither needs local AI aim. */
      public static function presentPose(u:Object,w:Object,p:Object):Boolean {
         var v:DisplayObject=GameBridge.probe(w,"vis") as DisplayObject;
         var body:DisplayObject=GameBridge.probe(u,"vis") as DisplayObject;
         var layer:DisplayObjectContainer=body==null?null:body.parent;
         if(p==null || v==null || v.parent==null || layer==null)return false;
         var basis:Matrix=relativeMatrix(v.parent,layer);
         if(basis==null || Math.abs(basis.a*basis.d-basis.b*basis.c)<.000001)return false;
         var cos:Number=Math.cos(Number(p.r)),sin:Number=Math.sin(Number(p.r));
         var nativePose:Matrix=new Matrix(cos*Number(p.sx),sin*Number(p.sx),-sin*Number(p.sy),cos*Number(p.sy),
            Number(u.X)+Number(p.x),Number(u.Y)+Number(p.y));
         basis.invert();nativePose.concat(basis);v.transform.matrix=nativePose;
         return true;
      }

'''
        after = replace_once(after, before_apply, helper + before_apply)
    else:
        before_capture = '      private static function capturePose(u:Object,v:DisplayObject,layer:DisplayObjectContainer):Object {'
        helper = '''      /** Frequent packets need only the previous window's final anchor and
       * new native frames. The caller owns this state per weapon stream, so a
       * new authority/session starts with complete history. Full capture above
       * never consumes this cursor. TCP delivers each window in order. */
      public static function captureMotion(u:Object,w:Object,stamp:int,state:Object):Object {
         if(!RConnectMeleeAccess.isClub(w) || state==null)return null;
         var rec:Object=observed[w];
         if(rec==null){observe(u,w);rec=observed[w];}
         if(rec==null || rec.frames.length==0)return null;
         var frames:Array=rec.frames;
         if(stamp<=0)stamp=int(rec.at);
         if(state.meleeMotionStamp==null || int(state.meleeMotionStamp)!=stamp) {
            state.meleeMotionFrom=state.meleeMotionTo;state.meleeMotionStamp=stamp;
         }
         var first:int=0;
         if(state.meleeMotionFrom!=null)
            while(first+1<frames.length && Number(frames[first+1].at)<=Number(state.meleeMotionFrom))first++;
         state.meleeMotionTo=Number(frames[frames.length-1].at);
         // A second send can have the same source stamp. Keep its window start,
         // but re-slice current frames: final RENDER may replace that last pose.
         // Caching the old payload or moving the start would erase those frames
         // when RemoteMotion replaces an equal-stamp snapshot.
         return {kind:"club",player:get(u,"player")===true,frames:frames.slice(first)};
      }

'''
        after = replace_once(after, before_capture, helper+before_capture)
    target = HERE / 'src' / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(after, encoding='utf-8', newline='\n')
    diff.extend(difflib.unified_diff(before.splitlines(True), after.splitlines(True),
                                   fromfile='a/'+name, tofile='b/'+name))
    manifest[name] = {'base_sha256': hashlib.sha256((BASE/name).read_bytes()).hexdigest(),
                      'overlay_sha256': hashlib.sha256(target.read_bytes()).hexdigest()}
(HERE/'weapons.patch').write_text(''.join(diff), encoding='utf-8', newline='\n')
(HERE/'source-manifest.json').write_text(json.dumps({'base':str(BASE),'sources':manifest},indent=2),encoding='utf-8')
print(json.dumps(manifest, indent=2))

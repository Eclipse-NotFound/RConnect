"""Prepare an intentionally failing alias counterexample; NO production overlay."""
import argparse
import difflib
import hashlib
import json
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT / 'build/m52/recovery-21/src/rconnect/game'
PINS = {
    'RemoteMotion.as': '5f0d0ba3b8de5ec1a08d392b4147f04a4d318c0bcdd0a2f7bbf236a5d28fc877',
    'GameBridge.as': '260cebd0f89e348979d05d00338f7e444a1abf2c0bbe4d03350475b05e01142d',
    'WeaponDisplay.as': 'c76a6b157992398dbb8d8620de2482375594423226cd64b90e13e8fee96066f2',
    'TeleportVisuals.as': 'ec323ce52b1926e6cb1c98e722c78544cd396fa5b3661ba257111b4b703c272c',
}


def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()


def one(s, old, new):
    assert s.count(old) == 1, old
    return s.replace(old, new, 1)


def method(s, name):
    start = s.index('      ' + name)
    brace = s.index('{', start)
    depth, i = 1, brace + 1
    while depth:
        if s[i] == '{': depth += 1
        elif s[i] == '}': depth -= 1
        i += 1
    return s[start:i]


def derived():
    for name, digest in PINS.items(): assert sha(BASE / name) == digest, name
    old = (BASE / 'RemoteMotion.as').read_text(encoding='utf-8')
    new = one(old, '      private var state:Object;', '''      private var state:Object;
      // Only queueUnitMotion's position-only result may remain private. Once
      // sample/settle/currentSample publishes this Object, preserve its live
      // alias semantics by updating its complete pose on every later sample.
      private var stateExposed:Boolean=false;
      private var posePending:Boolean=false;
      private var poseA:Object,poseB:Object;
      private var poseT:Number=0,poseSpan:Number=0;''')
    new = one(new, '         origin={};target={};state={};', '''         origin={};target={};state={};
         stateExposed=false;posePending=false;poseA=poseB=null;''')
    new = one(new, '         if(frames.length>0)return sampleTimed(now);', '''         if(frames.length>0) {
            sampleTimed(now);stateExposed=true;return state;
         }''')
    new = one(new, '         return state;\n      }\n\n      /** Shared display cursor', '''         stateExposed=true;return state;
      }

      /** REJECTED TEST DESIGN: output ownership alone does not protect the
       * caller's mutable nested input. This component demonstrates that gap. */
      internal function samplePosition(now:int):Object {
         return frames.length>0?sampleTimed(now,true):sample(now);
      }

      /** Shared display cursor''')
    new = one(new, '      public function get currentSample():Object {return state;}', '''      public function get currentSample():Object {
         if(posePending) {
            posePending=false;
            if(poseA.weapons is Array && poseB.weapons is Array)
               state.weapons=blendWeapons(poseA.weapons as Array,poseB.weapons as Array,poseT);
            state.bodyPose=blendBodyPose(poseA.visual,poseB.visual,poseT,poseSpan);
            poseA=poseB=null;
         }
         stateExposed=true;return state;
      }''')
    new = one(new, '            return sampleTimed(now);', '            sampleTimed(now);stateExposed=true;return state;')
    new = one(new, '            frames=[];gaps=[];selected=null;state=null;preceding=null;firstSample=true;dropDelay=0;', '''            frames=[];gaps=[];selected=null;state=null;preceding=null;firstSample=true;dropDelay=0;
            stateExposed=false;posePending=false;poseA=poseB=null;''')
    new = one(new, '      private function sampleTimed(now:int):Object {', '      private function sampleTimed(now:int,positionOnly:Boolean=false):Object {')
    new = one(new, '            selected=chosen;state={};for(var key:String in selected)state[key]=selected[key];', '''            selected=chosen;state={};for(var key:String in selected)state[key]=selected[key];
            stateExposed=false;''')
    new = one(new, '         if(crossing!=null) {\n            state.x=crossing.x;state.y=crossing.y;', '''         if(crossing!=null) {
            posePending=false;poseA=poseB=null;
            state.x=crossing.x;state.y=crossing.y;''')
    new = one(new, '''         if(a.snap.weapons is Array && b.snap.weapons is Array)
            state.weapons=blendWeapons(a.snap.weapons as Array,b.snap.weapons as Array,t);
         state.bodyPose=blendBodyPose(a.snap.visual,b.snap.visual,t,span);''', '''         if(positionOnly && !stateExposed) {
            // Capture snap identities, not mutable frame.snap slots: a later
            // same-stamp push may replace those slots without resampling.
            poseA=a.snap;poseB=b.snap;poseT=t;poseSpan=span;posePending=true;
         } else {
            posePending=false;poseA=poseB=null;
            if(a.snap.weapons is Array && b.snap.weapons is Array)
               state.weapons=blendWeapons(a.snap.weapons as Array,b.snap.weapons as Array,t);
            state.bodyPose=blendBodyPose(a.snap.visual,b.snap.visual,t,span);
         }''')
    out = {}
    for suffix, motion in [('Before', old), ('After', new)]:
        out['components/rconnect/game/RemoteMotion' + suffix + '.as'] = re.sub(r'\bRemoteMotion\b', 'RemoteMotion'+suffix, motion)
    out['components/rconnect/game/MotionPositionAccess.as'] = '''package rconnect.game {
   public final class MotionPositionAccess {
      public static function sample(m:RemoteMotionAfter,now:int):Object {return m.samplePosition(now);}
   }
}
'''
    tele=(BASE/'TeleportVisuals.as').read_text(encoding='utf-8')
    weapon=(BASE/'WeaponDisplay.as').read_text(encoding='utf-8')
    out['components/rconnect/game/TeleportVisuals.as']='package rconnect.game { public final class TeleportVisuals {\n'+method(tele,'private static function valid(')+'\n'+method(tele,'public static function split(')+'\n}}\n'
    out['components/rconnect/game/WeaponDisplay.as']='package rconnect.game { public final class WeaponDisplay {\n'+method(weapon,'public static function interpolate(')+'\n}}\n'
    out['rejected-defer.diff']=''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),
        fromfile='recovery-21/RemoteMotion.as',tofile='TEST-ONLY-REJECTED/RemoteMotion.as'))
    return out


def verify():
    for name,value in derived().items(): assert (HERE/name).read_bytes()==value.encode('utf-8'),name
    data=json.loads((HERE/'handoff.json').read_text(encoding='utf-8'))
    for name,digest in data['files'].items(): assert sha(HERE/name)==digest,name
    return data


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--verify',action='store_true');args=ap.parse_args()
    if args.verify:
        verify();print('exact recovery21 sources and derived component inputs verified; no JVM/AIR');return
    for name,value in derived().items():
        p=HERE/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(value.encode('utf-8'))
    files={p.relative_to(HERE).as_posix():sha(p) for p in sorted(HERE.rglob('*')) if p.is_file() and p.name!='handoff.json' and '__pycache__' not in str(p)}
    data={'baseline':'recovery-21','status':'blocked_by_mutable_nested_inputs','expected_counterexample_assertions':8,
          'expected_semantic_failures':2,'production_overlay':False,
          'candidate_sha256_from_root':'9ac7ede757c253bbf61e0c44334870b4a95112f976c1b40f2f390822a8b7e7ba',
          'source_pins':PINS,'files':files,'compiled':False,'air_started':False,'native_qualified':False,'performance_qualified':False}
    (HERE/'handoff.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    verify();print('rejected-design alias counterexample prepared; no production overlay, JVM or AIR')


if __name__=='__main__':main()

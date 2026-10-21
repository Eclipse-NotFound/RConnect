"""Exact recovery14 one-method overlay and full-class comparison component. No JVM/AIR."""
from pathlib import Path
import argparse
import difflib
import hashlib
import json
import shutil

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
BASE=ROOT/'build/m52/recovery-14'
NAME='rconnect/game/UnitPresentation.as'
BASE_SHA='225a794040c71f2a55ff433366a7969201ac3a58ffaab0a655cee1e4eefbe5f7'
SOURCE_SHA='d67dbcbed8d3ef67771eb10e41516102dabb34aad3a7065ab71ec7822ff53178'
OLD='''               var elapsed:int=getTimer()-int(m.at),p:Number=m.duration>0?Math.min(1,elapsed/m.duration):1;
               var angle:Number=Number(s.rot)-Number(m.r);
               while(angle>Math.PI)angle-=Math.PI*2;
               while(angle<-Math.PI)angle+=Math.PI*2;
               w.X=Number(u.X)+Number(m.x)+(Number(s.ox)-Number(m.x))*p;
               w.Y=Number(u.Y)+Number(m.y)+(Number(s.oy)-Number(m.y))*p;
               w.rot=Number(m.r)+angle*p;
               // Body and weapon share a source cursor, without a second tween.
               if(clockSample!=null && clockSample.weapons is Array)
                  for each(var pose:Object in clockSample.weapons)
                     if(pose.slot==s.slot&&pose.id==s.id&&pose.variant==s.variant&&pose.stream==s.stream) {
                        w.X=Number(u.X)+Number(pose.ox);w.Y=Number(u.Y)+Number(pose.oy);w.rot=Number(pose.rot);break;
                     }
'''
NEW='''               var elapsed:int=getTimer()-int(m.at),sourcePose:Object=null;
               // The source clock already interpolated this weapon. Only a
               // missing identity needs the legacy arrival-time fallback.
               if(clockSample!=null && clockSample.weapons is Array)
                  for each(var pose:Object in clockSample.weapons)
                     if(pose.slot==s.slot&&pose.id==s.id&&pose.variant==s.variant&&pose.stream==s.stream) {
                        sourcePose=pose;break;
                     }
               if(sourcePose!=null) {
                  w.X=Number(u.X)+Number(sourcePose.ox);w.Y=Number(u.Y)+Number(sourcePose.oy);w.rot=Number(sourcePose.rot);
               } else {
                  var p:Number=m.duration>0?Math.min(1,elapsed/m.duration):1;
                  var angle:Number=Number(s.rot)-Number(m.r);
                  while(angle>Math.PI)angle-=Math.PI*2;
                  while(angle<-Math.PI)angle+=Math.PI*2;
                  w.X=Number(u.X)+Number(m.x)+(Number(s.ox)-Number(m.x))*p;
                  w.Y=Number(u.Y)+Number(m.y)+(Number(s.oy)-Number(m.y))*p;
                  w.rot=Number(m.r)+angle*p;
               }
'''
ACCESS='''      // POSE_COMPONENT_ACCESS_BEGIN
      public function fixtureState(u:Object):Object {return states[u];}
      // POSE_COMPONENT_ACCESS_END
'''
TRACE='''         // POSE_COMPONENT_PLAY_BEGIN
         Trace.note("play",String(w.id),label);
         // POSE_COMPONENT_PLAY_END
'''

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return p.read_text(encoding='utf-8-sig')
def put(p,t):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(t,encoding='utf-8',newline='\n')
def once(s,a,b):assert s.count(a)==1,a;return s.replace(a,b,1)
def derive(s,label):
    s=once(s,'class UnitPresentation','class Pose'+label)
    s=once(s,'   import flash.utils.getTimer;','   import fixture.getTimer;\n   import fixture.Trace;')
    s=once(s,'         var vis:MovieClip=get(w,"vis") as MovieClip;',TRACE+'         var vis:MovieClip=get(w,"vis") as MovieClip;')
    return once(s,'      public function reset():void',ACCESS+'      public function reset():void')

def expected():
    assert sha(BASE/'RConnectMod.swf')==BASE_SHA
    assert sha(BASE/'src'/NAME)==SOURCE_SHA
    old=read(BASE/'src'/NAME);new=once(old,OLD,NEW)
    return old,new

def verify():
    old,new=expected();m=json.loads(read(HERE/'inputs.json'))
    assert read(HERE/'src'/NAME)==new
    for label,body in [('Before',old),('After',new)]:
        assert read(HERE/'components/rconnect/game'/('Pose'+label+'.as'))==derive(body,label)
    assert sha(Path(__file__))==m['recipe_sha256']
    for p,h in m['originals'].items():assert sha(Path(p))==h,p
    files={p.relative_to(HERE).as_posix():sha(p) for folder in ('src','tests','components')
           for p in sorted((HERE/folder).rglob('*')) if p.is_file()}
    assert files==m['files'],'Unlisted or changed source'
    assert sha(HERE/'proposal.patch')==m['patch_sha256']
    return dict(verified=True,production_methods_changed=1,expected_assertions=54,
                actual_classes_compared=True,compiled=False,air_started=False)

def main():
    old,new=expected()
    assert not (HERE/'components').exists(),'Never replace delivered component sources'
    put(HERE/'src'/NAME,new)
    shutil.copytree(HERE/'tests',HERE/'components')
    for label,body in [('Before',old),('After',new)]:
        put(HERE/'components/rconnect/game'/('Pose'+label+'.as'),derive(body,label))
    patch=''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),
                  fromfile='recovery14/'+NAME,tofile='actor-pose-fast/'+NAME))
    put(HERE/'proposal.patch',patch)
    originals={str(p):sha(p) for p in (BASE/'RConnectMod.swf',BASE/'prepared.json',BASE/'src'/NAME)}
    m=dict(base='build/m52/recovery-14',base_sha256=BASE_SHA,originals=originals,
           recipe_sha256=sha(Path(__file__)),patch_sha256=sha(HERE/'proposal.patch'),expected_assertions=54,
           files={p.relative_to(HERE).as_posix():sha(p) for folder in ('src','tests','components')
                  for p in sorted((HERE/folder).rglob('*')) if p.is_file()},
           compiled=False,air_started=False,gameplay_qualified=False,performance_qualified=False)
    put(HERE/'inputs.json',json.dumps(m,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(verify()))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--verify',action='store_true');a=p.parse_args()
    if a.verify:print(json.dumps(verify()))
    else:main()

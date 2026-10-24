"""Prepare only passive observation sources; no compiler or AIR invocation."""
from pathlib import Path
import argparse, ast, difflib, hashlib, json, sys
if sys.flags.optimize: raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
BASE=ROOT/'build/m52/goal-three-issues-native-drivers-02/tests'
ORIGINAL={'NativeMotionProbe.as':'4ca25c80d0ebeda696f02ef842b56ea691fdf6dd8c78736e5c18e65b2712a394',
 'NativeJumpNetworkTestDoc.as':'69c45eb85e1f7a77c4ca16dabbfd1cc82aee0cc60823ffc02722eb9bdabc3349'}

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text('utf-8-sig'))
def once(s,a,b):
 assert s.count(a)==1,a
 return s.replace(a,b,1)
def derived():
 for name,h in ORIGINAL.items():assert sha(BASE/name)==h,name
 raw=(BASE/'NativeMotionProbe.as').read_bytes();nl='\r\n' if b'\r\n' in raw else '\n'
 s=raw.decode('utf8').replace('\r\n','\n')
 s=once(s,'      private static const LIMIT:int=4096;',
   '      private static const LIMIT:int=4096;\n      private var observationOrder:int=0;')
 s=once(s,'            body:value(body,"currentFrame"),pose:value(osn,"currentLabel"),levit:value(o,"levit")};',
 '''            body:value(body,"currentFrame"),pose:value(osn,"currentLabel"),levit:value(o,"levit"),
            poseFrame:value(osn,"currentFrame"),bodyPlaying:value(body,"isPlaying"),bodyTotal:value(body,"totalFrames"),
            bodyOnStage:body!=null&&value(body,"stage")===mod.stage,bodyVisible:value(body,"visible"),
            aJump:value(o,"aJump"),jumpNumb:value(o,"jumpNumb"),animState:value(o,"animState"),
            animOff:value(o,"animOff"),work:value(o,"t_work"),isFly:value(o,"isFly"),
            isLaz:value(o,"isLaz"),isPlav:value(o,"isPlav"),t_port:value(o,"t_port"),
            hp:value(o,"hp"),sost:value(o,"sost")};''')
 s=once(s,'         target=o;key=targetKey;frame=0;frameAt=getTimer();lastRender=-1;',
   '         target=o;key=targetKey;frame=0;frameAt=getTimer();lastRender=-1;observationOrder=0;')
 s=once(s,'            diagnosticOnly:true,smoothnessQualified:false};',
 '''            diagnosticOnly:true,smoothnessQualified:false,poseObservationVersion:1,
            cursorAvailable:false,poseObservationDefinition:"packet scalars and final MovieClip properties; no private cursor or readSnapshot call"};''')
 s=once(s,'         append(live.render,{frame:frame,frameAt:frameAt,at:getTimer(),focused:focused(),',
 '''         append(live.render,{frame:frame,frameAt:frameAt,at:getTimer(),focused:focused(),
            order:++observationOrder,roomKey:mod.game.roomKey(),roomEpoch:value(mod.game,"roomEpoch"),''')
 s=once(s,'            focused:focused(),snapshots:[],positions:[]};',
   '            focused:focused(),order:++observationOrder,snapshots:[],positions:[]};')
 s=once(s,'            x:value(snap,"x"),y:value(snap,"y"),dx:value(snap,"dx"),dy:value(snap,"dy"),stay:value(snap,"stay")});',
 '''            x:value(snap,"x"),y:value(snap,"y"),dx:value(snap,"dx"),dy:value(snap,"dy"),stay:value(snap,"stay"),
            nativeJumpRun:value(snap,"nativeJumpRun"),pose:value(snap,"pose"),poseFrame:value(snap,"poseFrame"),
            bodyFrame:value(snap,"bodyFrame"),bodyPlaying:value(snap,"bodyPlaying"),
            hp:value(snap,"hp"),sost:value(snap,"sost"),roomKey:value(snap,"roomKey"),
            roomEpoch:value(snap,"roomEpoch"),landId:value(snap,"landId"),locId:value(snap,"locId")});''')
 assert s.count('readSnapshot')==1 and 'getRemoteGhost(host?1:0)' in s
 return {'NativeMotionProbe.as':s.replace('\n',nl).encode('utf8'),
  'NativeJumpNetworkTestDoc.as':(BASE/'NativeJumpNetworkTestDoc.as').read_bytes()}
def verify():
 m=read(HERE/'source-manifest.json')
 assert m['kind']=='native-jump-passive-observation-v1'
 for name,data in derived().items():assert (HERE/'tests'/name).read_bytes()==data,name
 assert {p.name:sha(p) for p in (HERE/'tests').glob('*.as')}==m['sources']
 for n,h in m['files'].items():assert sha(HERE/n)==h,n
 for n,h in m['original'].items():assert sha(n)==h,n
 for name in ('prepare.py','build.py','run.py','analyze_pose.py'):ast.parse((HERE/name).read_text('utf8'))
 assert sha(HERE/'tests/NativeJumpNetworkTestDoc.as')==ORIGINAL['NativeJumpNetworkTestDoc.as']
 return m
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--prepare',action='store_true');ap.add_argument('--check',action='store_true');a=ap.parse_args()
 if a.prepare:
  assert not a.check and not (HERE/'source-manifest.json').exists()
  (HERE/'tests').mkdir(exist_ok=True);diff=''
  for name,data in derived().items():
   with (HERE/'tests'/name).open('xb') as f:f.write(data)
   diff+=''.join(difflib.unified_diff((BASE/name).read_text('utf8').splitlines(True),data.decode('utf8').replace('\r\n','\n').splitlines(True),fromfile='drivers02/'+name,tofile='passive/'+name))
  with (HERE/'source.diff').open('x',encoding='utf8',newline='\n') as f:f.write(diff)
  import build
  with (HERE/'adapted-build.py.txt').open('x',encoding='utf8',newline='\n') as f:f.write(build.expanded_verify())
  import run
  with (HERE/'adapted-run.py.txt').open('x',encoding='utf8',newline='\n') as f:f.write(run.expanded_run())
  files={p.name:sha(p) for p in sorted(HERE.iterdir()) if p.is_file()}
  m=dict(kind='native-jump-passive-observation-v1',sources={n:sha(HERE/'tests'/n) for n in ORIGINAL},files=files,
   original={str(BASE/n):h for n,h in ORIGINAL.items()},compiled=False,air_started=False,cursorAvailable=False)
  with (HERE/'source-manifest.json').open('x',encoding='utf8') as f:json.dump(m,f,indent=2);f.write('\n')
 verify();print('Passive sources verified; no JVM/AIR')
if __name__=='__main__':main()

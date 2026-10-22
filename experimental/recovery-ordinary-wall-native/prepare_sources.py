"""Narrow text adaptation of frozen driver04; no compiler or game starts."""
from pathlib import Path
import difflib, hashlib, json, sys

HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
BASE=ROOT/'build/m52/recovery-wall-surfaces-driver-04/tests/LargeWallSurfaceTestDoc.as'
PIN='8b705228e106b32db9fbd2bbe01e2ec495e2f58e829f53b981fe17a63bdc8f36'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def adapted():
 assert sha(BASE)==PIN
 text=BASE.read_text(encoding='utf-8-sig')
 edits=[
  ('Four true native Weapon.attack/step -> Bullet.tilehit -> Grafon marks.',
   'Four ordinary-room native Weapon.attack/step -> Bullet.tilehit -> Grafon marks.\n    * Historical class/log labels stay compatible with the shared driver04 runner.'),
  ('sceneClass.nativeEnabled=host;break;','sceneClass.nativeEnabled=false;break;'),
  ('Boolean(sceneClass.nativeEnabled)!=host','Boolean(sceneClass.nativeEnabled)!=false'),
  ('for(var x:int=8;x<loc.spaceX-3;x++)for(var y:int=3;y<loc.spaceY-4;y++) {\n            if(x*40<=1920 && y*40<=1000)continue;',
   'for(var x:int=8;x<loc.spaceX;x++)for(var y:int=3;y<loc.spaceY-2;y++) {\n            if(x*40>=1920 || y*40+20>=1000)continue;'),
  ('Native generated large scene has fewer than four separated, dry, solid-wall shot lanes',
   'Native ordinary room has fewer than four separated, dry, solid-wall shot lanes; preparation failure, not synchronization evidence'),
  ('area=new Rectangle(p.x-64,p.y-64,128,128);',
   'area=new Rectangle(Math.max(0,Math.min(1920-128,p.x-64)),Math.max(0,Math.min(1000-128,p.y-64)),128,128);'),
  ('check(mod.game.world.grafon.sceneLarge===true && (mod.game.loc.spaceX>48 || mod.game.loc.spaceY>25),"native merged large scene admitted");',
   'check(mod.game.world.grafon.sceneLarge===false && mod.game.loc.spaceX==48 && mod.game.loc.spaceY==25,"native ordinary 48x25 room admitted");'),
  ('check(target.x>1920 || target.y>1000,"actual target lies beyond old small-room limits");',
   'check(target.x>=0 && target.x<1920 && target.y>=0 && target.y<1000,"actual target lies inside ordinary front bounds");'),
  ('check(baseline.surfaces.length>0,"independent nativeBuffers and staged chunk cores cover world crop");',
   'check(baseline.surfaces.length==1 && baseline.surfaces[0].backingIdentity===true,"unique staged ordinary front bitmap covers world crop");'),
  ('start:sampleStart,startWall:sampleStartWall,end:sampleEnd,shots:shots,',
   'baselineAt:baseline.at,baselineWall:baseline.wall,start:sampleStart,startWall:sampleStartWall,end:sampleEnd,shots:shots,'),
 ]
 for before,after in edits:
  assert text.count(before)==1,before
  text=text.replace(before,after)
 return text,edits
def main():
 target=HERE/'tests/LargeWallSurfaceTestDoc.as';assert not target.exists()
 text,edits=adapted();target.write_text(text,encoding='utf-8',newline='\n')
 (HERE/'ordinary-driver.patch').write_text(''.join(difflib.unified_diff(BASE.read_text(encoding='utf-8-sig').splitlines(True),
  text.splitlines(True),fromfile='driver04/LargeWallSurfaceTestDoc.as',tofile='ordinary/LargeWallSurfaceTestDoc.as')),encoding='utf-8')
 print(json.dumps(dict(base_sha256=PIN,changes=len(edits),source_sha256=sha(target),compiled=False,air_started=False)))
def freeze():
 import native_tool as tool
 target=HERE/'handoff.json';assert not target.exists()
 result=json.loads((HERE/'offline-result.json').read_text(encoding='utf-8'))
 assert result['passed'] and result['count']==29 and result['failed']==0
 assert (HERE/'tests/LargeWallSurfaceTestDoc.as').read_text(encoding='utf-8')==adapted()[0]
 inputs=tool.tools()
 for p in (BASE,ROOT/'build/m52/recovery-22/prepared.json',ROOT/'build/m52/recovery-22/RConnectMod.swf',
           ROOT/'build/m52/recovery-wall-surfaces-host-01/after/scripts/fe/graph/Grafon.as'):
  inputs[str(p)]=sha(p)
 files={p.relative_to(HERE).as_posix():sha(p) for p in sorted(HERE.rglob('*')) if p.is_file() and p!=target}
 data=dict(kind='ordinary-native-wall-surfaces-external-source',frozen=True,files=files,sources=inputs,
  candidate_sha256=tool.shared.BASE14_SHA,native_host_sha256=tool.shared.WALL_SHA,
  exact_driver04_adaptation=True,offline_checks=29,compiled=False,air_started=False,native_qualified=False,
  performance_qualified=False,installed=False)
 target.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8');verify()
 print('handoff_sha256='+sha(target))
def verify():
 data=json.loads((HERE/'handoff.json').read_text(encoding='utf-8'))
 for name,digest in data['files'].items():assert sha(HERE/name)==digest,name
 for name,digest in data['sources'].items():assert sha(Path(name))==digest,name
 assert (HERE/'tests/LargeWallSurfaceTestDoc.as').read_text(encoding='utf-8')==adapted()[0]
 print(json.dumps(dict(passed=True,files=len(data['files']),source_inputs=len(data['sources']),compiled=False,air_started=False)))
if __name__=='__main__':
 if '--freeze' in sys.argv:freeze()
 elif '--verify' in sys.argv:verify()
 else:main()

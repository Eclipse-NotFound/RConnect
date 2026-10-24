"""Prepare/check two exact roomfix5 source reductions; never compile or launch AIR."""
from pathlib import Path
import argparse, difflib, hashlib, json, re, sys
if sys.flags.optimize: raise RuntimeError('Ordinary Python required')
HERE=Path(__file__).resolve().parent; ROOT=HERE.parents[1]
BASE=ROOT/'build/m52/recovery-room-production-05'
FIXTURE=ROOT/'experimental/recovery-terrain-observed-reuse/components/fe/loc/Tile.as'
RUNNER=ROOT/'tools/validation/run_recovery_component.py'
PINS={
 BASE/'prepared.json':'acdc405a6e214531831cbb532178337aaa7fb9f154a91a1f8b543a6480dd6c58',
 BASE/'compile.json':'68fcca0717bd9800725822211650c6fd74787a98a839432b5ed0216cb0ae48d4',
 BASE/'RConnectMod.swf':'78c052aea963f1689b705ae1e14d274916ae1a1f7e81933390caf8d1a88f4699',
 BASE/'src/rconnect/game/GameBridge.as':'f7016bfd096ca3c88ea1214733117758b1998b579ec6f3ca9fc9332b605011a9',
 BASE/'src/rconnect/game/RoomTerrainView.as':'a2eb59b8536414d26daa39a82c71c414009c5d4b29a7a24539e025d1b852877f',
 FIXTURE:'a5267e18c3479c50d8b4eb5881690566e297d168bf3191fd36fb281e513c370a',
 RUNNER:'9952aeeaa37f6eead636cceff9f25fabff3045671d3c4cbb60c326909d1e572d'}
FIELDS=['X','Y','phis','shelf','phX1','phX2','phY1','phY2','zForm','diagon','stair','water',
 'vid','vid2','front','back','zad','fRear','vRear','v2Rear','opac','mat','kontur','konturRot',
 'floor','place','fake','door']
SCAN='''         var byId:Object = {};
         // M25：本轮已消费的 Box（同 id 就近匹配用）
         var consumed:Dictionary = new Dictionary();
         try
         {
            for each(var b:Object in objs as Array)
            {
               var id:String = String(probe(b, "id"));
               if(id != null && id.length > 0 && byId[id] == undefined)
               {
                  byId[id] = b;
               }
            }
         }
         catch(err:*)
         {
         }
'''
KEEP='''         // M25：本轮已消费的 Box（同 id 就近匹配用）
         var consumed:Dictionary = new Dictionary();
'''
OLD_CALL='!same(rows[i++],tileInputs(tile))'
NEW_CALL='!sameTile(rows[i++],tile)'

def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def read(path): return json.loads(Path(path).read_text(encoding='utf-8-sig'))
def same_tile():
 expressions=['a.length==28']+['a[%d]===%s'%(i,'(t.door!=null)' if name=='door' else 't.'+name) for i,name in enumerate(FIELDS)]
 lines=['      private static function sameTile(a:Array,t:Object):Boolean {']
 for i in range(0,len(expressions),4):
  lines.append(('         return ' if i==0 else '            && ')+ ' && '.join(expressions[i:i+4])+(';' if i+4>=len(expressions) else ''))
 return '\n'.join(lines)+'\n      }\n'

def planned():
 for path,digest in PINS.items(): assert sha(path)==digest,str(path)
 meta=read(BASE/'prepared.json'); result=read(BASE/'compile.json')
 assert result['compiled'] is True and result['candidate_sha256']==PINS[BASE/'RConnectMod.swf']
 assert result['installation_before']==meta['installation_before']==result['installation_after']
 assert len(result['commands'])==2 and all(c['exit_code']==0 for c in result['commands'])
 assert result['sources_unchanged'] is True and result['installation_unchanged'] is True
 for name in ('GameBridge.as','RoomTerrainView.as'):
  rel='rconnect/game/'+name; assert meta['source'][rel]==PINS[BASE/'src'/rel]
 bridge=(BASE/'src/rconnect/game/GameBridge.as').read_bytes().decode('utf-8')
 view=(BASE/'src/rconnect/game/RoomTerrainView.as').read_bytes().decode('utf-8')
 assert bridge.count(SCAN)==1
 new_bridge=bridge.replace(SCAN,KEEP); assert new_bridge.replace(KEEP,SCAN,1)==bridge
 # The removed local table has no reader anywhere in this complete method.
 old_method=bridge.split('public function reconcileObjs',1)[1].split('private function applySceneState',1)[0]
 assert old_method.count('byId')==3
 anchor='      private static function colors(loc:Object):Array {'
 helper=same_tile(); assert view.count(anchor)==view.count(OLD_CALL)==1 and 'sameTile(' not in view
 new_view=view.replace(anchor,helper+anchor).replace(OLD_CALL,NEW_CALL)
 assert new_view.replace(helper,'').replace(NEW_CALL,OLD_CALL)==view
 assert re.findall(r't\.(\w+)',helper)==FIELDS
 assert helper.count('===')==28 and 'new ' not in helper and 'tileInputs(' not in helper
 # Actual compile stubs expose only some Tile fields; preserve dynamic access,
 # exactly as the existing tileInputs(Object), without extending production stubs.
 assert 't:Object' in helper
 control=re.sub(r'\bRoomTerrainView\b','ControlRoomTerrainView',view)
 assert control.count('ControlRoomTerrainView')==2
 assert control.replace('ControlRoomTerrainView','RoomTerrainView')==view
 fixture=FIXTURE.read_bytes().decode('utf-8')
 assert fixture.count('public var front:String')==1
 # One test-only storage slot admits cross-type counterexamples. No getter,
 # setter or production field declaration is introduced or changed.
 fixture=fixture.replace('public var front:String','public var front:*')
 files={'src/rconnect/game/GameBridge.as':new_bridge.encode(),
  'src/rconnect/game/RoomTerrainView.as':new_view.encode(),
  'components/rconnect/game/RoomTerrainView.as':new_view.encode(),
  'components/rconnect/game/ControlRoomTerrainView.as':control.encode(),
  'components/fe/loc/Tile.as':fixture.encode()}
 diff=[]
 for name,old,new in [('GameBridge.as',bridge,new_bridge),('RoomTerrainView.as',view,new_view)]:
  diff+=difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile='prod05/rconnect/game/'+name,tofile='allocation/rconnect/game/'+name)
 files['source.diff']=''.join(diff).encode()
 return files

def main():
 parser=argparse.ArgumentParser(description=__doc__); parser.add_argument('--materialize',action='store_true'); args=parser.parse_args()
 files=planned(); manifest_path=HERE/'source-manifest.json'
 if args.materialize:
  assert not manifest_path.exists(),'Frozen proposal exists; verify only'
  for name,data in files.items():
   path=HERE/name; assert not path.exists(),name; path.parent.mkdir(parents=True,exist_ok=True); path.write_bytes(data)
  outputs={p.relative_to(HERE).as_posix():sha(p) for p in sorted(HERE.rglob('*')) if p.is_file()}
  with manifest_path.open('x',encoding='utf-8') as stream:
   json.dump(dict(kind='room-restore-allocation-source-proposal',base_sha256=PINS[BASE/'RConnectMod.swf'],
    input_sources={str(p):h for p,h in PINS.items()},outputs=outputs,production_overlays=2,expected_assertions=55,
    actual_complete_old_new_terrain_view=True,gamebridge_scan_source_proof_only=True,
    fixture_front_type_relaxed=True,compiled=False,air_started=False,installed=False,performance_qualified=False),stream,indent=2)
 else:
  meta=read(manifest_path); assert meta['input_sources']=={str(p):h for p,h in PINS.items()}
  assert meta['expected_assertions']==55 and meta['production_overlays']==2
  assert {p.relative_to(HERE).as_posix() for p in HERE.rglob('*') if p.is_file()}==set(meta['outputs'])|{'source-manifest.json'}
  for name,digest in meta['outputs'].items(): assert sha(HERE/name)==digest,name
  for name,data in files.items(): assert (HERE/name).read_bytes()==data,name
 print(json.dumps(dict(verified=True,source_only=True,materialized=args.materialize,expected_assertions=55,
  production_overlays=2,compiled=False,air_started=False,performance_qualified=False)))
if __name__=='__main__': main()

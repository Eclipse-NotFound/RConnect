"""Text-only, reversible first-rejection diagnostics over the exact 5325 source."""
from pathlib import Path
import argparse,ast,difflib,hashlib,importlib.util,json,sys
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
BASE=ROOT/'build/m52/goal-native-ui-jump-product-01'
BASE_SHA='5325a3aaeff65e215d8e01cd6ef5f87feea362ce422ce3b93b35a038a5cb4930'
INSTALLED_SHA='78c052aea963f1689b705ae1e14d274916ae1a1f7e81933390caf8d1a88f4699'
VERSION='0.2.24-nativeui2'
RECIPE=ROOT/'experimental/goal-native-ui-jump-product'
DELEGATE=ROOT/'experimental/recovery-room-production-v5/build.py'
OLD_DIFF=ROOT/'experimental/recovery-room-terrain-reason/source.diff'
NAMES=('rconnect/game/RoomTerrainView.as','rconnect/game/GameBridge.as')
PINS={
 BASE/'prepared.json':'e19bbf8eb5b041adb60a77cb44c8a3f82c8708a813ad78fd1a9a4b818cf0014b',
 BASE/'compile.json':'f764786ba6bbf3f57e51ebe82d01d4bca0c61bd325fa1a436b4c77dc5b8c7b98',
 RECIPE/'prepare.py':'d830d9732a1b85ca247e63ee43cece7b996b0e9c701430492505dc404466cbf7',
 RECIPE/'build.py':'2dd9874b35bdd9064b0fc92932680d016d8c54b84afef6c6d2433cd2ebd2c60b',
 RECIPE/'source-manifest.json':'d8a173e4eecbca19ec64e96db98292cb7f64c9330d9fd763cdeb4ef2f41e9adc',
 DELEGATE:'1889514c5563c5af44ee3e50c4cf08cb3108a1cda0d2904078fcab366ee142b9',
 OLD_DIFF:'5a81d51f7552f0067e472b16ebbf466ef0569925bfea55ea56550c6ef4a3b49b'}
BUILDER_EDITS=(
 ("assert before['mods/Rconnect/release/RConnectMod.swf']==receipt['base_sha256']",
  "assert before['mods/Rconnect/release/RConnectMod.swf']==receipt['installed_base_sha256']"),
 ("meta=dict(kind='room-repair-overlay', version=receipt['version']",
  "meta=dict(kind='terrain-reuse-diagnostic-overlay', diagnostic_only=True, performance_qualified=False, version=receipt['version']"),
 ('result=dict(compiled=False,commands=[]',
  'result=dict(diagnostic_only=True,performance_qualified=False,compiled=False,commands=[]'))

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text('utf-8-sig'))
def inventory(p):return {f.relative_to(p).as_posix():sha(f) for f in sorted(p.rglob('*')) if f.is_file()}
def load(p,n):
 s=importlib.util.spec_from_file_location(n,p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def replace(text,edits):
 old=text
 for before,after in edits:
  assert text.count(before)==1 and (not after or after not in text),before[:100]
  text=text.replace(before,after)
 check=text
 for before,after in reversed(edits):
  assert after and check.count(after)==1,after[:100]
  check=check.replace(after,before)
 assert check==old
 return text
def hunks():
 # Reuse exact reviewed contexts, not the old recipe's obsolete environment.
 lines=OLD_DIFF.read_text('utf8').splitlines(True);i=0;out={}
 while i<len(lines):
  assert lines[i].startswith('--- a/src/');name=lines[i][10:].strip();i+=1
  assert name in NAMES and name not in out and lines[i].strip()=='+++ b/src/'+name;i+=1;out[name]=[]
  while i<len(lines) and lines[i].startswith('@@ '):
   i+=1;before=[];after=[]
   while i<len(lines) and not lines[i].startswith(('@@ ','--- ')):
    row=lines[i];i+=1;assert row[0] in ' +-'
    if row[0] in ' -':before.append(row[1:])
    if row[0] in ' +':after.append(row[1:])
   out[name].append((''.join(before),''.join(after)))
 assert set(out)==set(NAMES);return out
def patches():
 view=[
 ('   import flash.utils.getDefinitionByName;','   import rconnect.core.Log;'),
 ('      private static var reasonSpent:Boolean=false,reasonData:Object=null;',
  '      private static var reasonData:Object=null;'),
 ('      public static function diagnosticBegin(loc:Object):Boolean {',
  '      public static function diagnosticBegin(loc:Object,retained:Boolean,dirty:Boolean):Boolean {'),
 ('            if(reasonSpent || loc==null)return false;',
  '            reasonData=null;\n            if(loc==null)return false;'),
 ('            var nativeWorld:Object=getDefinitionByName("fe.World");\n'
  '            if(!(loc.spaceX>nativeWorld["cellsX"] || loc.spaceY>nativeWorld["cellsY"]))return false;\n'
  '            reasonSpent=true;reasonKind="";reasonFields=null;reasonX=-1;reasonY=-1;reasonIndex=-1;',
  '            reasonKind="";reasonFields=null;reasonX=-1;reasonY=-1;reasonIndex=-1;'),
 ('            reasonData={schema:"first-terrain-reuse-reason-v1",complete:false,performanceQualified:false,',
  '            reasonData={schema:"terrain-reuse-first-rejection-v1",DIAGNOSTIC_ONLY:true,complete:false,performanceQualified:false,\n'
  '               appId:app,captureRetained:retained,captureDirty:dirty,'),
 ('         if(value===undefined)return {type:"undefined"};\n'
  '         if(value==null || value is Boolean)return value;\n'
  '         if(value is String)return String(value).length<=256?value:{type:"string",prefix:String(value).substr(0,256),length:String(value).length};\n'
  '         if(value is Number)return isFinite(Number(value))?value:{type:"number",value:String(value)};\n'
  '         return {type:typeof value};',
  '         if(value===undefined)return {type:"undefined"};\n'
  '         if(value===null)return {type:"null",value:null};\n'
  '         if(value is Boolean)return {type:"boolean",value:value};\n'
  '         if(value is String)return String(value).length<=96?{type:"string",value:value}:{type:"string",prefix:String(value).substr(0,96),length:String(value).length};\n'
  '         if(value is Number)return {type:typeof value,value:isFinite(Number(value))?value:String(value)};\n'
  '         return {type:typeof value};'),
 ('      public static function diagnosticFinish(armed:Boolean,reused:Boolean):Object {\n'
  '         if(!armed)return null;\n'
  '         var result:Object=reasonData;reasonData=null;reasonFields=null;\n'
  '         try{if(result!=null){result.complete=true;result.reused=reused;}}\n'
  '         catch(error:*){if(result!=null){result.complete=false;result.faultCount++;}}\n'
  '         return result;\n'
  '      }',
  '      public static function diagnosticFinish(armed:Boolean,reused:Boolean,key:*):void {\n'
  '         if(!armed)return;\n'
  '         var result:Object=reasonData;reasonData=null;reasonFields=null;\n'
  '         try {\n'
  '            if(result==null)return;\n'
  '            result.complete=true;result.reused=reused;result.key=key;\n'
  '            Log.d("RConnectTerrainReuse DIAGNOSTIC_ONLY "+JSON.stringify(result));\n'
  '         } catch(ignored:*) {} // Absent output is incomplete evidence, never a gameplay failure.\n'
  '      }')]
 bridge=[
 ('RoomTerrainView.diagnosticBegin(loc);','RoomTerrainView.diagnosticBegin(loc,retained,_terrain.dirty);'),
 ('         timing.beforeRole=getTimer()-timingStart; // TERRAIN-REASON: pre-role boundary only.',
  '         // TERRAIN-REASON: no additional timing boundary.'),
 ('         var terrainReasonResult:Object=RoomTerrainView.diagnosticFinish(terrainReason,timing.terrainReused===true);\n'
  '         if(terrainReasonResult!=null)timing.terrainReuseReason=terrainReasonResult;',
  '         RoomTerrainView.diagnosticFinish(terrainReason,timing.terrainReused===true,timing.key);')]
 return dict(zip(NAMES,(view,bridge)))
def expected():
 for p,h in PINS.items():assert sha(p)==h,str(p)
 load(RECIPE/'build.py','terrain_diagnostic_actual_base').verify(BASE)
 meta=read(BASE/'prepared.json');assert sha(BASE/'RConnectMod.swf')==BASE_SHA
 assert meta['version']==VERSION and len(meta['source'])==82
 old_hunks=hunks();new_edits=patches();files={};changes={};full=dict(meta['source']);diff=''
 for name in NAMES:
  original=(BASE/'src'/name).read_bytes();old=original.decode('utf8')
  candidate=replace(replace(old,old_hunks[name]),new_edits[name])
  # Both exact edit sets are reversible; the rest of the full class is byte-identical.
  raw=candidate.encode('utf8');assert raw!=original
  files['src/'+name]=raw;digest=hashlib.sha256(raw).hexdigest();full[name]=digest
  changes[name]=dict(base_sha256=sha(BASE/'src'/name),candidate_sha256=digest)
  diff+=''.join(difflib.unified_diff(old.splitlines(True),candidate.splitlines(True),fromfile='5325/'+name,tofile='DIAGNOSTIC_ONLY/'+name))
  if name.endswith('GameBridge.as'):
   for token in ('_wall.checkpoint(loc)','terrainView.unchanged(loc)','tileRedrawIfDirty();','Log.d("RConnectRoomTiming restore "+JSON.stringify(timing));'):
    assert old.count(token)==candidate.count(token),token
   assert candidate.count('RoomTerrainView.diagnosticFinish(')==1
 assert sum(full[k]==v for k,v in meta['source'].items())==80
 assert full['RConnectMod.as']==meta['source']['RConnectMod.as']
 files['source.diff']=diff.encode('utf8')
 old=DELEGATE.read_text('utf8');new=replace(old,BUILDER_EDITS);ast.parse(new)
 files['bounded-build.py.txt']=new.encode('utf8')
 files['builder.diff']=''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile='frozen/v5-build.py',tofile='DIAGNOSTIC_ONLY/bounded-build.py')).encode('utf8')
 manifest=dict(kind='terrain-reuse-diagnostic-v1',diagnostic_only=True,performance_qualified=False,
  base_sha256=BASE_SHA,installed_base_sha256=INSTALLED_SHA,version=VERSION,changes=changes,
  base_source=meta['source'],candidate_source=full,historical_build_environment=meta['installation_before'],
  inputs={str(p):h for p,h in PINS.items()},maximum_added_log_lines_per_restore=1,source_qualification_only=True)
 manifest['files']={n:hashlib.sha256(v).hexdigest() for n,v in files.items()}
 for name in ('prepare.py','build.py','README.md'):
  if name.endswith('.py'):ast.parse((HERE/name).read_text('utf8'))
  manifest['files'][name]=sha(HERE/name)
 return files,manifest
def verify():
 files,manifest=expected()
 assert read(HERE/'source-manifest.json')==manifest
 for n,v in files.items():assert (HERE/n).read_bytes()==v,n
 assert inventory(HERE/'src')=={n:r['candidate_sha256'] for n,r in manifest['changes'].items()}
 for n,h in manifest['files'].items():assert sha(HERE/n)==h,n
 return manifest
if __name__=='__main__':
 ap=argparse.ArgumentParser();group=ap.add_mutually_exclusive_group(required=True)
 group.add_argument('--prepare',action='store_true');group.add_argument('--check',action='store_true');a=ap.parse_args()
 if a.prepare:
  files,manifest=expected();files['source-manifest.json']=(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n').encode('utf8')
  for n,data in files.items():
   p=HERE/n
   if p.exists():assert p.read_bytes()==data,'Refuse changing prepared text: '+n
   else:
    p.parent.mkdir(parents=True,exist_ok=True)
    with p.open('xb') as f:f.write(data)
 verify();print(json.dumps(dict(source_checked=True,DIAGNOSTIC_ONLY=True,changed_classes=2,unchanged_classes=80,
  compiled=False,air_started=False,performance_qualified=False)))

"""Exact A796 text overlay. No compiler, AIR, SWF copy or installation write."""
from pathlib import Path
import argparse, ast, difflib, hashlib, json, re, sys
if sys.flags.optimize: raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
GAME=ROOT.parents[1]
EXPORT=ROOT/'build/m52/recovery-room-first-raster-current-source-02'
OLD=ROOT/'build/m52/recovery-early-host-01'
HOST=GAME/'pfe.swf'
HOST_SHA='a796827173af7d6fab9885fb66ecc62182ab5335918a30c7cce4c44914a238b7'
BASE_XML=GAME/'mods/ContinuousScene/build/generated/scene-compat-20261024/tint/product/pfe.xml'
CLASSES=('fe.World','fe.loc.Game','fe.graph.Grafon')
CHANGED={'fe.World':['step','exitStep'], 'fe.loc.Game':['enterToCurLand'],
 'fe.graph.Grafon':['sceneOpen','sceneEnsure','sceneTick','sceneViewReady','drawLoc']}
ADDED={'fe.World':['rconnectLoadingHold','rconnectCancelLoading'], 'fe.loc.Game':[],
 'fe.graph.Grafon':['get rconnectRasterPending','rconnectRasterWaiting','rconnectRasterPainted']}
PINS={
 EXPORT/'receipt.json':'fd125e64837c84a6a3ba339c9f60e42fc526dcc152503c0dc53bcaa82b257a66',
 BASE_XML:'1d2642c7d55d1f97121738e6ae84996a140ebfeff686e6706c88cef82a7338da',
 OLD/'pfe.swf':'2d415dd373236fff3c7a691db4eff8327a6de97b91c23d8a818ec77082b3dd29',
 OLD/'before/scripts/fe/World.as':'f9b5d270ad95a223ca37b0e339dcee1380856dff6254a5b1a0d9b12d997aaf16',
 OLD/'after/scripts/fe/World.as':'885bd7c986a28a2f1e37e99a950a5e357dbb6e93a4627cf9151568ee938d80f6',
 OLD/'after/scripts/fe/loc/Game.as':'538d5d0439ba6d5bfc6ddc147725a894dd7c0664a2bbce46cd4582144b8ca40a',
 OLD/'after/scripts/fe/graph/Grafon.as':'e6b4142462c1187388c4bb9c8151dd6c2605ce4e4b9fedd421cf4749c54bd7a0',
 GAME/'mods/ContinuousScene/build/generated/scene-compat-20261024/tint/product/source-equivalent.as.inc':'57398e9e9a75b287688a02dfb20d3df476291dca92c6f004b58d0c3f34dcdaf5',
}
LEX=re.compile(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|//[^\n]*|/\*[\s\S]*?\*/|\s+|\w+|[^\w\s]')
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def text(p):return Path(p).read_text(encoding='utf-8-sig')
def read(p):return json.loads(text(p))
def token(s):return ''.join(m[0] for m in LEX.finditer(s) if not m[0].isspace() and not m[0].startswith(('//','/*')))
def methods(s):
 out={}
 for m in re.finditer(r'(?:public|private|internal|protected)\s+(?:(?:static|override|final)\s+)*function\s+((?:get\s+|set\s+)?\w+)\([^\n]*\)[^{]*\{',s):
  depth=1
  for t in LEX.finditer(s,m.end()):
   if t[0]=='{':depth+=1
   elif t[0]=='}':depth-=1
   if depth==0:break
  assert depth==0 and m[1] not in out,m[1]
  out[m[1]]=s[m.start():t.end()]
 return out
def once(s,old,new):
 assert s.count(old)==1,old[:120]
 return s.replace(old,new,1)
def replace_method(s,name,new):return once(s,methods(s)[name],new)
def append_call(body,call):
 assert body.endswith('}')
 return body[:-1]+call+'      }'
def paths(cls):return Path(*cls.split('.')).with_suffix('.as')

def inputs():
 for p,h in PINS.items():assert h and sha(p)==h,str(p)
 assert sha(HOST)==HOST_SHA
 r=read(EXPORT/'receipt.json')
 assert r['passed'] is True and r['source_sha256']==HOST_SHA and r['classes']==list(CLASSES)
 assert r['installation_unchanged'] is True and r['inputs_unchanged'] is True and r['air_started'] is False
 assert len(r['commands'])==2 and all(x['exit_code']==0 for x in r['commands'])
 assert len(r['files'])==6
 for p,h in r['files'].items():assert sha(EXPORT/p)==h,p
 for p,h in r['inputs'].items():assert sha(p)==h,p
 return {str(p):h for p,h in PINS.items()}|r['inputs']|{str(EXPORT/p):h for p,h in r['files'].items()}

def generate():
 pins=inputs(); originals={c:text(EXPORT/'source/scripts'/paths(c)) for c in CLASSES}; output=dict(originals)
 old={c:text(OLD/'after/scripts'/paths(c)) for c in CLASSES}
 c='fe.World';s=output[c];om=methods(old[c]);control=methods(text(OLD/'before/scripts'/paths(c)))
 for name in CHANGED[c]:
  assert token(methods(s)[name])==token(control[name]),name
  s=replace_method(s,name,om[name])
 s=once(s,'      internal function exitStep()', ''.join('      '+om[n]+'\n      \n' for n in ADDED[c])+'      internal function exitStep()')
 output[c]=s
 c='fe.loc.Game';s=output[c]
 assert 'rconnectTravelBridge' not in s
 s=once(s,'      public var lands:Array;', '      public static var rconnectTravelBridge:Function = null;\n      \n      public static const rconnectEarlyTravelVersion:int = 1;\n      \n      public var lands:Array;')
 body=methods(s)['enterToCurLand']
 tail='         if(rconnectTravelBridge != null)\n         {\n            rconnectTravelBridge("constructed",this,null);\n         }\n'
 assert token(tail) in token(methods(old[c])['enterToCurLand'])
 # Preserve native constructor/Encounter/entry/spawn/effect/trigger order.
 s=replace_method(s,'enterToCurLand',body[:-7]+tail+'      }')
 output[c]=s
 c='fe.graph.Grafon';s=output[c];om=methods(old[c])
 assert 'rconnectRaster' not in s
 s=once(s,'      public static var spriteLists:Array = new Array();', '      public static var rconnectRasterBridge:Function = null;\n      \n      public static var spriteLists:Array = new Array();')
 ctor=methods(s)['Grafon'];s=once(s,ctor,'private var rconnectRasterTicket:Object;\n      \n      '+ctor)
 s=once(s,'      private function sceneOpen(', ''.join('      '+om[n]+'\n      \n' for n in ADDED[c])+'      private function sceneOpen(')
 b=methods(s)['sceneOpen']
 acquisition=om['sceneOpen'][om['sceneOpen'].index('         var ticket:Object'):om['sceneOpen'].index('         this.sceneSyncRegionLighting(value);')]
 b=once(b,'         this.sceneSyncRegionLighting(value);',acquisition+'         this.sceneSyncRegionLighting(value);')
 b=once(b,'         this.drawAllObjs();','         this.drawAllObjs();\n         this.rconnectRasterPainted();')
 s=replace_method(s,'sceneOpen',b)
 for name,ret in [('sceneEnsure','return;'),('sceneTick','return;'),('sceneViewReady','return false;')]:
  b=methods(s)[name];point=b.index('{')+1
  b=b[:point]+'\n         if(this.rconnectRasterWaiting())\n         {\n            '+ret+'\n         }'+b[point:]
  if name=='sceneTick':b=once(b,'         this.sceneCullSurfaces();','         this.sceneCullSurfaces();\n         this.rconnectRasterPainted();')
  s=replace_method(s,name,b)
 b=methods(s)['drawLoc'];needle='         sceneStarted = int(getTimer());'
 b=once(b,needle,'         if(!this.sceneRasterizing)\n         {\n            this.rconnectRasterTicket = null;\n         }\n'+needle)
 s=replace_method(s,'drawLoc',b);output[c]=s
 # Donor-only compiler repairs. These two methods are NEVER copied to final ABC.
 donor=dict(output)
 s=donor[c]
 s=once(s,'                  var _loc1_:* = §§findproperty(j);\n                  var _loc2_:Number = Number(_loc1_.j) + 1;\n                  _loc1_.j = _loc2_;','                  j++;')
 s=once(s,'               _loc1_ = §§findproperty(i);\n               _loc2_ = Number(_loc1_.i) + 1;\n               _loc1_.i = _loc2_;','               i++;')
 eq=text(GAME/'mods/ContinuousScene/build/generated/scene-compat-20261024/tint/product/source-equivalent.as.inc')
 s=replace_method(s,'sceneEntitySameColor',methods(eq)['sceneEntitySameColor']);donor[c]=s
 proof={}
 for c in CLASSES:
  a,b,d=methods(originals[c]),methods(output[c]),methods(donor[c])
  assert set(b)-set(a)==set(ADDED[c]) and not(set(a)-set(b)),c
  assert {n for n in a if token(a[n])!=token(b[n])}==set(CHANGED[c]),c
  assert {n for n in b if token(b[n])!=token(d[n])}==({'sceneDrawSteps','sceneEntitySameColor'} if c=='fe.graph.Grafon' else set()),c
  for n in ADDED[c]:assert token(b[n])==token(methods(old[c])[n]),n
  assert '§§' not in donor[c],c
  proof[c]=dict(changed=CHANGED[c],added=ADDED[c],unchanged={n:hashlib.sha256(token(a[n]).encode()).hexdigest() for n in a if n not in CHANGED[c]},
   donor_only_repairs=['sceneDrawSteps','sceneEntitySameColor'] if c=='fe.graph.Grafon' else [])
 return pins,originals,output,donor,proof

def expected():
 pins,originals,overlay,donor,proof=generate();files={};patch=[];repairs=[]
 for c in CLASSES:
  rel=paths(c).as_posix();files['patched-readback/'+rel]=overlay[c];files['import/'+rel]=donor[c]
  patch.extend(difflib.unified_diff(originals[c].splitlines(True),overlay[c].splitlines(True),fromfile='A796/'+rel,tofile='first-raster/'+rel))
  repairs.extend(difflib.unified_diff(overlay[c].splitlines(True),donor[c].splitlines(True),fromfile='patched-readback/'+rel,tofile='donor-only/'+rel))
 files['source.diff']=''.join(patch);files['donor-only.diff']=''.join(repairs)
 meta=dict(kind='A796-first-raster-text-only',host_sha256=HOST_SHA,base_xml_sha256=PINS[BASE_XML],inputs=pins,
  files={p:hashlib.sha256(s.encode()).hexdigest() for p,s in files.items()},methods=proof,
  changed_original_methods=8,new_methods=5,new_fields=4,
  compiled=False,air_started=False,installed=False,gameplay_qualified=False,performance_qualified=False,
  required_retention='Keep all original non-target method bodies, class/script indices, old traits and constant prefix; append precise traits/helpers; cinit uses original code plus literal new assignments only.')
 for n in ('prepare.py','retain.py','build.py','README.md'):
  if (HERE/n).exists():
   if n.endswith('.py'):ast.parse(text(HERE/n))
   meta.setdefault('recipe_inputs',{})[n]=sha(HERE/n)
 return files,meta
def verify():
 files,meta=expected();assert read(HERE/'source-manifest.json')==meta
 for p,s in files.items():assert (HERE/p).read_bytes()==s.encode(),p
 return meta
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--prepare',action='store_true');ap.add_argument('--check',action='store_true');a=ap.parse_args();assert a.prepare!=a.check
 if a.prepare:
  files,meta=expected()
  for p,s in files.items():
   target=HERE/p;target.parent.mkdir(parents=True,exist_ok=True);target.write_text(s,encoding='utf-8',newline='\n')
  (HERE/'source-manifest.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 result=verify();print(json.dumps(dict(passed=True,changed_original_methods=8,new_methods=5,new_fields=4,manifest_sha256=sha(HERE/'source-manifest.json'),compiled=False)))
if __name__=='__main__':main()

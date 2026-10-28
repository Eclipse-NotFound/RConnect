"""Prepare PI's independent B source plus an exact-source native patch recipe.
No decompiler/compiler/game is launched. Existing PI source remains read-only.
"""
from pathlib import Path
import argparse,hashlib,json,subprocess,sys
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;RC=HERE.parents[1];GAME=RC.parents[1]
sys.path.insert(0,str(RC/'tools/host_authority'))
from common import JAVA,SDK,FFDEC
COMMIT='ce39a10'
FILES=['InjuryDoc.as','PermanentInjuryMod.as','InjuryCarrier.as','InjuryCore.as','InjuryDefaults.as']
BASE_SHA='eced04ad8dae6b74444ee6e5f5ec5ddf2e83528a9eecfef66f58985cb0c83063'
def git(name):return subprocess.check_output(['git','-C',str(GAME/'mods/PermanentInjury'),'show',COMMIT+':'+name]).decode('utf-8-sig')
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def replace(text,a,b,count=1):
 if text.count(a)!=count:raise ValueError('Source anchor changed: '+a[:100])
 return text.replace(a,b)
def prepare(out):
 if out.exists():raise FileExistsError('Use a fresh candidate-source directory')
 out.mkdir(parents=True);src=out/'src';src.mkdir();original={}
 for name in FILES:
  text=git('src/'+name);original[name]=hashlib.sha256(text.encode()).hexdigest()
  if name=='InjuryCarrier.as':text=replace(text,'public var api:Object;','public var api:Object; public var authorityAPI:Object;')
  if name=='PermanentInjuryMod.as':
   text=replace(text,'  private static const NAMES:Array=',
    '  private static var authorityOwner:Object,authorityRole:String="";\n  private static const NAMES:Array=')
   text=replace(text,'   carrier.api={version:VERSION,dispatch:dispatch,snapshot:snapshot,open:openPanel};',
    '   carrier.api={version:VERSION,dispatch:dispatch,snapshot:snapshot,open:openPanel};\n   carrier.authorityAPI={version:1,attach:attachAuthority};')
   text=replace(text,'    if(key=="probe")return 1;', '''    if(key=="probe")return 1;
    // A joiner receives confirmed state; it never draws injury random numbers,
    // advances injury timers or pays medical costs a second time.
    if(authorityRole=="client") {
     var confirmed:Object=records[p];
     if(key=="save")return p.hasOwnProperty("piPermanent")?JSON.parse(JSON.stringify(p["piPermanent"])):null;
     if(key=="factor")return confirmed&&confirmed.factor.hasOwnProperty(String(arg))?confirmed.factor[String(arg)]:1;
     if(key=="describe"&&confirmed)return describeItem(confirmed,String(arg));
     if(key=="doctorRows"&&confirmed)return doctorRows(confirmed,arg);
     return null;
    }''')
   text=replace(text,'if(ready){var r:Object=rec(lastPers);refresh(r);}',
    'if(ready&&authorityRole!="client"){var r:Object=rec(lastPers);refresh(r);}')
   text=replace(text,'lastPers=world.pers;if(!("piEvent" in lastPers))',
    'lastPers=world.pers;if(!("piEvent" in lastPers))') # assert lifecycle anchor
   text=replace(text,'ready=true;rec(lastPers);log("hooks ready");',
    'ready=true;if(authorityRole!="client")rec(lastPers);log("hooks ready");')
   text=replace(text,'set:function(v:*):void{if(!configValid)return;',
    'set:function(v:*):void{if(authorityRole=="client"){notice="联机时由主侧调整伤残规则";return;}if(!configValid)return;')
   text=replace(text,'set:function(v:*):void{if(lastPers)flush(rec(lastPers));config.magicEnabled=',
    'set:function(v:*):void{if(authorityRole=="client"){notice="联机时由主侧调整伤残规则";return;}if(lastPers)flush(rec(lastPers));config.magicEnabled=')
   text=replace(text,'   var r:Object=rec(world.pers);flush(r);var s:Object=r.s,f:Object=r.factor,lines:Array=[];',
    '   var r:Object=authorityRole=="client"?records[world.pers]:rec(world.pers);if(!r){body.text="等待主侧确认伤残状态";return;}if(authorityRole!="client")flush(r);var s:Object=r.s,f:Object=r.factor,lines:Array=[];')
   entry=(HERE/'injury-authority-methods.as.inc').read_text(encoding='utf-8')
   text=replace(text,'  public static function log(text:String):void {',entry+'\n  public static function log(text:String):void {')
  (src/name).write_text(text,encoding='utf-8')
 # Preserve the exact, already-tested PI source generator. Only I/O and the
 # World clock seam differ: B advances each occupied actor itself.
 patch=git('build/patch-host.cjs')
 patch=replace(patch,"const dir=path.resolve(__dirname),source=path.join(dir,'host/scripts'),dest=path.join(dir,'candidate/scripts');",'''const dir=path.resolve(process.argv[2]||'');
const allowed=path.resolve(__dirname);
if(dir===allowed||!dir.startsWith(allowed+path.sep))throw Error('Output must be a new job below the independent PI recipe');
const source=path.join(dir,'host/scripts'),dest=path.join(dir,'candidate/scripts');
if(fs.existsSync(dest))throw Error('Use a new native preparation job');''')
 patch=replace(patch,'if(this.pers != null) this.pers.piEvent("tick",1/fps);',
   'if(this.pers != null && Land.rconnectRoomStep == null) this.pers.piEvent("tick",1/fps);')
 patch=replace(patch,'if(this.pers != null) this.pers.piEvent("flush");',
   'if(this.pers != null && Land.rconnectRoomStep == null) this.pers.piEvent("flush");')
 (out/'patch-native.cjs').write_text(patch,encoding='utf-8')
 java=git('build/MethodPatch.java')
 java=replace(java,'!output.toString().replace(\'\\\\\',\'/\').contains("/mods/PermanentInjury/build/candidate/")',
   '!output.startsWith(Paths.get(System.getProperty("rconnect.pi.outputRoot", "__unset__")).toRealPath())')
 # Also require the input hash before constructing a donor. Existing B methods
 # and unrelated resources are never replaced wholesale by the donor.
 java=replace(java,'  SWF target=load(v[0]),donor=load(v[1]);',
   '  String inputHash=HexFormat.of().formatHex(java.security.MessageDigest.getInstance("SHA-256").digest(Files.readAllBytes(input)));\n  if(!inputHash.equals("'+BASE_SHA+'"))throw new IllegalArgumentException("Expected exact B native021");\n  SWF target=load(v[0]),donor=load(v[1]);')
 (out/'MethodPatch.java').write_text(java,encoding='utf-8')
 commands=[[str(JAVA),'-Xmx512m','-jar',str(SDK/'lib/mxmlc.jar'),'+configname=air','+flexlib='+str(SDK/'frameworks'),
  '-source-path='+str(src),'-swf-version=38','-debug=false','-optimize=true','-output='+str(out/'PermanentInjuryMod.swf'),str(src/'InjuryDoc.as')]]
 result=dict(kind='b-injury-independent-source',source_commit=COMMIT,original_sources=original,
  sources={p.relative_to(out).as_posix():sha(p) for p in out.rglob('*') if p.is_file()},commands=commands,
  native_base_sha256=BASE_SHA,native_generator='patch-native.cjs',native_transplant='MethodPatch.java',
  compiler={str(p):sha(p) for p in (JAVA,SDK/'lib/mxmlc.jar',SDK/'frameworks/libs/air/airglobal.swc')},
  compiled=False,native_prepared=False,runtime_qualified=False,installed=False)
 (out/'prepared.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8');return result
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',default='injury-sources-01');a=ap.parse_args();out=(HERE/a.output).resolve()
 if not out.is_relative_to(HERE) or out==HERE:raise ValueError('Only own independent preparation directory')
 r=prepare(out);print(json.dumps({'output':str(out),'sources':len(r['sources']),'compiled':False}))
if __name__=='__main__':main()

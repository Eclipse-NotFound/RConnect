"""Exact recovery20 source-only decoder comparison. Never compiles or runs AIR."""
from pathlib import Path
import difflib,hashlib,json
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];BASE=ROOT/'build/m52/recovery-20'
ANCESTOR=ROOT/'experimental/recovery-wall-encode'
PIN='0674019c4aeea22900aef3e2390a31aed4fafc7850e0f3a74bc5ebb2facce9f5'
CODEC='rconnect/net/WallCellCodec.as';WALL='rconnect/game/WallImpactVisuals.as'
ACCESS='''      // DECODE_COMPONENT_ACCESS_BEGIN: stripped by exact source verification.
      public function testPacked(cell:Object):Object {return packed(cell);}
      public function testWords(data:String):Array {return decodeWords(data);}
      public function testCells(loc:Object,list:Array,limit:Boolean=true):Array {return decode(loc,list,limit);}
      public function testState(loc:Object):Object {return state(loc);}
      public function testDispose():void {reset();scratchA.dispose();scratchB.dispose();}
      // DECODE_COMPONENT_ACCESS_END
'''
DIGITS='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
TABLE='      // Invalid ASCII entries remain -1; non-ASCII is rejected before lookup.\n      private static const REVERSE:Vector.<int> = new <int>[\n'+',\n'.join('         '+','.join(str(DIGITS.find(chr(i))) for i in range(start,start+16)) for start in range(0,128,16))+'];\n'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text(encoding='utf-8-sig'))
def text(p):return Path(p).read_text(encoding='utf-8-sig')
def write(name,value):
 p=HERE/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(value,encoding='utf-8',newline='\n')
def once(s,a,b):assert s.count(a)==1,a;return s.replace(a,b,1)
def codec_overlay(s):
 start=s.index('      public static function unpack(');end=s.index('\n   }\n}',start)
 s=s[:start]+text(HERE/'unpack.inc').rstrip()+s[end:]
 return once(s,'      private static const MAX_RAW:int=9602;',TABLE+'      private static const MAX_RAW:int=9602;')
def wall_overlay(s):
 s=once(s,'var words:Array=WallCellCodec.isCell(data)?WallCellCodec.unpack(data):RoomCodec.unpack(data) as Array;',
   'var binary:Boolean=WallCellCodec.isCell(data);\n         var words:Array=binary?WallCellCodec.unpack(data):RoomCodec.unpack(data) as Array;')
 s=once(s,'         var previous:int=-1,numeric:Boolean=true;\n         for(var i:int=0;i<words.length;i+=2)',
   '         var previous:int=-1,numeric:Boolean=true;\n         // W1 already validates count, strictly increasing offsets and uint colors.\n         // Keep legacy coercion/type validation unchanged; it is not W1.\n         if(!binary)for(var i:int=0;i<words.length;i+=2)')
 return s
def wall_copy(s,side):
 if side in ('VerifyOnly','After'):s=wall_overlay(s)
 s=once(s,'class WallImpactVisuals','class Wall'+side)
 s=once(s,'function WallImpactVisuals(','function Wall'+side+'(')
 s=once(s,'      public function reset():void',ACCESS+'      public function reset():void')
 if side in ('Before','VerifyOnly'):s=s.replace('WallCellCodec','WallCellBefore')
 return s
def check_source(s):
 s=s.replace('WallEncodeChecks','WallDecodeChecks')
 s=once(s,'   import rconnect.game.WallAfter;', '   import rconnect.game.WallAfter;\n   import rconnect.game.WallCodecOnly;\n   import rconnect.game.WallVerifyOnly;\n   import rconnect.net.WallCellBefore;')
 s=once(s,'      private var oldPayloads:Array=[],newPayloads:Array=[];', '      private var oldPayloads:Array=[],newPayloads:Array=[];\n      private var codecOnly:WallCodecOnly,verifyOnly:WallVerifyOnly,corpora:Array=[];')
 s=once(s,'naturalCases();cacheCases();negativeCases();pixelCases();transportCases();','naturalCases();cacheCases();negativeCases();pixelCases();transportCases();decodeCases();')
 start=s.index('            // Two unmeasured full-corpus passes');end=s.index('            addEventListener(Event.ENTER_FRAME,benchmark);',start)
 s=s[:start]+'''            codecOnly=new WallCodecOnly();verifyOnly=new WallVerifyOnly();prepareCorpora();
            // Equal unmeasured warm-up. Cache reset happens outside each timed batch.
            for each(var warm:Object in [old,codecOnly,fresh,verifyOnly,verifyOnly,fresh,codecOnly,old])
               completeDecode(warm,corpora[4],1);
'''+s[end:]
 start=s.index('      private function measure(');end=s.index('      private function finish():void',start)
 s=s[:start]+text(HERE/'decode-checks.inc')+'\n'+text(HERE/'decode-benchmark.inc')+'\n'+s[end:]
 s=once(s,'         if(old!=null)old.testDispose();if(fresh!=null)fresh.testDispose();','         if(old!=null)old.testDispose();if(fresh!=null)fresh.testDispose();\n         if(codecOnly!=null)codecOnly.testDispose();if(verifyOnly!=null)verifyOnly.testDispose();')
 return s
def verify():
 m=read(HERE/'inputs.json');assert sha(__file__)==m['recipe_sha256']
 for p,h in m['originals'].items():assert sha(p)==h,p
 for p,h in m['files'].items():assert sha(HERE/p)==h,p
 for name,transform in ((CODEC,codec_overlay),(WALL,wall_overlay)):
  assert text(HERE/'src'/name)==transform(text(BASE/'src'/name))
 assert text(HERE/'components'/CODEC)==text(HERE/'src'/CODEC)
 assert text(HERE/'components/rconnect/net/WallCellBefore.as')==once(text(BASE/'src'/CODEC),'class WallCellCodec','class WallCellBefore')
 for side in ('Before','CodecOnly','VerifyOnly','After'):
  assert text(HERE/('components/rconnect/game/Wall'+side+'.as'))==wall_copy(text(BASE/'src'/WALL),side)
 assert text(HERE/'components/WallDecodeChecks.as')==check_source(text(ANCESTOR/'components/WallEncodeChecks.as'))
 # Pack and every decode tail operation after Base64 bytes remain byte-for-byte text equal.
 old=text(BASE/'src'/CODEC);new=text(HERE/'src'/CODEC)
 assert old[old.index('      public static function pack('):old.index('      public static function unpack(')]==new[new.index('      public static function pack('):new.index('      public static function unpack(')]
 assert old[old.index('         if(bytes.length>MAX_COMPRESSED)return null;'):]==new[new.index('         if(bytes.length>MAX_COMPRESSED)return null;'):]
 actual={p.relative_to(HERE).as_posix() for folder in ('src','components') for p in (HERE/folder).rglob('*') if p.is_file()}
 assert actual==set(m['files']);return m
def main():
 meta=read(BASE/'prepared.json');assert meta['compiled'] and meta['sha256']==PIN
 names=(CODEC,WALL,'rconnect/net/RoomCodec.as','rconnect/game/WallSurfaceBridge.as','rconnect/game/NativeWallColor.as')
 inputs=[BASE/'prepared.json',Path(__file__),HERE/'unpack.inc',HERE/'decode-checks.inc',HERE/'decode-benchmark.inc',
  HERE/'run_component.py',HERE/'check_static.py',HERE/'prepare_color_components.py',
  ROOT/'tools/validation/run_recovery_component.py',ANCESTOR/'components/WallEncodeChecks.as']
 for name in names:
  p=BASE/'src'/name;assert sha(p)==meta['source'][name];inputs.append(p)
 for name,transform in ((CODEC,codec_overlay),(WALL,wall_overlay)):
  before=text(BASE/'src'/name);after=transform(before);write('src/'+name,after)
  write(Path(name).stem+'.patch',''.join(difflib.unified_diff(before.splitlines(True),after.splitlines(True),fromfile='recovery20/'+name,tofile='wall-decode-fast/'+name)))
 write('components/'+CODEC,text(HERE/'src'/CODEC))
 write('components/rconnect/net/WallCellBefore.as',once(text(BASE/'src'/CODEC),'class WallCellCodec','class WallCellBefore'))
 for side in ('Before','CodecOnly','VerifyOnly','After'):write('components/rconnect/game/Wall'+side+'.as',wall_copy(text(BASE/'src'/WALL),side))
 for name in names[2:]:write('components/'+name,text(BASE/'src'/name))
 for name in ('rconnect/core/Log.as','rconnect/game/GameBridge.as','fe/weapon/Bullet.as'):
  p=ANCESTOR/'components'/name;inputs.append(p);write('components/'+name,text(p))
 corpus=ANCESTOR/'components/natural-payloads.json';inputs.append(corpus);write('components/natural-payloads.json',text(corpus))
 write('components/WallDecodeChecks.as',check_source(text(ANCESTOR/'components/WallEncodeChecks.as')))
 files={p.relative_to(HERE).as_posix():sha(p) for folder in ('src','components') for p in sorted((HERE/folder).rglob('*')) if p.is_file()}
 write('inputs.json',json.dumps({'baseline':str(BASE),'baseline_sha256_from_formal_receipt':PIN,'originals':{str(p):sha(p) for p in inputs},'files':files,'recipe_sha256':sha(__file__),'expected_runtime_checks':67,'compiled':False,'air_started':False,'performance_qualified':False},indent=2)+'\n')
 verify();print('Exact20 two independent decoder subitems and whole-class copies prepared; no JVM/AIR')
if __name__=='__main__':main()

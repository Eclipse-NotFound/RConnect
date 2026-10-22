"""Exact recovery18: only the Base64 tail of WallCellCodec.pack changes.
Source preparation and equivalence fixture only; no JVM/AIR or deployment.
"""
from pathlib import Path
import collections,difflib,hashlib,json,re
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];BASE=ROOT/'build/m52/recovery-18'
ANCESTOR=ROOT/'experimental/recovery-wall-encode'
PIN='11b795d0d6681caa4edfcc2d1c0df73cb38f6d706a1fb3c26518163f738fe4d3'
CODEC='rconnect/net/WallCellCodec.as';WALL='rconnect/game/WallImpactVisuals.as'
ACCESS='''      // BASE64_COMPONENT_ACCESS_BEGIN: stripped in verification.
      public function testPacked(cell:Object):Object {return packed(cell);}
      public function testWords(data:String):Array {return decodeWords(data);}
      public function testCells(loc:Object,list:Array,limit:Boolean=true):Array {return decode(loc,list,limit);}
      public function testState(loc:Object):Object {return state(loc);}
      public function testDispose():void {reset();scratchA.dispose();scratchB.dispose();}
      // BASE64_COMPONENT_ACCESS_END
'''
TABLE='''      // One bounded ASCII alphabet; no per-group temporary strings.
      private static const ASCII:Vector.<uint> = new <uint>[
         65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,
         97,98,99,100,101,102,103,104,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122,
         48,49,50,51,52,53,54,55,56,57,43,47];
'''
OLD='''         var out:Array=[];
         while(bytes.bytesAvailable) {
            var left:int=bytes.bytesAvailable,a:int=bytes.readUnsignedByte();
            var b:int=left>1?bytes.readUnsignedByte():0,c:int=left>2?bytes.readUnsignedByte():0;
            out.push(DIGITS.charAt(a>>2)+DIGITS.charAt(((a&3)<<4)|(b>>4))+
               (left>1?DIGITS.charAt(((b&15)<<2)|(c>>6)):"=")+(left>2?DIGITS.charAt(c&63):"="));
         }
         return PREFIX+out.join("");'''
NEW='''         var out:ByteArray=new ByteArray();
         out.length=int((bytes.length+2)/3)*4; // MAX_COMPRESSED already enforced.
         while(bytes.bytesAvailable) {
            var left:int=bytes.bytesAvailable,a:int=bytes.readUnsignedByte();
            var b:int=left>1?bytes.readUnsignedByte():0,c:int=left>2?bytes.readUnsignedByte():0;
            // ByteArray's default big endian writes these four ASCII bytes.
            out.writeUnsignedInt((ASCII[a>>2]<<24)|(ASCII[((a&3)<<4)|(b>>4)]<<16)|
               ((left>1?ASCII[((b&15)<<2)|(c>>6)]:61)<<8)|(left>2?ASCII[c&63]:61));
         }
         out.position=0;return PREFIX+out.readUTFBytes(out.length);'''
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text(encoding='utf-8-sig'))
def text(p):return Path(p).read_text(encoding='utf-8-sig')
def write(name,value):
    p=HERE/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(value,encoding='utf-8',newline='\n')
def once(s,a,b):assert s.count(a)==1,a;return s.replace(a,b,1)
def overlay(s):
    s=once(s,'      private static const MAX_RAW:int=9602;',TABLE+'      private static const MAX_RAW:int=9602;')
    return once(s,OLD,NEW)
def wall_copy(s,side):
    s=once(s,'class WallImpactVisuals','class Wall'+side)
    s=once(s,'function WallImpactVisuals(','function Wall'+side+'(')
    s=once(s,'      public function reset():void',ACCESS+'      public function reset():void')
    if side=='Before':s=s.replace('WallCellCodec','WallCellBefore')
    return s
def check_source(s):
    assert s.count('WallEncodeChecks')==2
    s=s.replace('WallEncodeChecks','WallBase64Checks')
    s=once(s,'   import rconnect.net.WallCellCodec;','   import rconnect.net.WallCellCodec;\n   import rconnect.net.WallCellBefore;')
    s=once(s,'naturalCases();cacheCases();negativeCases();pixelCases();transportCases();','naturalCases();cacheCases();negativeCases();pixelCases();transportCases();base64Cases();')
    s=once(s,'      private function measure(wall:Object,repetitions:int):Object {',text(HERE/'base64-checks.inc')+'\n      private function measure(wall:Object,repetitions:int):Object {')
    s=once(s,'if(phase<8)return;','if(phase<24)return;')
    s=once(s,'rounds:2,repetitions:3','rounds:6,repetitions:3')
    s=once(s,'ABBA measures eight nonempty equal-work 246-encode blocks','ABBA measures 24 nonempty equal-work 246-encode blocks')
    s=once(s,'var nonempty:Boolean=true;for each(var r:Object in benchRows)','var nonempty:Boolean=benchRows.length==24;for each(var r:Object in benchRows)')
    s=once(s,'forcedUncached:true,includesNumericSort:true,','forcedUncached:true,includesNumericSort:true,includesKeyColorValidation:true,includesZlib:true,includesWallEnvelope:true,base64OnlyTiming:false,')
    s=once(s,'''            check(benchRows[0].chars==benchRows[3].chars&&benchRows[1].chars==benchRows[2].chars&&
                  benchRows[4].chars==benchRows[7].chars&&benchRows[5].chars==benchRows[6].chars,
                  "ABBA repeated codec outputs remain stable independent of order");
            check(benchRows[0].coldDecode.words==benchRows[1].coldDecode.words&&
                  benchRows[0].coldDecode.checksum==benchRows[1].coldDecode.checksum,
                  "cold decode comparison consumes identical complete pixel words");''',
        '''            var stable:Boolean=true,sameDecode:Boolean=true;
            for each(r in benchRows) {
               stable=stable&&r.chars==benchRows[0].chars&&r.checksum==benchRows[0].checksum;
               sameDecode=sameDecode&&r.coldDecode.words==benchRows[0].coldDecode.words&&r.coldDecode.checksum==benchRows[0].coldDecode.checksum;
            }
            check(stable,"all 24 old/new ABBA outputs have identical characters/checksums independent of order");
            check(sameDecode,"all 24 cold decode blocks consume identical complete pixel words");''')
    return s
def verify():
    m=read(HERE/'inputs.json');assert sha(__file__)==m['recipe_sha256']
    for p,h in m['originals'].items():assert sha(p)==h,p
    for p,h in m['files'].items():assert sha(HERE/p)==h,p
    old=text(BASE/'src'/CODEC);new=text(HERE/'src'/CODEC)
    assert new==overlay(old)
    assert text(HERE/'components'/CODEC)==new
    assert text(HERE/'components/rconnect/net/WallCellBefore.as')==old.replace('class WallCellCodec','class WallCellBefore',1)
    for side in ('Before','After'):
        assert text(HERE/('components/rconnect/game/Wall'+side+'.as'))==wall_copy(text(BASE/'src'/WALL),side)
    assert text(HERE/'components/WallBase64Checks.as')==check_source(text(ANCESTOR/'components/WallEncodeChecks.as'))
    # Validation/sort/serialization/zlib and all receive code remain exact.
    clean=new.replace(TABLE,'').replace(NEW,OLD)
    assert clean==old
    actual={p.relative_to(HERE).as_posix() for folder in ('src','components') for p in (HERE/folder).rglob('*') if p.is_file()}
    assert actual==set(m['files'])
    return m
def main():
    meta=read(BASE/'prepared.json');assert meta['compiled'] and meta['sha256']==PIN
    names=(CODEC,WALL,'rconnect/net/RoomCodec.as','rconnect/game/WallSurfaceBridge.as','rconnect/game/NativeWallColor.as')
    inputs=[BASE/'prepared.json',Path(__file__),HERE/'base64-checks.inc',ANCESTOR/'components/WallEncodeChecks.as']
    for name in names:
        p=BASE/'src'/name;assert sha(p)==meta['source'][name];inputs.append(p)
    old=text(BASE/'src'/CODEC);new=overlay(old);write('src/'+CODEC,new)
    write('components/'+CODEC,new)
    write('components/rconnect/net/WallCellBefore.as',once(old,'class WallCellCodec','class WallCellBefore'))
    for side in ('Before','After'):write('components/rconnect/game/Wall'+side+'.as',wall_copy(text(BASE/'src'/WALL),side))
    for name in names[2:]:write('components/'+name,text(BASE/'src'/name))
    for name in ('rconnect/core/Log.as','rconnect/game/GameBridge.as','fe/weapon/Bullet.as'):
        p=ANCESTOR/'components'/name;inputs.append(p);write('components/'+name,text(p))
    corpus=ANCESTOR/'components/natural-payloads.json';inputs.append(corpus);write('components/natural-payloads.json',text(corpus))
    write('components/WallBase64Checks.as',check_source(text(ANCESTOR/'components/WallEncodeChecks.as')))
    write('base64-only.patch',''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile='recovery18/'+CODEC,tofile='wall-base64/'+CODEC)))
    files={p.relative_to(HERE).as_posix():sha(p) for folder in ('src','components') for p in sorted((HERE/folder).rglob('*')) if p.is_file()}
    write('inputs.json',json.dumps({'baseline':str(BASE),'baseline_sha256_from_formal_receipt':PIN,'originals':{str(p):sha(p) for p in inputs},
      'files':files,'recipe_sha256':sha(__file__),'compiled':False,'air_started':False,'performance_qualified':False},indent=2)+'\n')
    verify();print('Exact18 one-file Base64 candidate and whole-class copies prepared; no JVM/AIR')
if __name__=='__main__':main()

"""Create exact recovery13 wall encoding overlay and whole-class test copies."""
from pathlib import Path
import difflib,hashlib,json,shutil
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];BASE=ROOT/'build/m52/recovery-13'
BASE_SHA='1177eb1ae9b227bcf3c0eb39dedad92b63ac16dcb7ffb0b421ea0a2024bfddb1'
WALL='rconnect/game/WallImpactVisuals.as';CODEC='rconnect/net/RoomCodec.as'
ACCESS='''      // ENCODE_COMPONENT_ACCESS_BEGIN: wrappers only, stripped in verification.
      public function testPacked(cell:Object):Object {return packed(cell);}
      public function testWords(data:String):Array {return decodeWords(data);}
      public function testCells(loc:Object,list:Array,limit:Boolean=true):Array {return decode(loc,list,limit);}
      public function testState(loc:Object):Object {return state(loc);}
      public function testDispose():void {reset();scratchA.dispose();scratchB.dispose();}
      // ENCODE_COMPONENT_ACCESS_END
'''
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text(encoding='utf-8-sig'))
def write(name,value):
    p=HERE/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(value,encoding='utf-8',newline='\n')
def change(s,old,new):assert s.count(old)==1,old;return s.replace(old,new,1)
def derive(s,suffix):
    s=change(s,'class WallImpactVisuals','class Wall'+suffix)
    s=change(s,'function WallImpactVisuals(','function Wall'+suffix+'(')
    return change(s,'      public function reset():void',ACCESS+'      public function reset():void')
def overlay(old):
    s=change(old,'   import rconnect.net.RoomCodec;','   import rconnect.net.RoomCodec;\n   import rconnect.net.WallCellCodec;')
    s=change(s,'''         var indices:Array=[];for(var key:String in c.values)indices.push(int(key));indices.sort(Array.NUMERIC);
         var words:Array=[];for each(var i:int in indices)words.push(i,Number(c.values[String(i)]));
         var wire:Object={x:int(c.x),y:int(c.y),v:int(c.v),d:RoomCodec.pack(words)};''',
        '         var wire:Object={x:int(c.x),y:int(c.y),v:int(c.v),d:WallCellCodec.pack(c.values)};')
    s=change(s,'         var words:Array=RoomCodec.unpack(data) as Array;',
        '         var words:Array=WallCellCodec.isCell(data)?WallCellCodec.unpack(data):RoomCodec.unpack(data) as Array;')
    return change(s,'               var words:Array=RoomCodec.unpack(String(c.d)) as Array;',
        '               var words:Array=decodeWords(String(c.d));')
def verify():
    m=read(HERE/'inputs.json')
    assert sha(__file__)==m['recipe_sha256']
    for p,h in m['originals'].items():assert sha(p)==h,p
    for p,h in m['files'].items():assert sha(HERE/p)==h,p
    old=(BASE/'src'/WALL).read_text(encoding='utf-8-sig');new=(HERE/'src'/WALL).read_text(encoding='utf-8')
    assert new==overlay(old)
    for suffix,production in (('Before',old),('After',new)):
        assert (HERE/'components/rconnect/game'/('Wall'+suffix+'.as')).read_text(encoding='utf-8')==derive(production,suffix)
    assert sha(HERE/'components'/CODEC)==sha(BASE/'src'/CODEC)
    assert sha(HERE/'components/rconnect/net/WallCellCodec.as')==sha(HERE/'src/rconnect/net/WallCellCodec.as')
    actual={p.relative_to(HERE).as_posix() for folder in ('src','components') for p in (HERE/folder).rglob('*') if p.is_file()}
    assert actual==set(m['files']),'Unlisted source/component input'
    return m
def main():
    assert sha(BASE/'RConnectMod.swf')==BASE_SHA
    meta=read(BASE/'prepared.json');old=(BASE/'src'/WALL).read_text(encoding='utf-8-sig')
    for name in (WALL,CODEC):assert sha(BASE/'src'/name)==meta['source'][name]
    new=overlay(old);write('src/'+WALL,new)
    for suffix,source in (('Before',old),('After',new)):write('components/rconnect/game/Wall'+suffix+'.as',derive(source,suffix))
    write('components/'+CODEC,(BASE/'src'/CODEC).read_text(encoding='utf-8-sig'))
    write('components/rconnect/net/WallCellCodec.as',(HERE/'src/rconnect/net/WallCellCodec.as').read_text(encoding='utf-8'))
    write('components/rconnect/core/Log.as','package rconnect.core {public class Log {public static function d(s:String):void{}}}\n')
    write('components/rconnect/game/GameBridge.as','package rconnect.game {public class GameBridge {public static function probe(o:Object,k:String):*{try{return o!=null && k in o?o[k]:null;}catch(e:*){}return null;}}}\n')
    fixture=ROOT/'experimental/recovery-cost/components/fe/weapon/Bullet.as'
    write('components/fe/weapon/Bullet.as',fixture.read_text(encoding='utf-8-sig'))
    corpus=ROOT/'experimental/recovery-wall-working-set/data/flight-payloads.json'
    write('components/natural-payloads.json',corpus.read_text(encoding='utf-8'))
    write('proposal.patch',''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile='recovery13/'+WALL,tofile='wall-encode/'+WALL)))
    originals={str(p):sha(p) for p in (BASE/'prepared.json',BASE/'RConnectMod.swf',BASE/'src'/WALL,BASE/'src'/CODEC,fixture,corpus)}
    files={p.relative_to(HERE).as_posix():sha(p) for folder in ('src','components') for p in sorted((HERE/folder).rglob('*')) if p.is_file()}
    write('inputs.json',json.dumps(dict(originals=originals,files=files,recipe_sha256=sha(__file__),
        compiled=False,air_started=False,performance_qualified=False,current_density_payloads=False),indent=2)+'\n')
    verify();print('Exact13 two-file candidate and full-class component copies prepared; no JVM/AIR')
if __name__=='__main__':main()

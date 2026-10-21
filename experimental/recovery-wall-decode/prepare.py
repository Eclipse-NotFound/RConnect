"""Source-only exact-payload wall decoder proposal; never compile or run AIR."""
from pathlib import Path
import hashlib, json, difflib

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT / 'build/m52/recovery-02/src'

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def put(rel, text):
    p = (HERE / rel).resolve()
    assert p.is_relative_to(HERE)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text, encoding='utf-8', newline='\n')

def change(s, old, new):
    assert s.count(old) == 1, old
    return s.replace(old, new, 1)

def main():
    path = BASE / 'rconnect/game/WallImpactVisuals.as'
    before = path.read_text(encoding='utf-8-sig')
    after = change(before, '      private static const MARGIN:int=96;', '''      private static const MARGIN:int=96;
      // Cache only validated, numeric sparse words; room/version checks stay
      // outside this cache. Three independent bounds limit retained memory.
      private static const WORD_CACHE_ENTRIES:int=64;
      private static const WORD_CACHE_WORDS:int=32768;
      private static const WORD_CACHE_CHARS:int=131072;
      private var wordCache:Dictionary=new Dictionary();
      private var wordOrder:Array=[];
      private var wordCount:int=0,wordChars:int=0;''')
    old = '''               var words:Array=RoomCodec.unpack(String(c.d)) as Array;
               if(words==null || words.length>2*CELL*CELL || words.length%2!=0)return null;
               var previous:int=-1;
               for(var i:int=0;i<words.length;i+=2)
               {
                  var index:Number=Number(words[i]),color:Number=Number(words[i+1]);
                  if(!isFinite(index) || index!=int(index) || index<=previous || index>=CELL*CELL ||
                     !isFinite(color) || color<0 || color>4294967295 || color!=Math.floor(color))return null;
                  previous=int(index);
               }'''
    after = change(after, old, '''               var words:Array=decodeWords(String(c.d));
               if(words==null)return null;''')
    helpers = '''      /** The payload alone determines these words. Cache hits still return a
       * fresh array, so later consumers cannot mutate the retained value. */
      private function decodeWords(data:String):Array
      {
         var cached:Object=wordCache[data];
         if(cached!=null && cached.data===data)return cached.words.concat();
         var words:Array=RoomCodec.unpack(data) as Array;
         if(words==null || words.length>2*CELL*CELL || words.length%2!=0)return null;
         var previous:int=-1,numeric:Boolean=true;
         for(var i:int=0;i<words.length;i+=2)
         {
            var index:Number=Number(words[i]),color:Number=Number(words[i+1]);
            if(!isFinite(index) || index!=int(index) || index<=previous || index>=CELL*CELL ||
               !isFinite(color) || color<0 || color>4294967295 || color!=Math.floor(color))return null;
            previous=int(index);
            // Preserve legacy Number coercion for unusual payloads, but never
            // retain nested mutable arrays/objects or change returned types.
            if(!(words[i] is Number) || !(words[i+1] is Number))numeric=false;
         }
         if(numeric && data.length<=WORD_CACHE_CHARS)rememberWords(data,words);
         return words;
      }
      private function rememberWords(data:String,words:Array):void
      {
         while(wordOrder.length && (wordOrder.length>=WORD_CACHE_ENTRIES ||
            wordCount+words.length>WORD_CACHE_WORDS || wordChars+data.length>WORD_CACHE_CHARS))
         {
            var old:Object=wordOrder.shift();delete wordCache[old.data];
            wordCount-=old.words.length;wordChars-=old.data.length;
         }
         var entry:Object={data:data,words:words.concat()};
         wordCache[data]=entry;wordOrder.push(entry);
         wordCount+=words.length;wordChars+=data.length;
      }
'''
    after = change(after, '      private function protectedPixels(s:Object):Object', helpers+'      private function protectedPixels(s:Object):Object')
    after = change(after, '         rooms=new Dictionary(true);tracked=[];contacts=new Dictionary(true);tileState={};dirty=false;',
                   '         rooms=new Dictionary(true);tracked=[];contacts=new Dictionary(true);tileState={};dirty=false;\n'
                   '         wordCache=new Dictionary();wordOrder=[];wordCount=0;wordChars=0;')
    put('src/rconnect/game/WallImpactVisuals.as', after)
    put('proposal.patch', ''.join(difflib.unified_diff(before.splitlines(True), after.splitlines(True),
        fromfile='a/rconnect/game/WallImpactVisuals.as', tofile='b/rconnect/game/WallImpactVisuals.as')))
    for suffix, source in [('Before', before), ('After', after)]:
        source = source.replace('class WallImpactVisuals', 'class Wall'+suffix).replace(
            'function WallImpactVisuals(', 'function Wall'+suffix+'(')
        source = change(source, '      private function decode(', '      public function decode(')
        if suffix == 'After':
            source = change(source, '      public function reset():void',
                '      public function cacheStats():Object {return {entries:wordOrder.length,words:wordCount,chars:wordChars};}\n'
                '      public function reset():void')
        put('components/rconnect/game/Wall'+suffix+'.as', source)
    codec_path=BASE/'rconnect/net/RoomCodec.as'
    codec=codec_path.read_text(encoding='utf-8-sig')
    codec=change(codec, '      public static function unpack(s:String):Object\n      {',
                 '      public static function unpack(s:String):Object\n      {\n         DecodeCounter.calls++;')
    put('components/rconnect/net/RoomCodec.as',codec)
    transport_path=BASE/'rconnect/net/BinaryMessageCodec.as'
    put('components/rconnect/net/BinaryMessageCodec.as',transport_path.read_text(encoding='utf-8-sig'))
    put('components/rconnect/net/DecodeCounter.as', 'package rconnect.net { public class DecodeCounter { public static var calls:int=0; }}\n')
    put('components/rconnect/core/Log.as', 'package rconnect.core { public class Log { public static var rows:Array=[]; public static function d(s:String):void {rows.push(s);} }}\n')
    put('components/rconnect/game/GameBridge.as', '''package rconnect.game { public class GameBridge {
      public static function probe(o:Object,k:String):* {try{return o!=null && k in o?o[k]:null;}catch(e:*){}return null;}
   }}
''')
    manifest={'base':'build/m52/recovery-02/src',
        'base_inputs':{'rconnect/game/WallImpactVisuals.as':sha(path),'rconnect/net/RoomCodec.as':sha(codec_path),
          'rconnect/net/BinaryMessageCodec.as':sha(transport_path)},
        'overlay':{'rconnect/game/WallImpactVisuals.as':sha(HERE/'src/rconnect/game/WallImpactVisuals.as')},
        'components':{p.relative_to(HERE/'components').as_posix():sha(p) for p in (HERE/'components').rglob('*.as')},
        'recipe_sha256':sha(Path(__file__)),'compiled':False,'runtime_tested':False,'deployed':False,
        'expected_component_assertions':120,'component_assertions_executed':0,
        'component_boundary':['Real complete WallImpactVisuals before/after, renamed and decode made public only in fixtures',
          'Real RoomCodec plus one unpack-entry counter; Log is in-memory; GameBridge only provides safe probe',
          'Native room/grafon fixtures are small BitmapData grids; no TCP or game timing claims'],
        'cache_limits':{'entries':64,'words':32768,'encoded_chars':131072},
        'protocol_or_frequency_changed':False}
    put('inputs.json',json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'overlay_files':1,'components':len(manifest['components']),'runtime_tested':False}))

if __name__=='__main__':main()

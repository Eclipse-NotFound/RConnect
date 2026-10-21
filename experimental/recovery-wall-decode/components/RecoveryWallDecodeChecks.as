package {
   import flash.desktop.NativeApplication;
   import flash.display.BitmapData;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.filesystem.*;
   import flash.utils.ByteArray;
   import rconnect.game.WallBefore;
   import rconnect.game.WallAfter;
   import rconnect.net.RoomCodec;
   import rconnect.net.BinaryMessageCodec;
   import rconnect.net.DecodeCounter;
   public class RecoveryWallDecodeChecks extends Sprite {
      private var rows:Array=[],old:WallBefore,fresh:WallAfter,loc:Object;
      private const DIGITS:String="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
      public function RecoveryWallDecodeChecks(){addEventListener(Event.ADDED_TO_STAGE,begin);}
      private function check(ok:Boolean,label:String):void {rows.push({passed:ok,label:label});trace((ok?"PASS ":"FAIL ")+label);}
      private function equal(a:*,b:*,label:String):void {check(JSON.stringify(a)===JSON.stringify(b),label);}
      private function begin(e:Event):void {
         removeEventListener(Event.ADDED_TO_STAGE,begin);
         try {run();}catch(error:Error){check(false,"uncaught "+error+" "+error.getStackTrace());}
         var failed:int=0;for each(var row:Object in rows)if(!row.passed)failed++;
         var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         f.writeUTFBytes(JSON.stringify({passed:failed==0,failed:failed,assertions:rows,functional_only:true,native_runtime:false}));f.close();
         NativeApplication.nativeApplication.exit(failed?1:0);
      }
      private function setup():void {old=new WallBefore();fresh=new WallAfter();loc={spaceX:48,spaceY:25};DecodeCounter.calls=0;}
      private function cell(words:Object,v:int=1,x:int=0,y:int=0):Object {return {x:x,y:y,v:v,d:RoomCodec.pack(words)};}
      private function pair(list:Array,label:String,limit:Boolean=true):Array {
         var a:Array=old.decode(loc,list,limit),b:Array=fresh.decode(loc,list,limit);equal(a,b,label);return b;
      }
      private function grid():Object {
         var room:Object={spaceX:2,spaceY:2,space:[],firstObj:null};
         for(var x:int=0;x<2;x++){room.space[x]=[];for(var y:int=0;y<2;y++)room.space[x][y]={phis:1,hp:100};}
         room.grafon={loc:room,frontBmp:new BitmapData(80,80,true,0)};return room;
      }
      private function raw(json:String):String {
         var b:ByteArray=new ByteArray();b.writeUTFBytes(json);b.compress();b.position=0;
         var out:Array=[];while(b.bytesAvailable) {
            var n:int=b.bytesAvailable,a:int=b.readUnsignedByte(),c:int=n>1?b.readUnsignedByte():0,d:int=n>2?b.readUnsignedByte():0;
            out.push(DIGITS.charAt(a>>2)+DIGITS.charAt(((a&3)<<4)|(c>>4))+(n>1?DIGITS.charAt(((c&15)<<2)|(d>>6)):"=")+(n>2?DIGITS.charAt(d&63):"="));
         }return out.join("");
      }
      private function dense(seed:uint):Array {
         var a:Array=[],n:uint=seed;for(var i:int=0;i<1600;i++){n=uint(n*1664525+1013904223);a.push(i,Number(n));}return a;
      }
      private function denseConstant(color:uint):Array {
         var a:Array=[];for(var i:int=0;i<1600;i++)a.push(i,Number(color));return a;
      }
      private function whitespace(seed:uint,count:int=80000):String {
         var out:Array=[],n:uint=seed;for(var i:int=0;i<count;i++){n=uint(n*1664525+1013904223);out.push(" \t\r\n".charAt(n>>>30));}return out.join("");
      }
      private function bounded(label:String):void {
         var s:Object=fresh.cacheStats();check(s.entries<=64 && s.words<=32768 && s.chars<=131072,label);
      }
      private function run():void {
         setup();var c:Object=cell([0,4294967295,1599,0]),a:Array,b:Array;
         pair([c],"first valid payload equals baseline");check(DecodeCounter.calls==2,"first payload unpacks once on each side");
         DecodeCounter.calls=0;pair([c],"identical repeated payload equals baseline");
         check(DecodeCounter.calls==1,"identical repeat eliminates only the candidate unpack");
         var changed:Object=cell([0,17,1599,0],1);DecodeCounter.calls=0;
         b=pair([changed],"same version different payload preserves newly decoded words");
         check(DecodeCounter.calls==2 && b[0].words[1]==17,"version is never a cache key");
         c={x:0,y:0,v:7,d:changed.d};DecodeCounter.calls=0;b=pair([c],"same payload new version preserves outer version");
         check(DecodeCounter.calls==1 && b[0].v==7,"cache hit does not retain old version");
         c={x:1,y:1,v:8,d:changed.d};b=pair([c],"same payload new coordinates preserve outer coordinates");
         check(b[0].x==1 && b[0].y==1 && b[0].v==8,"cache is independent of the receiving room and coordinates");

         setup();c=cell([0,5]);a=fresh.decode(loc,[c]);a[0].words[1]=99;a[0].words.push(1,99);a[0].x=9;
         b=fresh.decode(loc,[c]);equal(b,[{x:0,y:0,v:1,words:[0,5]}],"caller mutation cannot corrupt cached words or envelope");
         check(a[0].words!==b[0].words,"every cache hit returns a private array");
         b[0].words[0]=900;equal(fresh.decode(loc,[c]),[{x:0,y:0,v:1,words:[0,5]}],"repeated hit mutation remains isolated");

         setup();c=cell([0,5]);var alternate:Object={x:0,y:0,v:1,d:raw(" [ 0, 5 ] ")};
         check(c.d!==alternate.d,"equivalent JSON has a genuinely different encoded payload");
         pair([c],"canonical payload baseline");DecodeCounter.calls=0;pair([alternate],"different exact bytes decode independently");
         check(DecodeCounter.calls==2 && fresh.cacheStats().entries==2,"payload equivalence does not substitute for exact string equality");

         setup();var odd:Array=[0],tooMany:Array=[];for(var i:int=0;i<1601;i++)tooMany.push(i,1);
         var bad:Array=[cell(odd),cell(tooMany),cell({a:1}),cell([1,2,0,3]),cell([0,1,0,2]),
            cell([0.5,1]),cell([-1,1]),cell([1600,1]),cell([0,-1]),cell([0,4294967296]),cell([0,1.5]),
            {x:0,y:0,v:1,d:raw("[0,1e400]")},{x:0,y:0,v:1,d:"%%%"},{x:0,y:0,v:1,d:""}];
         for(i=0;i<bad.length;i++) {
            b=pair([bad[i]],"malformed payload "+i+" matches baseline");check(b==null,"malformed payload "+i+" is rejected");
         }
         check(fresh.cacheStats().entries==0,"rejected words never enter the cache");
         c=cell([0,5]);pair([c],"warm cache before invalid same-version payload");
         b=pair([{x:0,y:0,v:1,d:"%%%"}],"same version invalid changed payload is not masked by cache");check(b==null,"same-version corruption is rejected");

         setup();var unusual:Array=[cell(["0","12"]),cell([[0],[12]]),cell([false,true])];
         for(i=0;i<unusual.length;i++) {
            DecodeCounter.calls=0;pair([unusual[i]],"legacy coercion "+i+" first result");pair([unusual[i]],"legacy coercion "+i+" repeat result");
            check(DecodeCounter.calls==4,"legacy coercion "+i+" remains uncached");
         }
         check(fresh.cacheStats().entries==0,"mutable or nonnumeric legacy values are not retained");

         setup();c=cell([0,11]);pair([c],"outer validation warm cache");
         var invalidOuter:Array=[[{x:-1,y:0,v:1,d:c.d}],[{x:0.1,y:0,v:1,d:c.d}],[{x:48,y:0,v:1,d:c.d}],
            [{x:0,y:25,v:1,d:c.d}],[{x:"NaN",y:0,v:1,d:c.d}],[null],[{x:0,y:0,v:1,d:[]}],[c,c]];
         for(i=0;i<invalidOuter.length;i++) {
            DecodeCounter.calls=0;b=pair(invalidOuter[i],"cached payload outer check "+i);check(b==null,"outer check "+i+" rejects cached payload");
         }
         var save:Object=loc;loc={spaceX:60,spaceY:40};
         check(pair([{x:48,y:0,v:1,d:c.d}],"1920px limit on cached payload")==null,"1920px limit remains");
         check(pair([{x:0,y:25,v:1,d:c.d}],"1000px limit on cached payload")==null,"1000px limit remains");loc=save;
         var list:Array=[];for(i=0;i<65;i++)list.push({x:i%48,y:int(i/48),v:1,d:c.d});
         check(pair(list,"network 64-cell maximum remains")==null,"65 network cells rejected even when all cached");
         b=pair(list,"checkpoint permits more than 64 cells",false);check(b!=null && b.length==65,"checkpoint retains its separate limit");
         list=[];for(i=0;i<1201;i++)list.push(c);check(pair(list,"checkpoint 1200-cell maximum remains",false)==null,"oversized checkpoint rejected before cache");
         check(pair(null,"null list remains rejected")==null,"null list cannot hit cache");

         setup();c=cell(dense(7));pair([c],"dense payload warms cache");list=[];
         for(i=0;i<=int(48000/c.d.length);i++)list.push({x:i%48,y:int(i/48),v:1,d:c.d});
         check(list.length<=64 && list.length*c.d.length>48000,"wire-limit fixture exceeds only the unchanged 48000-char bound");
         check(pair(list,"aggregate encoded-length bound runs before cached reuse")==null,"cached words cannot bypass encoded-length maximum");
         var oversized:String=new Array(1000002).join("A");
         check(pair([{x:0,y:0,v:1,d:oversized}],"RoomCodec one-million limit remains for checkpoint",false)==null,"oversized individual encoding rejected");

         setup();c=cell([0,7]);fresh.decode(loc,[c]);fresh.decode(loc,[c]);
         check(DecodeCounter.calls==1,"cache warm before reset");fresh.reset();equal(fresh.cacheStats(),{entries:0,words:0,chars:0},"reset releases all retained words and strings");
         fresh.decode(loc,[c]);check(DecodeCounter.calls==2,"same payload after reset decodes again");

         setup();c=cell([0,9000]);fresh.decode(loc,[c]);
         for(i=0;i<64;i++)fresh.decode(loc,[cell([0,i])]);
         check(fresh.cacheStats().entries==64,"entry limit bounds distinct sparse payloads");bounded("entry eviction obeys all bounds");
         DecodeCounter.calls=0;fresh.decode(loc,[c]);check(DecodeCounter.calls==1,"oldest entry is decoded again after FIFO eviction");
         setup();c=cell(denseConstant(200));fresh.decode(loc,[c]);
         for(i=0;i<11;i++)fresh.decode(loc,[cell(denseConstant(uint(i+201)))]);
         bounded("expanded-word eviction obeys all bounds");check(fresh.cacheStats().words==32000 && fresh.cacheStats().entries==10 && fresh.cacheStats().chars<131072,"expanded words impose an independent bound");
         DecodeCounter.calls=0;fresh.decode(loc,[c]);check(DecodeCounter.calls==1,"word-cap eviction does not return stale words");
         setup();c={x:0,y:0,v:1,d:raw(whitespace(700)+"[0,700]")};fresh.decode(loc,[c]);
         var sumChars:int=c.d.length;
         for(i=0;i<12;i++){var padded:Object={x:0,y:0,v:1,d:raw(whitespace(uint(i+701))+"[0,"+(i+701)+"]")};sumChars+=padded.d.length;fresh.decode(loc,[padded]);}
         check(sumChars>131072,"encoded-char fixture really exceeds cache character budget");bounded("encoded-char eviction obeys all bounds");
         check(fresh.cacheStats().entries<13 && fresh.cacheStats().words<32768,"encoded characters impose an independent bound");
         DecodeCounter.calls=0;fresh.decode(loc,[c]);check(DecodeCounter.calls==1,"character-cap eviction performs a real decode on reuse");
         setup();c={x:0,y:0,v:1,d:raw(whitespace(990,400000)+"[0,990]")};
         check(c.d.length>131072 && c.d.length<1000000,"single-entry fixture exceeds cache budget but respects original codec limit");
         pair([c],"oversized valid cache entry retains checkpoint decode semantics",false);
         pair([c],"oversized valid cache entry remains readable on repeat",false);
         check(DecodeCounter.calls==4 && fresh.cacheStats().entries==0,"oversized valid encoding is never retained or reused");

         setup();var roomOld:Object=grid(),roomNew:Object=grid();c=cell([0,0xff123456]);
         old.receive(roomOld,[c],false);fresh.receive(roomNew,[c],false);
         changed=cell([0,0xff654321],1);old.receive(roomOld,[changed],false);fresh.receive(roomNew,[changed],false);
         check(roomOld.grafon.frontBmp.getPixel32(0,0)==0xff123456 && roomNew.grafon.frontBmp.getPixel32(0,0)==0xff123456,"same-version changed data retains original version filtering");
         changed.v=2;old.receive(roomOld,[changed],false);fresh.receive(roomNew,[changed],false);
         check(roomOld.grafon.frontBmp.getPixel32(0,0)==0xff654321 && roomNew.grafon.frontBmp.getPixel32(0,0)==0xff654321,"new version paints exactly the new payload");
         var invalidTransaction:Array=[cell([0,0xffabcdef],3),{x:1,y:0,v:3,d:"%%%"}];
         old.receive(roomOld,invalidTransaction,false);fresh.receive(roomNew,invalidTransaction,false);
         check(roomOld.grafon.frontBmp.getPixel32(0,0)==0xff654321 && roomNew.grafon.frontBmp.getPixel32(0,0)==0xff654321,"invalid cell leaves the entire batch unapplied");
         fresh.reset();roomNew.grafon.frontBmp.setPixel32(0,0,0);fresh.receive(roomNew,[changed],false);
         check(roomNew.grafon.frontBmp.getPixel32(0,0)==0xff654321,"return to room after reset restores marks without stale incoming versions");
         old.reset();fresh.reset();roomOld.grafon.frontBmp.dispose();roomNew.grafon.frontBmp.dispose();

         setup();var source:WallBefore=new WallBefore(),room:Object=grid();c=cell([0,0xff102030]);source.receive(room,[c],false);
         var first:Array=source.snapshot(room),second:Array=source.snapshot(room);
         check(first.length==1 && second.length==1 && first[0]===second[0] && first[0].d===second[0].d,"unchanged native snapshot reuses exactly the same packed cell");
         var packet1:Object=BinaryMessageCodec.unpack(BinaryMessageCodec.pack({type:"unitsync",wallPaint:first}));
         var packet2:Object=BinaryMessageCodec.unpack(BinaryMessageCodec.pack({type:"unitsync",wallPaint:second}));
         check(packet1.wallPaint[0].d===packet2.wallPaint[0].d,"real binary codec preserves repeated snapshot payload equality");
         DecodeCounter.calls=0;pair(packet1.wallPaint,"first round-tripped snapshot decode equals baseline");pair(packet2.wallPaint,"repeated round-tripped snapshot decode equals baseline");
         check(DecodeCounter.calls==3,"two unchanged transmitted snapshots require old=2 candidate=1 unpack");
         source.reset();room.grafon.frontBmp.dispose();
      }
   }
}

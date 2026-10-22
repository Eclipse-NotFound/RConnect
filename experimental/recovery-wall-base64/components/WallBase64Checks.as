package {
   import flash.desktop.NativeApplication;
   import flash.display.BitmapData;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.utils.ByteArray;
   import flash.utils.getTimer;
   import fe.weapon.Bullet;
   import rconnect.game.WallBefore;
   import rconnect.game.WallAfter;
   import rconnect.net.RoomCodec;
   import rconnect.net.WallCellCodec;
   import rconnect.net.WallCellBefore;

   /** Real complete WallImpactVisuals classes, renamed plus test wrappers only.
    * Pixel inputs use BitmapData and a contact marker, not a loaded game. */
   public final class WallBase64Checks extends Sprite {
      private var rows:Array=[],failed:int=0,measurements:Object={},data:Object,natural:Array=[];
      private var phase:int=0,benchRows:Array=[],old:WallBefore,fresh:WallAfter;
      private var oldPayloads:Array=[],newPayloads:Array=[];
      private const DIGITS:String="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
      public function WallBase64Checks(){addEventListener(Event.ADDED_TO_STAGE,start);}
      private function check(ok:Boolean,label:String):void {
         rows.push({passed:ok,label:label});if(!ok)failed++;trace((ok?"PASS ":"FAIL ")+label);
      }
      private function equal(a:*,b:*):Boolean {return JSON.stringify(a)===JSON.stringify(b);}
      private function values(words:Array):Object {
         var v:Object={};for(var i:int=0;i<words.length;i+=2)v[String(words[i])]=words[i+1];return v;
      }
      private function cell(words:Array,revision:int=7,x:int=0,y:int=0):Object {
         return {x:x,y:y,v:revision,values:values(words),wire:null};
      }
      private function world(w:int=2,h:int=2):Object {
         var loc:Object={spaceX:w,spaceY:h,space:[],firstObj:null};
         for(var x:int=0;x<w;x++){loc.space[x]=[];for(var y:int=0;y<h;y++)loc.space[x][y]={phis:1,hp:100};}
         loc.grafon={loc:loc,frontBmp:new BitmapData(w*40,h*40,true,0)};return loc;
      }
      private function pixels(a:Object,b:Object):Boolean {
         var d:*=a.grafon.frontBmp.compare(b.grafon.frontBmp);
         if(d is BitmapData){d.dispose();return false;}return d===0;
      }
      private function decode(wall:Object,loc:Object,list:Array,limit:Boolean=true):Array {
         return wall.testCells(loc,list,limit);
      }
      private function start(e:Event):void {
         removeEventListener(Event.ADDED_TO_STAGE,start);
         try {
            var f:FileStream=new FileStream();f.open(File.applicationDirectory.resolvePath("src/natural-payloads.json"),FileMode.READ);
            data=JSON.parse(f.readUTFBytes(f.bytesAvailable));f.close();
            for each(var item:Object in data.payloads)natural.push(RoomCodec.unpack(item.data));
            old=new WallBefore();fresh=new WallAfter();
            naturalCases();cacheCases();negativeCases();pixelCases();transportCases();base64Cases();
            old.testDispose();fresh.testDispose();old=new WallBefore();fresh=new WallAfter();
            for each(var words:Array in natural) {
               oldPayloads.push(old.testPacked(cell(words)).d);newPayloads.push(fresh.testPacked(cell(words)).d);
            }
            // Two unmeasured full-corpus passes warm both code paths equally.
            measure(old,1);measure(fresh,1);measure(fresh,1);measure(old,1);
            addEventListener(Event.ENTER_FRAME,benchmark);
         }catch(error:Error){check(false,"uncaught preparation "+error.getStackTrace());finish();}
      }
      private function naturalCases():void {
         check(data.payloads.length==82 && data.missOrder.length==1276,"historical natural fixture is exactly 82 payloads/1276 observed decode misses");
         var legacy:Boolean=true,encoded:Boolean=true,isolated:Boolean=true,pixelEqual:Boolean=true;
         var oldChars:int=0,newChars:int=0,beforeInput:String=JSON.stringify(natural);
         for(var i:int=0;i<natural.length;i++) {
            var source:Array=natural[i],c:Object=cell(source),a:Object=old.testPacked(c),b:Object=fresh.testPacked(cell(source));
            var da:Array=old.testWords(a.d),db:Array=fresh.testWords(b.d),compat:Array=fresh.testWords(data.payloads[i].data);
            legacy=legacy&&equal(da,compat)&&equal(compat,source);
            encoded=encoded&&WallCellCodec.isCell(b.d)&&equal(db,source)&&a.x==b.x&&a.y==b.y&&a.v==b.v;
            oldChars+=a.d.length;newChars+=b.d.length;
            var ba:BitmapData=new BitmapData(40,40,true,0),bb:BitmapData=new BitmapData(40,40,true,0);
            for(var j:int=0;j<source.length;j+=2) {
               ba.setPixel32(int(da[j])%40,int(da[j])/40,uint(da[j+1]));
               bb.setPixel32(int(db[j])%40,int(db[j])/40,uint(db[j+1]));
            }
            var diff:*=ba.compare(bb);if(diff is BitmapData){pixelEqual=false;diff.dispose();}else if(diff!==0)pixelEqual=false;
            ba.dispose();bb.dispose();
            db[1]=123;db.push(1599,123);compat[1]=456;
            var again:Array=fresh.testWords(b.d);
            isolated=isolated&&again!==db&&equal(again,source)&&equal(fresh.testWords(data.payloads[i].data),source);
         }
         check(legacy,"candidate reads every original natural payload without value/order change");
         check(encoded,"new natural encoding preserves every offset/uint/envelope/version");
         check(pixelEqual,"all 82 natural 40x40 ARGB rasters compare pixel-exact");
         check(isolated,"new and legacy cache hits return independent arrays after caller mutation");
         check(JSON.stringify(natural)==beforeInput,"natural fixture arrays remain unchanged");
         measurements.natural={payloads:82,oldChars:oldChars,newChars:newChars,currentDensityDistribution:false};
         var replay:Boolean=true;
         for each(var event:Object in data.missOrder) {
            source=natural[int(event.payload)];b=fresh.testPacked(cell(source));
            if(!equal(fresh.testWords(b.d),source))replay=false;
         }
         check(replay,"exact historical 1276 observed order re-encodes without loss (not current encode frequency)");
      }
      private function cacheCases():void {
         var a:Object=cell([0,0,1599,4294967295]),b:Object=cell([0,0,1599,4294967295]);
         var p:Object=old.testPacked(a),q:Object=fresh.testPacked(b);
         check(old.testPacked(a)===p && fresh.testPacked(b)===q,"unchanged version returns same encoded cache object in both classes");
         a.values["1599"]=7;b.values["1599"]=7;a.v++;b.v++;a.wire=null;b.wire=null;
         var n:Object=fresh.testPacked(b);
         check(n!==q&&n.v==8&&equal(fresh.testWords(n.d),old.testWords(old.testPacked(a).d)),"real invalidation re-encodes changed values and revision");
         var unversioned:Object={x:0,y:0,values:{"0":4}};
         p=fresh.testPacked(unversioned);unversioned.values["0"]=5;q=fresh.testPacked(unversioned);
         check(p!==q&&p.d!==q.d&&equal(fresh.testWords(q.d),[0,5]),"queued cells without v never inherit a stale packed cache");
         p=fresh.testPacked(cell([],1));check(equal(fresh.testWords(p.d),[]),"empty sparse cell is exactly represented");
         var huge:Array=[];for(var i:int=0;i<1600;i++)huge.push(i,i%2?4294967295:0);
         p=fresh.testPacked(cell(huge));check(equal(fresh.testWords(p.d),huge),"full 1600 pixels preserve transparent and maximum uint boundaries");
         p=fresh.testPacked(cell([0,1],17,1,1));
         check(p.x==1&&p.y==1&&p.v==17,"cell coordinates and version stay outside pixel codec");
      }
      private function raw(indices:Array,colors:Array,count:int=-1,extra:Boolean=false):String {
         var b:ByteArray=new ByteArray();b.writeShort(count<0?indices.length:count);
         for(var i:int=0;i<indices.length;i++){b.writeShort(indices[i]);b.writeUnsignedInt(colors[i]);}
         if(extra)b.writeByte(1);b.compress();b.position=0;var out:Array=[];
         while(b.bytesAvailable) {
            var left:int=b.bytesAvailable,a:int=b.readUnsignedByte(),c:int=left>1?b.readUnsignedByte():0,d:int=left>2?b.readUnsignedByte():0;
            out.push(DIGITS.charAt(a>>2)+DIGITS.charAt(((a&3)<<4)|(c>>4))+(left>1?DIGITS.charAt(((c&15)<<2)|(d>>6)):"=")+(left>2?DIGITS.charAt(d&63):"="));
         }return WallCellCodec.PREFIX+out.join("");
      }
      private function rejected(text:String):Boolean {
         try{return fresh.testCells({spaceX:48,spaceY:25},[{x:0,y:0,v:1,d:text}])==null;}catch(error:Error){return true;}return false;
      }
      private function negativeCases():void {
         var bad:Array=["!W1:","!W1:%%%%","!W1:AA=A","!W1:AAAA=AAA",raw([0,0],[1,2]),raw([1,0],[1,2]),
            raw([1600],[1]),raw([0],[1],2),raw([0],[1],1601),raw([0],[1],-1,true),"!W1:"+new Array(13342).join("A")];
         var rejectedAll:Boolean=true;for each(var s:String in bad)if(!rejected(s))rejectedAll=false;
         check(rejectedAll,"malformed base64/padding/order/count/offset/trailing/size binary inputs are rejected before paint");
         var badLegacy:Array=[[0],[-1,1],[1600,1],[0,1,0,2],[1,1,0,2],[0,-1],[0,4294967296],[0,1.5]];
         var same:Boolean=true;for each(var words:Array in badLegacy) {
            s=RoomCodec.pack(words);
            if(old.testCells({spaceX:48,spaceY:25},[{x:0,y:0,d:s}])!=null || !rejected(s))same=false;
         }
         check(same,"legacy malformed numeric payload rejection remains unchanged");
         var unusual:Array=[["0","12"],[[0],[12]],[false,true]],preserved:Boolean=true;
         for each(words in unusual) {
            s=RoomCodec.pack(words);if(!equal(old.testWords(s),fresh.testWords(s)))preserved=false;
         }
         check(preserved,"legacy unusual Number coercion and returned types remain unchanged");
         s=fresh.testPacked(cell([0,1])).d;var loc:Object={spaceX:48,spaceY:25};
         check(fresh.testCells(loc,[{x:0,y:0,d:s},{x:0,y:0,d:s}])==null,"duplicate cell coordinates remain rejected");
         check(fresh.testCells(loc,[{x:48,y:0,d:s}])==null&&fresh.testCells(loc,[{x:0,y:25,d:s}])==null&&
               fresh.testCells(loc,[{x:.5,y:0,d:s}])==null,"native map/bitmap/fractional coordinate bounds remain enforced");
         var tooMany:Array=[];for(var i:int=0;i<65;i++)tooMany.push({x:i%48,y:int(i/48),d:s});
         check(fresh.testCells(loc,tooMany)==null,"network maximum remains 64 cells");
         var oversized:String="!W1:"+new Array(48001).join("A");
         check(fresh.testCells(loc,[{x:0,y:0,d:oversized}])==null,"network maximum remains 48000 text characters");
      }
      private function pixelCases():void {
         var walls:Array=[new WallBefore(),new WallAfter()],locs:Array=[world(),world()],reports:Array=[];
         var p:Array=[],i:int;
         for(i=0;i<2;i++) {
            var w:Object=walls[i],loc:Object=locs[i];w.before(loc);
            loc.grafon.frontBmp.setPixel32(20,20,0xffaa00aa);loc.space[0][0].hp--;
            var bullet:Bullet=new Bullet();bullet.loc=loc;bullet.X=20;bullet.Y=20;bullet.tilehit=true;loc.firstObj=bullet;
            reports.push(w.report(loc));p.push(w.snapshot(loc,false));
         }
         check(reports[0]!=null&&reports[1]!=null&&reports[0].seq==reports[1].seq,
               "actual BitmapData/contact observation creates pending reports in both full classes");
         check(equal(decode(walls[0],locs[0],reports[0].cells),decode(walls[1],locs[1],reports[1].cells)),
               "report semantic pixels and versions match despite different encoded bytes");
         var cachedA:Object=p[0][0],cachedB:Object=p[1][0];
         check(walls[0].snapshot(locs[0],false)[0]===cachedA&&walls[1].snapshot(locs[1],false)[0]===cachedB,
               "unchanged real snapshots reuse encoded cache objects");
         var authoritative:Array=[{x:0,y:0,v:99,d:RoomCodec.pack([820,0xff00bb00,821,0xff123456])}];
         for(i=0;i<2;i++)walls[i].receive(locs[i],authoritative,true);
         check(pixels(locs[0],locs[1])&&locs[1].grafon.frontBmp.getPixel32(20,20)==0xffaa00aa&&
               locs[1].grafon.frontBmp.getPixel32(21,20)==0xff123456,"pending local pixels protected while disjoint authoritative pixels merge");
         var beforeAck:Array=walls[1].snapshot(locs[1],false);
         walls[1].acknowledge(locs[1],{seq:reports[1].seq+1,cells:reports[1].cells});
         check(walls[1].testState(locs[1]).pending!=null,"wrong ACK sequence cannot release prediction protection");
         for(i=0;i<2;i++){walls[i].acknowledge(locs[i],reports[i]);walls[i].receive(locs[i],authoritative,true);}
         check(pixels(locs[0],locs[1])&&locs[1].grafon.frontBmp.getPixel32(20,20)==0xff00bb00,
               "valid ACK releases prediction and permits same authoritative revision after skip");
         check(walls[1].testState(locs[1]).pending==null&&walls[1].snapshot(locs[1],false)[0]!==beforeAck[0],
               "changed authoritative pixel invalidates only that encoded revision");
         var damage:Array=[{x:0,y:0,v:1,d:RoomCodec.pack([820,1])}];
         for(i=0;i<2;i++)walls[i].receive(locs[i],damage,false);
         check(pixels(locs[0],locs[1])&&locs[1].grafon.frontBmp.getPixel32(20,20)==0xff00bb00,"old revisions cannot overwrite pixels after ACK");
         var red:String=fresh.testPacked(cell([0,0xffff0000],100)).d;
         walls[1].receive(locs[1],[{x:0,y:0,v:100,d:red},{x:1,y:0,v:100,d:"!W1:%%%%"}],false);
         check(locs[1].grafon.frontBmp.getPixel32(0,0)==0,"invalid second cell rejects complete batch before first pixel paint");
         for(i=0;i<2;i++) {
            loc=locs[i];w=walls[i];loc.space[0][0].phis=0;loc.grafon.frontBmp.fillRect(loc.grafon.frontBmp.rect,0);
            w.redraw(loc);
         }
         check(pixels(locs[0],locs[1])&&walls[0].snapshot(locs[0],false)==null&&walls[1].snapshot(locs[1],false)==null,
               "destroyed walls discard old coatings without filling removed pixels");
         for(i=0;i<2;i++){walls[i].testDispose();locs[i].grafon.frontBmp.dispose();}
      }
      private function randomWords(seed:uint):Array {
         var words:Array=[],n:uint=seed;
         for(var i:int=0;i<1600;i++){n^=n<<13;n^=n>>>17;n^=n<<5;words.push(i,Number(n));}return words;
      }
      private function transportCases():void {
         var walls:Array=[new WallBefore(),new WallAfter()],outcomes:Array=[];
         for(var side:int=0;side<2;side++) {
            var w:Object=walls[side],loc:Object=world(12,6),source:Array=[],i:int;
            for(i=0;i<70;i++)source.push({x:i%12,y:int(i/12),v:i+1,d:RoomCodec.pack([0,i+1])});
            w.restore(loc,source);
            var first:Array=w.updates(loc),again:Array=w.updates(loc);
            check(first.length==64&&again.length==64&&first[0]===again[0],"side "+side+" read-only updates preserve unsent batch and 64-cell limit");
            w.sentUpdates(loc,first);var second:Array=w.updates(loc);w.sentUpdates(loc,second);
            check(second.length==6&&w.updates(loc)==null,"side "+side+" actual sent cursor drains remaining cells without loss");
            var one:Array=w.snapshot(loc,false),two:Array=w.snapshot(loc,false),seen:Object={},count:int=0;
            for each(var c:Object in one.concat(two))seen[c.x+","+c.y]=true;
            for(var k:String in seen)count++;
            check(one.length==64&&two.length==64&&count==70,"side "+side+" cumulative snapshot rotation covers all 70 cells");
            w.roleChanged(loc);check(w.updates(loc).length==64,"side "+side+" ownership change reopens transport cursors without dropping paint");
            var restored:Object=world(12,6),copy:Object=side==0?new WallBefore():new WallAfter();
            copy.restore(restored,w.checkpoint(loc));
            check(pixels(loc,restored),"side "+side+" checkpoint restore/redraw preserves every actual pixel");
            copy.testDispose();restored.grafon.frontBmp.dispose();w.testDispose();loc.grafon.frontBmp.dispose();
         }
         walls=[new WallBefore(),new WallAfter()];var sizes:Array=[];
         for(side=0;side<2;side++) {
            w=walls[side];loc=world(6,1);source=[];
            for(i=0;i<6;i++)source.push({x:i,y:0,v:i+1,d:RoomCodec.pack(randomWords(i+13))});
            w.restore(loc,source);var got:Object={},all:int=0,batches:int=0,valid:Boolean=true;
            while((first=w.updates(loc))!=null&&batches<8) {
               var chars:int=0;for each(c in first){chars+=c.d.length;got[c.x+","+c.y]=true;}
               valid=valid&&chars<=48000&&first.length<=64&&w.testCells(loc,first)!=null;
               w.sentUpdates(loc,first);sizes.push({side:side,batch:batches,chars:chars,cells:first.length});batches++;
            }
            for(k in got)all++;
            check(valid&&all==6&&batches>1&&w.updates(loc)==null,"side "+side+" dense batch splits respect 48k and preserve all six cells");
            var owner:Object=side==0?new WallBefore():new WallAfter(),destination:Object=world(6,1);
            first=w.snapshot(loc,false);var request:Object={seq:1,cells:first},receipt:Object=owner.settle(destination,"peer",request);
            check(receipt!=null&&receipt.seq==1&&owner.settle(destination,"peer",request)===receipt,
                  "side "+side+" accepted wire batch has idempotent exact ACK receipt");
            check(owner.settle(destination,"peer",{seq:0,cells:first})==null,
                  "side "+side+" invalid sequence cannot alter settled receipt");
            owner.testDispose();destination.grafon.frontBmp.dispose();w.testDispose();loc.grafon.frontBmp.dispose();
         }
         measurements.batchSizes=sizes;
      }
      /** Extra checks use the complete old/new WallCellCodec classes. */
      private function packedBytes(v:Object):ByteArray {
         var keys:Array=[];for(var k:String in v)keys.push(int(k));keys.sort(Array.NUMERIC);
         var bytes:ByteArray=new ByteArray();bytes.writeShort(keys.length);
         for each(var index:int in keys){bytes.writeShort(index);bytes.writeUnsignedInt(uint(v[String(index)]));}
         bytes.compress();bytes.position=0;return bytes;
      }
      private function outcome(v:Object,newer:Boolean):String {
         try{return "ok:"+(newer?WallCellCodec.pack(v):WallCellBefore.pack(v));}
         catch(error:Error){return "throw:"+error.name+":"+error.message;}
         return "unreachable";
      }
      private function base64Cases():void {
         var allBytes:Boolean=true,allPixels:Boolean=true,wireSame:Boolean=true;
         var i:int,j:int,v:Object,a:String,b:String,words:Array;
         for each(words in natural) {
            v=values(words);a=WallCellBefore.pack(v);b=WallCellCodec.pack(v);
            allBytes=allBytes&&a===b;
            allPixels=allPixels&&equal(WallCellBefore.unpack(b),words)&&equal(WallCellCodec.unpack(a),words);
            wireSame=wireSame&&equal(old.testPacked(cell(words)),fresh.testPacked(cell(words)));
         }
         check(allBytes,"all 82 natural encoded strings are character-for-character identical");
         check(allPixels,"both complete codecs read each other's exact natural bytes");
         check(wireSame,"full WallImpactVisuals envelopes are byte-identical on all 82 natural cells");
         var reverse:Object={};for(i=natural[0].length-2;i>=0;i-=2)reverse[String(natural[0][i])]=natural[0][i+1];
         check(WallCellCodec.pack(reverse)===WallCellBefore.pack(values(natural[0])),"property insertion order still sorts to exactly the same wire bytes");
         var seen:Array=[false,false,false],compressedAlphabet:Array=[],pads:Boolean=true,exactLength:Boolean=true;
         var random:uint=0x51efabcd,deterministic:Boolean=true,ascii:Boolean=true;
         for(var sample:int=0;sample<128;sample++) {
            v={};var count:int=sample==0?0:(sample==127?1600:(sample*37)%1600);
            for(i=0;i<count;i++){random^=random<<13;random^=random>>>17;random^=random<<5;v[String((i*83)%1600)]=Number(random);}
            var bytes:ByteArray=packedBytes(v),r:int=bytes.length%3;
            seen[r]=true;while(bytes.bytesAvailable)compressedAlphabet[bytes.readUnsignedByte()]=true;
            a=WallCellBefore.pack(v);b=WallCellCodec.pack(v);deterministic=deterministic&&a===b;
            pads=pads&&(r==0?b.charAt(b.length-1)!="=":r==1?b.substr(b.length-2)=="==":b.charAt(b.length-1)=="="&&b.charAt(b.length-2)!="=");
            exactLength=exactLength&&b.length==4+int((bytes.length+2)/3)*4;
            for(j=4;j<b.length;j++)if(b.charAt(j)!="="&&DIGITS.indexOf(b.charAt(j))<0)ascii=false;
         }
         check(deterministic,"128 deterministic empty/sparse/full maps produce exact old/new wire bytes");
         check(seen[0]&&seen[1]&&seen[2],"native compressed lengths actually exercise all three Base64 remainders");
         check(pads,"zero/one/two byte tail padding is exact for every observed compressed remainder");
         check(exactLength&&ascii,"ASCII output has exact bounded length and contains no unwritten zeros or extra bytes");
         var covered:int=0;for(i=0;i<256;i++)if(compressedAlphabet[i])covered++;
         check(covered==256,"compressed fixture bytes exercise every unsigned input value including high bits");
         var boundary:Object={"0":0,"1599":4294967295};
         check(WallCellCodec.pack(boundary)===WallCellBefore.pack(boundary)&&equal(WallCellCodec.unpack(WallCellCodec.pack(boundary)),[0,0,1599,4294967295]),
            "transparent/maximum uint and both offset endpoints retain exact bytes");
         var badKeys:Array=["", "-1","1600","01","+1","1.0","1e0","-0","NaN","Infinity","1.5"];
         var rejects:Boolean=true;
         for each(var key:String in badKeys){v={};v[key]=1;a=outcome(v,false);b=outcome(v,true);if(a!==b||a.indexOf("throw:")!=0)rejects=false;}
         check(rejects,"noncanonical/out-of-range indices reject with unchanged error type/message");
         var badColors:Array=[-1,4294967296,1.5,NaN,Infinity,-Infinity,undefined,{},[1,2]];
         rejects=true;for each(var color:* in badColors){v={"0":color};a=outcome(v,false);b=outcome(v,true);if(a!==b||a.indexOf("throw:")!=0)rejects=false;}
         check(rejects,"invalid numeric colors reject before encoding with unchanged error type/message");
         var coercions:Array=[0,4294967295,"12",[12],true,false,null],coercionSame:Boolean=true;
         for each(color in coercions){v={"0":color};a=outcome(v,false);b=outcome(v,true);if(a!==b||a.indexOf("ok:")!=0)coercionSame=false;}
         check(coercionSame,"existing valid Number coercion stays byte-identical");
         var input:Object={"0":7,"1599":9},saved:String=JSON.stringify(input);
         for(i=0;i<4;i++){WallCellBefore.pack(input);WallCellCodec.pack(input);}
         check(JSON.stringify(input)===saved,"repeated pack does not mutate caller input");
         measurements.byteEquivalence={natural:82,deterministic:128,compressedRemainders:seen,unsignedByteCoverage:covered,
            formatUnchanged:true,receivedValidationUnchanged:true,benchmarkScope:"full production packed including validation/sort/zlib/Base64"};
      }

      private function measure(wall:Object,repetitions:int):Object {
         var cells:Array=[];
         for each(var words:Array in natural)cells.push(cell(words));
         var begin:int=getTimer(),sum:uint=0,chars:int=0;
         for(var n:int=0;n<repetitions;n++)for each(var c:Object in cells) {
            c.wire=null;var p:Object=wall.testPacked(c);chars+=p.d.length;sum+=p.d.charCodeAt(p.d.length-1)+p.v;
         }
         return {ms:getTimer()-begin,calls:cells.length*repetitions,chars:chars,checksum:sum};
      }
      private function benchmark(e:Event):void {
         try {
            // Per-round ABBA: equivalent corpus/order/work, full production
            // packed() including sort/cache lookup; no JSON/file work in timing.
            var order:Array=["old","new","new","old"],side:String=order[phase%4];
            var wall:Object=side=="old"?old:fresh;
            var row:Object=measure(wall,3);row.side=side;row.block=phase;
            row.coldDecode=decodeMeasure(wall,side=="old"?oldPayloads:newPayloads,3);
            benchRows.push(row);phase++;
            if(phase<24)return;
            measurements.abba={blocks:benchRows,rounds:6,repetitions:3,naturalPayloads:82,
                forcedUncached:true,includesNumericSort:true,includesKeyColorValidation:true,includesZlib:true,includesWallEnvelope:true,base64OnlyTiming:false,sourceWasDecodeMissTrace:true,currentDenseFrequency:false};
            var nonempty:Boolean=benchRows.length==24;for each(var r:Object in benchRows)
               if(r.calls!=246||r.chars<=0||r.checksum==0||r.coldDecode.calls!=246||r.coldDecode.words<=0)nonempty=false;
            check(nonempty,"ABBA measures 24 nonempty equal-work 246-encode blocks");
            var stable:Boolean=true,sameDecode:Boolean=true;
            for each(r in benchRows) {
               stable=stable&&r.chars==benchRows[0].chars&&r.checksum==benchRows[0].checksum;
               sameDecode=sameDecode&&r.coldDecode.words==benchRows[0].coldDecode.words&&r.coldDecode.checksum==benchRows[0].coldDecode.checksum;
            }
            check(stable,"all 24 old/new ABBA outputs have identical characters/checksums independent of order");
            check(sameDecode,"all 24 cold decode blocks consume identical complete pixel words");
            finish();
         }catch(error:Error){check(false,"uncaught benchmark "+error.getStackTrace());finish();}
      }
      private function decodeMeasure(wall:Object,texts:Array,repetitions:int):Object {
         var ms:int=0,count:int=0,wordsTotal:int=0,checksum:uint=0;
         for(var n:int=0;n<repetitions;n++) {
            // Reset only the retained read cache before each timed corpus pass.
            // Public reset is outside measured time on both complete classes.
            wall.reset();var start:int=getTimer();
            for each(var text:String in texts) {
               var words:Array=wall.testWords(text);wordsTotal+=words.length;count++;
               for(var i:int=0;i<words.length;i++)checksum+=uint(words[i]);
            }
            ms+=getTimer()-start;
         }
         return {ms:ms,calls:count,words:wordsTotal,checksum:checksum,resetOutsideTiming:true};
      }
      private function finish():void {
         removeEventListener(Event.ENTER_FRAME,benchmark);
         if(old!=null)old.testDispose();if(fresh!=null)fresh.testDispose();
         var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         f.writeUTFBytes(JSON.stringify({passed:failed==0,failed:failed,assertions:rows,measurements:measurements,
            native_game_test:false,performance_qualified:false,net_gain_qualified:false}));f.close();
         NativeApplication.nativeApplication.exit(failed?1:0);
      }
   }
}

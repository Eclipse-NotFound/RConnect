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
   import rconnect.game.WallCodecOnly;
   import rconnect.game.WallVerifyOnly;
   import rconnect.net.WallCellBefore;
   import rconnect.net.RoomCodec;
   import rconnect.net.WallCellCodec;

   /** Real complete WallImpactVisuals classes, renamed plus test wrappers only.
    * Pixel inputs use BitmapData and a contact marker, not a loaded game. */
   public final class WallDecodeChecks extends Sprite {
      private var rows:Array=[],failed:int=0,measurements:Object={},data:Object,natural:Array=[];
      private var phase:int=0,benchRows:Array=[],old:WallBefore,fresh:WallAfter;
      private var oldPayloads:Array=[],newPayloads:Array=[];
      private var codecOnly:WallCodecOnly,verifyOnly:WallVerifyOnly,corpora:Array=[];
      private const DIGITS:String="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
      public function WallDecodeChecks(){addEventListener(Event.ADDED_TO_STAGE,start);}
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
            naturalCases();cacheCases();negativeCases();pixelCases();transportCases();decodeCases();
            old.testDispose();fresh.testDispose();old=new WallBefore();fresh=new WallAfter();
            for each(var words:Array in natural) {
               oldPayloads.push(old.testPacked(cell(words)).d);newPayloads.push(fresh.testPacked(cell(words)).d);
            }
            codecOnly=new WallCodecOnly();verifyOnly=new WallVerifyOnly();prepareCorpora();
            // Equal unmeasured warm-up. Cache reset happens outside each timed batch.
            for each(var warm:Object in [old,codecOnly,fresh,verifyOnly,verifyOnly,fresh,codecOnly,old])
               completeDecode(warm,corpora[4],1);
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
      private function binaryOutcome(s:String,after:Boolean):Object {
         try {return {words:after?WallCellCodec.unpack(s):WallCellBefore.unpack(s)};}
         catch(e:Error){return {errorID:e.errorID,name:e.name,message:e.message};}
         return null;
      }
      private function outcomesAgree(texts:Array,requireRejected:Boolean=true):Boolean {
         for each(var s:String in texts) {
            var a:Object=binaryOutcome(s,false),b:Object=binaryOutcome(s,true);
            if(!equal(a,b)||(requireRejected&&a.words!=null))return false;
         }
         return true;
      }
      private function encodeBytes(b:ByteArray):String {
         b.position=0;var out:Array=[];
         while(b.bytesAvailable) {
            var left:int=b.bytesAvailable,a:int=b.readUnsignedByte();
            var c:int=left>1?b.readUnsignedByte():0,d:int=left>2?b.readUnsignedByte():0;
            out.push(DIGITS.charAt(a>>2)+DIGITS.charAt(((a&3)<<4)|(c>>4))+
               (left>1?DIGITS.charAt(((c&15)<<2)|(d>>6)):"=")+(left>2?DIGITS.charAt(d&63):"="));
         }
         return "!W1:"+out.join("");
      }
      private function decodeCases():void {
         var i:int,j:int,s:String,a:Array,b:Array,ok:Boolean=true,paddings:Object={};
         var variants:Array=[new WallBefore(),new WallCodecOnly(),new WallVerifyOnly(),new WallAfter()];
         var source:Array=[],seed:uint=1117;
         for(i=0;i<96;i++) {
            var count:int=i==95?1600:(i*19)%1601;source=randomWords(uint(i+1)).slice(0,count*2);
            s=WallCellBefore.pack(values(source));a=WallCellBefore.unpack(s);b=WallCellCodec.unpack(s);
            ok=ok&&s===WallCellCodec.pack(values(source))&&equal(source,a)&&equal(a,b);
            paddings[s.charAt(s.length-1)=="="?(s.charAt(s.length-2)=="="?2:1):0]=true;
            for each(var wall:Object in variants)ok=ok&&equal(wall.testWords(s),source);
         }
         check(ok,"96 deterministic empty through full cells decode identically in all four complete variants; encoder bytes unchanged");
         check(paddings[0]&&paddings[1]&&paddings[2],"valid native zlib payloads exercise zero, one and two Base64 padding characters");
         check(outcomesAgree([null,"","AA==","!W0:AA==","!W1:","!W1:A","!W1:AA","!W1:AAA"]),
            "null, prefix and quartet length rejection order is unchanged");
         var bad:Array=["!W1:=AAA","!W1:A=AA","!W1:AA=A","!W1:====","!W1:AA==AAAA","!W1:AAA=AAAA","!W1:AAAA===="];
         for(i=1;i<16;i++)bad.push("!W1:A"+DIGITS.charAt(i)+"==");
         for(i=1;i<4;i++)bad.push("!W1:AA"+DIGITS.charAt(i)+"=");
         check(outcomesAgree(bad),"misplaced/interior padding and all noncanonical low pad bits retain exact rejection");
         bad=[];s=WallCellCodec.pack({"0":4294967295});
         for each(var code:int in [0,9,10,13,32,33,45,46,58,64,91,96,123,127,128,255,256,1024,0xd800,0xdc00,0xff0b,0xffff])
            for(j=0;j<4;j++)bad.push(s.substr(0,4+j)+String.fromCharCode(code)+s.substr(5+j));
         check(outcomesAgree(bad),"invalid ASCII and non-ASCII UTF-16 code units in each quartet position cannot alias lookup entries");
         bad=[];for(i=4;i<s.length;i++)bad.push(s.substr(0,i));
         bad.push(s+"AAAA",s+"\n",s+"\u0000");
         check(outcomesAgree(bad),"every truncation of a valid small cell and trailing text remains rejected");
         bad=[raw([0,0],[1,2]),raw([1,0],[1,2]),raw([1600],[1]),raw([65535],[1]),raw([0],[1],0),
            raw([0],[1],2),raw([0],[1],1601),raw([0],[1],-1,true)];
         check(outcomesAgree(bad),"duplicate/descending/out-of-range offsets, count mismatch and raw trailing bytes remain rejected");
         var bytes:ByteArray=new ByteArray();bytes.compress();bad=[encodeBytes(bytes)];
         bytes=new ByteArray();bytes.writeByte(0);bytes.compress();bad.push(encodeBytes(bytes));
         check(outcomesAgree(bad),"inflated data shorter than the two-byte header remains rejected");
         bytes=new ByteArray();bytes.length=131072;bytes.compress();s=encodeBytes(bytes);
         check(s.length<13340&&outcomesAgree([s]),"bounded compressed expansion past MAX_RAW is rejected before any pixel or ACK operation");
         bad=[];for each(count in [9999,10000,10001,10002,10003]) {
            bytes=new ByteArray();bytes.length=count;bad.push(encodeBytes(bytes));
         }
         check(outcomesAgree(bad),"compressed-size and text-size boundaries preserve return-versus-native-inflate-error behavior");
         check(outcomesAgree(["!W1:AAAA","!W1:AA==","!W1:AAA=","!W1:"+new Array(13338).join("A")]),
            "canonical but invalid zlib streams and over-limit text keep exact codec failure outcome");
         // Real legacy arrays retain original coercion/type and cache policy.
         var unusual:Array=[["0","12"],[[0],[12]],[false,true],[null,null],[0,"4294967295"]];ok=true;
         for each(a in unusual) {
            s=RoomCodec.pack(a);var reference:Array=variants[0].testWords(s);
            for each(wall in variants)ok=ok&&equal(reference,wall.testWords(s));
         }
         check(ok,"all four whole classes retain legacy Number coercion and nested returned types");
         ok=true;s=RoomCodec.pack([[0],[12]]);
         for each(wall in variants) {
            a=wall.testWords(s);a[0][0]=77;a[1][0]=88;
            ok=ok&&equal(wall.testWords(s),[[0],[12]]);
         }
         check(ok,"legacy nested arrays are still decoded afresh rather than retained in the numeric cache");
         ok=true;s=WallCellCodec.pack({"0":0,"1599":4294967295});
         for each(wall in variants) {
            a=wall.testWords(s);a[1]=17;a.push(2,2);b=wall.testWords(s);
            ok=ok&&a!==b&&equal(b,[0,0,1599,4294967295]);b[3]=0;
            ok=ok&&equal(wall.testWords(s),[0,0,1599,4294967295]);
         }
         check(ok,"both cold and repeated W1 returns remain isolated from caller mutations in every variant");
         ok=true;var loc:Object={spaceX:48,spaceY:25};
         for each(wall in variants) {
            var badLegacy:String=RoomCodec.pack([0,-1]);
            ok=ok&&wall.testCells(loc,[{x:0,y:0,v:1,d:s},{x:1,y:0,v:1,d:badLegacy}])==null;
         }
         check(ok,"mixed new/legacy invalid second cell rejects the whole batch in every variant");
         // The old-version test still decodes/validates the whole packet first.
         ok=true;
         for each(wall in variants) {
            var target:Object=world();wall.receive(target,[{x:0,y:0,v:9,d:WallCellCodec.pack({"0":0xff123456})}],false);
            wall.receive(target,[{x:0,y:0,v:1,d:"!W1:%%%%"},{x:1,y:0,v:10,d:WallCellCodec.pack({"0":0xffabcdef})}],false);
            ok=ok&&target.grafon.frontBmp.getPixel32(0,0)==0xff123456&&target.grafon.frontBmp.getPixel32(40,0)==0;
            target.grafon.frontBmp.dispose();
         }
         check(ok,"invalid stale first cell still rejects a valid newer second cell before painting (no version-first bypass)");
         ok=true;
         for each(wall in variants) {
            wall.reset();target=world();wall.before(target);target.grafon.frontBmp.setPixel32(20,20,0xff778899);target.space[0][0].hp--;
            var bullet:Bullet=new Bullet();bullet.loc=target;bullet.X=20;bullet.Y=20;bullet.tilehit=true;target.firstObj=bullet;
            var request:Object=wall.report(target),pending:Object=wall.testState(target).pending;
            wall.acknowledge(target,{seq:request.seq,cells:[{x:0,y:0,v:1,d:"!W1:%%%%"}]});
            ok=ok&&wall.testState(target).pending===pending&&target.grafon.frontBmp.getPixel32(20,20)==0xff778899;
            wall.acknowledge(target,request);ok=ok&&wall.testState(target).pending==null;
            target.grafon.frontBmp.dispose();
         }
         check(ok,"matching-sequence malformed ACK cannot release prediction; original valid ACK still releases it in all four classes");
         for each(wall in variants)wall.testDispose();
      }

      private function corpus(name:String,texts:Array,repetitions:int):Object {
         var batches:Array=[],current:Array=[],chars:int=0,total:int=0;
         for(var i:int=0;i<texts.length;i++) {
            var s:String=texts[i];
            if(current.length&&(current.length==64||chars+s.length>48000)) {batches.push(current);current=[];chars=0;}
            current.push({x:i%48,y:int(i/48),v:i+1,d:s});chars+=s.length;total+=s.length;
         }
         if(current.length)batches.push(current);
         return {name:name,texts:texts,batches:batches,repetitions:repetitions,chars:total};
      }
      private function prepareCorpora():void {
         var empty:Array=[],sparse:Array=[],large5:Array=[],large6:Array=[],legacy:Array=[];
         for(var i:int=0;i<6;i++) {
            empty.push(WallCellCodec.pack({}));
            sparse.push(WallCellCodec.pack(values(randomWords(i+91).slice(0,32))));
            large6.push(WallCellCodec.pack(values(randomWords(i+121).slice(0,2000))));
            if(i<5)large5.push(WallCellCodec.pack(values(randomWords(i+151).slice(0,2400))));
         }
         for each(var item:Object in data.payloads)legacy.push(item.data);
         corpora=[corpus("empty6",empty,8),corpus("sparse6_16pixels",sparse,8),
            corpus("full1600",[WallCellCodec.pack(values(randomWords(211)))],8),
            corpus("large5_1200pixels_each",large5,8),corpus("large6_1000pixels_each",large6,8),
            corpus("historical82_W1",newPayloads,3),corpus("historical82_legacy",legacy,3)];
         measurements.corpora=[];
         for each(var c:Object in corpora) {
            var counts:Array=[];for each(var batch:Array in c.batches) {
               var size:int=0;for each(var entry:Object in batch)size+=entry.d.length;
               counts.push({cells:batch.length,chars:size});
            }
            measurements.corpora.push({name:c.name,cells:c.texts.length,chars:c.chars,batches:counts,repetitions:c.repetitions});
         }
         check(corpora[3].batches.length==1&&corpora[4].batches.length==1&&corpora[3].chars>=40000&&corpora[4].chars>=40000,
            "five/six-cell representative packets stay within 48k while spanning actual 40k-plus wall-text scale");
      }
      private function completeDecode(wall:Object,c:Object,repetitions:int):Object {
         var ms:int=0,calls:int=0,cells:int=0,words:int=0,checksum:uint=0;
         for(var r:int=0;r<repetitions;r++)for each(var batch:Array in c.batches) {
            wall.reset(); // Cache clearing and state cleanup excluded identically.
            var begin:int=getTimer(),decoded:Array=wall.testCells({spaceX:48,spaceY:25},batch);
            ms+=getTimer()-begin;
            if(decoded==null||decoded.length!=batch.length)throw new Error("Benchmark rejected "+c.name);
            calls++;cells+=decoded.length;
            // Exact result consumption/checksum is outside the measured decode.
            for each(var cellResult:Object in decoded) {
               words+=cellResult.words.length;
               for(var j:int=0;j<cellResult.words.length;j++)checksum+=uint(cellResult.words[j]);
            }
         }
         return {ms:ms,calls:calls,cells:cells,words:words,checksum:checksum};
      }
      private function benchmark(e:Event):void {
         try {
            // Three independent comparisons, each two ABBA rounds. The one
            // complete-class baseline is compared with each isolated subitem
            // and with their combination; no pack/JSON/PNG/disk work is timed.
            var pair:int=int(phase/8),order:Array=[false,true,true,false],candidate:Boolean=order[phase%4];
            var wall:Object=candidate?([codecOnly,verifyOnly,fresh][pair]):old;
            var name:String=["ascii_and_word_write","validated_W1_only","combined"][pair];
            var results:Array=[];
            for each(var c:Object in corpora) {
               var result:Object=completeDecode(wall,c,c.repetitions);result.corpus=c.name;results.push(result);
            }
            benchRows.push({pair:name,block:phase%8,side:candidate?"candidate":"control",corpora:results});phase++;
            if(phase<24)return;
            measurements.abba={blocks:benchRows,roundsPerPair:2,pairs:3,forcedColdCache:true,cacheResetOutsideTiming:true,
               includesEnvelopeValidation:true,includesBase64:true,includesZlib:true,includesNumericValidation:true,
               includesCacheInsertion:true,checksumOutsideTiming:true,syntheticLargePackets:true,currentPayloadBytesCaptured:false};
            var complete:Boolean=benchRows.length==24,equalWork:Boolean=true,legacySame:Boolean=true;
            for(var p:int=0;p<3;p++)for(var k:int=0;k<8;k++)for(var n:int=0;n<corpora.length;n++) {
               var base:Object=benchRows[p*8].corpora[n],row:Object=benchRows[p*8+k].corpora[n];
               complete=complete&&row.calls>0&&row.cells>0&&row.ms>=0;
               var same:Boolean=row.calls==base.calls&&row.cells==base.cells&&row.words==base.words&&row.checksum==base.checksum;
               equalWork=equalWork&&same;if(n==6)legacySame=legacySame&&same;
            }
            check(complete,"24 full-decode ABBA blocks contain all seven bounded corpora; zero-ms small cases are reported without fabricated precision");
            check(equalWork,"every ABBA block consumes identical complete words and checksums across independent subitems and their combination");
            check(legacySame,"legacy complete-decode workload and result remain identical in all three ABBA comparisons");
            finish();
         }catch(error:Error){check(false,"uncaught benchmark "+error.getStackTrace());finish();}
      }

      private function finish():void {
         removeEventListener(Event.ENTER_FRAME,benchmark);
         if(old!=null)old.testDispose();if(fresh!=null)fresh.testDispose();
         if(codecOnly!=null)codecOnly.testDispose();if(verifyOnly!=null)verifyOnly.testDispose();
         var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         f.writeUTFBytes(JSON.stringify({passed:failed==0,failed:failed,assertions:rows,measurements:measurements,
            native_game_test:false,performance_qualified:false,net_gain_qualified:false}));f.close();
         NativeApplication.nativeApplication.exit(failed?1:0);
      }
   }
}

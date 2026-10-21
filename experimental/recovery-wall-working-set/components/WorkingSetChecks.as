package {
   import flash.desktop.NativeApplication;
   import flash.display.BitmapData;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.utils.ByteArray;
   import flash.utils.getQualifiedClassName;
   import fe.weapon.Bullet;
   import rconnect.core.Log;
   import rconnect.game.WallBefore;
   import rconnect.game.WallAfter;
   import rconnect.net.RoomCodec;
   import rconnect.net.WorkingSetCounter;

   /** Full frozen production classes with test access wrappers. No native game,
    * no replacement codec, no predicted decode counts and no timing acceptance. */
   public class WorkingSetChecks extends Sprite {
      [Embed(source="../data/flight-payloads.json",mimeType="application/octet-stream")]
      private static const TraceData:Class;
      private var checks:Array=[],failed:int=0,measurements:Object={};
      public function WorkingSetChecks(){addEventListener(Event.ADDED_TO_STAGE,start);}
      private function check(ok:Boolean,label:String):void {
         checks.push({passed:ok,label:label});if(!ok)failed++;
         trace((ok?"PASS ":"FAIL ")+label);
      }
      private function equal(a:*,b:*):Boolean {
         if(a===b)return true;
         if(a==null || b==null || typeof a!=typeof b || typeof a!="object" || (a is Array)!=(b is Array))return false;
         if(a is Array) {
            if(a.length!=b.length)return false;
            for(var i:int=0;i<a.length;i++)if(!equal(a[i],b[i]))return false;
         }
         var ak:Array=[],bk:Array=[],k:String;
         for(k in a)ak.push(k);for(k in b)bk.push(k);ak.sort();bk.sort();
         if(ak.join("|")!=bk.join("|"))return false;
         for each(k in ak)if(!equal(a[k],b[k]))return false;
         return true;
      }
      private function readData():Object {
         var bytes:ByteArray=new TraceData() as ByteArray;
         return JSON.parse(bytes.readUTFBytes(bytes.length));
      }
      private function measured(wall:Object,data:String):Object {
         var before:int=WorkingSetCounter.unpack,words:Array=wall.testWords(data);
         return {words:words,unpacks:WorkingSetCounter.unpack-before};
      }
      private function traceCases():void {
         var data:Object=readData(),immutable:String=JSON.stringify(data);
         check(data.payloads.length==82 && data.missOrder.length==1276,"exact recorded 82 payload / 1276 miss fixture");
         var before:WallBefore=new WallBefore(),after:WallAfter=new WallAfter(),expected:Array=[];
         for each(var payload:Object in data.payloads)expected.push(RoomCodec.unpack(payload.data));
         WorkingSetCounter.unpack=0;
         var oldCount:int=0,newCount:int=0,allEqual:Boolean=true,firstFailure:int=-1,byCase:Array=[];
         for(var c:int=0;c<8;c++)byCase.push({oldUnpack:0,newUnpack:0,visits:0});
         for(var i:int=0;i<data.missOrder.length;i++) {
            var item:Object=data.missOrder[i],s:String=data.payloads[item.payload].data;
            var a:Object=measured(before,s),b:Object=measured(after,s);
            oldCount+=a.unpacks;newCount+=b.unpacks;
            byCase[item["case"]].oldUnpack+=a.unpacks;byCase[item["case"]].newUnpack+=b.unpacks;byCase[item["case"]].visits++;
            if(!equal(a.words,b.words) || !equal(a.words,expected[item.payload]) ||
               a.words===b.words || a.words===expected[item.payload] || b.words===expected[item.payload]) {
               allEqual=false;if(firstFailure<0)firstFailure=i;
            }
         }
         check(allEqual,"every replay output value/type/order and independent array identity; firstFailure="+firstFailure);
         check(oldCount==1276,"actual old production RoomCodec.unpack calls = 1276; observed="+oldCount);
         check(newCount==82,"actual new production RoomCodec.unpack calls = 82; observed="+newCount);
         check(JSON.stringify(data)==immutable,"raw payloads, order and metadata not mutated");
         measurements.trace={oldUnpack:oldCount,newUnpack:newCount,byCase:byCase,
            oldCache:before.testStats(),newCache:after.testStats(),recordedMissOrderOnly:true,
            omittedReadOnlyHits:data.omittedReadOnlyHits,omittedProtectedDecodes:data.omittedProtectedDecodes};
         before.testDispose();after.testDispose();

         before=new WallBefore();after=new WallAfter();var detached:Boolean=true;
         for each(payload in data.payloads) {
            a=measured(before,payload.data);b=measured(after,payload.data);
            // Poison returned arrays; neither retained cache nor the peer test
            // instance nor subsequent caller may share those mutable arrays.
            a.words[1]=123;a.words.push(1599,1);b.words[1]=456;b.words.push(1599,2);
            var a2:Object=measured(before,payload.data),b2:Object=measured(after,payload.data);
            if(a2.unpacks!=0 || b2.unpacks!=0 || !equal(a2.words,expected[payload.id]) ||
               !equal(b2.words,expected[payload.id]) || a2.words===a.words || b2.words===b.words)detached=false;
         }
         check(detached,"all 82 cold/hit returned arrays remain isolated after caller mutation");
         before.reset();after.reset();
         check(equal(before.testStats(),{entries:0,words:0,chars:0}) && equal(after.testStats(),before.testStats()),
            "public reset empties all cache bounds in both actual classes");
         a=measured(before,data.payloads[0].data);b=measured(after,data.payloads[0].data);
         check(a.unpacks==1 && b.unpacks==1 && equal(a.words,b.words),"first post-reset payload is decoded again in both");
         before.testDispose();after.testDispose();
      }
      private function dense(seed:uint,random:Boolean):Array {
         var result:Array=[],value:uint=seed;
         for(var i:int=0;i<1600;i++) {
            if(random){value^=value<<13;value^=value>>>17;value^=value<<5;}
            result.push(i,random?value:seed);
         }
         return result;
      }
      private function limits(wall:Object,newer:Boolean):Object {
         return newer?{entries:128,words:131072,chars:524288}:{entries:64,words:32768,chars:131072};
      }
      private function boundCase(newer:Boolean,kind:String):void {
         var wall:Object=newer?new WallAfter():new WallBefore(),cap:Object=limits(wall,newer);
         var label:String=(newer?"new":"old")+" "+kind,first:String=null,removed:Boolean=false,count:int=0;
         var before:Object,after:Object,exceeds:Boolean=false,exclusive:Boolean=false;
         for(var i:int=1;i<=140;i++) {
            var words:Array=kind=="entries"?[0,i]:dense(i,kind=="chars");
            var text:String=RoomCodec.pack(words);if(first==null)first=text;
            before=wall.testStats();var out:Object=measured(wall,text);after=wall.testStats();count++;
            if(!equal(out.words,words) || out.unpacks!=1)throw new Error(label+" non-unique/corrupt generated payload "+i);
            var byEntries:Boolean=before.entries+1>cap.entries,byWords:Boolean=before.words+words.length>cap.words;
            var byChars:Boolean=before.chars+text.length>cap.chars;
            if(after.entries<=before.entries) {
               removed=true;
               exceeds=kind=="entries"?byEntries:kind=="words"?byWords:byChars;
               exclusive=(int(byEntries)+int(byWords)+int(byChars))==1;
               break;
            }
         }
         check(removed && exceeds && exclusive,label+" independently reaches the intended sole eviction limit");
         check(after.entries<=cap.entries && after.words<=cap.words && after.chars<=cap.chars,label+" all three retained bounds hold");
         var reloaded:Object=measured(wall,first);
         check(reloaded.unpacks==1,label+" FIFO oldest payload really evicted and unpacked again");
         measurements[label]={insertionsToEvict:count,previous:before,retained:after,reloadUnpack:reloaded.unpacks};
         wall.testDispose();
      }
      private function outcome(wall:Object,s:String):Object {
         var before:int=WorkingSetCounter.unpack;
         try{return {value:wall.testWords(s),unpacks:WorkingSetCounter.unpack-before};}
         catch(e:Error){return {errorClass:getQualifiedClassName(e),errorID:e.errorID,unpacks:WorkingSetCounter.unpack-before};}
         return null;
      }
      private function invalidCases():void {
         var large:Array=[];for(var j:int=0;j<1601;j++)large.push(j,1);
         var samples:Array=[{name:"null",raw:null},{name:"malformed",raw:"not-base64-zlib"},
            {name:"object",value:{x:1}},{name:"odd words",value:[0]},
            {name:"duplicate index",value:[0,1,0,2]},{name:"descending",value:[1,1,0,2]},
            {name:"negative index",value:[-1,1]},{name:"too large index",value:[1600,1]},
            {name:"fractional index",value:[0.5,1]},{name:"negative color",value:[0,-1]},
            {name:"too large color",value:[0,4294967296]},{name:"fractional color",value:[0,1.5]},
            {name:"too many words",value:large}];
         var before:WallBefore=new WallBefore(),after:WallAfter=new WallAfter();
         for each(var sample:Object in samples) {
            var s:String=sample.hasOwnProperty("raw")?sample.raw:RoomCodec.pack(sample.value);
            var a:Object=outcome(before,s),b:Object=outcome(after,s);
            check(equal(a,b) && (a.hasOwnProperty("errorClass") || a.value==null),sample.name+" same native reject/error");
            a=outcome(before,s);b=outcome(after,s);
            check(equal(a,b) && a.unpacks==1 && b.unpacks==1,sample.name+" rejected input never cached");
         }
         var legacy:Array=[[0,"42"],[0,[42]],[null,null]];
         for(var i:int=0;i<legacy.length;i++) {
            s=RoomCodec.pack(legacy[i]);a=outcome(before,s);b=outcome(after,s);
            check(equal(a,b) && equal(a.value,legacy[i]),"legacy coercion "+i+" preserves original returned types");
            if(a.value[1] is Array)a.value[1][0]=77;
            a=outcome(before,s);b=outcome(after,s);
            check(equal(a,b) && equal(a.value,legacy[i]) && a.unpacks==1 && b.unpacks==1,
               "legacy coercion "+i+" uncached nested mutation remains isolated");
         }
         check(equal(before.testStats(),{entries:0,words:0,chars:0}) && equal(after.testStats(),before.testStats()),
            "rejected and unusual legacy values retain no cache entries");
         before.testDispose();after.testDispose();
      }
      private function world():Object {
         var loc:Object={spaceX:4,spaceY:2,space:[],firstObj:null};
         for(var x:int=0;x<4;x++){loc.space[x]=[];for(var y:int=0;y<2;y++)loc.space[x][y]={hp:10,phis:1};}
         loc.grafon={loc:loc,frontBmp:new BitmapData(160,80,true,0xff222222)};return loc;
      }
      private function pixels(a:Object,b:Object):Boolean {
         var av:Vector.<uint>=a.grafon.frontBmp.getVector(a.grafon.frontBmp.rect);
         var bv:Vector.<uint>=b.grafon.frontBmp.getVector(b.grafon.frontBmp.rect);
         if(av.length!=bv.length)return false;
         for(var i:int=0;i<av.length;i++)if(av[i]!=bv[i])return false;return true;
      }
      private function publicCases():void {
         var before:WallBefore=new WallBefore(),after:WallAfter=new WallAfter(),a:Object=world(),b:Object=world();
         var red:String=RoomCodec.pack([0,0xffff0000]),green:String=RoomCodec.pack([0,0xff00ff00]);
         var batch:Array=[{x:0,y:0,v:2,d:red}],immutable:String=JSON.stringify(batch);
         before.receive(a,batch,false);after.receive(b,batch,false);
         check(pixels(a,b)&&a.grafon.frontBmp.getPixel32(0,0)==0xffff0000,"public receive actual pixels match");
         check(JSON.stringify(batch)==immutable,"public receive leaves input cells/version/payload unchanged");
         before.receive(a,[{x:0,y:0,v:1,d:green}],false);after.receive(b,[{x:0,y:0,v:1,d:green}],false);
         check(pixels(a,b)&&a.grafon.frontBmp.getPixel32(0,0)==0xffff0000,"older cell revision cannot overwrite actual pixels");
         before.receive(a,[{x:0,y:0,v:2,d:green}],false);after.receive(b,[{x:0,y:0,v:2,d:green}],false);
         check(pixels(a,b)&&a.grafon.frontBmp.getPixel32(0,0)==0xffff0000,"equal revision still cannot overwrite actual pixels");
         batch=[{x:0,y:0,v:3,d:green},{x:1,y:0,v:3,d:RoomCodec.pack([1600,2])}];
         before.receive(a,batch,false);after.receive(b,batch,false);
         check(pixels(a,b)&&a.grafon.frontBmp.getPixel32(0,0)==0xffff0000,"malformed later cell rejects whole batch before any paint");
         check(before.testCells(a,[{x:0,y:0,d:red},{x:0,y:0,d:red}])==null &&
            after.testCells(b,[{x:0,y:0,d:red},{x:0,y:0,d:red}])==null,"duplicate cell coordinates remain rejected");
         check(before.testCells(a,[{x:-1,y:0,d:red}])==null && after.testCells(b,[{x:-1,y:0,d:red}])==null,
            "out-of-room coordinates remain rejected");
         var a2:Object=world(),b2:Object=world();
         before.receive(a2,[{x:0,y:0,v:1,d:green}],false);after.receive(b2,[{x:0,y:0,v:1,d:green}],false);
         check(pixels(a2,b2)&&a2.grafon.frontBmp.getPixel32(0,0)==0xff00ff00&&a.grafon.frontBmp.getPixel32(0,0)==0xffff0000,
            "same payload cache does not merge room version ownership or pixels");
         before.reset();after.reset();
         before.receive(a,[{x:0,y:0,v:1,d:green}],false);after.receive(b,[{x:0,y:0,v:1,d:green}],false);
         check(pixels(a,b)&&a.grafon.frontBmp.getPixel32(0,0)==0xff00ff00,"reset releases prior room revisions along with cache");
         before.testDispose();after.testDispose();
         a.grafon.frontBmp.dispose();b.grafon.frontBmp.dispose();a2.grafon.frontBmp.dispose();b2.grafon.frontBmp.dispose();
      }
      private function protectedCases():void {
         var before:WallBefore=new WallBefore(),after:WallAfter=new WallAfter(),a:Object=world(),b:Object=world();
         var walls:Array=[before,after],locs:Array=[a,b],reports:Array=[];
         for(var i:int=0;i<2;i++) {
            var wall:Object=walls[i],loc:Object=locs[i];wall.before(loc);
            loc.grafon.frontBmp.setPixel32(20,20,0xffaa00aa);loc.space[0][0].hp--;
            var bullet:Bullet=new Bullet();bullet.loc=loc;bullet.X=20;bullet.Y=20;bullet.tilehit=true;loc.firstObj=bullet;
            reports.push(wall.report(loc));
         }
         check(reports[0]!=null && equal(reports[0],reports[1]),"native contact fixture creates identical real pending reports");
         var batch:Array=[{x:0,y:0,v:8,d:RoomCodec.pack([820,0xff00bb00])}];
         before.receive(a,batch,true);after.receive(b,batch,true);
         check(pixels(a,b)&&a.grafon.frontBmp.getPixel32(20,20)==0xffaa00aa,"pending local contact protects original pixel");
         before.acknowledge(a,reports[0]);after.acknowledge(b,reports[1]);
         before.receive(a,batch,true);after.receive(b,batch,true);
         check(pixels(a,b)&&a.grafon.frontBmp.getPixel32(20,20)==0xff00bb00,
            "same authoritative revision remains eligible after pending ACK");
         before.testDispose();after.testDispose();a.grafon.frontBmp.dispose();b.grafon.frontBmp.dispose();
      }
      private function start(e:Event):void {
         removeEventListener(Event.ADDED_TO_STAGE,start);
         try {
            check(RoomCodec.timingEnabled===false,"frozen recovery07 codec starts with diagnostics disabled");
            traceCases();
            for each(var newer:Boolean in [false,true])for each(var kind:String in ["entries","words","chars"])boundCase(newer,kind);
            invalidCases();publicCases();protectedCases();
            check(Log.calls==0,"component did not enable per-cell codec logging");
         }catch(error:Error){check(false,"uncaught "+error.getStackTrace());}
         var stream:FileStream=new FileStream();stream.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         stream.writeUTFBytes(JSON.stringify({passed:failed==0,failed:failed,assertions:checks,measurements:measurements,
            native_game:false,tcp_socket:false,performance_qualified:false,observed_real_payloads:true}));stream.close();
         NativeApplication.nativeApplication.exit(failed?1:0);
      }
   }
}

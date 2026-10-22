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

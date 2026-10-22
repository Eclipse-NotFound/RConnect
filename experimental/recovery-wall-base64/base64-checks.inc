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

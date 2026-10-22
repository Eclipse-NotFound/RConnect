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

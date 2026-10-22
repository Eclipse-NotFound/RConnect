      public static function unpack(data:String):Array {
         if(!isCell(data) || data.length>MAX_TEXT)return null;
         var text:String=data.substr(PREFIX.length);
         if(text.length==0 || text.length%4!=0)return null;
         var bytes:ByteArray=new ByteArray();
         for(var i:int=0;i<text.length;i+=4) {
            // Each UTF-16 code unit is checked before the bounded ASCII lookup.
            // In particular, a non-ASCII character must not wrap into the table.
            var ca:int=text.charCodeAt(i),cb:int=text.charCodeAt(i+1);
            var cc:int=text.charCodeAt(i+2),cd:int=text.charCodeAt(i+3);
            var a:int=ca<128?REVERSE[ca]:-1,b:int=cb<128?REVERSE[cb]:-1;
            var c:int=cc<128?REVERSE[cc]:-1,d:int=cd<128?REVERSE[cd]:-1;
            var padC:Boolean=cc==61,padD:Boolean=cd==61;
            if(a<0 || b<0 || (c<0&&!padC) || (d<0&&!padD) || (padC&&!padD)
               || ((padC||padD)&&i+4!=text.length) || (padC&&(b&15)!=0) || (padD&&!padC&&(c&3)!=0))return null;
            if(padC)bytes.writeByte((a<<2)|(b>>4));
            else {
               // Default big endian writes the same first two decoded bytes.
               bytes.writeShort((a<<10)|(b<<4)|(c>>2));
               if(!padD)bytes.writeByte((c<<6)|d);
            }
         }
         if(bytes.length>MAX_COMPRESSED)return null;
         // AIR's native inflate has no output-size argument. Encoded input is
         // bounded above; reject expanded content before any pixel/ACK update.
         bytes.uncompress();bytes.position=0;
         if(bytes.length<2 || bytes.length>MAX_RAW)return null;
         var count:int=bytes.readUnsignedShort();
         if(count>1600 || bytes.length!=2+6*count)return null;
         var words:Array=[],previous:int=-1;
         for(i=0;i<count;i++) {
            var index:int=bytes.readUnsignedShort();
            if(index<=previous || index>=1600)return null;
            previous=index;words.push(Number(index),Number(bytes.readUnsignedInt()));
         }
         return words;
      }

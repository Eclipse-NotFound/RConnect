package authority {
   import flash.display.DisplayObjectContainer;
   import flash.display.BitmapData;
   import flash.events.Event;
   import flash.utils.getTimer;
   /** Exploration is local display knowledge, separate from authoritative combat. */
   public final class SharedVision {
      private var owner:RConnectMod,api:Object,memories:Object={},own:Object={},sent:Object={},lastAt:int=0,lastDiscovery:int=-10000;
      private var sharing:Boolean=true,apiErrorAt:int=-10000;
      private static const HEX:String="0123456789abcdef";
      public var received:uint=0;
      public function get enabled():Boolean{return sharing;}
      public function set enabled(value:Boolean):void {
         if(value==sharing)return;sharing=value;
         if(value && owner.welcomed && owner.link!=null)owner.link.send({type:"exploration-request",session:owner.sessionId});
      }
      public function SharedVision(owner:RConnectMod) {
         this.owner=owner;
         owner.stage.addEventListener(Event.ENTER_FRAME,requestRender,false,-20000,true);
         owner.stage.addEventListener(Event.RENDER,render,false,-100,true);
      }
      private function discover():void {
         if(getTimer()-lastDiscovery<1000)return;lastDiscovery=getTimer();
         var carrier:Object=DisplayObjectContainer(owner.main).getChildByName("RVExplorationAPI");
         var value:Object=NativeAccess.get(carrier,"api");
         if(value!=null && value.version===1 && value.capture is Function && value.merge is Function && value.active is Function)api=value;
      }
      public function step():void {
         if(!owner.welcomed || getTimer()-lastAt<100 || !owner.access.ready())return;
         lastAt=getTimer();discover();
         var room:Object=owner.access.world.loc,key:String=owner.access.keyFor(room),rows:Array=remember(room);
         if(rows==null)return;
         var previous:Array=sent[key] as Array,changed:Array=[],indices:Array=[];
         for(var y:int=0;y<rows.length;y++)if(previous==null || rows[y]!==previous[y]){indices.push(y);changed.push(rows[y]);}
         if(changed.length==0)return;
         if(owner.link.send({type:"exploration",session:owner.sessionId,room:key,cols:room.spaceX,height:room.spaceY,
            full:previous==null,indices:indices,rows:changed}))sent[key]=rows.concat();
      }
      /** Preserve the player's own view before a replica room is reconstructed. */
      public function remember(room:Object):Array {
         if(room==null)return null;
         var key:String=owner.access.keyFor(room),rows:Array;
         if(api!=null)try{rows=api.capture(room) as Array;}catch(error:*){apiFailure(error);}
         if(!valid(rows,room.spaceX,room.spaceY)) {
            rows=[];
            for(var y:int=0;y<room.spaceY;y++) {
               var row:Array=[];
               for(var x:int=0;x<room.spaceX;x++) {
                  var n:int=Math.max(0,Math.min(15,Math.round(Number(room.space[x][y].visi)*15)));
                  row.push(HEX.charAt(n)+(n>0?"ffffffffffffffff":"0000000000000000"));
               }
               rows.push(row.join(""));
            }
         }
         if(room.retDark)return rows;
         var old:Object=own[key],merged:Array=[],changed:Boolean=old==null;
         for(y=0;y<rows.length;y++) {
            var line:String=mergeRow(old==null?null:old.rows[y],rows[y]);merged.push(line);
            if(old!=null && old.rows[y]!==line)changed=true;
         }
         if(changed)own[key]={cols:room.spaceX,height:room.spaceY,rows:merged,applied:old==null?room:old.applied};
         return merged;
      }
      public function restore(room:Object):void {
         var entry:Object=own[owner.access.keyFor(room)];
         if(room.retDark || !fits(entry,room))return;
         for(var y:int=0;y<room.spaceY;y++)for(var x:int=0;x<room.spaceX;x++) {
            var known:Number=HEX.indexOf(entry.rows[y].charAt(x*17))/15,t:Object=room.space[x][y];
            t.visi=Math.max(t.visi,known);t.t_visi=Math.max(t.t_visi,known);
         }
      }
      private function fits(entry:Object,room:Object):Boolean{return entry!=null && entry.cols==room.spaceX && entry.height==room.spaceY;}
      private function mergeRow(a:String,b:String):String {
         if(a==null || a==b)return b;
         var chars:Array=[];
         for(var i:int=0;i<b.length;i++) {
            var av:int=HEX.indexOf(a.charAt(i)),bv:int=HEX.indexOf(b.charAt(i));
            chars.push(HEX.charAt(i%17==0?Math.max(av,bv):av|bv));
         }
         return chars.join("");
      }
      private function valid(rows:Array,cols:int,height:int):Boolean {
         if(cols<1 || cols>400 || height<1 || height>400 || rows==null || rows.length!=height)return false;
         for each(var row:* in rows)if(!(row is String) || row.length!=cols*17 || /[^0-9a-f]/.test(row))return false;
         return true;
      }
      public function receive(packet:Object):void {
         if(!enabled || !(packet.room is String) || packet.room.length>180 || !(packet.cols is Number) || !(packet.height is Number) ||
            packet.cols!=int(packet.cols) || packet.height!=int(packet.height) || packet.cols<1 || packet.cols>400 || packet.height<1 || packet.height>400 ||
            !(packet.rows is Array) || !(packet.indices is Array) || packet.rows.length!=packet.indices.length || packet.rows.length>packet.height)return;
         if(!valid(packet.rows as Array,int(packet.cols),packet.rows.length))return;
         var old:Object=memories[packet.room],incoming:Array=packet.rows,rows:Array=[];
         if(old!=null && (old.cols!=packet.cols || old.height!=packet.height))return;
         if(old==null && (packet.full!==true || packet.rows.length!=packet.height)) {
            owner.link.send({type:"exploration-request",session:owner.sessionId});return;
         }
         var visited:Object={};
         for each(var index:* in packet.indices) {
            if(!(index is Number) || index!=int(index) || index<0 || index>=packet.height || visited[index])return;
            visited[index]=true;
         }
         rows=old==null?new Array(packet.height):old.rows.concat();
         for(var y:int=0;y<incoming.length;y++) {
            var target:int=packet.indices[y],a:String=old==null?null:old.rows[target],b:String=incoming[y];
            rows[target]=mergeRow(a,b);
         }
         memories[packet.room]={cols:packet.cols,height:packet.height,rows:rows,applied:null};++received;
      }
      private function requestRender(e:Event):void {owner.stage.invalidate();}
      private function render(e:Event):void {
         if(!owner.access.ready())return;discover();
         var room:Object=owner.access.world.loc,key:String=owner.access.keyFor(room);
         for each(var entry:Object in [own[key],memories[key]])apply(room,entry);
      }
      private function apply(room:Object,entry:Object):void {
         if(room.retDark || !fits(entry,room))return;
         if(api!=null) {
            try {
               if(entry.applied!==room && api.merge(room,entry.rows)===true)entry.applied=room;
               if(entry.applied===room && api.active(room)===true)return;
            }catch(error:*){apiFailure(error);}
         }
         var bitmap:BitmapData=room.grafon.lightBmp as BitmapData;if(bitmap==null)return;
         for(var y:int=1;y<room.spaceY;y++)for(var x:int=1;x<room.spaceX;x++) {
            var known:Number=HEX.indexOf(entry.rows[y].charAt(x*17))/15;
            var alpha:int=Math.floor((1-known)*255),current:int=bitmap.getPixel32(x,y+1)>>>24;
            if(alpha<current)bitmap.setPixel32(x,y+1,alpha<<24);
         }
      }
      public function resetLink():void {sent={};lastAt=0;}
      public function resetJourney():void {memories={};own={};resetLink();}
      private function apiFailure(error:*):void {
         api=null;
         if(getTimer()-apiErrorAt>10000){apiErrorAt=getTimer();Log.write("exploration-api-fallback",{reason:String(error)});}
      }
   }
}

package authority {
   import flash.display.DisplayObjectContainer;
   import flash.display.BitmapData;
   import flash.events.Event;
   import flash.utils.getTimer;
   /** Exploration is local display knowledge, separate from authoritative combat. */
   public final class SharedVision {
      private var owner:RConnectMod,api:Object,memories:Object={},sent:Object={},lastAt:int=0,lastDiscovery:int=-10000;
      private static const HEX:String="0123456789abcdef";
      public var enabled:Boolean=true,received:uint=0;
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
         var room:Object=owner.access.world.loc,key:String=owner.access.keyFor(room),rows:Array;
         if(api!=null)rows=api.capture(room) as Array;
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
         var fingerprint:String=rows.join("|");
         if(sent[key]===fingerprint)return;sent[key]=fingerprint;
         owner.link.send({type:"exploration",room:key,cols:room.spaceX,height:room.spaceY,rows:rows});
      }
      private function valid(rows:Array,cols:int,height:int):Boolean {
         if(cols<1 || cols>400 || height<1 || height>400 || rows==null || rows.length!=height)return false;
         for each(var row:* in rows)if(!(row is String) || row.length!=cols*17 || /[^0-9a-f]/.test(row))return false;
         return true;
      }
      public function receive(packet:Object):void {
         if(!enabled || !(packet.room is String) || packet.room.length>180 || !valid(packet.rows as Array,int(packet.cols),int(packet.height)))return;
         var old:Object=memories[packet.room],incoming:Array=packet.rows,rows:Array=[];
         if(old!=null && (old.cols!=packet.cols || old.height!=packet.height))return;
         for(var y:int=0;y<incoming.length;y++) {
            var a:String=old==null?null:old.rows[y],b:String=incoming[y];
            if(a==null || a==b){rows.push(b);continue;}
            var chars:Array=[];
            for(var i:int=0;i<b.length;i++) {
               var av:int=HEX.indexOf(a.charAt(i)),bv:int=HEX.indexOf(b.charAt(i));
               chars.push(HEX.charAt(i%17==0?Math.max(av,bv):av|bv));
            }
            rows.push(chars.join(""));
         }
         memories[packet.room]={cols:packet.cols,height:packet.height,rows:rows,applied:null};++received;
      }
      private function requestRender(e:Event):void {owner.stage.invalidate();}
      private function render(e:Event):void {
         if(!owner.access.ready())return;discover();
         var room:Object=owner.access.world.loc,entry:Object=memories[owner.access.keyFor(room)];
         if(entry==null || room.spaceX!=entry.cols || room.spaceY!=entry.height)return;
         if(api!=null) {
            if(entry.applied!==room && api.merge(room,entry.rows)===true)entry.applied=room;
            if(entry.applied===room && api.active(room)===true)return;
         }
         if(room.retDark)return;
         var bitmap:BitmapData=room.grafon.lightBmp as BitmapData;if(bitmap==null)return;
         for(var y:int=1;y<room.spaceY;y++)for(var x:int=1;x<room.spaceX;x++) {
            var known:Number=HEX.indexOf(entry.rows[y].charAt(x*17))/15;
            if(known>Number(room.space[x][y].visi))bitmap.setPixel32(x,y+1,Math.floor((1-known)*255)<<24);
         }
      }
      public function resetLink():void {sent={};lastAt=0;}
      public function resetJourney():void {memories={};resetLink();}
   }
}

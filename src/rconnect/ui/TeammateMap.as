package rconnect.ui
{
   import flash.display.Bitmap;
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.text.TextField;
   import flash.text.TextFieldAutoSize;
   import flash.text.TextFormat;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;
   import rconnect.game.RemoteMotion;

   /** Overlay on the native local map. Its own mask, pan and zoom remain intact. */
   public class TeammateMap
   {
      private var mod:RConnectMod,layer:Sprite=new Sprite(),markers:Object={};
      private var errors:int=0;
      public function TeammateMap(m:RConnectMod)
      {
         mod=m;layer.name="rconnect-teammate-map";layer.mouseEnabled=false;layer.mouseChildren=false;
         m.stage.addEventListener(Event.ENTER_FRAME,tick,false,-12000,true);
      }
      private function tick(e:Event):void
      {
         try {update();}
         catch(error:Error) {detach();if(errors++<3)Log.d("RConnectMap: failed "+error);}
      }
      private function detach():void {if(layer.parent!=null)layer.parent.removeChild(layer);if(layer.numChildren==0)return;markers={};while(layer.numChildren)layer.removeChildAt(0);}
      private function shown(o:DisplayObject):Boolean
      {
         if(o==null || o.stage==null)return false;
         for(var p:DisplayObject=o;p!=null;p=p.parent)if(!p.visible || p.alpha<=0)return false;
         return true;
      }
      public function update():void
      {
         var game:GameBridge=mod.game,w:Object=game.world,pip:Object=GameBridge.probe(w,"pip");
         var map:Bitmap=GameBridge.probe(GameBridge.probe(pip,"currentPage"),"map") as Bitmap;
         if(mod.navigation==null || pip==null || pip.active!=true || game.loc==null || game.loc.noMap
            || game.isTransitioning() || mod.session.rooms.busy || !mod.session.rooms.ready
            || map==null || map.bitmapData==null || !shown(map)) {detach();return;}
         var parent:DisplayObjectContainer=map.parent;
         if(layer.parent!==parent) {detach();parent.addChild(layer);}
         var seen:Object={},now:int=getTimer(),land:Object=w.land,constants:Object=Object(w).constructor;
         for each(var peer:Object in mod.navigation.players)
         {
            var s:Object=peer.snap,info:Object=GameBridge.probe(s,"worldInfo");
            if(!mod.navigation.sameMap(s) || info==null || String(info.landProb || "")!=String(game.loc.landProb || "")
               || !isFinite(Number(s.x)) || !isFinite(Number(s.y)))continue;
            var room:Object;
            try {room=land.locs[int(info.landX)][int(info.landY)][int(info.landZ)];}catch(missing:*) {room=null;}
            if(room==null || String(s.roomKey)!=game.roomKey(room))continue;
            var key:String=String(peer.id),record:Object=markers[key];seen[key]=true;
            if(record==null)record=markers[key]=createMarker();
            if(record.key!=s.roomKey) {record.motion=new RemoteMotion(50);record.snap=null;record.key=s.roomKey;}
            if(record.snap!==s) {record.motion.push(s,now);record.snap=s;}
            var position:Object=record.motion.sample(now),shape:Object=s.hitShape;
            var tx:Number=(Number(info.landX)-Number(land.minLocX))*Number(constants.cellsX)+Number(position.x)/Number(constants.tileX);
            var ty:Number=(Number(info.landY)-Number(land.minLocY))*Number(constants.cellsY)
               +(Number(position.y)-(shape==null?0:Number(shape.scY))/2)/Number(constants.tileY);
            var marker:Sprite=record.vis;
            marker.visible=isFinite(tx)&&isFinite(ty)&&tx>=0&&ty>=0&&tx<map.bitmapData.width&&ty<map.bitmapData.height;
            marker.x=map.x+tx*map.scaleX;marker.y=map.y+ty*map.scaleY;
            marker.alpha=Number(s.hp)>0 && int(s.sost)<3?1:.45;
            var label:TextField=record.label,name:String=String(peer.name);
            if(record.name!=name) {label.text=name.length>28?name.substr(0,27)+"…":name;record.name=name;}
         }
         for(key in markers)if(!seen[key]) {layer.removeChild(markers[key].vis);delete markers[key];}
      }
      private function createMarker():Object
      {
         var marker:Sprite=new Sprite();marker.mouseEnabled=false;marker.mouseChildren=false;
         marker.graphics.lineStyle(2,0x082C39,1);marker.graphics.beginFill(0x43E9FF,1);
         marker.graphics.moveTo(0,-7);marker.graphics.lineTo(6,0);marker.graphics.lineTo(0,7);
         marker.graphics.lineTo(-6,0);marker.graphics.lineTo(0,-7);marker.graphics.endFill();
         marker.graphics.beginFill(0xFFFFFF);marker.graphics.drawCircle(0,0,2);marker.graphics.endFill();
         var label:TextField=new TextField();label.defaultTextFormat=new TextFormat("_sans",12,0x9AF4FF,true);
         label.autoSize=TextFieldAutoSize.LEFT;label.x=10;label.y=-10;label.selectable=false;label.mouseEnabled=false;
         label.background=true;label.backgroundColor=0x09222D;label.embedFonts=false;
         marker.addChild(label);layer.addChild(marker);
         return {vis:marker,label:label,key:null,snap:null,name:null};
      }
   }
}

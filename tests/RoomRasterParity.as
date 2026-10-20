package {
   import flash.display.BitmapData;
   import flash.display.Loader;
   import flash.events.Event;
   import flash.utils.ByteArray;
   import flash.utils.Dictionary;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;

   /** Diagnostic-only native redraw comparison. Pixel stores are compressed
    * one at a time; no second full-size world bitmap is allocated. */
   public class RoomRasterParity {
      private var mod:RConnectMod,links:Dictionary=new Dictionary();
      public function RoomRasterParity(m:RConnectMod) {
         mod=m;mod.stage.addEventListener(Event.ENTER_FRAME,frame,false,100007);
      }
      private function frame(e:Event):void {
         var peers:Array=mod.session.mode=="hosting"?mod.session.server.clients:[mod.session.link];
         for each(var l:TcpLink in peers)if(l!=null && !links[l]) {
            links[l]=true;l.addEventListener(TcpLink.MESSAGE,after,false,-300000);
         }
      }
      private function wallBlend():Object {
         var main:MainFE=mod.game.main as MainFE;
         for(var key:Object in main.modEntryByLoader) {
            var loader:Loader=key as Loader;
            if(loader!=null && loader.contentLoaderInfo.applicationDomain.hasDefinition("WallBlendMod"))
               return loader.contentLoaderInfo.applicationDomain.getDefinition("WallBlendMod");
         }
         throw new Error("WallBlend runtime entry unavailable for equal-state comparison");
      }
      private function pixels(g:Object):Object {
         var out:Object={};
         for each(var surface:Object in g.sceneSurfaces()) {
            var layers:Array=[];
            for each(var bitmap:BitmapData in surface.nativeBuffers) {
               var bytes:ByteArray=bitmap.getPixels(bitmap.rect);bytes.compress();bytes.position=0;
               layers.push(bytes);
            }
            out[surface.cx+":"+surface.cy]=layers;
         }
         return out;
      }
      private function equal(a:ByteArray,b:ByteArray):Boolean {
         if(a.length!=b.length)return false;a.position=b.position=0;
         while(a.bytesAvailable>=4)if(a.readUnsignedInt()!=b.readUnsignedInt())return false;
         while(a.bytesAvailable)if(a.readUnsignedByte()!=b.readUnsignedByte())return false;
         return true;
      }
      private function after(event:NetMessageEvent):void {
         var p:Object=event.data;
         if(p.type!="room" || p.op!="grant" || mod.game.loc==null || mod.game.loc.spaceX<=48)return;
         var at:int=getTimer(),result:Object={valid:false,diagnosticOnly:true,room:mod.game.roomKey()};
         try {
            var w:Object=mod.game.world,g:Object=w.grafon,wb:Object=wallBlend();
            g.sceneTick();wb.refreshNow();var before:Object=pixels(g);
            w.redrawLoc();g.sceneTick();wb.refreshNow();var after:Object=pixels(g);
            var totalBefore:int=0,totalAfter:int=0,compared:int=0,differences:Array=[];
            for(var key:String in after)totalAfter++;
            for(key in before) {
               totalBefore++;if(after[key]==null)continue;
               for(var i:int=0;i<before[key].length;i++) {
                  compared++;
                  if(!equal(before[key][i],after[key][i]))differences.push(key+"/"+i);
               }
            }
            result.before=totalBefore;result.after=totalAfter;result.comparedLayers=compared;
            result.differences=differences;result.valid=compared>0 && differences.length==0;
         } catch(e:*) {result.error=String(e);}
         result.ms=getTimer()-at;Log.d("ROOM RASTER PARITY "+JSON.stringify(result));
      }
   }
}

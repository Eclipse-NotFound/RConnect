package rconnect.core {
   /** One exact native destination. No room authority or packet coalescing here.
    * The renderer owns unpainted; only a completed native raster clears it. */
   public final class FirstRasterGate {
      private var world:Object,nativeGame:Object,land:Object,location:Object,renderer:Object;
      private var travel:String="",ticket:Object,receipt:Object;
      private var grantFrame:int=0;
      public function get active():Boolean {return ticket!=null;}
      public function get awaitingView():Boolean {return receipt!=null;}
      public function matches(w:Object,l:Object,g:Object,id:String):Boolean {
         return ticket!=null && w===world && w!=null && w.game===nativeGame && w.land===land
            && w.loc===location && l===location && g===renderer && id===travel;
      }
      public function open(w:Object,l:Object,g:Object,id:String):Object {
         if(active)return matches(w,l,g,id)?ticket:null;
         if(w==null || w.game==null || w.land==null || l==null || l!==w.loc || l.land!==w.land
            || g==null || g!==w.grafon || id=="")return null;
         world=w;nativeGame=w.game;land=w.land;location=l;renderer=g;travel=id;
         ticket={waiting:true,unpainted:true};return ticket;
      }
      public function beginRestore(w:Object,l:Object,g:Object,id:String):void {
         if(!matches(w,l,g,id) || receipt!=null)throw new Error("First raster restore identity changed");
         ticket.waiting=false;
      }
      public function restored(w:Object,l:Object,g:Object,id:String,barrier:int,epoch:int,frame:int):void {
         if(!matches(w,l,g,id) || ticket.waiting===true || receipt!=null)
            throw new Error("First raster grant identity changed");
         receipt={barrier:barrier,epoch:epoch,travelId:id};grantFrame=frame;
      }
      public function sameGrant(barrier:int,epoch:int,id:String):Boolean {
         return receipt!=null && receipt.barrier===barrier && receipt.epoch===epoch && receipt.travelId===id;
      }
      public function ready(w:Object,l:Object,g:Object,id:String,frame:int):Boolean {
         // A subsequent native frame must place the camera after the anchor.
         // Do not add an out-of-order Camera.calc just to shorten this wait.
         return receipt!=null && matches(w,l,g,id) && frame>grantFrame && ticket.waiting!==true
            && ticket.unpainted===false && g.sceneViewReady()===true;
      }
      public function complete():Object {
         var result:Object=receipt;clear();return result;
      }
      public function cancel():void {
         // Leave unpainted true until native sceneTick really produces pixels.
         // On disconnect/failed entry the old local renderer can then recover.
         if(ticket!=null)ticket.waiting=false;
         clear();
      }
      private function clear():void {
         world=nativeGame=land=location=renderer=ticket=receipt=null;travel="";grantFrame=0;
      }
   }
}

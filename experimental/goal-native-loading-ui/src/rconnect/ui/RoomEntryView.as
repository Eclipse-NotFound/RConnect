package rconnect.ui {
   import flash.display.Stage;

   /** Uses World's one native visualWait. No cover, clone or input ownership. */
   public final class RoomEntryView {
      private var world:Object,owner:Object,player:Object,game:Object;
      public var lastState:Object={supported:false,shown:false,reason:"idle"};
      public var bridgeFaults:uint=0;
      public function clear():void {
         try {
            if(world!=null && owner!=null && "rconnectLoadingView" in world)
               lastState=world.rconnectLoadingView(owner,false);
         } catch(error:*) {bridgeFaults++;lastState={supported:true,shown:false,reason:"bridge-fault",faults:bridgeFaults};}
         world=null;owner=null;player=null;game=null;
      }
      public function show(current:Object,stage:Stage,status:String):void {
         try {
         if(current==null || stage==null){clear();return;}
         if(world!==current || player!==current.gg || game!==current.game) {
            clear();world=current;player=current.gg;game=current.game;owner={};
         }
         if(!("rconnectLoadingView" in world)) {
            lastState={supported:false,shown:false,reason:"native-bridge-unavailable"};
            return;
         }
         lastState=world.rconnectLoadingView(owner,true);
         } catch(error:*) {bridgeFaults++;lastState={supported:true,shown:false,reason:"bridge-fault",faults:bridgeFaults};}
      }
   }
}

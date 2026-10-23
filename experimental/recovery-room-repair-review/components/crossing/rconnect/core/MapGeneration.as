package rconnect.core {
   /** Only native integration I/O is substituted; RoomSync is copied unchanged. */
   public class MapGeneration {
      public var nativeTravelSupported:Boolean=true,earlyTravelSupported:Boolean=false;
      public function MapGeneration(s:Session){}
      public var externalAvailable:Boolean=true,externalAcquires:int=0,externalReleases:int=0;
      private var heldId:String="";
      public function acquireEarly(id:String):Boolean{externalAcquires++;if(!externalAvailable)return false;heldId=id;return true;}
      public function releaseEarly(id:String):Boolean{if(heldId==id){externalReleases++;heldId="";}return true;}
      public function reset():void{}
      public function receive(info:Object):void{}
      public function differs(info:Object,land:Object):Boolean{return false;}
      public function sceneMode(land:Object,constructing:Boolean=false):Boolean{return land.sceneMerged===true;}
   }
}

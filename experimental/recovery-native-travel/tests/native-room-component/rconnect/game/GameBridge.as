package rconnect.game {
   import flash.display.*;
   import rconnect.core.MapGeneration;
   /** Native generation is explicit test input, not an imitation of RoomSync.
    * begin/complete keep the old Land until a constructor is declared complete. */
   public dynamic class GameBridge {
      public var world:Object,gg:Object,loc:Object,main:Sprite,mapGeneration:MapGeneration;
      public var roomHold:Boolean=false,independentRooms:Boolean=false,freezeAI:Boolean=false;
      public var roomEpoch:int=0,transition:Boolean=false,startCalls:int=0,restores:int=0;
      public var activeTravelId:String="";
      public function GameBridge(root:Sprite) {
         main=root;world={main:root,onPause:false,land:{act:{id:"map"},loc_t:0},gg:{X:12,Y:34},
            t_exit:0,t_die:0,comLoad:-1,ng_wait:0,cam:{dblack:0},
            game:{curLandId:"map",crea:false,lands:{map:{id:"map",rnd:false},way:{id:"way",rnd:false}}}};
         for each(var name:String in ["vwait","vfon","visual","vscene","vblack","vpip","vsats","vgui","vstand","verror","vconsol"]) {
            world[name]=new Sprite();world[name].name=name;root.addChild(world[name]);
         }
         world.mm={active:false};world.allStat=1;world.vsats.visible=false;world.vpip.visible=false;
         setRoom("map//0,0,0");
      }
      public function setRoom(key:String):void {
         world.loc={key:key,land:world.land,spaceX:12,spaceY:8};
         world.land.loc=world.loc;world.gg.loc=world.loc;refreshWorld();
      }
      public function completeNative(info:Object):void {
         world.land={act:{id:String(info.curLandId)},loc_t:0};
         world.game.curLandId=String(info.curLandId);world.t_exit=0;transition=false;
         setRoom(String(info.curLandId)+"//0,0,0");
      }
      public function refreshWorld():void{loc=world.loc;gg=world.gg;}
      public static function probe(o:Object,k:String):*{return o==null?null:o[k];}
      public function roomKey(room:Object=null):String{return String((room||loc).key);}
      public function readWorldInfo():Object {
         return {curLandId:world.game.curLandId,curCoord:"",roomKey:roomKey(),roomEpoch:roomEpoch,
            travelId:activeTravelId,landProb:"",landStage:0,worldReady:!transition && world.land.act.id==world.game.curLandId,
            landX:0,landY:0,landZ:0,x:gg.X,y:gg.Y};
      }
      public function isTransitioning():Boolean{return transition;}
      public function isPlayerDead():Boolean{return false;}
      public function releaseMovablesForHandoff():void{}
      public function startSharedTravel(info:Object):Boolean {
         startCalls++;world.game.curLandId=String(info.curLandId);world.t_exit=21;transition=true;return true;
      }
      public function inRoom(room:Object,fn:Function):* {
         var previous:Object=loc;loc=room;try{return fn();}finally{loc=previous;}
      }
      public function checkpoint():Object{return {key:roomKey(),width:12,height:8};}
      public function roomRole(authority:Boolean):void{freezeAI=!authority;}
      public function restoreCheckpoint(s:Object,authority:Boolean,foreign:Boolean,retained:Boolean=false):void {
         if(String(s.key)!=roomKey())throw new Error("Fixture: foreign-room checkpoint");restores++;
      }
   }
}

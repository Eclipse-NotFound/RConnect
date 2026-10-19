package rconnect.game {
   import flash.display.*;
   import rconnect.core.MapGeneration;
   /** Native-world test double; RoomSync and the AIR display tree are real.
    * Native generation/checkpoint fidelity is covered by the separate game test. */
   public dynamic class GameBridge {
      public var world:Object,gg:Object,loc:Object,main:Sprite,mapGeneration:MapGeneration;
      public var roomHold:Boolean=false,independentRooms:Boolean=false,freezeAI:Boolean=false;
      public var roomEpoch:int=0,transition:Boolean=false,failRestore:Boolean=false;
      public var restores:int=0,restoreHook:Function;
      public function GameBridge(root:Sprite) {
         main=root;world={main:root,onPause:false,land:{act:{id:"map"},loc_t:0},gg:{},t_exit:0};
         for each(var name:String in ["vwait","vfon","visual","vscene","vblack","vpip","vsats","vgui","vstand","verror","vconsol"]) {
            world[name]=new Sprite();world[name].name=name;root.addChild(world[name]);
         }
         world.mm={active:false};world.allStat=1;
         world.vsats.visible=false;world.vpip.visible=false;
         setRoom("map//0,0,0",0xC02020);refreshWorld();
      }
      public function setRoom(key:String,color:uint):Object {
         world.loc={key:key,color:color,land:world.land,spaceX:12,spaceY:8};
         world.land.loc=world.loc;world.gg.loc=world.loc;refreshWorld();paint(color);return loc;
      }
      public function paint(color:uint):void {
         var s:Sprite=world.visual;s.graphics.clear();s.graphics.beginFill(color);
         s.graphics.drawRect(0,0,640,400);s.graphics.endFill();
      }
      public function refreshWorld():void{loc=world.loc;gg=world.gg;}
      public static function probe(o:Object,k:String):*{return o==null?null:o[k];}
      public function roomKey(room:Object=null):String{return String((room||loc).key);}
      public function readWorldInfo():Object {
         return {curLandId:world.land.act.id,curCoord:"",roomKey:roomKey(),roomEpoch:roomEpoch,
            landProb:"",landStage:0,worldReady:!transition,landX:0,landY:0,landZ:0};
      }
      public function isTransitioning():Boolean{return transition;}
      public function isPlayerDead():Boolean{return false;}
      public function releaseMovablesForHandoff():void{}
      public function followHostWorld(info:Object):String{return "skip-same-room";}
      public function followMapGeneration(info:Object):void{}
      public function startSharedTravel(info:Object):Boolean{return false;}
      public function inRoom(room:Object,fn:Function):* {
         var previous:Object=loc;loc=room;try{return fn();}finally{loc=previous;}
      }
      public function checkpoint():Object{return {key:roomKey(),color:loc.color,width:12,height:8};}
      public function roomRole(authority:Boolean):void{freezeAI=!authority;}
      public function restoreCheckpoint(s:Object,authority:Boolean,foreign:Boolean):void {
         restores++;if(restoreHook!=null)restoreHook();
         if(failRestore)throw new Error("injected restore failure");
         loc.color=uint(s.color);paint(loc.color);
      }
   }
}

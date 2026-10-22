package rconnect.core {
   /** One negotiated shared-map transaction. No simulation, network or native
    * control writes here. The renderer owns unpainted; RoomSync owns pause. */
   public final class EarlyTravelGate {
      private var w:Object,g:Object,player:Object,oldLand:Object,land:Object,loc:Object,renderer:Object;
      private var target:String="",seed:Number=0,originEpoch:int=0,token:String="";
      private var raster:Object,paintFrame:int=-1;
      public var constructed:Boolean=false,restored:Boolean=false,paintAllowed:Boolean=false;
      public var localReady:Boolean=false,peerReady:Boolean=false,ackSent:Boolean=false;
      public var barrier:int=0,epoch:int=0,anchor:Object;
      public function get active():Boolean{return token!="";}
      public function get id():String{return token;}
      public function get ticket():Object{return raster;}
      public function get ownerWorld():Object{return w;}
      public function get ownerGame():Object{return g;}
      public function get ownerPlayer():Object{return player;}
      public function arm(info:Object,world:Object,fromEpoch:int):Boolean {
         if(active || info==null || world==null || world.game==null || world.land==null || world.gg==null
            || !(info.earlyId is String) || info.earlyId=="" || info.earlyId.length>128
            || Number(info.earlyEpoch)!=fromEpoch || info.sceneMerged!==true
            || !(info.curLandId is String) || info.curLandId=="")return false;
         var n:Number=Number(info.layoutSeed),act:Object=world.game.lands[String(info.curLandId)];
         if(act==null || !isFinite(n) || n<0 || n>4294967295 || n!=Math.floor(n) || act.rnd && n==0)return false;
         w=world;g=world.game;player=world.gg;oldLand=world.land;target=String(info.curLandId);
         seed=n;originEpoch=fromEpoch;token=String(info.earlyId);return true;
      }
      public function sameWorld(world:Object):Boolean {
         return active && world===w && world!=null && world.game===g && world.gg===player;
      }
      public function safeWorld(world:Object):Boolean {
         return sameWorld(world) && int(world.t_die)<=0 && int(world.comLoad)<0 && int(world.ng_wait)<=0
            && int(world.t_exit)>=0 && (!constructed || int(world.t_exit)<=19);
      }
      public function matchesInfo(info:Object):Boolean {
         return active && info!=null && String(info.curLandId)==target && Number(info.layoutSeed)==seed
            && info.sceneMerged===true;
      }
      public function destination(world:Object,room:Object):Boolean {
         return safeWorld(world) && world.land!=null && world.land!==oldLand && room!=null
            && world.loc===room && room.land===world.land && String(world.game.curLandId)==target
            && String(world.land.act.id)==target && Number(world.land.rconnectLayoutSeed || 0)==seed;
      }
      public function open(world:Object,room:Object,visual:Object):Object {
         if(!destination(world,room) || visual==null || visual.scenePreload!==true && visual.sceneCullRender!==true)return null;
         if(raster!=null)return room===loc && world.land===land && visual===renderer?raster:null;
         land=world.land;loc=room;renderer=visual;raster={waiting:true,unpainted:true};return raster;
      }
      public function finishConstruction(world:Object):Boolean {
         if(constructed)return valid(world);
         if(raster==null || !destination(world,loc) || world.grafon!==renderer || int(world.t_exit)!=19)return false;
         constructed=true;return true;
      }
      public function valid(world:Object):Boolean {
         return constructed && destination(world,loc) && world.land===land && world.grafon===renderer;
      }
      public function acceptSeal(msg:Object):Boolean {
         if(!active || msg==null || String(msg.earlyId || "")!=token || !matchesInfo(msg.info)
            || Number(msg.epoch)!=originEpoch+1 || Number(msg.barrier)!=int(msg.barrier) || int(msg.barrier)<=0)return false;
         var a:Object=msg.info;
         if(!(a.roomKey is String) || a.roomKey=="" || a.x==null || a.y==null
            || !isFinite(Number(a.x)) || !isFinite(Number(a.y)))throw new Error("Early travel anchor missing");
         if(anchor!=null) {
            if(barrier!=int(msg.barrier) || epoch!=int(msg.epoch) || anchor.roomKey!==a.roomKey
               || anchor.x!==Number(a.x) || anchor.y!==Number(a.y))throw new Error("Early travel seal changed");
            return true;
         }
         barrier=int(msg.barrier);epoch=int(msg.epoch);anchor={roomKey:String(a.roomKey),x:Number(a.x),y:Number(a.y)};return true;
      }
      public function accepts(msg:Object):Boolean {
         return active && anchor!=null && msg!=null && String(msg.earlyId || "")==token
            && Number(msg.barrier)==barrier && Number(msg.epoch)==epoch;
      }
      public function allowPaint(world:Object,frame:int):void {
         if(!valid(world) || anchor==null || paintAllowed)throw new Error("Invalid early paint release");
         restored=true;paintAllowed=true;paintFrame=frame;raster.waiting=false;
      }
      public function viewReady(world:Object,frame:int):Boolean {
         if(localReady)return valid(world);
         if(!valid(world) || !paintAllowed || frame<=paintFrame || raster.unpainted!==false
            || int(world.t_exit)!=0 || int(world.comLoad)>=0 || int(world.t_die)>0 || int(world.ng_wait)>0)return false;
         if(renderer.sceneViewReady()!==true)return false;
         localReady=true;return true;
      }
      public function cancel():void {
         if(raster!=null)raster.waiting=false;
         w=g=player=oldLand=land=loc=renderer=raster=anchor=null;target=token="";seed=0;
         originEpoch=barrier=epoch=0;paintFrame=-1;
         constructed=restored=paintAllowed=localReady=peerReady=ackSent=false;
      }
   }
}

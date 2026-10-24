package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.filesystem.*;
   import rconnect.core.*;
   /** Full production RoomSync, TravelGuard and Gate. Native world, network
    * and unused page-click access are explicit fixtures, not native gameplay. */
   public class EarlyExitAuthorizationChecks extends Sprite {
      private var rows:Array=[],mods:Array=[],h:RConnectMod,j:RConnectMod;
      private var prep:Object,grant:Object,ht:Object,jt:Object;
      private function check(ok:Boolean,label:String):void {rows.push({passed:ok,label:label});}
      public function EarlyExitAuthorizationChecks(){addEventListener(Event.ADDED_TO_STAGE,begin);}
      private function begin(e:Event):void {
         try {
            for each(var cached:Boolean in [false,true])for each(var remaining:int in [19,10,1])lifecycle(remaining,cached);
            preGrantCancel();postGrantCancel();unauthorized();clear();
         }catch(error:Error){check(false,error+" "+error.getStackTrace());}
         var failed:int=0;for each(var r:Object in rows)if(!r.passed)failed++;
         var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         f.writeUTFBytes(JSON.stringify({passed:failed==0,failed:failed,assertions:rows,functional_only:true,native_runtime:false,
            fullTravelGuard:true,fullRoomSync:true}));f.close();NativeApplication.nativeApplication.exit(failed?1:0);
      }
      private function fields(m:RConnectMod):void {
         m.game.loc.units=[];m.game.loc.objs=[];m.game.loc.acts=[];m.game.loc.areas=[];
         m.game.loc.prob=null;m.game.loc.landProb="";m.game.world.land.scripts=[];
      }
      private function make(role:String):RConnectMod {
         var m:RConnectMod=new RConnectMod(stage);mods.push(m);m.session.mode=role;
         m.session.pause={paused:false};m.session.hostEarlyTravel=1;
         m.session.rooms=new RoomSync(m.session);m.session.rooms.epoch=1;m.game.roomEpoch=1;
         m.game.mapGeneration.earlyTravelSupported=true;
         m.game.world.game.lands.random_city={id:"random_city",rnd:true};
         m.game.world.game.curCoord="base";m.game.world.game.missionId="base-mission";
         m.game.world.grafon={scenePreload:false,sceneCullRender:true,sceneViewReady:function():Boolean{return true;}};
         m.game.world.pip={noAct:false};m.game.gg.ggControl=true;
         m.game.gg.offCount=0;m.game.gg.onCount=0;
         var player:Object=m.game.gg,world:Object=m.game.world;
         player.controlOff=function():void{player.offCount++;player.ggControl=false;world.pip.noAct=true;};
         player.controlOn=function():void{player.onCount++;player.ggControl=true;world.pip.noAct=false;};
         if(role==Session.HOSTING)m.session.peers=[{nativeTravel:1,earlyTravel:1}];fields(m);return m;
      }
      private function clear():void {
         for each(var m:RConnectMod in mods){m.session.mode=Session.OFFLINE;m.session.rooms.reset();}mods=[];
      }
      private function last(m:RConnectMod,op:String):Object {
         var found:Object,list:Array=m.session.mode==Session.HOSTING?m.session.outbox:m.session.link.messages;
         for each(var x:Object in list)if(x.op==op)found=x;return found;
      }
      private function count(m:RConnectMod,op:String):int {
         var n:int=0,list:Array=m.session.mode==Session.HOSTING?m.session.outbox:m.session.link.messages;
         for each(var x:Object in list)if(x.op==op)n++;return n;
      }
      private function start(cached:Boolean=false):void {
         clear();h=make(Session.HOSTING);j=make(Session.CONNECTED);
         // Capture the previous settled map, exactly the state that an early
         // endTravel previously restored during a still-running native exit.
         TravelGuard.guardTravel(j.game,j.session.rooms);
         h.game.world.t_exit=21;
         h.session.rooms.prepareMap({act:{id:"random_city",rnd:true,landStage:0,visited:cached},landDifLevel:29,sceneMerged:true},77,!cached);
         prep=last(h,"prepare");j.session.rooms.handle(prep);
         TravelGuard.guardTravel(j.game,j.session.rooms);
         check(j.game.world.t_exit==21 && j.game.world.game.curLandId=="random_city","prepare authorizes native exit with previous settled map; cached="+cached);
      }
      private function construct(m:RConnectMod,x:Number):Object {
         m.game.completeNative(prep.info);m.game.world.t_exit=19;m.game.transition=true;fields(m);
         m.game.gg.X=x;m.game.gg.Y=240;
         var ticket:Object=m.session.rooms.openFirstRaster(m.game.world,m.game.loc,m.game.world.grafon);
         m.session.rooms.nativeConstructed(m.game.world.game);return ticket;
      }
      private function build(cached:Boolean=false):void {
         start(cached);ht=construct(h,800);j.session.rooms.handle(last(h,"seal"));jt=construct(j,12);
         TravelGuard.guardTravel(j.game,j.session.rooms);
         h.session.rooms.handle(last(j,"ready"));grant=last(h,"grant");
      }
      private function frame():void{stage.dispatchEvent(new Event(Event.ENTER_FRAME));stage.dispatchEvent(new Event(Event.RENDER));}
      private function lifecycle(remaining:int,cached:Boolean):void {
         build(cached);var label:String=" grant@"+remaining+" cached="+cached;
         check(Boolean(prep.info.hostVisited)==cached,"first/revisit preparation preserves visited state"+label);
         j.game.world.t_exit=remaining;j.session.rooms.handle(grant);
         check(j.game.restores==1 && jt.waiting===false,"full grant restores once and releases drawing"+label);
         TravelGuard.guardTravel(j.game,j.session.rooms);
         check(j.game.world.t_exit==remaining && j.game.world.game.curLandId=="random_city","grant retains authorization for remaining native exit"+label);
         j.session.rooms.handle(grant);TravelGuard.guardTravel(j.game,j.session.rooms);
         check(j.game.restores==1 && j.game.world.t_exit==remaining,"duplicate grant neither imports twice nor revokes exit"+label);
         ht.unpainted=false;jt.unpainted=false;
         var kept:Boolean=true;
         for(var t:int=remaining;t>0;t--) {
            j.game.world.t_exit=t;j.game.transition=true;frame();
            kept=kept && j.game.world.t_exit==t && j.game.world.game.curLandId=="random_city" && j.session.rooms.earlyTravelPending;
         }
         check(kept,"actual RoomSync before/TravelGuard chain preserves every decreasing native counter"+label);
         check(count(j,"ack")==0,"painted nonzero exit cannot acknowledge"+label);
         j.game.world.t_exit=0;j.game.transition=false;frame();
         check(count(j,"ack")==1 && j.game.world.game.curLandId=="random_city","native exit zero becomes ready on the intended map"+label);
         if(last(j,"ack")==null)return;
         h.session.rooms.handle(last(j,"ack"));h.game.world.t_exit=0;h.game.transition=false;frame();
         check(count(h,"activate")==1,"both finished native countdowns activate once"+label);
         j.session.rooms.handle(last(h,"activate"));
         check(!j.session.rooms.earlyTravelPending && !j.session.rooms.busy && j.game.gg.ggControl,"activation completes and returns control"+label);
         var restores:int=j.game.restores,controls:int=j.game.gg.onCount;
         j.session.rooms.handle(grant);j.session.rooms.handle(last(h,"activate"));
         check(j.game.restores==restores && j.game.gg.onCount==controls,"retired grant and activation are inert"+label);
         TravelGuard.guardTravel(j.game,j.session.rooms);
         j.game.world.game.curLandId="unauthorized";j.game.world.t_exit=21;TravelGuard.guardTravel(j.game,j.session.rooms);
         check(j.game.world.t_exit==0 && j.game.world.game.curLandId=="random_city","completed authorization cannot grant a later independent trip"+label);
      }
      private function preGrantCancel():void {
         start();j.session.rooms.handle({type:"room",op:"earlyCancel",earlyId:prep.info.earlyId});
         j.game.world.t_exit=20;TravelGuard.guardTravel(j.game,j.session.rooms);
         check(!j.session.rooms.earlyTravelPending && j.game.world.t_exit==20 && j.game.world.game.curLandId=="random_city",
            "preconstruction optimization cancellation preserves the authorized legacy exit");
      }
      private function postGrantCancel():void {
         build();j.game.world.t_exit=10;j.session.rooms.handle(grant);
         j.session.rooms.handle({type:"room",op:"earlyCancel",earlyId:prep.info.earlyId});
         TravelGuard.guardTravel(j.game,j.session.rooms);
         check(j.session.rooms.busy && j.session.rooms.earlyTravelPending && j.game.world.onPause && j.game.world.t_exit==10,
            "postrestore cancellation remains fail-closed without undoing destination");
         j.session.mode=Session.OFFLINE;j.session.rooms.reset();
         check(!j.session.rooms.earlyTravelPending && !j.game.world.onPause && j.game.gg.ggControl,
            "disconnect cleans early hold and restores owned control");
         j.game.world.t_exit=0;TravelGuard.guardTravel(j.game,j.session.rooms);
         j.game.world.game.curLandId="other";j.game.world.t_exit=21;TravelGuard.guardTravel(j.game,j.session.rooms);
         check(j.game.world.t_exit==0 && j.game.world.game.curLandId=="random_city","disconnect reset removes old exit authorization");
      }
      private function unauthorized():void {
         clear();j=make(Session.CONNECTED);TravelGuard.guardTravel(j.game,j.session.rooms);
         j.game.world.game.curLandId="forbidden";j.game.world.t_exit=21;TravelGuard.guardTravel(j.game,j.session.rooms);
         check(j.game.world.t_exit==0 && j.game.world.game.curLandId=="map","unguarded independent travel is still blocked");
      }
   }
}

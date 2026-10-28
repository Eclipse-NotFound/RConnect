package {
 import flash.system.ApplicationDomain;
 import flash.utils.getTimer;
 /** Isolated driver only: native empty-room warmup and actual party map trips. */
 public final class BLoadingCases {
  private var mod:Object,api:Object,side:String,phase:int=0,trip:int=0,at:int=0;
  private var oldLand:Object,players:Array,loadingSeen:Boolean=false,joinSeen:int=-1;
  private var seedType:Class,oldSeed:Function,seedHook:Function;
  public function BLoadingCases(m:Object,r:Object,d:ApplicationDomain,c:Object,role:String,a:Object) {
   mod=m;api=a;side=role;at=getTimer();
  }
  public function input():void {
   var w:Object=mod.access.world;
   if(w.ctr!=null)for each(var key:String in ["keyLeft","keyRight","keyJump","keyAttack","keySit","keyRun","keyAction","keyTele"])w.ctr[key]=false;
  }
  private function warmup():void {
   var s:Object=mod.host,w:Object=mod.access.world,room:Object=null;
   for each(var column:Array in w.land.locs)for each(var row:Array in column)if(row!=null)for each(var r:Object in row)
    if(r!=null && !r.sky && r.prob==null && r!==s.actors[0].unit.loc && r!==s.actors[1].unit.loc){room=r;break;}
   if(room==null)throw new Error("Warmup fixture needs an unoccupied ordinary room");
   s.runtime.rooms.ensure(room);
   var Box:Class=mod.access.definition("fe.loc.Box"),Location:Class=mod.access.definition("fe.loc.Location"),box:Object;
   var previous:Function=Location["rconnectObjectStep"],calls:int=0;
   mod.access.scope.runRoom(s.actors[0].context,room,function():void {
    box=new Box(room,"term1",400,Math.floor((room.limY-120)/40)*40-1);
    room.objs.push(box);room.addObj(box);
   });
   api.check(s.security.owns(box.inter),"warmup fixture is a real native security terminal");
   var observer:Function=function(loc:Object,obj:Object):void {if(obj===box)++calls;previous(loc,obj);};
   try {
    Location["rconnectObjectStep"]=observer;
    room.preStep();
    api.check(calls==30,"native preStep routes all 30 terminal steps through the installed hook",{calls:calls});
    api.check(!w.verror.visible,"empty-room native warmup has no game error",String(w.verror.txt.text));
    // A record made before warmup ends would incorrectly retain -100 here.
    box.inter.lockAtt=13;
    api.check(s.security.capture(box.inter,0).lockAtt==13 && s.security.capture(box.inter,1).lockAtt==13,
     "personal terminal state is first captured after native initialization");
    api.check(w.gg===s.actors[0].unit && w.loc===s.actors[0].unit.loc && mod.access.scope.depth==0,
     "warmup preserves host room, player and native context");
   } finally {
    Location["rconnectObjectStep"]=previous;
    box.remVisual();room.remObj(box);var index:int=room.objs.indexOf(box);if(index>=0)room.objs.splice(index,1);
   }
  }
  private function beginTrip():void {
   var s:Object=mod.host,w:Object=mod.access.world;oldLand=w.land;loadingSeen=false;at=getTimer();
   for each(var actor:Object in s.actors){actor.unit.invulner=true;actor.unit.pers.healAll();}
   if(trip==1) {
    // Reproduce the user's recorded failing exploration, only in this fixture.
    seedType=mod.access.definition("fe.loc.Land");oldSeed=seedType["rconnectSeedSource"];
    seedHook=function(land:Object):uint {
     if(land.act.id!="random_mane")return uint(oldSeed(land));
     seedType["rconnectSeedSource"]=oldSeed;seedHook=null;return 1288542690;
    };
    seedType["rconnectSeedSource"]=seedHook;w.game.beginMission("random_mane");
   }else w.game.gotoLand("rbl",null,true);
   phase=2;
  }
  public function step():void {
   var w:Object=mod.access.world,s:Object=mod.host,control:Object;
   if(side=="join") {
    control=api.read("loading-control.json");if(control==null)return;
    if(control.done){api.write("loading-join-done.json",{done:true});api.finish();return;}
    var f:Object=mod.replica==null?null:mod.replica.lastFrame;
    if(f!=null && control.trip!=joinSeen && f.map.id==control.map && f.map.seed==control.seed && w.land.act.id==control.map && w.land.rconnectLayoutSeed==control.seed && mod.replica.scene.key==f.room && w.gg.ggControl) {
     joinSeen=control.trip;
     api.check(!w.verror.visible,"join renders confirmed destination "+joinSeen,{map:f.map.id,seed:f.map.seed,room:f.room});
     api.check(f.players[0].room==f.players[1].room,"both players reach the same destination "+joinSeen);
     api.write("loading-ack-"+joinSeen+".json",{trip:joinSeen,room:f.room,map:f.map.id,seed:f.map.seed});
    }
    return;
   }
   if(phase==0) {
    if(w.t_exit>0 || w.t_die>0 || !w.gg.ggControl)return;
    players=[s.actors[0].unit,s.actors[1].unit];warmup();
    if(w.verror.visible){api.finish();return;}
    beginTrip();return;
   }
   if(phase==4){if(api.read("loading-join-done.json")!=null)api.finish();return;}
   if(getTimer()-at>65000)throw new Error("Native map trip timed out: "+trip+" t_exit="+w.t_exit+" loading="+w.vwait.visible);
   if(phase==2) {
    if(w.vwait.visible)loadingSeen=true;
    if(w.land===oldLand || w.t_exit>0 || !w.gg.ggControl)return;
    api.check(loadingSeen && !w.vwait.visible,"host exits the native Loading screen "+trip,{seen:loadingSeen,t_exit:w.t_exit,visible:w.vwait.visible});
    api.check(w.gg===players[0] && s.actors[0].unit===players[0] && s.actors[1].unit===players[1] && w.loc===players[0].loc && mod.access.scope.depth==0,
     "native map travel preserves both player entities and restores host control "+trip);
    if(trip==1) {
     var terminals:int=0;
     for each(var column:Array in w.land.locs)for each(var row:Array in column)if(row!=null)for each(var room:Object in row)if(room!=null)
      for each(var object:Object in room.objs)if(object!=null && "inter" in object && s.security.owns(object.inter))++terminals;
     api.check(terminals>0 && seedHook==null && w.land.rconnectLayoutSeed==1288542690,
      "reported map seed generates native security terminals without a load error",{terminals:terminals,seed:w.land.rconnectLayoutSeed});
    }
    api.write("loading-control.json",{trip:trip,map:w.land.act.id,seed:w.land.rconnectLayoutSeed});phase=3;return;
   }
   if(phase==3 && api.read("loading-ack-"+trip+".json")!=null) {
    ++trip;if(trip<3)beginTrip();else {api.picture("host-loading-complete");api.write("loading-control.json",{done:true});phase=4;}
   }
  }
 }
}

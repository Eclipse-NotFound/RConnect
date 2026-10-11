package authority {
   import flash.display.DisplayObjectContainer;
   import flash.utils.getTimer;
   /** Real native lighting, RV public callbacks and two isolated network clients. */
   public final class VisionProbe extends Probe {
      private var home:Object,back:Object,fy:Number,by:Number,mid:int,cy:int;
      private var phase:int=-1,stageAt:int=0,remotePhase:int=-1,stageInfo:Object;
      private var carrier:Object,original:Object,merges:Array=[],captures:uint=0,full:uint=0,delta:uint=0;
      private var beforeReceived:uint=0,ownRoom:Object,sentMeet:Boolean=false,faults:uint=0;
      public function VisionProbe(a:NativeAccess,h:Boolean){super(a,h);}
      override public function prepare():void {
         super.prepare();RConnectMod.instance.preferences.setValue("sharedExploration","0");
      }
      override public function message(value:Object):void {
         if(value.type=="vision-stage")stageInfo=value;
         if(value.type=="vision-ready")remotePhase=value.phase;
         if(value.type=="exploration"){if(value.full)++full;else ++delta;}
      }
      override public function input(frame:Object,session:HostSession):Object {
         frame.buttons=0;return frame;
      }
      private function instrument():void {
         carrier=DisplayObjectContainer(RConnectMod.instance.main).getChildByName("RVExplorationAPI");
         if(carrier==null || carrier.api==null)throw new Error("Installed RV public exploration API is missing");
         original=carrier.api;
         carrier.api={version:1,active:function(room:Object):Boolean{return original.active(room);},
            capture:function(room:Object):Array {++captures;return original.capture(room);},
            merge:function(room:Object,rows:Array):Boolean {
               var ok:Boolean=original.merge(room,rows);
               if(ok)merges.push({room:access.keyFor(room),rows:rows.concat()});return ok;
            }};
      }
      private function setting(on:Boolean):void {
         var m:RConnectMod=RConnectMod.instance;m.preferences.setValue("sharedExploration",on?"1":"0");m.vision.enabled=on;
      }
      private function stage(session:HostSession,next:int):void {
         phase=next;stageAt=getTimer();setting(phase==1);
         session.link.send({type:"vision-stage",phase:phase,home:access.keyFor(home),back:access.keyFor(back),mid:mid,cy:cy});
      }
      private function mergedOther():Boolean {
         var key:String=stageInfo==null?access.keyFor(home):stageInfo.home,x:int=host?mid+4:mid-4;
         for each(var r:Object in merges)if(r.room==key && parseInt(r.rows[cy].charAt(x*17),16)>0)return true;
         return false;
      }
      private function nativeLight(x:int):Number{return Number(access.world.loc.space[x][cy].visi);}
      private function observations(index:int):void {
         var m:RConnectMod=RConnectMod.instance,w:Object=access.world;
         if(index==0) {
            check(original.active(w.loc)===true && captures>0,"RV computes actual local exploration in the authority scene");
            check(nativeLight(host?mid-4:mid+4)>.5 && nativeLight(host?mid+4:mid-4)==0,
               "native lighting belongs to the local viewpoint on opposite sides of a wall",{self:nativeLight(host?mid-4:mid+4),other:nativeLight(host?mid+4:mid-4)});
            check(m.vision.received==0,"disabled sharing accepts no new peer exploration");
            beforeReceived=m.vision.received;
         } else if(index==1) {
            check(m.vision.received>beforeReceived && full>0,"enabling exploration requests and accepts the full peer history");
            check(mergedOther(),"real RV merge receives the area hidden behind the wall");
            check(nativeLight(host?mid+4:mid-4)==0,"shared exploration never changes native interaction visibility");
            beforeReceived=m.vision.received;
            SceneChecks.picture(access,"shared-exploration.png");
         } else if(index==2) {
            check(m.vision.received==beforeReceived,"turning sharing off stops new packets while preserving accepted knowledge");
            check(mergedOther(),"switching sharing off preserves the previously accepted area");
         } else if(index==3 && !host) {
            check(access.world.loc!==ownRoom && access.keyFor(access.world.loc)==stageInfo.home,"background return reconstructs the same logical room with a fresh replica");
            check(nativeLight(mid+4)>.5,"own previously explored side survives a background-room round trip",{known:nativeLight(mid+4)});
         } else if(index==4) {
            var f:Object=host?m.host.lastFrame:m.replica.lastFrame;
            check(f.players[0].room===f.players[1].room && Math.abs(f.players[0].x-f.players[1].x)<5,
               "normal meet-peer intent returns only the requesting player to the teammate");
            check(full>0 && delta>0,"exploration transport includes an initial full state and changed rows",{full:full,delta:delta});
         }
      }
      private function exitBackground(session:HostSession,room:Object,x:Number,y:Number):void {
         var a:PlayerActor=session.actors[1];a.context.transitionCooldown=0;a.context.t_battle=0;a.unit.loc.t_alarm=0;
         access.scope.run(a.context,function():void {check(a.unit.outLoc(5,x,y),"native background door accepts the exploration visit");});
      }
      override public function observe(session:HostSession,replica:ClientReplica):void {
         if(finished)return;
         var m:RConnectMod=RConnectMod.instance;
         if(original==null)instrument();
         if(!host) {
            if(replica==null || replica.displayFrame==null || stageInfo==null)return;
            var f:Object=replica.displayFrame;
            if(phase!=stageInfo.phase) {
               if(stageInfo.phase==0 && f.room!==stageInfo.home)return;
               phase=stageInfo.phase;mid=stageInfo.mid;cy=stageInfo.cy;stageAt=getTimer();setting(phase==1);
               if(phase==0){m.vision.resetJourney();ownRoom=access.world.loc;}
               if(phase==4){m.meetPeer();sentMeet=true;}
            }
            if(remotePhase!=phase && getTimer()-stageAt>1800) {
               observations(phase);remotePhase=phase;m.link.send({type:"vision-ready",phase:phase});
               if(phase==4){carrier.api=original;finish();}
            }
            return;
         }
         if(session==null || !session.active)return;
         if(home==null) {
            for each(var col:Array in access.world.land.locs)for each(var row:Array in col)
               if(home==null && row!=null && row[0]!=null && row[1]!=null && !row[0].sky && !row[1].sky && row[0].spaceX>30) {home=row[0];back=row[1];}
            if(home==null)throw new Error("No ordinary foreground/background pair for exploration");
            fy=ProbeArena.floor(home);by=ProbeArena.floor(back);mid=int(home.spaceX/2);cy=int(fy/40)-1;
            for(var x:int=0;x<home.spaceX;x++)for(var y:int=0;y<home.spaceY;y++) {
               var t:Object=home.space[x][y];t.visi=t.t_visi=0;t.opac=t.phis?1:0;
               if(x==mid){t.phis=t.opac=1;t.indestruct=true;t.hp=100000;}
            }
            home.black=true;home.retDark=false;home.lDist1=300;home.lDist2=500;home.isRelight=true;access.world.black=true;
            session.runtime.transfers.relocate(session.actors[0],home,(mid-4)*40+20,fy);
            session.runtime.transfers.relocate(session.actors[1],home,(mid+4)*40+20,fy);
            session.runtime.rooms.showHost();m.vision.resetJourney();stage(session,0);return;
         }
         if(remotePhase!=phase || getTimer()-stageAt<2400)return;
         observations(phase);
         if(phase==0)stage(session,1);
         else if(phase==1)stage(session,2);
         else if(phase==2){exitBackground(session,back,400,by);stage(session,25);}
         else if(phase==25){exitBackground(session,home,(mid-4)*40+20,fy);stage(session,3);}
         else if(phase==3){exitBackground(session,back,400,by);stage(session,35);}
         else if(phase==35)stage(session,4);
         else if(phase==4){carrier.api=original;finish();}
      }
   }
}

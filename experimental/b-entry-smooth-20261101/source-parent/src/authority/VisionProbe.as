package authority {
   import flash.display.DisplayObjectContainer;
   import flash.utils.getTimer;
   /** Real native lighting, RV public callbacks and two isolated network clients. */
   public final class VisionProbe extends Probe {
      private var home:Object,back:Object,fy:Number,by:Number,mid:int,cy:int;
      private var phase:int=-1,stageAt:int=0,remotePhase:int=-1,stageInfo:Object;
      private var carrier:Object,original:Object,merges:Array=[],captures:uint=0,full:uint=0,delta:uint=0;
      private var beforeReceived:uint=0,ownRoom:Object,sentMeet:Boolean=false,faults:uint=0;
      private var viewTargets:Array=[];
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
         session.actors[0].unit.pers.infravis=phase==1;
         session.actors[1].unit.pers.infravis=phase==0;
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
         if(index>=0 && index<=2) {
            var infrared:Boolean=index==0?!host:index==1?host:false;
            check(Boolean(w.pers.infravis)==infrared && w.grafon.visLight.blendMode==(infrared?"multiply":"normal"),
               "native infrared tint belongs to the local character, including removal",{phase:index,infrared:infrared,blend:w.grafon.visLight.blendMode});
         }
         if(index==0) {
            check(original.active(w.loc)===true && captures>0,"RV computes actual local exploration in the authority scene");
            check(nativeLight(host?mid-4:mid+4)>.5 && nativeLight(host?mid+4:mid-4)==0,
               "native lighting belongs to the local viewpoint on opposite sides of a wall",{self:nativeLight(host?mid-4:mid+4),other:nativeLight(host?mid+4:mid-4)});
            check(m.vision.received==0,"disabled sharing accepts no new peer exploration");
            beforeReceived=m.vision.received;
            if(host)remoteSatsSight(m.host);
            if(host)lateViewRead(m.host);
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
      private function viewState():Array {
         var state:Array=[];
         for each(var u:Object in access.world.loc.units)if(u.vis!=null)
            state.push([u.vis,u.vis.visible,u.vis.mask,u.vis.cacheAsBitmap,u.prior]);
         for each(var layer:DisplayObjectContainer in access.world.grafon.visObjs) {
            var children:Array=[];for(var i:int=0;i<layer.numChildren;i++)children.push(layer.getChildAt(i));
            state.push(children);
         }
         return state;
      }
      private function sameView(a:Array,b:Array):Boolean {
         if(a.length!=b.length)return false;
         for(var i:int=0;i<a.length;i++) {
            if(a[i].length!=b[i].length)return false;
            for(var j:int=0;j<a[i].length;j++)if(a[i][j]!==b[i][j])return false;
         }
         return true;
      }
      private function lateViewRead(s:HostSession):void {
         var local:Array=viewState(),raw:Boolean=false,threw:Boolean=false;
         raw=access.view.readNative(function():Boolean {
            return viewTargets[0].vis.visible && viewTargets[1].vis.visible;
         });
         check(!viewTargets[1].vis.visible && viewTargets[0].vis.visible,"host local RV hides the real far-side enemy and keeps its near-side enemy visible");
         check(raw && sameView(local,viewState()),"late native capture sees both bodies then restores every host visibility, mask and layer index");
         try {access.view.readNative(function():void {throw new Error("intentional native reader failure");});}catch(expected:Error){threw=true;}
         check(threw && sameView(local,viewState()),"failed native reader restores the exact host RV view and propagates the error");
         var transported:Boolean=true;
         for each(var target:Object in viewTargets) {
            var found:Boolean=false;
            for each(var u:Object in s.lastFrame.scene.units)if(u.key==s.sceneId(target))found=u.pose!=null && u.pose.v;
            transported=transported && found;
         }
         check(transported,"published confirmed enemy poses exclude host-only RV occlusion");
      }
      private function remoteSatsSight(s:HostSession):void {
         var remote:PlayerActor=s.actors[1],room:Object=remote.unit.loc,Type:Class=access.definition("fe.unit.UnitZombie");
         var clear:Object=new Type("1",10,<unit tr="1" dig="0"/>,null);
         var blocked:Object=new Type("1",10,<unit tr="1" dig="0"/>,null);
         clear.putLoc(room,(mid+6)*40+20,fy);blocked.putLoc(room,(mid-4)*40+20,fy);
         room.units.push(clear,blocked);
         var originalSpace:Array=room.space,originalBitmap:Object=room.grafon.lightBmp,lightBefore:Array=[];
         for(var x:int=0;x<room.spaceX;x++)for(var y:int=0;y<room.spaceY;y++)lightBefore.push(room.space[x][y].visi,room.space[x][y].t_visi);
         var originalPixels:Vector.<uint>=originalBitmap.getVector(originalBitmap.rect),lightSame:Boolean=true;
         var clearId:uint=s.sceneId(clear),blockedId:uint=s.sceneId(blocked);
         try {
            remote.sight.update();
            check(remote.sight.visible(clear) && !clear.getTileVisi(),
               "remote SATS eligibility uses its own native exploration beyond the host's dark wall");
            check(!remote.sight.visible(blocked),"remote native sight does not inherit the host's explored side of the wall");
            access.scope.run(remote.context,function():void {
               remote.context.sats.od=remote.unit.pers.maxOd;
               SatsActions.execute(remote,[{target:clearId,x:clear.X,y:clear.Y-30}]);
               check(remote.context.sats.que.length==1,"authoritative SATS accepts the joining player's visible target beyond the host's view");
               SatsActions.execute(remote,[{target:blockedId,x:blocked.X,y:blocked.Y-30}]);
               check(remote.context.sats.que.length==0,"authoritative SATS rejects a target behind the joining player's wall");
               remote.context.sats.clearAll();
            });
            var at:int=0;for(x=0;x<room.spaceX;x++)for(y=0;y<room.spaceY;y++)
               lightSame=lightSame && room.space[x][y].visi===lightBefore[at++] && room.space[x][y].t_visi===lightBefore[at++];
            var after:Vector.<uint>=originalBitmap.getVector(originalBitmap.rect);
            for(at=0;at<after.length;at++)lightSame=lightSame && after[at]===originalPixels[at];
            check(lightSame && room.space===originalSpace && room.grafon.lightBmp===originalBitmap && access.world.gg===s.actors[0].unit,
               "remote native light and SATS checks leave every host light value, pixel and controller unchanged");
         }finally {
            for each(var target:Object in [clear,blocked]){target.remVisual();var index:int=room.units.indexOf(target);if(index>=0)room.units.splice(index,1);}
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
            var Type:Class=access.definition("fe.unit.UnitZombie");
            for each(var side:int in [-1,1]) {
               var foe:Object=new Type("1",10,<unit tr="1" dig="0"/>,null);
               foe.putLoc(home,(mid+side*6)*40+20,fy);home.units.push(foe);
               foe.invulner=true;foe.disabled=false;foe.doop=true;foe.hp=foe.maxhp=5000;
               foe.addVisual();foe.setVisPos();foe.animate();foe.vis.visible=true;viewTargets.push(foe);
            }
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

package {
   import flash.desktop.NativeApplication;
   import flash.display.DisplayObject;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.geom.Point;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   import rconnect.core.TeammateNavigation;
   import rconnect.core.TravelGuard;
   import rconnect.game.GameBridge;
   import rconnect.net.NetMessageEvent;
   import rconnect.net.TcpLink;

   /** Real TCP departures with a temporarily unavailable destination in the
    * follower's native Land table. No private production state is replaced.
    * The old candidate must lose the retry, rather than fail test-only loading.
    * Run in random_mane; both clients need the same generated map as usual. */
   public class FollowRecoveryTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private static const CASES:Array=[{follower:"join",kind:"retry"},{follower:"host",kind:"retry"},
         {follower:"join",kind:"retarget"},{follower:"host",kind:"cancel"}];
      private var mod:RConnectMod,host:Boolean,timer:Timer=new Timer(100),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=getTimer(),readyAt:int=0,round:int=0;
      private var rooms:Array,blocked:Object,blockedRow:Array,blockedIndex:int;
      private var originKey:String="",expectedKey:String="",seenKey:String="",anchor:Object;
      private var gun:Object,oldGun:Object,oldChildren:Object,hooked:Boolean=false;
      private var sawDeparture:Boolean=false,departureAt:int=0,remoteSamples:int=0,remoteWrong:int=0;
      private var firstArrival:Boolean=false,visitedBlocked:Boolean=false,donePeer:Boolean=false;

      public function FollowRecoveryTestDoc() {
         var app:String=NativeApplication.nativeApplication.applicationID;if(app.indexOf("rconnect-coop-")<0)return;
         host=app.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();abort();
         });timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,s:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"follow-recovery "+s+" round="+round);}
      private function change(s:String):void {phase=s;at=getTimer();Log.d("FOLLOW RECOVERY "+(host?"host ":"join ")+s+" round="+round);}
      private function follower():Boolean {return (CASES[round].follower=="host")==host;}
      private function stable():Boolean {return mod.session.rooms.ready&&!mod.session.rooms.busy&&!mod.game.isTransitioning();}
      private function info(l:Object):Object {return {landX:l.landX,landY:l.landY,landZ:l.landZ,landProb:l.landProb,key:mod.game.roomKey(l)};}
      private function send(op:String,p:Object=null):void {
         if(mod==null||mod.session==null)return;p=p||{};p.type="follow-recovery-test";p.op=op;p.round=round;
         if(host&&mod.session.server!=null)mod.session.server.broadcast(p);else if(!host&&mod.session.link!=null)mod.session.link.send(p);
      }
      private function watch(l:TcpLink):void {if(l!=null&&!links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);}}
      private function pose(u:Object,w:Object):Object {
         var body:DisplayObject=GameBridge.probe(u,"vis") as DisplayObject,v:DisplayObject=GameBridge.probe(w,"vis") as DisplayObject;
         if(body==null||body.parent==null||v==null||v.stage==null)return null;
         var point:Point=body.parent.globalToLocal(v.localToGlobal(new Point()));
         return {x:point.x-Number(u.X),y:point.y-Number(u.Y)};
      }
      private function closeWeapon(u:Object,w:Object):Boolean {
         var p:Object=pose(u,w),ok:Boolean=p!=null&&Math.abs(p.x)<=130&&Math.abs(p.y)<=140;
         if(!ok) {
            var body:DisplayObject=GameBridge.probe(u,"vis") as DisplayObject,v:DisplayObject=GameBridge.probe(w,"vis") as DisplayObject;
            var point:Point=body!=null && body.parent!=null && v!=null?body.parent.globalToLocal(v.localToGlobal(new Point())):null;
            Log.d("FOLLOW WEAPON DIAGNOSTIC "+JSON.stringify({phase:phase,round:round,role:host?"host":"join",pose:p,
               x:u.X,y:u.Y,wx:w.X,wy:w.Y,bodyX:body==null?null:body.x,bodyY:body==null?null:body.y,
               bodyStage:body!=null&&body.stage!=null,weaponStage:v!=null&&v.stage!=null,
               sameParent:body!=null&&v!=null&&body.parent===v.parent,
               rawX:point==null?null:point.x-Number(u.X),rawY:point==null?null:point.y-Number(u.Y),
               active:mod.game.loc.active,trigDis:u.trigDis,weaponLoc:w.loc===mod.game.loc}));
         }
         return ok;
      }
      private function equip():void {
         if(gun!=null)return;
         var g:Object=mod.game.gg,c:Object=mod.main.loaderInfo.applicationDomain.getDefinition("fe.weapon.Weapon");
         oldGun=g.currentWeapon;oldChildren=g.childObjs;
         gun=c.create(g,"lmg",0);gun.setPers(g,g.pers);gun.addVisual();g.currentWeapon=gun;g.childObjs=[gun];
         gun.hold=41;g.celX=g.X+400;g.celY=g.Y-60;g.setVisPos();g.setWeaponPos(gun.tip);gun.setNull();
         check(closeWeapon(g,gun),"native LMG starts attached near its owner");
      }
      private function teleport(i:Object,far:Boolean=false):void {
         anchor=null;TravelGuard.follow(mod.game,i);
         if(far) {
            var g:Object=mod.game.gg,p:Object={landX:i.landX,landY:i.landY,landZ:i.landZ,landProb:"",
               x:Number(g.X)<Number(mod.game.loc.limX)/2?Number(mod.game.loc.limX)-170:170,y:g.Y};
            var oldX:Number=g.X,oldY:Number=g.Y;
            gun.t_attack=17;gun.t_reload=23;var ammo:Number=gun.hold;
            TravelGuard.follow(mod.game,p);
            check(Math.abs(g.X-oldX)>300,"native same-room relocation spans more than 300 pixels");
            check(closeWeapon(g,gun),"local weapon moves with the player in the teleport call");
            check(gun.t_attack==17&&gun.t_reload==23&&gun.hold==ammo,"same-room placement preserves cooldown, reload and ammo");
            var snapshot:Object=mod.game.readSnapshot(),display:Object;
            for each(var s:Object in snapshot.weapons)if(s.main===true)display=s.display;
            check(display!=null&&Math.abs(display.x)<=130&&Math.abs(display.y)<=140,"first outgoing native weapon pose has no old-room offset");
            gun.t_attack=gun.t_reload=0;
         }
         anchor={key:mod.game.roomKey(),x:mod.game.gg.X,y:mod.game.gg.Y};seenKey=anchor.key;
      }
      private function restoreBlocked():void {
         if(blockedRow!=null){blockedRow[blockedIndex]=blocked;blockedRow=null;blocked=null;}
      }
      private function prepare(n:int):void {
         restoreBlocked();round=n;mod.config.setValue("followTeammate","0");mod.game.forceCloseOverlays();
         sawDeparture=firstArrival=visitedBlocked=donePeer=false;remoteSamples=remoteWrong=0;expectedKey="";
         teleport(rooms[0]);equip();originKey=rooms[0].key;change("align");
      }
      private function arm():void {
         if(follower()) {
            var target:Object=rooms[1];blockedRow=mod.game.world.land.locs[int(target.landX)][int(target.landY)];
            blockedIndex=int(target.landZ);blocked=blockedRow[blockedIndex];
            check(blocked!=null&&blocked!==mod.game.loc,"fault removes only an inactive destination");blockedRow[blockedIndex]=null;
            mod.config.setValue("followTeammate","1");expectedKey=rooms[1].key;
         }
         change("armed");
      }
      private function depart():void {
         if(!follower())teleport(rooms[1],true);
         change("departed");
      }
      private function before(e:Event):void {
         if(phase=="done"||mod==null||mod.game.gg==null)return;
         // Unit.addVisual refuses disabled units during native room entry.
         // Keep the actual player active and still by clearing test input.
         var g:Object=mod.game.gg;g.invulner=true;g.disabled=false;g.dx=g.dy=0;
         mod.game.world.ctr.clearAll();
         if(anchor!=null&&mod.game.roomKey()==anchor.key){g.setPos(anchor.x,anchor.y);g.setVisPos();}
      }
      private function afterFollow(e:Event):void {
         if(phase=="done"||mod==null||gun==null)return;
         var key:String=mod.game.roomKey(),g:Object=mod.game.gg;
         if(key!=seenKey) {
            if(follower()&&expectedKey!="") {
               if(key==rooms[1].key)visitedBlocked=true;
               if(key==expectedKey) {
                  firstArrival=true;check(closeWeapon(g,gun),"first frame after automatic follow has no local weapon drift");
               }
            }
            seenKey=key;anchor={key:key,x:g.X,y:g.Y};
         }
      }
      private function render(e:Event):void {
         if(phase!="sampling"||mod==null||follower())return;
         var remote:Object=mod.game.getRemoteGhost(host?1:0);
         if(remote==null||GameBridge.probe(remote,"currentWeapon")==null)return;
         if(pose(remote,remote.currentWeapon)==null)return;
         remoteSamples++;if(!closeWeapon(remote,remote.currentWeapon))remoteWrong++;
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;if(p.type!="follow-recovery-test"||phase=="done")return;
         try {
            if(p.op=="done"){finish();return;}
            if(host&&p.op=="ready"&&phase=="boot") {
               rooms=[];
               for each(var col:Array in mod.game.world.land.locs)if(col)for each(var row:Array in col)if(row)
                  for each(var l:Object in row)if(l&&l.landZ==0&&!TravelGuard.restricted(l))rooms.push(info(l));
               check(rooms.length>=3,"three ordinary rooms available for retry and replacement");
               if(rooms.length<3){abort();return;}
               send("prepare",{rooms:rooms});prepare(0);
            } else if(!host&&p.op=="prepare") {rooms=p.rooms;prepare(int(p.round));}
            else if(host&&p.op=="aligned"&&phase=="align") {donePeer=true;}
            else if(!host&&p.op=="arm") {arm();send("armed");}
            else if(host&&p.op=="armed") {change("arm-wait");}
            else if(!host&&p.op=="depart")depart();
            else if(p.op=="retarget"&&!follower()) {teleport(rooms[2],true);send("retargeted");}
            else if(p.op=="retargeted"&&follower()) {expectedKey=rooms[2].key;change("recover");}
            else if(p.op=="arrived"&&!follower()) {change("sampling");}
            else if(p.op=="sampled"&&follower()) {send("case-done");if(host)next();else change("wait-next");}
            else if(p.op=="case-done"&&host)next();
         }catch(error:Error){check(false,"receive "+error.getStackTrace());abort();}
      }
      private function next():void {
         if(round+1==CASES.length){send("done");finish();return;}
         round++;send("prepare",{rooms:rooms});prepare(round);
      }
      private function tick(e:TimerEvent):void {
         if(phase=="done")return;mod=RConnectMod.instance;
         if(mod==null||mod.session==null||mod.game.gg==null||mod.game.loc==null)return;
         try {
            if(host&&mod.session.server!=null)for each(var p:Object in mod.session.peers)watch(p.link);else if(!host)watch(mod.session.link);
            if(!hooked) {
               hooked=true;mod.stage.addEventListener(Event.ENTER_FRAME,before,false,100100);
               mod.stage.addEventListener(Event.ENTER_FRAME,afterFollow,false,99999);
               mod.stage.addEventListener(Event.RENDER,render,false,-30000);
            }
            if(phase=="boot") {
               if(!stable()||mod.game.readWorldInfo().curLandId!="random_mane")return;
               mod.config.setValue("followTeammate","0");
               if(!host&&getTimer()-readyAt>600){readyAt=getTimer();send("ready");}
               return;
            }
            if(getTimer()-at>45000){check(false,"timeout "+phase+" room="+mod.game.roomKey());abort();return;}
            if(!stable())return;
            var elapsed:int=getTimer()-at;
            if(phase=="align"&&mod.game.roomKey()==originKey&&elapsed>1500) {
               mod.navigation.refresh();var peer:Object=mod.navigation.teammate();
               if(peer==null||peer.snap.roomKey!=originKey)return;
               if(!host)send("aligned");
               else if(donePeer){arm();send("arm");}
            } else if(host&&phase=="arm-wait"&&elapsed>600) {send("depart");depart();}
            else if(follower()&&phase=="departed") {
               mod.navigation.refresh();peer=mod.navigation.teammate();
               if(peer!=null&&peer.snap.roomKey==rooms[1].key&&!sawDeparture) {
                  sawDeparture=true;departureAt=getTimer();
                  check(mod.game.roomKey()==originKey&&blockedRow!=null,"real peer departure received while destination unavailable");
               }
               if(sawDeparture&&getTimer()-departureAt>2500) {
                  check(mod.game.roomKey()==originKey,"failed follow leaves the local player in the original room");
                  if(CASES[round].kind=="cancel") {
                     mod.config.setValue("followTeammate","0");restoreBlocked();change("cancel-wait");
                  } else if(CASES[round].kind=="retarget") {expectedKey=rooms[2].key;send("retarget");change("retarget-wait");}
                  else {restoreBlocked();change("recover");}
               }
            } else if(follower()&&phase=="recover"&&mod.game.roomKey()==expectedKey) {
               check(firstArrival,"retry reaches the teammate without toggling follow or another departure");
               if(CASES[round].kind=="retarget")check(!visitedBlocked,"replacement cancels the old unavailable destination");
               check(mod.game.world.gg===mod.game.gg&&mod.game.gg.loc===mod.game.loc,"native local player retains ownership after handoff");
               restoreBlocked();send("arrived");change("wait-sample");
            } else if(follower()&&phase=="cancel-wait"&&elapsed>2200) {
               check(mod.game.roomKey()==originKey,"turning follow off cancels the pending retry");
               mod.config.setValue("followTeammate","1");change("reenable-wait");
            } else if(follower()&&phase=="reenable-wait"&&elapsed>1800) {
               check(mod.game.roomKey()==originKey,"reenabling does not resurrect the cancelled departure");send("case-done");if(host)next();
            } else if(!follower()&&phase=="sampling") {
               mod.stage.invalidate();
               if(elapsed>1800) {
                  check(remoteSamples>=8,"teammate's post-travel weapon is attached in final display frames="+remoteSamples);
                  check(remoteSamples>=8&&remoteWrong==0,"teammate's weapon stays near its owner on the other client wrong="+remoteWrong);
                  send("sampled");change("wait-next");
               }
            }
         }catch(error:Error){check(false,"tick "+error.getStackTrace());abort();}
      }
      private function abort():void {send("done");finish();}
      private function finish():void {
         if(phase=="done")return;restoreBlocked();phase="done";timer.stop();
         if(mod!=null) {
            mod.config.setValue("followTeammate","0");
            mod.stage.removeEventListener(Event.ENTER_FRAME,before);mod.stage.removeEventListener(Event.ENTER_FRAME,afterFollow);
            mod.stage.removeEventListener(Event.RENDER,render);
            if(gun!=null){gun.remVisual();mod.game.gg.currentWeapon=oldGun;mod.game.gg.childObjs=oldChildren;}
         }
         Log.d("COOP EFFECTS DONE follow-recovery "+(host?"host":"join"));
      }
   }
}

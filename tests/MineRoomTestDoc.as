package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.TimerEvent;
   import flash.events.MouseEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import flash.utils.getQualifiedClassName;
   import rconnect.core.Log;
   import rconnect.core.TravelGuard;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;

   /** Native placement, real ordinary-room travel and native disarming. The
    * test never calls PlayerMines or substitutes a checkpoint implementation. */
   public class MineRoomTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var mod:RConnectMod,host:Boolean,t:Timer=new Timer(100),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=getTimer(),readyAt:int=0;
      private var origin:Object,away:Object,mine:Object,damage:Number=0,lastView:Object;
      public function MineRoomTestDoc() {
         var id:String=NativeApplication.nativeApplication.applicationID;if(id.indexOf("rconnect-coop-")<0)return;host=id.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();send("done");finish();
         });t.addEventListener(TimerEvent.TIMER,tick);t.start();
      }
      private function check(ok:Boolean,s:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"mine-room "+s);}
      private function phaseTo(s:String):void {phase=s;at=getTimer();}
      private function send(op:String,p:Object=null):void {p=p||{};p.type="mine-room-test";p.op=op;if(host)mod.session.server.broadcast(p);else mod.session.link.send(p);}
      private function watch(l:TcpLink):void {if(l!=null&&!links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);}}
      private function info(room:Object):Object {return {landX:room.landX,landY:room.landY,landZ:room.landZ,landProb:room.landProb,key:mod.game.roomKey(room)};}
      private function go(where:Object):void {TravelGuard.follow(mod.game,where);}
      private function live():Array {var a:Array=[];for each(var u:Object in mod.game.loc.units)if(getQualifiedClassName(u)=="fe.unit::Mine"&&u.fraction==100&&u.id=="x37"&&u.sost<4)a.push(u);return a;}
      private function inspect(nativeOwner:Boolean,label:String):void {
         var a:Array=live();check(a.length==1,label+" exactly one planted mine count="+a.length);
         if(a.length!=1)return;mine=a[0];
         check(nativeOwner==Boolean(mod.session.rooms.authority),label+" correct room authority");
         check(nativeOwner?(mine.in_chain&&!mine.disabled):(!mine.in_chain&&mine.disabled),label+" one simulation or inert mirror");
         Log.d("MINE ROOM VIEW "+JSON.stringify({label:label,room:mod.game.roomKey(),active:mod.game.loc.active,
            x:mine.X,y:mine.Y,playerX:mod.game.gg.X,playerY:mod.game.gg.Y,isVis:mine.isVis,
            hasVis:mine.vis!=null,stage:mine.vis!=null&&mine.vis.stage!=null,
            parent:mine.vis==null||mine.vis.parent==null?null:getQualifiedClassName(mine.vis.parent),
            visible:mine.vis==null?null:mine.vis.visible,alpha:mine.vis==null?null:mine.vis.alpha,wire:lastView}));
         check(mine.vis!=null&&mine.vis.stage!=null&&mine.vis.visible,label+" native mine visual present");
         if(nativeOwner)check(Math.abs(mine.damage1-damage)<.0001&&mine.reloadTime==0,label+" damage/arming progress retained");
      }
      private function place():void {
         var g:Object=mod.game.gg,c:Object=mod.main.loaderInfo.applicationDomain.getDefinition("fe.weapon.Weapon");
         var w:Object=c.create(g,"x37",0),old:Object=g.currentWeapon,children:Object=g.childObjs;
         w.setPers(g,g.pers);w.lvl=0;w.addVisual();g.currentWeapon=w;g.childObjs=[w];g.invent.items.x37.kol=2;
         w.step();w.attack(true);w.step();w.remVisual();g.currentWeapon=old;g.childObjs=children;
         var a:Array=live();check(a.length==1&&g.invent.items.x37.kol==1,"real WThrow consumes one radio mine");
         if(a.length==1){mine=a[0];damage=mine.damage1;}
         send("placed",{origin:origin,away:away,damage:damage});phaseTo("arming");
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;
         if(p.type=="player-mines"&&p.op=="state")lastView=p;
         if(p.type!="mine-room-test")return;
         if(p.op=="done"){finish();return;}
         if(host&&p.op=="ready"&&phase=="boot") {
            origin=info(mod.game.loc);
            // Native listLocs contains separately built challenge rooms. The
            // ordinary map, including its background layers, lives in locs.
            for each(var column:Object in mod.game.world.land.locs)for each(var row:Object in column)
               for each(var room:Object in row)if(room!=null&&room!==mod.game.loc&&!TravelGuard.restricted(room)&&String(room.landProb)==""){away=info(room);break;}
            check(away!=null&&!TravelGuard.restricted(mod.game.loc),"two ordinary rooms available");
            if(away==null){send("done");finish();return;}place();
         }else if(!host&&p.op=="placed"){origin=p.origin;away=p.away;damage=p.damage;phaseTo("mirror");}
         else if(host&&p.op=="mirrored") {phaseTo("wait-armed");}
         else if(!host&&p.op=="promote")phaseTo("promoted");
         else if(host&&p.op=="promoted") {send("vacate");phaseTo("wait-vacated");}
         else if(!host&&p.op=="vacate"){go(away);phaseTo("vacated");}
         else if(host&&p.op=="vacated"){go(origin);phaseTo("revisit");}
         else if(!host&&p.op=="rejoin"){go(origin);phaseTo("rejoined");}
         else if(host&&p.op=="rejoined") {
            inspect(true,"reunited host");mine.remine();check(mine.sost==4,"native disarming retires mine");send("disarmed");phaseTo("wait-disarmed");
         }else if(!host&&p.op=="disarmed")phaseTo("disarmed");
         else if(host&&p.op=="disarmed") {go(away);send("leave-dead");phaseTo("dead-away");}
         else if(!host&&p.op=="leave-dead"){go(away);phaseTo("dead-away");}
         else if(host&&p.op=="dead-vacated") {go(origin);phaseTo("dead-revisit");}
         else if(!host&&p.op=="dead-return"){go(origin);phaseTo("dead-revisit");}
         else if(host&&p.op=="dead-checked"){send("done");finish();}
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null||mod.game==null||mod.game.gg==null)return;
         if(host&&mod.session.server!=null)for each(var p:Object in mod.session.peers)watch(p.link as TcpLink);else watch(mod.session.link);
         if(mod.game.world.clickReq==1){mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN,true));mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP,true));}
         if(getTimer()-at>65000){check(false,"timeout "+phase);send("done");finish();return;}
         if(!mod.session.rooms.ready||mod.session.rooms.busy||mod.game.isTransitioning())return;
         var g:Object=mod.game.gg;g.invulner=true;g.disabled=true;g.dx=g.dy=0;mod.config.setValue("followTeammate","0");mod.stage.invalidate();
         if(phase=="boot"&&!host&&t.currentCount>180&&getTimer()-readyAt>500){readyAt=getTimer();send("ready");}
         if(phase=="mirror"&&!host&&getTimer()-at>1500){inspect(false,"initial joining view");send("mirrored");phaseTo("wait-promoted");}
         if(phase=="wait-armed"&&host&&mine!=null&&mine.reloadTime==0){send("promote");go(away);phaseTo("wait-promoted");}
         if(phase=="promoted"&&!host&&mod.game.roomKey()==origin.key&&mod.session.rooms.authority&&getTimer()-at>1500) {
            inspect(true,"joining endpoint promoted");send("promoted");phaseTo("wait-vacate");
         }
         if(phase=="vacated"&&!host&&mod.game.roomKey()==away.key){send("vacated");phaseTo("wait-rejoin");}
         if(phase=="revisit"&&host&&mod.game.roomKey()==origin.key&&getTimer()-at>1000){inspect(true,"empty-room revisit");send("rejoin");phaseTo("wait-rejoin");}
         if(phase=="rejoined"&&!host&&mod.game.roomKey()==origin.key&&getTimer()-at>1200){inspect(false,"rejoined mirror");send("rejoined");phaseTo("wait-disarm");}
         if(phase=="disarmed"&&!host&&getTimer()-at>1200){check(live().length==0,"native disarming removes mirror");send("disarmed");phaseTo("wait-leave");}
         if(phase=="dead-away"&&!host&&mod.game.roomKey()==away.key&&getTimer()-at>1200){send("dead-vacated");phaseTo("wait-dead-return");}
         if(phase=="dead-revisit"&&mod.game.roomKey()==origin.key&&getTimer()-at>1200){check(live().length==0,"retired mine remains absent after empty-room revisit");
            if(host){send("dead-return");phaseTo("wait-dead-checked");}else{send("dead-checked");phaseTo("wait-done");}}
      }
      private function finish():void {if(phase=="done")return;phaseTo("done");t.stop();Log.d("COOP EFFECTS DONE mine-room "+(host?"host":"join"));}
   }
}

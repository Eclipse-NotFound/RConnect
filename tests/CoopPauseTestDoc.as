package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.display.DisplayObjectContainer;
   import flash.display.BitmapData;
   import flash.display.PNGEncoderOptions;
   import flash.events.MouseEvent;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.text.TextField;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import fe.unit.Unit;
   import fe.loc.Location;
   import rconnect.core.Log;
   import rconnect.core.TravelGuard;
   import rconnect.game.GameBridge;
   import rconnect.net.NetMessageEvent;
   import rconnect.net.TcpLink;

   /** Real native menus/SATS, actual World.step clock, authenticated TCP on both sides. */
   public class CoopPauseTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var timer:Timer=new Timer(100),mod:RConnectMod,host:Boolean,watched:Dictionary=new Dictionary();
      private var state:String="boot",at:int=0,number:int=-1,step:Object;
      private var baseline:Number,worldMessages:int=0,baselineMessages:int=0;
      private var tacticalBaseline:Number,tdfcRoot:DisplayObjectContainer;
      private var scheduledOverlay:String;
      private var worldClock:NativePauseClock;
      private var localDone:Boolean=false,remoteDone:Boolean=false,joinReady:Boolean=false;
      private var enemy:Object,proxy:Object,gun:Object,selected:Object,origin:Object,otherRoom:Object;
      private var ammoBefore:Number,apBefore:Number,volleyHp:Number;
      private var steps:Array=[
         {name:"default join settings",h:"none",j:"settings",hf:false,jf:true,pause:false},
         {name:"host enables menu switch",h:"menus-on",j:"none",hf:true,jf:true,pause:true},
         {name:"both menus",h:"settings",j:"inventory",hf:true,jf:true,pause:true},
         {name:"joining player closes first",h:"none",j:"close",hf:true,jf:true,pause:true},
         {name:"host closes last",h:"close",j:"none",hf:false,jf:false,pause:false},
         {name:"joining map also pauses",h:"none",j:"map",hf:true,jf:true,pause:true},
         {name:"disable policy during menu",h:"menus-off",j:"none",hf:false,jf:true,pause:false},
         {name:"independent SATS option",h:"sats-on",j:"none",hf:false,jf:true,pause:false},
         {name:"prepare native SATS",h:"none",j:"close",hf:false,jf:false,pause:false},
         {name:"teammate pauses before SATS",h:"menus-and-open",j:"none",hf:true,jf:true,pause:true},
         {name:"joining native SATS",h:"none",j:"sats",hf:true,jf:true,pause:true},
         {name:"queue while paused",h:"none",j:"queue",hf:true,jf:true,pause:true},
         {name:"host menu holds queued shot",h:"settings",j:"none",hf:true,jf:true,pause:true},
         {name:"confirm waits for host",h:"none",j:"confirm",hf:true,jf:true,pause:true},
         {name:"sats volley resumes once",h:"close",j:"none",hf:false,jf:false,pause:false,measure:2800},
         {name:"remote menu before native stand",h:"settings",j:"none",hf:true,jf:true,pause:true},
         {name:"real stand opens during pause frame",h:"none",j:"stand-next-frame",hf:true,jf:true,pause:true},
         {name:"native stand retains pause ownership",h:"close",j:"none",hf:true,jf:true,pause:true},
         {name:"close native stand",h:"none",j:"stand-close",hf:false,jf:false,pause:false},
         {name:"remote menu before native message",h:"settings",j:"none",hf:true,jf:true,pause:true},
         {name:"real message opens during pause frame",h:"none",j:"gui-next-frame",hf:true,jf:true,pause:true},
         {name:"native message retains pause ownership",h:"close",j:"none",hf:true,jf:true,pause:true},
         {name:"dismiss native message",h:"none",j:"gui-close",hf:false,jf:false,pause:false},
         {name:"external native pause",h:"external-pause",j:"settings",hf:true,jf:true,pause:true},
         {name:"preserve native pause owner",h:"none",j:"close",hf:true,jf:false,pause:false},
         {name:"external pause released",h:"external-resume",j:"none",hf:false,jf:false,pause:false},
         {name:"split ordinary rooms",h:"none",j:"split",hf:false,jf:false,pause:false,settle:1800},
         {name:"pause across separate rooms",h:"none",j:"settings",hf:true,jf:true,pause:true},
         {name:"resume both separate rooms",h:"none",j:"close",hf:false,jf:false,pause:false},
         {name:"pause before map transition",h:"none",j:"settings",hf:true,jf:true,pause:true},
         {name:"host map travel clears old UI pause",h:"travel",j:"none",hf:false,jf:false,pause:false,settle:1600,land:"rbl"},
         {name:"old map pause report is ignored",h:"none",j:"stale",hf:false,jf:false,pause:false},
         {name:"pause before disconnect",h:"none",j:"settings",hf:true,jf:true,pause:true},
         {name:"disconnect releases remote hold",h:"none",j:"leave",hf:false,jf:true,pause:false}
      ];
      public function CoopPauseTestDoc() {
         var app:String=NativeApplication.nativeApplication.applicationID;
         if(app.indexOf("rconnect-coop-")<0)return;
         host=app.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();finish();
         });
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,label:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"pause "+label);}
      private function change(value:String):void {state=value;at=getTimer();}
      private function send(op:String,data:Object=null):void {
         var message:Object=data||{};message.type="pause-test";message.op=op;
         if(host)mod.session.server.broadcast(message);else if(mod.session.link!=null)mod.session.link.send(message);
      }
      private function watch(link:TcpLink):void {
         if(link!=null&&!watched[link]){watched[link]=true;link.addEventListener(TcpLink.MESSAGE,receive);}
      }
      private function stable():Boolean {return mod.session.rooms.ready&&!mod.session.rooms.busy&&!mod.game.isTransitioning();}
      private function receive(e:NetMessageEvent):void {
         var message:Object=e.data;
         if(message.type=="worldstate" || message.type=="playerstate")worldMessages++;
         if(message.type!="pause-test")return;
         try {
            if(message.op=="ready")joinReady=true;
            else if(message.op=="setup"&&!host) {origin=message.origin;otherRoom=message.other;change("setup");}
            else if(message.op=="prepared"&&host) {joinReady=true;change("prepared");}
            else if(message.op=="step"&&!host) {number=int(message.number);begin(steps[number]);}
            else if(message.op=="result"&&host&&int(message.number)==number)remoteDone=true;
         } catch(error:Error){check(false,"receive "+error.getStackTrace());finish();}
      }
      private function click(name:String):void {
         var button:TextField=mod.hud.getChildByName(name) as TextField;
         if(button==null)throw new Error("missing F10 button "+name);
         button.dispatchEvent(new MouseEvent(MouseEvent.CLICK,true));
      }
      private function tacticalClock(container:DisplayObjectContainer=null):Number {
         if(container==null)container=tdfcRoot;
         if(container==null)throw new Error("installed TDFC observation panel is missing");
         for(var i:int=0;i<container.numChildren;i++) {
            var field:TextField=container.getChildAt(i) as TextField;
            if(field!=null) {
               var match:Array=/^v\S+.*\s(\d+)\s*$/.exec(field.text.split(/[\r\n]/)[0]);
               if(match!=null)return Number(match[1]);
            }
            var child:DisplayObjectContainer=container.getChildAt(i) as DisplayObjectContainer;
            if(child!=null) {var result:Number=tacticalClock(child);if(isFinite(result))return result;}
         }
         return NaN;
      }
      private function action(value:String):void {
         var w:Object=mod.game.world,g:Object=mod.game.gg;
         if(value=="settings")w.pip.onoff(5);
         else if(value=="inventory")w.pip.onoff(2);
         else if(value=="map")w.pip.onoff(3,1);
         else if(value=="close")w.pip.onoff(-1);
         else if(value=="menus-on"||value=="menus-off")click("rconnect-pause-menus");
         else if(value=="sats-on")click("rconnect-pause-sats");
         else if(value=="menus-and-open"){click("rconnect-pause-menus");w.pip.onoff(5);}
         else if(value=="external-pause")w.onPause=true;
         else if(value=="external-resume")w.onPause=false;
         else if(value=="stand-next-frame"||value=="gui-next-frame") {
            scheduledOverlay=value;mod.stage.addEventListener(Event.ENTER_FRAME,openNativeOverlay,false,99400);
         }
         else if(value=="stand-close")w.stand.onoff(-1);
         else if(value=="gui-close")w.ctr.active=true;
         else if(value=="sats") {
            g.ggControl=true;g.pipOff=0;w.catPause=false;w.pip.onoff(-1);gun.lvl=0;
            mod.game.loc.getAbsTile(enemy.X,enemy.Y-enemy.scY/2).visi=1;
            w.ctr.keySats=true;ammoBefore=gun.hold;apBefore=w.sats.od;
         }
         else if(value=="queue") {
            for each(var entry:Object in w.sats.units)if(entry.u===proxy)selected=entry;
            check(w.sats.active&&selected!=null,"native SATS can select the mirrored enemy during shared pause");
            if(selected==null)throw new Error("native SATS fixture has no target");
            selected.du.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_OVER,true));w.ctr.keyAttack=true;
         }
         else if(value=="confirm")w.ctr.keyAction=true;
         else if(value=="split") {w.pip.onoff(-1);TravelGuard.follow(mod.game,otherRoom);}
         else if(value=="travel")w.game.gotoLand("rbl");
         else if(value=="stale")mod.session.link.send({type:"coop-pause",op:"report",epoch:mod.session.rooms.epoch-1,seq:999999,mask:1});
         else if(value=="leave") {mod.session.leave();check(w.pip.active,"disconnect preserves the player's native menu");}
      }
      private function openNativeOverlay(e:Event):void {
         mod.stage.removeEventListener(Event.ENTER_FRAME,openNativeOverlay);
         if(scheduledOverlay=="stand-next-frame")mod.game.world.stand.onoff(1);
         else mod.game.world.gui.impMess("Pause regression","Native message opened while the other player pauses.");
      }
      private function begin(s:Object):void {
         step=s;localDone=remoteDone=false;
         Log.d("PAUSE TEST "+(host?"host ":"join ")+number+" "+step.name);
         action(host?step.h:step.j);change("settle");
      }
      private function next():void {
         number++;
         if(number>=steps.length){finish();return;}
         send("step",{number:number});begin(steps[number]);
      }
      private function prepareHost():void {
         check(!mod.session.pause.policyMenus&&!mod.session.pause.policySats,"new options default to off");
         var c:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit.UnitSlaver") as Class;
         var g:Object=mod.game.gg;
         enemy=new c("slaver2",100,<unit tr="2"/>,null);
         enemy.putLoc(mod.game.loc,g.X+90,g.Y);mod.game.loc.addObj(enemy);mod.game.loc.units.push(enemy);
         enemy.disabled=true;enemy.doop=true;enemy.xp=0;enemy.hp=enemy.maxhp=43210;
         enemy.isSats=true;enemy.invis=false;enemy.animate();
         origin={x:g.X,y:g.Y};
         for each(var col:Array in mod.game.world.land.locs)if(col)for each(var row:Array in col)if(row)for each(var r:Object in row)
            if(r && r!==mod.game.loc && !TravelGuard.restricted(r) && r.landZ==0 && r.landProb=="")
               {otherRoom={landX:r.landX,landY:r.landY,landZ:r.landZ,landProb:"",key:mod.game.roomKey(r)};break;}
         if(otherRoom==null)throw new Error("no second ordinary room for global pause case");
         send("setup",{origin:origin,other:otherRoom});joinReady=false;change("wait-prepared");
      }
      private function prepareJoin():Boolean {
         for each(var u:Object in mod.game.loc.units) {
            if(u.id=="slaver2"&&Number(u.maxhp)==43210)enemy=u;
            if(u.id=="rconnect_hit_slaver2"&&Number(u.maxhp)==43210)proxy=u;
         }
         if(enemy==null||proxy==null)return false;
         var w:Object=mod.game.world,g:Object=mod.game.gg;
         g.setPos(origin.x,origin.y);g.setVisPos();g.storona=1;
         gun=new NativeTestGun(g as Unit);gun.hold=90;gun.loc=mod.game.loc;
         gun.X=g.X;gun.Y=g.Y-g.scY/2;g.currentWeapon=gun;g.childObjs[0]=gun;
         gun.addVisual();gun.setPers(g,g.pers);gun.lvl=0;gun.precision=0;gun.deviation=0;w.testDam=true;
         check(!mod.session.pause.setPolicy(true,true),"join cannot change the host's shared policy");
         send("prepared");change("waiting");return true;
      }
      private function validate():void {
         var w:Object=mod.game.world,expectedFrozen:Boolean=host?step.hf:step.jf;
         var difference:Number=worldClock.steps-baseline;
         check(expectedFrozen?difference==0:difference>1,step.name+" native world steps "+difference);
         var tacticalDifference:Number=tacticalClock()-tacticalBaseline;
         check(isFinite(tacticalDifference)&&(expectedFrozen?tacticalDifference==0:tacticalDifference>1),step.name+" installed TDFC tactical steps "+tacticalDifference);
         check(mod.session.pause.paused===Boolean(step.pause),step.name+" shared pause state");
         if(step.name!="disconnect releases remote hold")check(worldMessages>baselineMessages,step.name+" TCP state still arrives while UI is open");
         check(!w.verror.visible,step.name+" has no native error dialog");
         if(step.pause) {
            var banner:TextField=mod.stage.getChildByName("rconnect-pause-banner") as TextField;
            check(banner!=null&&banner.visible&&banner.text.length>0,step.name+" shows pause reason outside F10 panel");
            check(!mod.navigation.request(),step.name+" cannot teleport during shared pause");
         }
         if(!host) {
            if(step.name=="real stand opens during pause frame"||step.name=="native stand retains pause ownership")
               check(w.stand.active&&w.vstand.visible,"the genuinely opened native stand keeps its own active flag");
            if(step.name=="real message opens during pause frame"||step.name=="native message retains pause ownership")
               check(w.gui.guiPause&&w.gui.vis.getChildByName("imp").visible,"the native important message remains visible and paused");
            if(step.name=="joining native SATS")check(w.sats.active&&gun.hold==ammoBefore&&w.sats.od==apBefore,"SATS stays open with ammunition and AP unspent");
            if(step.name=="queue while paused"||step.name=="confirm waits for host")
               check(w.sats.que.length==1&&gun.hold==ammoBefore&&w.sats.od==apBefore,"queued volley waits for both players to resume");
            if(step.name=="confirm waits for host")check(!w.sats.active,"SATS confirmation remains usable while the host pauses");
            if(step.name=="sats volley resumes once") {
               check(w.sats.que.length==0&&gun.hold<ammoBefore&&w.sats.od<apBefore,"resume executes the native queued volley queue="+w.sats.que.length+" ammo="+gun.hold+"/"+ammoBefore+" AP="+w.sats.od+"/"+apBefore);
               check(enemy.hp<43210,"SATS volley damages the mirrored enemy after resume");
            }
            if(step.name=="pause across separate rooms")check(mod.session.rooms.authority&&mod.game.roomKey()==otherRoom.key,"joining player is paused in their independently simulated room");
         } else {
            if(step.name=="sats volley resumes once")check(enemy.hp<43210,"resumed SATS damage reaches authority");
            if(step.name=="preserve native pause owner")check(w.onPause,"cooperative release keeps the unrelated native pause flag");
            if(step.name=="host enables menu switch") {
               mod.config.load();check(mod.config.getValue("pauseMenus")=="1","host switch persists in isolated user configuration");
               var oldLang:String=String(w.lang);
               for each(var lang:String in ["en","ru","tw"]) {
                  w.lang=lang;mod.hud.refresh();
                  for each(var name:String in ["rconnect-pause-menus","rconnect-pause-sats"]) {
                     var b:TextField=mod.hud.getChildByName(name) as TextField;
                     check(b!=null&&b.textWidth<b.width-4,"pause label fits "+lang+" "+name);
                  }
               }
               savePanel();w.lang=oldLang;
            }
         }
      }
      private function savePanel():void {
         var bitmap:BitmapData=new BitmapData(mod.stage.stageWidth,mod.stage.stageHeight,false,0);
         bitmap.draw(mod.stage);
         var stream:FileStream=new FileStream();
         stream.open(File.applicationStorageDirectory.resolvePath("pause-panel.png"),FileMode.WRITE);
         stream.writeBytes(bitmap.encode(bitmap.rect,new PNGEncoderOptions()));stream.close();bitmap.dispose();
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;
         if(mod==null||mod.session==null||mod.game.gg==null||mod.game.loc==null)return;
         if(host&&mod.session.server!=null)for each(var p:Object in mod.session.peers)watch(p.link);
         else if(!host)watch(mod.session.link);
         try {
            if(state=="done")return;
            // Keep the isolated fresh player safe during the initial room trip,
            // before RoomSync is ready and before the pause scenario begins.
            mod.game.world.godMode=true;mod.game.gg.invulner=true;
            if(tdfcRoot==null) {
               tdfcRoot=mod.main.getChildByName("TDFC_DebugRoot") as DisplayObjectContainer;
               if(tdfcRoot==null)throw new Error("installed TDFC observation panel is missing");
               tdfcRoot.getChildAt(1).dispatchEvent(new MouseEvent(MouseEvent.CLICK,true));
            }
            if(worldClock==null || worldClock.loc!==mod.game.loc) {
               worldClock=new NativePauseClock();worldClock.loc=mod.game.loc as Location;mod.game.loc.addObj(worldClock);
            }
            if(at>0&&getTimer()-at>35000){check(false,"timeout "+state+" "+number);finish();return;}
            if(state=="boot"&&stable()&&String(mod.game.readWorldInfo().curLandId)=="random_mane") {
               mod.game.gg.invulner=true;mod.game.world.pip.onoff(-1);mod.game.world.sats.onoff(-1);
               mod.config.setValue("followTeammate","0");
               if(host) {if(joinReady)prepareHost();}
               else {send("ready");change("wait-setup");}
            }
            else if(state=="setup"&&stable())prepareJoin();
            else if(host&&state=="prepared")next();
            else if(state=="settle"&&(stable()||step.name=="disconnect releases remote hold")&&getTimer()-at>=int(step.settle||700)) {
               if(step.land!=null && String(mod.game.readWorldInfo().curLandId)!=String(step.land))return;
               if(!host&&step.name=="joining native SATS") {ammoBefore=gun.hold;apBefore=mod.game.world.sats.od;}
               baseline=worldClock.steps;tacticalBaseline=tacticalClock();baselineMessages=worldMessages;change("measuring");
            }
            else if(state=="measuring"&&getTimer()-at>=int(step.measure||1100)) {
               // SATS changes the native simulation rate. Wait for its finite
               // queue, rather than assuming a fixed wall-clock playback speed.
               if(!host&&step.name=="sats volley resumes once"&&mod.game.world.sats.que.length>0&&getTimer()-at<12000)return;
               validate();localDone=true;
               if(!host) {
                  if(step.name=="disconnect releases remote hold"){finish();return;}
                  send("result",{number:number});change("waiting");
               } else change("waiting-result");
            }
            if(host&&localDone&&(remoteDone||step.name=="disconnect releases remote hold"))next();
         }catch(error:Error){check(false,"tick "+error.getStackTrace());finish();}
      }
      private function finish():void {if(state=="done")return;change("done");timer.stop();Log.d("COOP EFFECTS DONE pause "+(host?"host":"join"));}
   }
}

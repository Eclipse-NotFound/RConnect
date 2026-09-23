package {
   import flash.desktop.NativeApplication;
   import flash.display.BitmapData;
   import flash.display.DisplayObject;
   import flash.display.PNGEncoderOptions;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.geom.Matrix;
   import flash.geom.Rectangle;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getQualifiedClassName;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   import rconnect.net.NetMessageEvent;
   import rconnect.net.TcpLink;

   /** Native mounts, local hidden fixtures and missing-unit injection over real TCP. */
   public class TurretTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var timer:Timer=new Timer(250),mod:RConnectMod;
      private var host:Boolean,links:Dictionary=new Dictionary();
      private var kinds:Array=["","land","wall","arm","combat","boss","hidden","hidden2"];
      private var index:int=-1,phase:String="boot",at:int=0,unit:Object,expected:Object;
      private var pixels:int=0,frames:int=0,angleError:Number=999,renderWatch:Boolean=false;
      private var barrelPixels:int=0,fireFrames:int=0,shots:int=0;
      public function TurretTestDoc() {
         var app:String=NativeApplication.nativeApplication.applicationID;
         if(app.indexOf("pfe-rconnect-coop-")!=0 && app.indexOf("pfe-modsettings-rconnect-coop-")!=0)return;
         host=app.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();
         });
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
         addEventListener(Event.ENTER_FRAME,frame);
      }
      private function check(ok:Boolean,label:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"turret "+index+" "+label);}
      private function send(stage:String,data:Object=null):void {
         var p:Object=data||{};p.type="turret-test";p.stage=stage;
         if(host)mod.session.server.broadcast(p);else mod.session.link.send(p);
      }
      private function setPhase(value:String):void {phase=value;at=getTimer();Log.d("TURRET "+(host?"host ":"join ")+index+" "+value);}
      private function watch(link:TcpLink):void {if(link==null||links[link])return;links[link]=true;link.addEventListener(TcpLink.MESSAGE,message);}
      private function removeFixture():void {
         var arr:Array=mod.game.loc.units;
         for(var i:int=arr.length-1;i>=0;i--)if(getQualifiedClassName(arr[i]).indexOf("UnitTurret")>=0) {
            mod.game.loc.remObj(arr[i]);arr.splice(i,1);
         }
         unit=null;
      }
      private function create(kind:String,awake:Boolean):Object {
         var c:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit.UnitTurret") as Class;
         var map:XML=<unit tr="1" vis="right"/>;
         var u:Object=new c(kind,100,map,null);
         u.putLoc(mod.game.loc,mod.game.gg.X+130,mod.game.gg.Y-45);mod.game.loc.addObj(u);mod.game.loc.units.push(u);
         u.disabled=true;u.doop=true;u.lootIsDrop=true;u.xp=0;u.stay=true;u.fixed=true;
         if(awake)u.alarma();
         u.currentWeapon.rot=0.5;u.setVisPos();u.animate();return u;
      }
      private function next():void {
         removeFixture();index++;
         if(index==kinds.length){send("done");finish();return;}
         send("prepare",{index:index});setPhase("prepare");
      }
      private function message(e:NetMessageEvent):void {
         var p:Object=e.data;if(p.type!="turret-test")return;
         if(host) {
            if(p.stage=="ready"&&phase=="boot-ready")next();
            else if(p.stage=="prepared") {unit=create(kinds[index],true);setPhase("settle");}
            else if(p.stage=="checked") {
               if(index==7){shots=0;send("fire");setPhase("fire");}else next();
            }
            else if(p.stage=="fire-checked") {unit.hack();unit.animate();setPhase("close");send("close");}
            else if(p.stage=="closed-checked")next();
         } else {
            if(p.stage=="prepare") {
               removeFixture();index=int(p.index);
               // Ordinary game placement can already contain a retracted turret.
               if(index>=6)unit=create(kinds[index],false);
               pixels=frames=barrelPixels=0;angleError=999;send("prepared");setPhase("settle");
            } else if(p.stage=="sample") {expected=p;mod.game.world.redrawLoc();setPhase("sample");}
            else if(p.stage=="fire"){fireFrames=0;setPhase("fire");}
            else if(p.stage=="check-fire") {
               check(fireFrames>0,"integrated native barrel shows firing frames");
               check(unit.currentWeapon.kol_shoot==0 && unit.currentWeapon.b==null,"mirror firing makes no local bullets");
               send("fire-checked");setPhase("wait-close");
            }
            else if(p.stage=="close")setPhase("close");
            else if(p.stage=="done")finish();
         }
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;
         if(mod==null||mod.game.gg==null||mod.game.loc==null||mod.game.isTransitioning())return;
         if(!renderWatch){renderWatch=true;mod.stage.addEventListener(Event.RENDER,rendered,false,-30000);}
         if(host){for each(var l:TcpLink in mod.session.server.clients)watch(l);}else watch(mod.session.link);
         if(timer.currentCount<55)return;
         try {
            if(phase=="boot") {
               mod.game.gg.disabled=true;mod.game.gg.dx=mod.game.gg.dy=0;
               if(host)setPhase("boot-ready");else {send("ready");setPhase("wait");}
            }
            if(host&&phase=="settle"&&getTimer()-at>2000) {
               check(unit.vis.stage===mod.stage,"host native visual attached for "+kinds[index]);
               send("sample",{visual:getQualifiedClassName(unit.vis),frame:unit.vis.osn.currentFrame,rot:unit.vis.osn.puha.rotation});setPhase("check");
            }
            if(!host&&phase=="sample"&&getTimer()-at>2000) {
               check(unit!=null,"native or injected unit exists");
               if(unit!=null) {
                  Log.d("TURRET sample kind="+kinds[index]+" visual="+getQualifiedClassName(unit.vis)+" expected="+expected.visual+" pixels="+pixels+" frame="+unit.vis.osn.currentFrame+" hostFrame="+expected.frame+" stage="+(unit.vis.stage===mod.stage)+" angleError="+angleError);
                  check(getQualifiedClassName(unit.vis)==expected.visual,"correct native mount visual");
                  check(pixels>30,"contributes real viewport pixels");
                  check(barrelPixels>20,"expanded barrel contributes viewport pixels after redraw");
                  check(unit.vis.osn.currentFrame==int(expected.frame),"matches host deployment frame");
                  check(angleError<2,"native barrel follows host aim");
                  saveScene();
               }
               send("checked");setPhase("wait");
            }
            if(host&&phase=="fire") {
               if(shots<5 && getTimer()-at>500+shots*500) {
                  var w:Object=unit.currentWeapon;
                  unit.celX=unit.X+300;unit.celY=unit.Y;
                  w.t_attack=0;w.t_reload=0;w.hold=90;w.damage=w.damageExpl=w.destroy=0;
                  w.attack();w.step();unit.animate();shots++;
               }
               if(getTimer()-at>4500){check(unit.currentWeapon.kol_shoot>0,"host fires real turret weapon");send("check-fire");setPhase("wait-fire");}
            }
            if(!host&&phase=="close"&&getTimer()-at>3000) {
               check(unit.vis.osn.currentFrame==6,"hidden turret retracts again when host deactivates it");
               send("closed-checked");setPhase("wait");
            }
            if(phase!="done"&&getTimer()-at>45000){check(false,"timeout at "+phase);finish();}
         }catch(err:Error){check(false,err.getStackTrace());finish();}
      }
      private function rendered(e:Event):void {
         if(host)return;
         if(phase=="fire"&&unit!=null) {
            try {if(unit.vis.osn.puha.puha.currentFrame>1)fireFrames++;}catch(error:*){}
         }
         if(phase!="sample")return;
         for each(var u:Object in mod.game.loc.units)if(getQualifiedClassName(u).indexOf("UnitTurret")>=0){unit=u;break;}
         if(unit==null)return;
         pixels=Math.max(pixels,scenePixels(unit));frames++;
         try {barrelPixels=Math.max(barrelPixels,scenePixels({vis:unit.vis.osn.puha}));}catch(barrelError:*){}
         try{angleError=Math.min(angleError,Math.abs(Number(unit.vis.osn.puha.rotation)-Number(expected.rot)));}catch(error:*){}
      }
      private function frame(e:Event):void {
         // Freeze native decisions, but let the host's own animation update the
         // newly-created barrel after the unfold timeline reaches its first frame.
         if(host&&unit!=null&&phase!="done")unit.animate();
      }
      private function scenePixels(u:Object):int {
         if(u==null||u.vis==null)return 0;
         var root:DisplayObject=mod.main as DisplayObject,rect:Rectangle=u.vis.getBounds(root);rect.inflate(4,4);
         rect=rect.intersection(new Rectangle(0,0,mod.stage.stageWidth,mod.stage.stageHeight));
         if(rect.width<1||rect.height<1)return 0;
         var a:BitmapData=new BitmapData(Math.ceil(rect.width),Math.ceil(rect.height),false,0),z:BitmapData=a.clone();
         var matrix:Matrix=new Matrix(1,0,0,1,-rect.x,-rect.y);a.draw(root,matrix);
         var visible:Boolean=u.vis.visible;u.vis.visible=false;z.draw(root,matrix);u.vis.visible=visible;
         var av:Vector.<uint>=a.getVector(a.rect),zv:Vector.<uint>=z.getVector(z.rect),count:int=0;
         for(var i:int=0;i<av.length;i++)if(av[i]!=zv[i])count++;
         a.dispose();z.dispose();return count;
      }
      private function saveScene():void {
         var b:BitmapData=new BitmapData(mod.stage.stageWidth,mod.stage.stageHeight,false,0);b.draw(mod.main as DisplayObject);
         var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath("presentation-turret-"+index+".png"),FileMode.WRITE);
         f.writeBytes(b.encode(b.rect,new PNGEncoderOptions()));f.close();b.dispose();
      }
      private function finish():void {phase="done";timer.stop();Log.d("COOP EFFECTS DONE "+(host?"host":"join"));}
   }
}

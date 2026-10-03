package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.display.DisplayObject;
   import flash.display.BitmapData;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.geom.Matrix;
   import flash.geom.Rectangle;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import fe.unit.Unit;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;

   /** Actual TCP, native LMG collision and pixels from the final scene. */
   public class CombatFeedbackNetworkTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var mod:RConnectMod,host:Boolean,timer:Timer=new Timer(100),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=0,enemy:Object,expected:Number=0,movedX:Number=0;
      public function CombatFeedbackNetworkTestDoc() {
         var id:String=NativeApplication.nativeApplication.applicationID;
         if(id.indexOf("pfe-rconnect-coop-")!=0 && id.indexOf("pfe-modsettings-rconnect-coop-")!=0)return;
         host=id.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();finish();
         });
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,s:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"feedback-network "+s);}
      private function setPhase(s:String):void {phase=s;at=getTimer();}
      private function watch(l:TcpLink):void {if(l!=null && !links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,message);}}
      private function send(s:String,p:Object=null):void {p=p||{};p.type="feedback-network-test";p.stage=s;if(host)mod.session.server.broadcast(p);else mod.session.link.send(p);}
      private function find():Object {for each(var u:Object in mod.game.loc.units)if(u.id=="feedback_network")return u;return null;}
      private function message(e:NetMessageEvent):void {
         var p:Object=e.data;if(p.type!="feedback-network-test")return;
         if(host){
            if(p.stage=="ready" && phase=="ready") {
               var cls:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit.UnitMerc") as Class;
               enemy=new cls("1",100,<unit tr="1"/>,null);enemy.id="feedback_network";
               enemy.putLoc(mod.game.loc,mod.game.gg.X+160,mod.game.gg.Y);mod.game.loc.addObj(enemy);mod.game.loc.units.push(enemy);
               enemy.disabled=true;enemy.xp=0;enemy.hp=1000;enemy.maxhp=2000;enemy.skin=enemy.armor=enemy.armor_qual=enemy.shithp=0;
               enemy.showNumbs=true;enemy.stay=true;enemy.visDetails();enemy.setHpbarPos();
               check(enemy.hpbar.visible,"host native wounded health bar visible");
               setPhase("initial");send("initial");
            } else if(p.stage=="move") {
               enemy.setPos(enemy.X+80,enemy.Y);enemy.setVisPos();enemy.setHpbarPos();send("moved",{x:enemy.X});setPhase("shot");
            } else if(p.stage=="shot") {expected=Number(p.loss);setPhase("settle");}
            else if(p.stage=="kill") {enemy.damage(10000,100,null,true);send("dead");setPhase("dead");}
            else if(p.stage=="done") {send("done");finish();}
         } else {
            if(p.stage=="initial")setPhase("initial");
            else if(p.stage=="moved"){movedX=Number(p.x);setPhase("moved");}
            else if(p.stage=="settled"){expected=Number(p.loss);setPhase("settled");}
            else if(p.stage=="dead")setPhase("dead");
            else if(p.stage=="done")finish();
         }
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;
         if(mod==null || mod.game==null || mod.game.gg==null || mod.game.loc==null || !mod.session.rooms.ready || mod.session.rooms.busy)return;
         mod.game.gg.invulner=true;
         if(host)for each(var peer:Object in mod.session.peers)watch(peer.link as TcpLink);else watch(mod.session.link);
         try {
            if(phase=="boot") {
               mod.game.world.showHit=1;mod.game.world.testDam=true;
               mod.game.gg.disabled=true;mod.game.forceCloseOverlays();
               mod.stage.addEventListener(Event.RENDER,sample,false,-30000);setPhase("ready");
            }
            if(!host && phase=="ready")send("ready");
            if(host && phase=="settle" && getTimer()-at>900) {
               check(expected>0,"join LMG reports positive damage");
               check(Math.abs(enemy.hp-(1000-expected))<.001,"host applies exactly the displayed LMG damage loss="+expected+" hp="+enemy.hp);
               send("settled",{loss:expected});setPhase("wait-kill");
            }
            if(phase!="done" && getTimer()-at>20000){check(false,"timeout "+phase);send("done");finish();}
            mod.stage.invalidate();
         }catch(error:Error){check(false,"tick "+error.getStackTrace());send("done");finish();}
      }
      private function pixels(display:DisplayObject):int {
         var root:DisplayObject=mod.main as DisplayObject,rect:Rectangle=display.getBounds(root);rect.inflate(2,2);
         rect=rect.intersection(new Rectangle(0,0,root.stage.stageWidth,root.stage.stageHeight));
         if(rect.width<1 || rect.height<1 || rect.width>1000 || rect.height>1000)return 0;
         var a:BitmapData=new BitmapData(Math.ceil(rect.width),Math.ceil(rect.height),false,0),b:BitmapData=a.clone();
         var matrix:Matrix=new Matrix(1,0,0,1,-rect.x,-rect.y),visible:Boolean=display.visible;
         a.draw(root,matrix);display.visible=false;b.draw(root,matrix);display.visible=visible;
         var av:Vector.<uint>=a.getVector(a.rect),bv:Vector.<uint>=b.getVector(b.rect),count:int=0;
         for(var i:int=0;i<av.length;i++)if(av[i]!=bv[i])count++;
         a.dispose();b.dispose();return count;
      }
      private function sample(e:Event):void {
         if(host || phase=="done")return;
         try {
            var elapsed:int=getTimer()-at,u:Object=find();
            if(phase=="initial" && elapsed>1000 && u!=null) {
               setPhase("wait-move");enemy=u;
               check(u.hp==1000,"host wounded HP crosses actual TCP");
               check(u.hpbar!=null && u.hpbar.visible && u.hpbar.stage!=null,"join health bar attached and visible");
               check(Math.abs(u.hpbar.x-u.X)<1,"join health bar follows body position");
               var n:int=pixels(u.hpbar as DisplayObject);check(n>5,"health bar contributes final scene pixels="+n);
               send("move");
            } else if(phase=="moved" && elapsed>900 && u!=null) {
               setPhase("reattach");
               check(Math.abs(u.X-movedX)<2 && Math.abs(u.hpbar.x-u.X)<1,"TCP movement and health bar finish together");
               u.hpbar.parent.removeChild(u.hpbar);
            } else if(phase=="reattach" && elapsed>200 && u!=null) {
               setPhase("wait-settle");
               check(u.hpbar.visible && u.hpbar.stage!=null,"next rendered frame repairs detached bar");
               var before:Dictionary=new Dictionary(),p:Object;
               for(p=mod.game.loc.firstObj;p!=null;p=p.nobj)before[p]=true;
               var hp:Number=u.hp,gun:NativeTestGun=new NativeTestGun(mod.game.gg as Unit),weapon:Object=gun;
               weapon.setPers(mod.game.gg,mod.game.gg.pers);weapon.damage=40;weapon.critCh=0;
               var bullet:Object=gun.fireAt(u,true),loss:Number=hp-u.hp,parts:Array=[];
               for(p=mod.game.loc.firstObj;p!=null;p=p.nobj)
                  if(!before[p] && GameBridge.probe(GameBridge.probe(p,"vis"),"numb")!=null && String(p.vis.numb.text).match(/^\d+$/))parts.push(p);
               check(loss>0 && parts.length==1,"native join LMG hit creates exactly one damage number");
               if(parts.length==1) {
                  p=parts[0];check(Number(p.vis.numb.text)==Math.round(loss),"displayed number equals actual HP loss="+loss);
                  check(Math.abs(p.Y-(bullet.Y-15))<1,"number starts at native projectile impact height");
                  check(p.vis.currentFrame==1,"ordinary LMG uses native damage-number color frame");
                  n=pixels(p.vis as DisplayObject);check(n>5,"damage number contributes final scene pixels="+n);
               }
               send("shot",{loss:loss});
            } else if(phase=="settled" && elapsed>600 && u!=null) {
               setPhase("wait-death");check(Math.abs(u.hp-(1000-expected))<.001,"join displayed HP remains equal to host settlement");send("kill");
            } else if(phase=="dead" && elapsed>900) {
               setPhase("wait-done");check(enemy.hpbar==null || enemy.hpbar.parent==null || !enemy.hpbar.visible,"host death removes join health bar");send("done");
            }
         }catch(error:Error){check(false,"render "+error.getStackTrace());send("done");finish();}
      }
      private function finish():void {
         if(phase=="done")return;phase="done";timer.stop();
         if(mod!=null)mod.stage.removeEventListener(Event.RENDER,sample);
         Log.d("COOP EFFECTS DONE feedback-network "+(host?"host":"join"));
      }
   }
}

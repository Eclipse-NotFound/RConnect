package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import fe.unit.Unit;
   import fe.unit.FeedbackProbe;
   import fe.weapon.Bullet;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;
   import rconnect.game.MirrorHitUnit;

   /** Native damage feedback compared with the exact production mirror path. */
   public class CombatFeedbackTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var timer:Timer=new Timer(200),mod:RConnectMod,host:Boolean,phase:int=0,at:int;
      private var bridge:GameBridge,enemy:Object,snapshot:Object,baseX:Number,baseY:Number;
      private var streamUnit:Object,lastPart:Object,expiredPart:Object;
      private var burstFrames:int=0;
      public function CombatFeedbackTestDoc() {
         var id:String=NativeApplication.nativeApplication.applicationID;
         if(id.indexOf("pfe-rconnect-coop-")!=0 && id.indexOf("pfe-modsettings-rconnect-coop-")!=0)return;
         host=id.indexOf("-host-")>=0;timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
         addEventListener(Event.ENTER_FRAME,function(e:Event):void {if(phase==20)burstFrames++;});
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+e.error);e.preventDefault();finish();
         });
      }
      private function check(ok:Boolean,s:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"feedback "+s);}
      private function spawn(offset:Number):Object {
         var cls:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit.UnitMerc") as Class;
         var u:Object=new cls("1",100,<unit tr="1"/>,null);u.id="feedback_"+offset;
         u.putLoc(bridge.loc,baseX+offset,baseY);bridge.loc.addObj(u);bridge.loc.units.push(u);
         u.disabled=true;u.xp=0;u.hp=u.maxhp=2000;u.skin=u.armor=0;u.armor_qual=0;u.shithp=0;u.showNumbs=true;
         // All style comparisons fire in one callback. Blood from those unrelated
         // cases can exceed native maxParts=100 and suppress the later number.
         // Keep the native number path/budget; isolate it from that fixture load.
         u.blood=0;
         u.stay=true;return u;
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;
         if(mod==null || mod.game==null || mod.game.gg==null || mod.game.loc==null
            || !mod.session.rooms.ready || mod.session.rooms.busy)return;
         if(!host){timer.stop();Log.d("COOP EFFECTS DONE feedback join");return;}
         try {
            if(phase==0) {
               phase=1;at=getTimer();
               bridge=new GameBridge({stage:mod.stage,loaderInfo:mod.main.loaderInfo});
               bridge.world=mod.game.world;bridge.gg=mod.game.gg;bridge.loc=mod.game.loc;
               bridge.roomEpoch=mod.game.roomEpoch;bridge.freezeAI=true;
               bridge.gg.invulner=true;baseX=bridge.gg.X;baseY=bridge.gg.Y;
               enemy=spawn(120);enemy.hp=1000;enemy.visDetails();enemy.setHpbarPos();
               check(enemy.hpbar.visible && Math.abs(enemy.hpbar.x-enemy.X)<1,"native damaged unit has correctly placed health bar");
               var list:Array=JSON.parse(JSON.stringify(bridge.readUnitsSnapshot())) as Array;
               for each(var s:Object in list)if(s.id==enemy.id)snapshot=s;
               enemy.hp=enemy.maxhp;enemy.visDetails();enemy.hpbar.x=enemy.hpbar.y=0;
               bridge.applyUnitsSync([snapshot]);
               return;
            }
            if(phase==1 && getTimer()-at>700) {
               phase=2;at=getTimer();
               Log.d("FEEDBACK bar="+JSON.stringify({hp:enemy.hp,max:enemy.maxhp,visible:enemy.hpbar.visible,x:enemy.hpbar.x,y:enemy.hpbar.y,unitX:enemy.X,unitY:enemy.Y,stage:enemy.hpbar.stage!=null}));
               check(enemy.hpbar.visible && enemy.hpbar.stage!=null,"mirrored host damage displays health bar");
               check(Math.abs(enemy.hpbar.x-enemy.X)<1 && enemy.hpbar.y>enemy.Y-enemy.scY-60,"mirrored health bar follows displayed body");
               snapshot.x+=80;snapshot.sampleTime=getTimer();bridge.applyUnitsSync([snapshot]);
               return;
            }
            if(phase==2 && getTimer()-at>800) {
               phase=3;
               check(Math.abs(enemy.hpbar.x-enemy.X)<1,"health bar follows interpolated movement");
               enemy.hpbar.parent.removeChild(enemy.hpbar);
               render();
               check(enemy.hpbar.stage!=null,"detached health bar rejoins the active display layer");
               snapshot.hp=snapshot.defense.maxhp;bridge.applyUnitsSync([snapshot]);render();
               check(!enemy.hpbar.visible,"fully healed ordinary enemy hides its health bar");
               snapshot.hp=1000;snapshot.view.isVis=false;bridge.applyUnitsSync([snapshot]);render();
               check(!enemy.hpbar.visible,"mechanically hidden enemy does not reveal a health bar");
               snapshot.view.isVis=true;bridge.applyUnitsSync([snapshot]);render();
               check(enemy.hpbar.visible,"revealed wounded enemy restores health bar");
               snapshot.sost=3;bridge.applyUnitsSync([snapshot]);render();
               check(enemy.hpbar.parent==null || !enemy.hpbar.visible,"dead enemy health bar stays removed");
               compare(false,false,1);compare(true,false,1);compare(false,true,1);compare(false,false,2);
               bridge.world.showHit=2;streamUnit=spawn(380);
               var a:Object=shot(streamUnit,false,false,false),b:Object=shot(streamUnit,false,false,false);
               check(Number(b.text)==a.loss+b.loss,"native burst merges its actual damage");
               streamUnit.hp=streamUnit.maxhp;
               a=shot(streamUnit,false,false,true);b=shot(streamUnit,false,false,true);
               check(Number(b.text)==a.loss+b.loss,"mirror burst merges its actual damage once");
               expiredPart=lastPart;phase=20;burstFrames=0;at=getTimer();
               return;
            }
            if(phase==20 && burstFrames>=15) {
               var next:Object=shot(streamUnit,false,false,true);
               check(Number(next.text)==next.loss && lastPart!==expiredPart && expiredPart.liv>0,
                  "native merge window expires while previous number is still visible");
               expiredPart=lastPart;phase=21;at=getTimer();return;
            }
            if(phase==21 && (expiredPart.liv<=0 || !expiredPart.in_chain)) {
               var fresh:Object=shot(streamUnit,false,false,true);
               check(Number(fresh.text)==fresh.loss && lastPart!==expiredPart,"new burst after particle expiry starts a fresh total");
               bridge.world.showHit=0;var before:int=numbers().length;
               shot(streamUnit,false,false,true,false);
               check(numbers().length==before,"disabled damage-number setting remains respected");
               finish();
            }
            if((phase==20 || phase==21) && getTimer()-at>10000){check(false,"damage particle did not expire");finish();}
         } catch(error:Error){check(false,"exception "+error.getStackTrace());finish();}
      }
      private function render():void {mod.stage.dispatchEvent(new Event(Event.RENDER));}
      private function numbers():Array {
         var result:Array=[];
         for(var p:Object=bridge.loc.firstObj;p!=null;p=p.nobj)
            if(GameBridge.probe(GameBridge.probe(p,"vis"),"numb")!=null)result.push(p);
         return result;
      }
      private function shot(u:Object,critical:Boolean,periodic:Boolean,mirror:Boolean,visible:Boolean=true):Object {
         var receiver:Object=u;
         if(mirror) {
            for each(var candidate:Object in bridge.loc.units)if(candidate is MirrorHitUnit && MirrorHitUnit(candidate).body===u)receiver=candidate;
            if(receiver===u) {
               var list:Array=JSON.parse(JSON.stringify(bridge.readUnitsSnapshot())) as Array;
               bridge.applyUnitsSync(list);
               for each(candidate in bridge.loc.units)if(candidate is MirrorHitUnit && MirrorHitUnit(candidate).body===u)receiver=candidate;
            }
         }
         var previous:Dictionary=new Dictionary();for each(var p:Object in numbers())previous[p]=String(p.vis.numb.text);
         var cls:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.weapon.Bullet") as Class;
         var b:Object=new cls(bridge.gg as Unit,u.X,u.Y-u.scY+8);b.owner=bridge.gg;b.loc=bridge.loc;
         b.X=u.X;b.Y=u.Y-u.scY+8;b.dx=0;b.dy=0;b.vel=1;b.armorMult=1;b.pier=0;b.probiv=0;
         b.critCh=critical?1:0;b.critDamMult=2;b.critInvis=0;b.desintegr=0;
         var emitter:Object=mod.main.loaderInfo.applicationDomain.getDefinition("fe.graph.Emitter");
         Log.d("FEEDBACK budget "+JSON.stringify({phase:phase,active:bridge.loc.active,numbers:numbers().length,
            group:emitter.arr.numb.maxkol,count:emitter.kols[emitter.arr.numb.maxkol],total:emitter.kol2,max:bridge.world.maxParts}));
         var before:Number=u.hp,prior:Object=FeedbackProbe.read(receiver as Unit);receiver.damage(40,0,b as Bullet,periodic);
         var fresh:Array=[];for each(p in numbers())if(previous[p]!==String(p.vis.numb.text) && String(p.vis.numb.text).match(/^\d+$/))fresh.push(p);
         Log.d("FEEDBACK shot "+JSON.stringify({phase:phase,mirror:mirror,before:before,after:u.hp,found:fresh.length,
            prior:prior,next:FeedbackProbe.read(receiver as Unit),texts:fresh.map(function(value:*,index:int,array:Array):* {return value.vis.numb.text;})}));
         check(fresh.length==(visible?1:0),(mirror?"mirror":"native")+(visible?" updates one HP number":" suppresses HP number"));
         if(!fresh.length)return {};
         p=fresh[0];lastPart=p;return {loss:before-u.hp,text:p.vis.numb.text,frame:p.vis.currentFrame,color:p.vis.numb.textColor,
            scale:p.vis.scaleX,y:p.Y-b.Y,x:p.X-b.X};
      }
      private function compare(critical:Boolean,periodic:Boolean,mode:int):void {
         bridge.world.showHit=mode;bridge.world.testDam=true;
         var u:Object=spawn(280+phase++*15),native:Object=shot(u,critical,periodic,false);
         u.hp=u.maxhp;var mirror:Object=shot(u,critical,periodic,true);
         var label:String="crit="+critical+" periodic="+periodic+" mode="+mode;
         Log.d("FEEDBACK compare "+label+" native="+JSON.stringify(native)+" mirror="+JSON.stringify(mirror));
         check(native.loss>0 && Math.abs(native.loss-mirror.loss)<.001 && native.text==mirror.text,"damage text agrees with native "+label);
         check(native.frame==mirror.frame && native.color==mirror.color && Math.abs(native.scale-mirror.scale)<.01,"number style agrees with native "+label);
         check(Math.abs(native.y-mirror.y)<1,"number starts at native impact height "+label);
      }
      private function finish():void {
         timer.stop();if(bridge!=null)bridge.endSession();
         Log.d("COOP EFFECTS DONE feedback host");
      }
   }
}

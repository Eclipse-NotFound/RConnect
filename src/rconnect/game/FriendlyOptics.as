package rconnect.game {
   import RConnectModDomains;
   import flash.events.Event;
   import flash.utils.Dictionary;
   import flash.utils.getTimer;
   import rconnect.core.Log;

   /** Read MSW's public geometry and live settings callbacks. Preserve its
    * actual firing, energy payment, eye rules and obstacle tests. */
   public final class FriendlyOptics {
      private var mod:RConnectMod,emit:Function,bindings:Dictionary=new Dictionary(true);
      private var domain:Object,geometry:Object,sweep:Object,settings:Object={},settingsAt:int=-1,pointerAt:int=0;
      private var errors:int=0;
      public function FriendlyOptics(m:RConnectMod,send:Function) {
         mod=m;emit=send;m.stage.addEventListener(Event.ENTER_FRAME,after,false,-7000);
      }
      private function config():Object {
         var now:int=getTimer();if(now-settingsAt<200&&settingsAt>=0)return settings;settingsAt=now;
         var carrier:Object=mod.main.getChildByName("ModSettingsCarrier"),api:Object=GameBridge.probe(carrier,"modAPI");
         settings={};if(api==null||!(api.getPages is Function))return settings;
         for each(var page:Object in api.getPages())if(page.modId=="msw-laser"||page.modId=="msw-pointer")
            for each(var item:Object in page.items)if(item.get is Function)settings[String(item.key)]=item.get();
         return settings;
      }
      private function available():Boolean {
         return mod.friendlyFire!=null&&mod.friendlyFire.enabled&&mod.session.rooms.ready&&!mod.session.rooms.busy
            &&mod.game.gg!=null&&!mod.game.isTransitioning()&&!mod.game.isPlayerDead();
      }
      private function definitions():Boolean {
         if(geometry==null) {
            domain=RConnectModDomains.find(mod.main,"MoreSkillsWeaponsMod");
            if(domain==null||!domain.hasDefinition("MSWLaserGeometry")||!domain.hasDefinition("MSWPointerSweep"))return false;
            geometry=domain.getDefinition("MSWLaserGeometry");var c:Class=domain.getDefinition("MSWPointerSweep") as Class;sweep=new c();
         }
         return true;
      }
      private function notify(hit:Object,source:String,c:Object):void {
         var duration:Number=Number(c[source=="laser"?"laserDuration":"pointerDuration"]);
         if(hit!=null&&hit.eye===true&&hit.unit!=null&&isFinite(duration)&&duration>0)
            emit(hit.unit,source,Math.min(60,duration));
      }
      private function laser(w:Object):void {
         if(!available()||!definitions()||w.owner!==mod.game.gg)return;
         var c:Object=config();if(c.laserEnabled!==true)return;
         var world:Object=mod.game.world,g:Object=mod.game.gg;
         var angle:Number=Math.atan2(g.celY-w.bulY,g.celX-w.bulX),target:Object;
         if(g.sats.que.length>0) {
            var sats:Object=domain.getDefinition("fe.inter.MSWLaserSats");
            target=sats.target(g.sats.que[0]);
         }else target=geometry.assist(world,w,c);
         if(target!=null&&geometry.hostile(target,world)) {
            var eye:Object=geometry.eye(target);angle=Math.atan2(eye.y-w.bulY,eye.x-w.bulX);
         }
         notify(geometry.castRay(world,w.bulX,w.bulY,angle,Number(c.laserEye),2000,g,c.laserNonFront===true),"laser",c);
      }
      private function bind(w:Object):void {
         var previous:Function=GameBridge.probe(w,"onShot") as Function,rec:Object=bindings[w];
         if(previous==null||rec!=null&&previous===rec.wrapper)return;
         rec={previous:previous};
         rec.wrapper=function(fired:Object):void {
            previous(fired);
            try {laser(fired);}catch(error:Error){if(errors++<8)Log.d("RConnect friendly optics: "+error.getStackTrace());}
         };
         bindings[w]=rec;w.onShot=rec.wrapper;
      }
      private function after(e:Event):void {
         try {
            if(!available()){reset();return;}
            var w:Object=GameBridge.probe(mod.game.gg,"currentWeapon");if(w==null)return;
            if(String(w.id)=="mswdazzler")bind(w);
            if(String(w.id)!="mswlaserpointer"||!definitions()) {sweepReset();return;}
            var world:Object=mod.game.world,layer:Object=world.grafon.visObjs[2];
            var beam:Object=layer.getChildByName("MSWPointerBeam");
            if(beam==null||!beam.visible||world.allStat!=1||world.onPause||mod.game.coopPaused){sweepReset();return;}
            var c:Object=config();if(c.pointerEnabled!==true)return;
            w.getBulXY();var angle:Number=Math.atan2(mod.game.gg.celY-w.bulY,mod.game.gg.celX-w.bulX);
            // Native MSW scans every source frame, including the swept eye
            // crossings. Network renewals are capped; the victim uses game time.
            sweep.scan(world,w.bulX,w.bulY,angle,Number(c.pointerEye),function(sample:Object):void {
               if(getTimer()-pointerAt<150)return;
               if(notifyPeer(sample,"pointer",c))pointerAt=getTimer();
            },c.laserNonFront===true,c.pointerBlockObjects===true);
         }catch(error:Error) {if(errors++<8)Log.d("RConnect friendly optics: "+error.getStackTrace());reset();}
      }
      private function notifyPeer(hit:Object,source:String,c:Object):Boolean {
         if(hit==null||hit.eye!==true||!mod.friendlyFire.isTeammate(hit.unit))return false;
         notify(hit,source,c);return true;
      }
      private function sweepReset():void {if(sweep!=null)sweep.reset();}
      public function reset():void {
         for(var w:Object in bindings)if(GameBridge.probe(w,"onShot")===bindings[w].wrapper)w.onShot=bindings[w].previous;
         bindings=new Dictionary(true);sweepReset();pointerAt=0;
      }
   }
}

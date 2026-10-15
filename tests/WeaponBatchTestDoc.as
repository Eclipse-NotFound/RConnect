package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.TimerEvent;
   import flash.utils.Timer;
   import flash.utils.ByteArray;
   import flash.utils.getTimer;
   import fe.unit.Unit;
   import rconnect.core.Log;
   import rconnect.game.UnitPresentation;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;

   /** Compare the optimized synchronous batch with the retained original
    * discovery path, using native weapons and a real still-flying projectile. */
   public class WeaponBatchTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var timer:Timer=new Timer(100),began:int=getTimer(),done:Boolean=false;
      private var link:TcpLink,seenWorldSnapshot:Boolean=false;
      public function WeaponBatchTestDoc() {
         if(NativeApplication.nativeApplication.applicationID.indexOf("pfe-modsettings-rconnect-coop-")!=0)return;
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,label:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"weapon-batch "+label);}
      private function same(a:*,b:*):Boolean {
         if(a===b)return true;
         if(a==null || b==null || typeof a!=typeof b || (a is Array)!=(b is Array))return false;
         if(typeof a!="object" || a is Array && a.length!=b.length)return false;
         var key:String,n:int=0,m:int=0;
         for(key in a){n++;if(!b.hasOwnProperty(key)||!same(a[key],b[key]))return false;}
         for(key in b)m++;return n==m;
      }
      private function compare(p:UnitPresentation,owner:Object,label:String):Array {
         var copy:ByteArray=new ByteArray();copy.writeObject(p.capture(owner));copy.position=0;
         var old:Array=copy.readObject() as Array,actual:Array;
         p.beginCaptureBatch();
         try {actual=p.capture(owner);}
         finally {p.endCaptureBatch();}
         if(!same(old,actual)) {var diff:Array=[];differences(old,actual,"weapons",diff);Log.d("WEAPON BATCH DIFFERENCES "+JSON.stringify({label:label,fields:diff}));}
         check(same(old,actual),label+" preserves every field and weapon/event ordering");return actual;
      }
      private function differences(a:*,b:*,path:String,out:Array):void {
         if(a===b || out.length>=10)return;
         if(a!=null && b!=null && typeof a=="object" && typeof b=="object") {
            for(var key:String in a)differences(a[key],b[key],path+"."+key,out);
            for(key in b)if(!a.hasOwnProperty(key))out.push({path:path+"."+key,extra:true});
         } else out.push({path:path,original:String(a),batch:String(b),aType:typeof a,bType:typeof b});
      }
      private function tick(e:TimerEvent):void {
         if(done)return;
         if(getTimer()-began>120000){check(false,"native connected room became ready");finish();return;}
         var mod:RConnectMod=RConnectMod.instance;
         if(mod!=null && mod.session.link!=null && link!==mod.session.link) {
            link=mod.session.link;link.addEventListener(TcpLink.MESSAGE,received);
         }
         if(mod==null || mod.game.gg==null || !mod.session.rooms.ready || mod.session.rooms.busy || mod.game.isTransitioning())return;
         if(mod.session.peers.length==0 && mod.session.remotes.length==0)return;
         if(mod.session.mode=="connected" && !seenWorldSnapshot)return;
         var owner:Object=mod.game.gg,oldWeapon:Object=owner.currentWeapon,oldChildren:Array=owner.childObjs;
         var first:NativeTestGun=new NativeTestGun(owner as Unit),second:NativeTestGun=new NativeTestGun(owner as Unit,"p308c");
         var p:UnitPresentation=new UnitPresentation(),shot:Object,rows:Array,at:int=getTimer();
         try {
            var secondNative:Object=second;secondNative.X=owner.X;secondNative.Y=owner.Y-20;secondNative.rot=0;
            check(isFinite(Number(secondNative.rot)),"replacement gun has a valid native aim before snapshot comparison");
            owner.currentWeapon=first;owner.childObjs=[first];p.observePlayer(owner,at);
            shot=first.emitLive();check(shot!=null && shot.in_chain,"native weapon creates a real live projectile");
            p.observePlayer(owner,at+1);compare(p,owner,"current weapon");
            owner.currentWeapon=second;owner.childObjs=[second];p.observePlayer(owner,at+2);
            rows=compare(p,owner,"switching guns with an in-flight old projectile");
            var retained:Boolean=false;
            for each(var row:Object in rows)if(row.id=="lmg" && row.effectsOnly && row.events.length>0)retained=true;
            check(retained,"old gun remains effects-only and keeps its native projectile event");
            p.beginCaptureBatch();p.beginCaptureBatch();
            try {check(same(rows,p.capture(owner)),"nested batch sees the same retained effects");}
            finally {p.endCaptureBatch();p.endCaptureBatch();}
            owner.childObjs=[second,first];compare(p,owner,"returning old gun to the child list");
            owner.childObjs=[second];mod.game.loc.remObj(shot);p.observePlayer(owner,at+3);
            rows=compare(p,owner,"native projectile ending after gun replacement");
            retained=false;
            for each(row in rows)if(row.id=="lmg")for each(var event:Object in row.events)
               if(event.flight!=null && Number(event.flight.end)>0)retained=true;
            check(retained,"final projectile state survives native removal");
            // A subsequent batch must rebuild its owner/room lookup, never use
            // the previous batch's strong references as a long-lived cache.
            var gun:Object=first,oldLoc:Object=gun.loc;gun.loc=null;
            try {compare(p,owner,"weapon leaving the room between batches");}
            finally {gun.loc=oldLoc;}
            owner.currentWeapon=first;owner.childObjs=[first];
            var display:UnitPresentation=new UnitPresentation();
            var weaponState:Object={slot:0,id:"lmg",variant:0,main:true,shots:0,ox:0,oy:-20,rot:0,prep:0,reload:0,cadence:1000};
            var state:Object={sost:1,anim:String(owner.animState),weapons:[weaponState]};
            display.apply(owner,state,mod.main);
            check(gun.t_shoot==0,"ordinary immediate application still updates the weapon");
            weaponState.shots=1;display.apply(owner,state,mod.main,null,false,true);
            check(gun.t_shoot==0,"frame-deferred application does not consume a muzzle frame");
            display.tick(owner,false);
            check(gun.t_shoot==3,"one native presentation tick retains the first muzzle frame");
         }catch(error:Error){check(false,error.getStackTrace());}
         finally {
            owner.currentWeapon=oldWeapon;owner.childObjs=oldChildren;
            if(shot!=null && shot.in_chain)mod.game.loc.remObj(shot);
         }
         timer.stop();
         new NativeWeaponCadenceRegression(mod,check,finish);
      }
      private function received(e:NetMessageEvent):void {if(e.data.type=="unitsync")seenWorldSnapshot=true;}
      private function finish():void {
         done=true;timer.stop();if(link!=null)link.removeEventListener(TcpLink.MESSAGE,received);
         Log.d("COOP EFFECTS DONE weapon-batch");
      }
   }
}

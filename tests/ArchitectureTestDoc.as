package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.TimerEvent;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import fe.unit.Unit;
   import rconnect.core.Log;
   import rconnect.game.WeaponCapture;
   import rconnect.net.NetMessageEvent;
   import rconnect.net.Protocol;
   import rconnect.net.TcpLink;

   /** Uses the compiled production recorder and a native LMG. Socket bursts
    * cross the real session: receiving player poses must not rebuild the host
    * snapshot repeatedly within one publishing tick. No substitute timers. */
   public class ArchitectureTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var timer:Timer=new Timer(100),began:int=getTimer(),phase:int=0,at:int;
      private var mod:RConnectMod,host:Boolean,done:Boolean=false,link:TcpLink;
      private var source:WeaponCapture=new WeaponCapture(),actor:Object,gun:NativeTestGun;
      private var wireTicks:Object={},packets:int=0,duplicates:int=0,bursts:int=0;
      private var sentAt:int=0,endFrames:int=0;
      public function ArchitectureTestDoc() {
         var id:String=NativeApplication.nativeApplication.applicationID;
         if(id.indexOf("pfe-modsettings-rconnect-coop-")!=0)return;
         host=id.indexOf("-host-")>=0;
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,label:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"architecture "+label);}
      private function receive(e:NetMessageEvent):void {
         if(phase<1 || host || e.data.type!=Protocol.MSG_WORLDSTATE)return;
         packets++;
         var key:String=String(e.data.tick);
         if(wireTicks[key])duplicates++;
         wireTicks[key]=true;
      }
      private function shots(player:Boolean):Array {
         var list:Array=source.capture(actor,player);
         for each(var w:Object in list)if(w.id=="lmg")return w.events;
         return [];
      }
      private function fire(player:Boolean):void {
         gun.fireAt({loc:actor.loc,X:actor.X+100,Y:actor.Y,scY:actor.scY},true);
         if(player)source.observePlayer(actor,getTimer());else source.observe(actor.loc,getTimer());
      }
      private function fixture():void {
         var cls:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit.UnitMerc") as Class;
         actor=new cls("merc",1,<unit weapon="lmg"/>,null);
         actor.putLoc(mod.game.loc,mod.game.gg.X+150,mod.game.gg.Y);
         // This source fixture is native but does not enter the room's AI or
         // network entity collection. The LMG still creates native Bullets.
         actor.disabled=true;actor.doop=true;actor.xp=0;
         gun=new NativeTestGun(actor as Unit);
         actor.currentWeapon=gun;actor.childObjs=[gun];
      }
      private function begin():void {
         fixture();
         source.recording(false,false);
         for(var i:int=0;i<160;i++)fire(true);
         check(shots(true).length==0,"offline shooting retains no projectile history after 160 native shots");
         source.recording(true,false);
         // Give observation the same native room chain but only this enemy.
         var units:Array=actor.loc.units;
         try {
            actor.loc.units=[actor];
            for(i=0;i<160;i++)fire(false);
         } finally {actor.loc.units=units;}
         check(Object(gun).kol_shoot>=160,"independent room produces a native burst without a snapshot consumer");
         at=getTimer();phase=1;
      }
      private function tick(e:TimerEvent):void {
         if(done)return;
         try {
            if(getTimer()-began>50000){check(false,"scenario completes within deadline");finish();return;}
            mod=RConnectMod.instance;
            if(mod==null || mod.game.gg==null || !mod.session.rooms.ready || mod.session.rooms.busy)return;
            if(phase==0) {
               link=host?mod.session.peers[0].link:mod.session.link;
               link.addEventListener(TcpLink.MESSAGE,receive);begin();return;
            }
            if(phase==1)source.observeFinal(actor.loc,getTimer());
            else source.observePlayer(actor,getTimer());
            if(!host && bursts<3) {
               var packet:Object=Protocol.make(Protocol.MSG_PLAYERSTATE,{id:mod.session.myId,
                  seq:100000+bursts,name:mod.session.myName,snap:mod.game.readSnapshot()});
               for(var i:int=0;i<25;i++)link.send(packet);
               bursts++;
            }
            if(phase==1 && getTimer()-at>=1100) {
               check(shots(false).length==0,"independent room retires unpublished endings after its handoff window");
               fire(false);source.observeFinal(actor.loc,getTimer());
               check(shots(false).length==1,"independent room still captures a fresh shot at a handoff");
               // Native Weapon.actions normally resets the burst counter. This
               // fixture calls protected shoot directly, so put it at rest
               // before beginning a new subscription to an idle native gun.
               Object(gun).kol_shoot=0;source.recording(true,true);
               source.observePlayer(actor,getTimer());fire(true);
               at=getTimer();phase=2;
            } else if(phase==2 && getTimer()-at>=1100) {
               // No capture has happened since fire: the ending is unsent.
               var events:Array=shots(true);
               check(events.length==1,"unsent ending survives a delayed consumer for more than 700 ms count="+events.length);
               var flight:Object=events.length?events[0].flight:null;
               check(flight!=null && flight.end>0 && flight.frames.length>0,"captured ending includes the real native projectile frame");
               endFrames=flight==null?0:flight.frames.length;
               source.observePlayer(actor,getTimer());events=shots(true);
               check(events.length==1 && events[0].flight.frames.length==endFrames,"ended projectile does not accumulate hidden extra frames");
               sentAt=getTimer();phase=3;
            } else if(phase==3 && getTimer()-sentAt>=900) {
               check(shots(true).length==0,"published ending retires after its delivery window");
               fire(true);source.recording(false,false);
               check(shots(true).length==0,"disconnect releases a previously recorded projectile");
               Object(gun).kol_shoot=0;source.recording(true,true);source.observePlayer(actor,getTimer());fire(true);
               check(shots(true).length==1,"new subscription records new shots without replaying old history");
               Object(gun).kol_shoot=0;source.reset();
               check(shots(true).length==0,"room cleanup removes history without replaying an idle native gun");
               source.observePlayer(actor,getTimer());fire(true);
               Object(gun).b.vis=null;
               events=shots(true);
               check(events.length==1 && events[0].flight==null,"native projectile without a remaining clip is consumed count="+events.length);
               sentAt=getTimer();phase=4;
            } else if(phase==4 && getTimer()-sentAt>=900) {
               check(shots(true).length==0,"ended projectile without a clip also retires after capture");
               if(!host) {
                  check(bursts==3 && packets>=15,"normal snapshots continue while 75 extra player packets are received");
                  check(duplicates==0,"host emits at most one periodic snapshot per tick, duplicates="+duplicates+" packets="+packets);
               }
               finish();
            }
         } catch(err:*) {check(false,"exception "+err+" "+(err is Error?Error(err).getStackTrace():""));finish();}
      }
      private function finish():void {
         if(done)return;done=true;timer.stop();
         if(link!=null)link.removeEventListener(TcpLink.MESSAGE,receive);
         source.reset();
         if(gun!=null)Object(gun).remVisual();
         if(actor!=null)actor.remVisual();
         Log.d("COOP EFFECTS DONE architecture "+(host?"host":"join"));
      }
   }
}

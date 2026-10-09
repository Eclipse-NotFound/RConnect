package rconnect.core {
   import rconnect.net.TcpLink;

   /** Personal consent for impact damage to the player thrown by a teammate.
    * Only PeerGrip's authenticated release can arm this short native throw.
    * No HP repair, invulnerability, second physics pass or damage relay. */
   public class PeerThrowDamage {
      // AllData's ordinary raider uses 25; littlepip has no damwall parameter.
      private static const PONY_IMPACT:Number=25;
      // Unit.run tests Boolean(damWall), then damageWall clears t_throw before
      // testing damWall>0. -1 keeps native collision cleanup with no damage,
      // armor wear, stun or damage text. Zero would skip that cleanup entirely.
      private static const SAFE_IMPACT:Number=-1;
      private var mod:RConnectMod,flight:Object,patch:Object;

      public function PeerThrowDamage(m:RConnectMod) {mod=m;}
      public function get allowed():Boolean {return mod.config.getValue("peerThrowDamage")=="1";}
      public function get active():Boolean {return flight!=null;}
      public function setAllowed(value:Boolean):void {
         mod.config.setValue("peerThrowDamage",value?"1":"0");mod.config.save();
         // Read consent again before each native step, including in mid-flight.
      }
      public function arm(player:Object,link:TcpLink,stamp:Object):void {
         reset();
         if(player==null||player!==mod.game.gg||link==null||!link.isOpen||stamp==null
            ||player.sost!=1||player.hp<=0||int(player.t_throw)!=45)return;
         flight={player:player,link:link,loc:player.loc,key:String(stamp.roomKey),
            epoch:int(stamp.roomEpoch),term:int(stamp.roomTerm),counter:45};
      }
      private function valid():Boolean {
         if(flight==null)return false;
         var g:Object=mod.game.gg,r:Object=mod.session.rooms;
         return g===flight.player&&g.loc===flight.loc&&g.loc===mod.game.loc&&g.sost==1&&g.hp>0
            &&!g.disabled&&g.levit==0&&flight.link.isOpen&&r.ready&&!r.busy&&!mod.game.roomHold
            &&!mod.game.isTransitioning()&&mod.game.roomKey()==flight.key
            &&r.epoch==flight.epoch&&r.term==flight.term&&int(g.t_throw)>0
            &&int(g.t_throw)==flight.counter;
      }
      public function beforeStep():void {
         restore();
         if(!valid()){flight=null;return;}
         var w:Object=mod.game.world;
         if(mod.session.pause.paused||w.onPause||w.allStat!=1)return;
         var g:Object=flight.player,old:Number=Number(g.damWall);
         if(!isFinite(old)){flight=null;return;}
         var value:Number=allowed?(old>0?old:PONY_IMPACT):SAFE_IMPACT;
         patch={player:g,old:old,value:value};g.damWall=value;
      }
      public function afterStep():void {
         var rec:Object=flight,p:Object=patch,g:Object=rec==null?null:rec.player;
         // Enemy telekinesis may write a new damWall during the same world step.
         // Restore only our value, never an intervening native damage coefficient.
         var replaced:Boolean=p!=null&&Number(p.player.damWall)!=p.value;
         restore();
         if(rec==null)return;
         var counter:int=int(g.t_throw);
         if(replaced||counter<=0||(counter!=rec.counter&&counter!=rec.counter-1)
            ||g.levit!=0){flight=null;return;}
         rec.counter=counter;
         if(!valid())flight=null;
      }
      private function restore():void {
         var p:Object=patch;patch=null;
         if(p!=null&&Number(p.player.damWall)==p.value)p.player.damWall=p.old;
      }
      public function reset():void {restore();flight=null;}
   }
}

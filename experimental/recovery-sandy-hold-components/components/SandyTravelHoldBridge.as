package {
   import flash.display.Sprite;

   /** Proposal only. Compile beside the exact CEC6 single-player source after approval. */
   public final class SandyTravelHoldBridge extends Sprite {
      public static const NAME:String = "SandevistanTravelHoldV1";
      private var readWorld:Function, readState:Function;
      private var owner:Object, heldWorld:Object, heldGame:Object;
      private var ticket:String = "";

      public function SandyTravelHoldBridge(worldReader:Function,stateReader:Function) {
         name=NAME;visible=false;mouseEnabled=false;mouseChildren=false;
         readWorld=worldReader;readState=stateReader;
      }
      public function get version():int {return 1;}
      public function get contract():String {return "sandy-travel-hold/1";}

      /** No World or Sandevistan gameplay field is written by this carrier. */
      public function query(w:Object,g:Object):Object {
         try {
            var active:Boolean=isHeld();
            if(w==null || g==null || readWorld()!==w || w.game!==g)return null;
            var s:Object=readState();
            return {version:1,contract:contract,held:active,phase:s.phase,
               sandyLeft:s.sandyLeft,cooldownLeft:s.cooldownLeft,replayIndex:s.replayIndex,
               enemyEnabled:s.enemyEnabled,debugTest:s.debugTest};
         } catch(e:*) {return null;}
         return null; // ASC definite-return compatibility; unreachable.
      }

      /** Atomic idle check + acquisition. Active player recordings cannot cross a new map. */
      public function acquire(leaseOwner:Object,w:Object,g:Object,id:String):Boolean {
         if(leaseOwner==null || w==null || g==null || id==null || id=="")return false;
         try {
            isHeld();
            if(readWorld()!==w || w.game!==g)return false;
            if(owner!=null)return owner===leaseOwner && heldWorld===w && heldGame===g && ticket===id;
            var s:Object=readState();
            if(s.phase!=="idle" || s.debugTest===true)return false;
            owner=leaseOwner;heldWorld=w;heldGame=g;ticket=id;return true;
         } catch(e:*) {return false;}
         return false; // ASC definite-return compatibility; unreachable.
      }

      /** The exact owner can cancel even after a Game replacement; no old flags are restored. */
      public function release(leaseOwner:Object,id:String):Boolean {
         if(owner!==leaseOwner || owner==null || ticket!==id)return false;
         clear();return true;
      }

      /** Fast no-ticket branch; exceptions fail closed until the owner releases/retries. */
      public function isHeld():Boolean {
         if(owner==null)return false;
         try {
            if(readWorld()!==heldWorld || heldWorld==null || heldWorld.game!==heldGame) {
               clear();return false;
            }
         } catch(e:*) {return true;}
         return true;
      }
      private function clear():void {owner=heldWorld=heldGame=null;ticket="";}
   }
}

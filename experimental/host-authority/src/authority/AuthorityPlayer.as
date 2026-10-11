package authority {
   import fe.unit.UnitPlayer;
   import fe.weapon.Bullet;
   /** Real UnitPlayer type for native weapon casts; never a UnitPonPon puppet. */
   public class AuthorityPlayer extends UnitPlayer {
      public var scope:NativeScope,context:Object;
      public var onExit:Function,onDeath:Function;
      public function AuthorityPlayer(){super();}
      override public function damage(amount:Number,type:int,bullet:Bullet=null,periodic:Boolean=false):Number {
         if(scope==null)return super.damage(amount,type,bullet,periodic);
         var call:Function=function():Number {return nativeDamage(amount,type,bullet,periodic);};
         return Number(scope.run(context,call));
      }
      private function nativeDamage(amount:Number,type:int,bullet:Bullet,periodic:Boolean):Number {
         return super.damage(amount,type,bullet,periodic);
      }
      override public function outLoc(direction:int,x:Number=-1,y:Number=-1):Boolean {
         return onExit!=null && Boolean(onExit(direction,x,y));
      }
      override public function die(type:int=0):* {
         if(onDeath!=null)onDeath(type);
         else throw new Error("B1 death lifecycle is not enabled");
      }
   }
}

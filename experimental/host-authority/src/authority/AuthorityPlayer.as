package authority {
   import fe.unit.UnitPlayer;
   import fe.unit.AuthorityAnimation;
   import fe.weapon.Bullet;
   /** Real UnitPlayer type for native weapon casts; never a UnitPonPon puppet. */
   public class AuthorityPlayer extends UnitPlayer {
      public var scope:NativeScope,context:Object;
      public var onDeath:Function;
      public function AuthorityPlayer(){super();}
      public function get predictionBlocked():Boolean {return diagon!=0 || AuthorityAnimation.inCover(this);}
      override public function damage(amount:Number,type:int,bullet:Bullet=null,periodic:Boolean=false):Number {
         if(scope==null)return super.damage(amount,type,bullet,periodic);
         var call:Function=function():Number {return nativeDamage(amount,type,bullet,periodic);};
         return Number(scope.run(context,call));
      }
      private function nativeDamage(amount:Number,type:int,bullet:Bullet,periodic:Boolean):Number {
         return super.damage(amount,type,bullet,periodic);
      }
      override public function outLoc(direction:int,x:Number=-1,y:Number=-1):Boolean {
         return super.outLoc(direction,x,y);
      }
      override public function die(type:int=0):* {
         if(scope==null)return super.die(type);
         scope.run(context,function():void {nativeDeath(type);});
      }
      private function nativeDeath(type:int):void {super.die(type);}
   }
}

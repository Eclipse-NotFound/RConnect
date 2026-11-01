package fe.unit {
   import fe.weapon.Bullet;
   import flash.geom.Rectangle;
   import flash.display.BitmapData;
   public class Unit {
      internal var anims:Array;
      internal var blitRect:Rectangle;
      internal var blitX:int;
      internal var visData:BitmapData;
      internal var burn:Object;
      protected var diagon:int;
      public function blit(row:int,frame:int):* {}
      public function step():* {}
      public function damage(amount:Number,type:int,bullet:Bullet=null,periodic:Boolean=false):Number{return 0;}
      public function die(type:int=0):* {}
      public function outLoc(direction:int,x:Number=-1,y:Number=-1):Boolean{return false;}
   }
}

package fe.unit
{
   import fe.weapon.Bullet;
   // Compile-only public signatures; external SWC, never embedded in the mod.
   public class Unit
   {
      public function Unit(id:String=null,difficulty:Number=100,map:XML=null,data:Object=null) {}
      public function damage(amount:Number,type:int,bullet:Bullet=null,periodic:Boolean=false):Number { return 0; }
      public function die(type:int=0):* {}
   }
}

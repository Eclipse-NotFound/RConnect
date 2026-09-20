package fe.weapon {
   import fe.unit.Unit;
   public class Weapon {
      public function Weapon(owner:Unit,id:String,variant:int=0) {}
      protected function shoot():Bullet { return null; }
   }
}

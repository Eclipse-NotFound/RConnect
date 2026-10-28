package fe.weapon {
   import fe.unit.Unit;
   import flash.display.MovieClip;
   public class WClub extends Weapon {
      internal var visvzz:MovieClip;
      public function WClub(owner:Unit,id:String,variant:int=0) {super(owner,id,variant);}
   }
}

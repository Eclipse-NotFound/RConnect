package rconnect.game {
   import fe.loc.Bonus;
   import fe.loc.Location;
   /** Preserve native pickup effects/calculation on the room owner only. */
   public class CooperativeBonus extends Bonus {
      private var progress:WorldProgress;
      public function CooperativeBonus(loc:Location,x:int,y:int,state:Object,p:WorldProgress) {
         super(loc,"xp",x,y,null,state);progress=p;
      }
      override public function take():* {progress.take(this);}
      public function takeNative():void {super.take();}
   }
}

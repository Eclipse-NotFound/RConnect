package fe.unit {
   /** Native Mine explosion, with the cooperative player receivers selected
    * only during target enumeration. Enemy damage, terrain and visuals use
    * the original explosion exactly once. */
   public class RConnectPlayerMine extends Mine {
      private var targets:Function;
      public function RConnectPlayerMine(id:String,select:Function) {super(id);targets=select;}
      override public function dropLoot():* {
         var self:Object=this,room:Object=self.loc,original:Array=room.units;
         try {if(targets!=null)room.units=targets(this,original);super.dropLoot();}
         finally {room.units=original;}
      }
   }
}

package rconnect.game {
   import fe.unit.Unit;
   import fe.unit.Mine;
   /** Native trap perception with the observing player's own direction, eye
    * position and detection skill. Discovery belongs to the room owner. */
   public final class MineSight {
      private var observer:Object;
      private static const FIELDS:Array=["X","Y","scX","scY","storona","eyeX","eyeY",
         "vision","detecting","vKonus","vAngle","mater"];
      public static function capture(player:Object):Object {
         var out:Object={range:GameBridge.probeNum(GameBridge.probe(player,"pers"),"visiTrap",0)};
         for each(var name:String in FIELDS)out[name]=GameBridge.probe(player,name);
         return out;
      }
      public function reveal(room:Object,sight:Object):void {
         if(room==null||sight==null||!isFinite(Number(sight.range))||Number(sight.range)<=0||Number(sight.range)>10000)return;
         if(observer==null)observer=new Unit();
         for each(var name:String in FIELDS) {
            var value:*=sight[name];
            if(!(value is Boolean)&&(!isFinite(Number(value))||Math.abs(Number(value))>100000))return;
            if(value===undefined||value===null)return;
            observer[name]=value;
         }
         observer.loc=room;
         for each(var unit:Object in room.units)if(unit is Mine&&unit.fraction>0&&unit.fraction<100
            &&unit.sost<3&&!unit.isVis&&observer.look(unit,false,Number(sight.range))>0)unit.setVis(true);
      }
   }
}

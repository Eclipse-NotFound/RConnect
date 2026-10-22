package {
   /** Non-Tile getter fixture; getter order and missing/throw/NaN semantics remain observable. */
   public class GetterTile {
      public var calls:Array=[],throwFront:Boolean=false,missingHp:Boolean=false,frontDamage:int=0;
      public var currentHp:*=100,currentPhis:Number=1,currentFront:String="wall";
      public var back:String="back",zad:String="rear",zForm:int=0,water:int=0,stair:int=0;
      public var opac:Number=1,vid:int=0,vid2:int=0,diagon:int=0,shelf:Boolean=false;
      public var door:Object=null,indestruct:Boolean=false;
      public function get phis():Number {calls.push("phis");return currentPhis;}
      public function set phis(v:Number):void {calls.push("setPhis");currentPhis=v;}
      public function get hp():* {calls.push("hp");if(missingHp)throw new Error("missing HP fixture");return currentHp;}
      public function set hp(v:*):void {calls.push("setHp");currentHp=v;}
      public function get front():String {calls.push("front");if(frontDamage)currentHp-=frontDamage;if(throwFront)throw new Error("front fixture");return currentFront;}
      public function set front(v:String):void {calls.push("setFront");currentFront=v;}
      public function setZForm(v:int):void {zForm=v;}
   }
}

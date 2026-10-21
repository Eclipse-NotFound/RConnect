package rconnect.game {
   /** Explicit confirmed-native-event fixture, never a collision detector. */
   public class BallisticImpactVisuals {
      public static var played:Array=[];
      public static function capture(b:Object,stamp:int):Object {return GameBridge.probe(b,"fixtureImpact");}
      public static function play(main:Object,loc:Object,s:Object):void {played.push(s);}
      public static function reset():void {played=[];}
   }
}

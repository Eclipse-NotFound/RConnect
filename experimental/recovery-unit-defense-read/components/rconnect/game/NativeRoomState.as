package rconnect.game { public class NativeRoomState {
public static function numbers(values:Array):Array
      {
         var out:Array=[];
         for each(var value:* in values)out.push(Number(value));
         return out;
      }
} }

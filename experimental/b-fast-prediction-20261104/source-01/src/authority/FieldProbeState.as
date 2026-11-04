package authority {
   /** Typed public storage exercises the same describeType route as native objects. */
   public final class FieldProbeState {
      public var X:Number=0,hp:Number=100;
      public var label:String="";
      public var active:Boolean=true;
      public var optional:*;
      public var nativeReference:Object;
      public var typedList:Array=[1,2,3];
      public var typedBody:FieldProbeState;
   }
}

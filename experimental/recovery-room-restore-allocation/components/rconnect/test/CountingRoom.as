package rconnect.test {
   /** Test-only room. Counts grid access without changing the Tile fields. */
   public dynamic class CountingRoom {
      public var raw:Array=[];
      public var reads:int=0;
      public var failAfter:int=-1;
      public function get space():Object {
         reads++;
         if(failAfter>=0 && reads>failAfter)throw new Error("Late grid read");
         return raw;
      }
   }
}

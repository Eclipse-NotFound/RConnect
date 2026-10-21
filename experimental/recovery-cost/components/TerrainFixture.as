package {
   /** Public fixture for dynamically invoked terrain methods in CallsBefore/After. */
   public class TerrainFixture {
      public function hostPatch(loc:Object):Array{return [{x:0,y:0}];}
      public function report(loc:Object):Object{return {tiles:[{x:0,y:0}]};}
   }
}

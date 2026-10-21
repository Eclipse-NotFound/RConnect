package fe.weapon {
   /** Native contact input only; no simulated movement, collision or artwork. */
   public class Bullet {
      public var loc:Object,nobj:Object;
      public var tipDecal:int=1;
      public var tilehit:Boolean=false,babah:Boolean=false;
      public var X:Number=0,Y:Number=0,explRadius:Number=0,expl_t:int=0;
   }
}

package fe.weapon {
 // Component contact carrier only. No native damage, movement or rendering.
 public class Bullet {
  public var loc:Object,nobj:Object=null;
  public var X:Number,Y:Number,tipDecal:int=15,explRadius:Number=0,expl_t:int=0;
  public var tilehit:Boolean=false,babah:Boolean=false;
  public function Bullet(room:Object,x:Number,y:Number){loc=room;X=x;Y=y;}
 }
}

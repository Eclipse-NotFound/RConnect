package fe.loc {
 import fe.serv.Item;
 public class Loot {
  public function Loot(loc:Location,item:Item,x:Number,y:Number,jump:Boolean=false,krit:Boolean=false,auto:Boolean=true) {}
  public function take(force:Boolean=false):* {}
  public function toTake():* {}
  public function step():* {}
  public function run(divisor:int=1):* {}
 }
}

package {
 public final class HoldWorld {
  private var current:Object;
  public var gameThrows:Boolean=false,gameWrites:int=0,onPause:int=17,ggControl:int=19;
  public function HoldWorld(g:Object){current=g;}
  public function get game():Object{if(gameThrows)throw new Error("fixture Game getter");return current;}
  public function set game(g:Object):void{gameWrites++;current=g;}
  public function replace(g:Object):void{current=g;}
 }
}

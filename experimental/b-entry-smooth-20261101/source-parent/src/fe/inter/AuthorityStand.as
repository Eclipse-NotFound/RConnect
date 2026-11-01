package fe.inter {
 import flash.display.MovieClip;
 public class AuthorityStand extends Stand {
  public var serial:uint=0;
  public function AuthorityStand(v:MovieClip,inv:*){super(v,inv);}
  override public function onoff(a:int=0):* {super.onoff(a);++serial;}
  public function snapshot():Object {return {serial:serial,active:active,page:page};}
 }
}

package fe.inter {
 import flash.display.MovieClip;
 /** A native PipBuck owned by the remote actor; its visuals stay off-stage. */
 public class AuthorityPip extends PipBuck {
  public var serial:uint=0;
  public var revision:uint=0;
  public function AuthorityPip(v:MovieClip){super(v);toNormalMode();}
  override public function onoff(a:int=0,b:int=0):* {
   var saved:Object=AuthorityMenus.viewBasket(vendor);
   try{super.onoff(a,b);++serial;}finally{AuthorityMenus.restoreView(saved);}
  }
  override public function setPage(sub:int=0):* {
   var saved:Object=AuthorityMenus.viewBasket(vendor);
   try{super.setPage(sub);}finally{AuthorityMenus.restoreView(saved);}
  }
 }
}

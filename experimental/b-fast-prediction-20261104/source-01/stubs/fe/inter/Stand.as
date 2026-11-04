package fe.inter {
 import flash.display.MovieClip;
 public class Stand {
  internal var page:int;
  internal var weapons:Array;
  public var active:Boolean;
  public function Stand(v:MovieClip,inv:*){}
  public function onoff(a:int=0):*{}
  internal function showWeaponList(page:int):*{}
 }
}

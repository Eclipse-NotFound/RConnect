package fe.inter {
 import flash.display.MovieClip;
 public class PipBuck {
  internal var vis:MovieClip,vishelp:MovieClip;
  internal var page:int,pages:Array,gg:*,inv:*,money:int;
  public var light:Boolean,active:Boolean,noAct:Boolean,vendor:*,npcInter:String,npcId:String,workTip:String;
  public var currentPage:PipPage;
  public function PipBuck(v:MovieClip){}
  public function onoff(a:int=0,b:int=0):*{}
  public function toNormalMode():*{}
  public function setPage(sub:int=0):*{}
  public function setRPanel():*{}
  public function allItems():*{}
 }
}

package fe.inter {
 import fe.unit.Invent;import fe.unit.Pers;import fe.unit.UnitPlayer;import flash.display.MovieClip;
 public class AddictionUIBridge {
  public static function bind(p:PipBuck,inv:Invent,pers:Pers,gg:UnitPlayer):void {
   p.inv=inv;p.gg=gg;
   for each(var item:PipPage in p.pages)if(item){item.inv=inv;item.gg=gg;
    if(item is PipPageMed)PipPageMed(item).pers=pers;
    if(item is PipPageStat)PipPageStat(item).pers=pers;
   }
  }
  public static function page(p:PipBuck):int{return p.page;}
  public static function view(p:PipBuck):MovieClip{return p.vis;}
 }
}

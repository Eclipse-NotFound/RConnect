package fe.inter {
 import authority.*;
 import flash.display.MovieClip;
 import flash.events.MouseEvent;
 /** Execute original menu handlers against newly generated, authoritative rows.
  * No price, repair, crafting or storage arithmetic is copied into the mod. */
 public final class AuthorityMenus {
  public static var replaying:int=0;
  public static function belongs(target:Object,pip:PipBuck):Boolean {
   return target is PipPage && PipPage(target).pip===pip;
  }
  public static function viewBasket(v:Object):Object {
   if(v==null || replaying>0)return null;
   var saved:Object={vendor:v,price:v.multPrice,buy:v.kolBou,sell:v.kolSell,counts:[]};
   for each(var item:Object in v.buys)saved.counts.push({item:item,count:item.bou});
   return saved;
  }
  public static function restoreView(saved:Object):void {
   if(saved==null)return;
   saved.vendor.multPrice=saved.price;saved.vendor.kolBou=saved.buy;saved.vendor.kolSell=saved.sell;
   for each(var state:Object in saved.counts)state.item.bou=state.count;
  }
  public static function basket(page:Object,all:Boolean=false):Array {
   var p:PipPageVend=page as PipPageVend,result:Array=[];
   if(p==null)return result;
   for(var id:String in p.assArr) {
    var item:Object=p.assArr[id],amount:int=all && item.tip=="valuables"?item.kol:int(item.bou);
    if(amount>0)result.push({id:id,count:amount});
   }
   return result;
  }
  private static function select(pip:PipBuck,page:int,sub:int):PipPage {
   pip.page=page;pip.setPage(sub);return pip.currentPage;
  }
  private static function row(page:PipPage,id:String):MovieClip {
   for each(var value:Object in page.arr)if(value!=null && String(value.id)==id) {
    var result:MovieClip=page.statArr[0];page.setStatItem(result,value);return result;
   }
   return null;
  }
  public static function validAppearance(value:Object):Boolean {
   if(value==null || !(value.visHair1 is Boolean))return false;
   for each(var key:String in ["cFur","cHair","cHair1","cEye","cMagic"])
    if(!(value[key] is Number) || value[key]!=uint(value[key]) || value[key]<0 || value[key]>0xffffff)return false;
   return value.fEye is Number && value.fEye==int(value.fEye) && value.fEye>=1 && value.fEye<=6 &&
    value.fHair is Number && value.fHair==int(value.fHair) && value.fHair>=1 && value.fHair<=5;
  }
  public static function execute(actor:PlayerActor,key:String,args:Array):Boolean {
   var w:Object=actor.access.world,p:PipBuck=actor.context.pip as PipBuck;
   if(p==null)return false;
   if(key=="menuStandClose") {++replaying;try{actor.context.stand.onoff(-1);}finally{--replaying;}return true;}
   if(key=="menuClose") {++replaying;try{p.onoff(-1);}finally{--replaying;}return true;}
   if(p.noAct || actor.unit.hp<=0)return false;
   var pg:PipPage,r:MovieClip,id:String=args.length>1?String(args[1]):"";
   ++replaying;
   try {
    if(key=="menuAppearance") {
     actor.context.app.load(args[0]);actor.unit.refreshVis();p.onoff(-1);return true;
    } else if(key=="menuWork") {
     var requested:String=String(args[2]);
     var portableId:String=requested=="lab"?"mworklab":requested=="expl"?"mworkexpl":requested;
     var portable:Boolean=portableId.indexOf("mwork")==0 && actor.unit.invent.items[portableId]!=null && actor.unit.invent.items[portableId].kol>0;
     if(!portable && !(p.active && p.page==7 && requested==p.workTip))return false;
     if(!actor.unit.loc.base && portable && actor.context.t_battle>0)return false;
     p.workTip=requested;pg=select(p,7,int(args[0]));
    } else if(key=="menuVault" || key=="menuVaultAll") {
     if(!actor.unit.loc.base && !(p.active && p.page==9))return false;
     pg=select(p,9,int(args[0]));
     if(key=="menuVaultAll"){PipPageVault(pg).sbrosHlam();return true;}
     r=row(pg,id);if(r==null)return false;PipPageVault(pg).chKol(r,int(args[2]));return true;
    } else if(key=="menuMedical") {
     if(!p.active || p.page!=6)return false;pg=select(p,6,int(args[0]));
    } else if(key=="menuVendor") {
     if(!p.active || p.vendor==null)return false;
     return transaction(p,int(args[0]),args[1] as Array);
    } else if(key=="menuRepair") {
     if(!p.active || p.vendor==null)return false;pg=select(p,4,3);
    } else if(key=="menuAmmo")pg=select(p,2,5);
    else return false;
    r=row(pg,id);if(r==null)return false;
    r.dispatchEvent(new MouseEvent(MouseEvent.CLICK));return true;
   } finally {--replaying;}
   return false;
  }
  private static function transaction(p:PipBuck,sub:int,items:Array):Boolean {
   var vendor:Object=p.vendor,saved:Object={price:vendor.multPrice,buy:vendor.kolBou,sell:vendor.kolSell,counts:[]};
   for each(var original:Object in vendor.buys)saved.counts.push({item:original,count:original.bou});
   try {
    vendor.reset();vendor.kolSell=0;
    var page:PipPageVend=select(p,4,sub) as PipPageVend;
    if(page==null)return false;
    for each(var request:Object in items) {
     var item:Object=page.assArr[request.id];
     if(item==null || int(request.count)>int(item.kol))return false;
     page.selBuy(item,int(request.count));
     if(int(item.bou)!=int(request.count))return false;
    }
    if(sub==1)page.trade(page.assArr);else page.sell(page.assArr);
    return true;
   } finally {
    // The other player's staged basket is presentation state. Actual stock and
    // money remain the result of the transaction; its next commit revalidates.
    vendor.multPrice=saved.price;
    vendor.kolBou=p is AuthorityPip?saved.buy:0;vendor.kolSell=p is AuthorityPip?saved.sell:0;
    for each(var state:Object in saved.counts)state.item.bou=p is AuthorityPip?state.count:0;
   }
   return false;
  }
  public static function capture(p:AuthorityPip):Object {
   if(p==null)return null;
   var v:Object=p.vendor,stock:Array=[];
   if(v!=null)for each(var item:Object in v.buys)stock.push({id:item.id,fields:NativeFields.capture(item)});
   return {serial:p.serial,revision:p.revision,active:p.active,page:p.page,sub:p.currentPage==null?1:p.currentPage.page2,
    work:p.workTip,npc:p.npcId,interaction:p.npcInter,vendor:v==null?null:{id:v.id,xml:v.xml==null?null:v.xml.toXMLString(),money:v.money,stock:stock}};
  }
  public static function apply(access:NativeAccess,state:Object,opened:Boolean,refreshOnly:Boolean=false):void {
   if(state==null)return;
   var w:Object=access.world,p:PipBuck=w.pip as PipBuck;
   if(opened || refreshOnly) {
    p.workTip=state.work;p.npcId=state.npc;p.npcInter=state.interaction;
    if(state.vendor==null)p.vendor=null;
    else {
     var Vendor:Class=access.definition("fe.serv.Vendor"),Item:Class=access.definition("fe.serv.Item");
     // Always build a display copy. Never run a client vendor transaction.
     var v:Object=new Vendor(0,<vendor id="random"/>,[],"vendor");
     v.id=state.vendor.id;v.xml=state.vendor.xml==null?null:new XML(state.vendor.xml);v.money=state.vendor.money;v.buys=[];v.buys2=[];
     for each(var record:Object in state.vendor.stock) {
      var item:Object=new Item(null,record.id,0);NativeFields.apply(item,record.fields);v.buys.push(item);
      v.buys2[item.id+(item.variant>0?"^"+item.variant:"")]=item;
     }
     p.vendor=v;
    }
    if(opened)p.onoff(state.active?int(state.page):-1,int(state.sub));
    else if(p.active){p.money=w.invent.money.kol;refresh(p);}
   }
  }
  public static function refresh(p:PipBuck):void {if(p!=null && p.active && p.currentPage!=null){p.currentPage.setStatus(false);p.setRPanel();}}
  public static function refreshStand(s:Stand):void {if(s!=null && s.active)s.showWeaponList(s.page);}
 }
}

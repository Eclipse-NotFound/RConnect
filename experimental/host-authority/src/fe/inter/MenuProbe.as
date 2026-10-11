package fe.inter {
 import authority.*;
 import flash.display.MovieClip;
 import flash.events.MouseEvent;
 import flash.utils.getTimer;
 /** Real native rows/events on the joining UI, actual resource changes on host. */
 public final class MenuProbe extends Probe {
  private var ready:Boolean=false,stage:int=0,done:int=0,acted:int=0,at:int=0;
  private var request:Object,vendor:Object,initial:Object,recipe:XML,product:String;
  private var expected:Object,joinActor:PlayerActor,hostActor:PlayerActor;
  public function MenuProbe(a:NativeAccess,h:Boolean){super(a,h);}
  override public function message(value:Object):void {
   if(host && value.type=="input" && value.probeMenuDone is Number)done=int(value.probeMenuDone);
   if(!host && value.type=="probe-menu")request=value;
  }
  override public function input(frame:Object,session:HostSession):Object {frame.buttons=0;if(!host)frame.probeMenuDone=done;return frame;}
  private function visibleRow(p:PipBuck,id:String):MovieClip {
   for each(var value:Object in p.currentPage.arr)if(String(value.id)==id) {
    var row:MovieClip=p.currentPage.statArr[0];p.currentPage.setStatItem(row,value);return row;
   }
   throw new Error("Native menu did not generate requested row "+p.page+"/"+p.currentPage.page2+"/"+id);
  }
  private function click(p:PipBuck,id:String):void {visibleRow(p,id).dispatchEvent(new MouseEvent(MouseEvent.CLICK));}
  override public function observe(session:HostSession,replica:ClientReplica):void {
   if(finished)return;
   var w:Object=access.world,p:PipBuck=w.pip as PipBuck;
   if(!host) {
    if(replica==null || replica.displayFrame==null || request==null)return;
    var state:Object=replica.displayFrame.character.menu;
    if(state==null || state.serial<request.serial || request.standSerial!=null && replica.displayFrame.character.stand.serial<request.standSerial)return;
    if(acted<request.stage) {
     acted=request.stage;at=getTimer();
     check(state.serial==request.serial,"joining native menu receives owner-specific open command",{stage:acted,page:p.page,sub:p.currentPage.page2});
     var before:int=w.invent.items.pot0.kol;
     if(acted==1 || acted==2 || acted==9 || acted==10) {
      var v:PipPageVend=p.currentPage as PipPageVend;
      v.selBuy(v.assArr.pot0,acted==10?1:2);
      if(acted==2)v.sell(v.assArr);else v.trade(v.assArr);
      check(w.invent.items.pot0.kol==before,"client trade click sends intent without local inventory mutation",{stage:acted});
     } else if(acted==3)click(p,"lmg");
     else if(acted==4 || acted==5)PipPageVault(p.currentPage).chKol(visibleRow(p,"kofe"),acted==4?4:0);
     else if(acted==6)click(p,request.product);
     else if(acted==7)click(p,"hp");
     else if(acted==8) {
      p.onoff(-1);
      access.definition("fe.inter.PipBuck")["rconnectMenu"](p,"menuWork",[1,request.product,request.work]);
     } else if(acted==11) {
      check(w.stand.active,"native weapon stand opens on the interacting player's screen");
      Stand(w.stand).weapons.lmg.dispatchEvent(new MouseEvent(MouseEvent.CLICK));
     } else if(acted==12) {
      var appearance:Object=w.app.save();appearance.cFur=0x345678;w.app.load(appearance);
      Object(p.currentPage).funVidOk();
     }
    }
    if(done<acted && getTimer()-at>1500 && replica.displayFrame.tick>request.tick+8) {
     if(acted==1)check(w.invent.items.pot0.kol==7 && p.vendor.buys2.pot0.kol==3,"confirmed shop purchase and remaining stock reach joining UI");
     if(acted==2)check(w.invent.items.pot0.kol==5 && p.vendor.buys2.pot0.kol==5,"confirmed sale returns stock and updates joining inventory");
     if(acted==3)check(w.invent.weapons.lmg.hp==w.invent.weapons.lmg.maxhp,"native vendor repair is confirmed on joining equipment");
     if(acted==4)check(w.invent.items.kofe.kol==5 && w.invent.items.kofe.vault==4,"native warehouse deposit is confirmed in both item counters");
     if(acted==5)check(w.invent.items.kofe.kol==9 && w.invent.items.kofe.vault==0,"native warehouse withdrawal restores the same items");
     if(acted==6)check(w.invent.items[request.product].kol==request.productCount,"native recipe output appears in joining personal inventory",{product:request.product,actual:w.invent.items[request.product].kol,expected:request.productCount});
     if(acted==7)check(w.gg.hp==w.gg.maxhp,"native medical treatment restores joining health");
     if(acted==8)check(!p.active && w.invent.items[request.product].kol==request.productCount,"closed workbench cannot create extra items");
     if(acted==9)check(w.invent.items.pot0.kol==7,"peer purchase succeeds while host has a staged basket");
     if(acted==10)check(w.invent.items.pot0.kol==7,"stale client quote cannot buy stock already taken by host");
     if(acted==11)check(w.invent.weapons.lmg.respect==request.respect,"stand selection confirms the original native weapon storage state",{expected:request.respect,actual:w.invent.weapons.lmg.respect});
     if(acted==12)check(w.app.save().cFur==0x345678 && !p.active,"native appearance confirmation closes its own editor");
     done=acted;
     if(done==12){SceneChecks.picture(access,"native-menus-confirmed.png");finish();}
    }
    return;
   }
   if(session==null || !session.active)return;
   if(!ready) {
    ready=true;hostActor=session.actors[0];joinActor=session.actors[1];
    var room:Object=joinActor.unit.loc,fy:Number=ProbeArena.floor(room);
    hostActor.unit.setLocPos(300,fy);joinActor.unit.setLocPos(600,fy);w.helpMess=false;
    for each(var actor:PlayerActor in session.actors)access.scope.run(actor.context,function():void {
     actor.unit.invent.money.kol=100000;actor.unit.invent.items.pot0.kol=actor.id==0?17:5;
     actor.unit.invent.items.kofe.kol=actor.id==0?17:9;actor.unit.invent.items.kofe.vault=0;
    });
    var Vendor:Class=access.definition("fe.serv.Vendor"),Item:Class=access.definition("fe.serv.Item");
    vendor=new Vendor(0,<vendor id="random"/>,[],"vendor");vendor.id="b-menu-fixture";vendor.money=100000;vendor.buys=[];vendor.buys2=[];
    var stock:Object=new Item(null,"pot0",5);vendor.buys.push(stock);vendor.buys2.pot0=stock;
    initial={hostMoney:hostActor.unit.invent.money.kol,hostHP:hostActor.unit.hp,hostGun:hostActor.unit.currentWeapon.hp};
    next(session);return;
   }
   if(done<stage)return;
   var g:Object=joinActor.unit,inv:Object=g.invent;
   if(stage==1)check(inv.items.pot0.kol==7 && vendor.buys2.pot0.kol==3 && inv.money.kol==expected.money,"joining purchase commits once with native price and shared vendor stock",{money:inv.money.kol,expected:expected.money});
   if(stage==2)check(inv.items.pot0.kol==5 && vendor.buys2.pot0.kol==5 && inv.money.kol==expected.money,"joining sale commits once with original native sell price");
   if(stage==3)check(g.currentWeapon.hp==g.currentWeapon.maxhp && inv.money.kol==expected.money,"joining repair uses native durability and repair cost");
   if(stage==4)check(inv.items.kofe.kol==5 && inv.items.kofe.vault==4,"host executes joining warehouse deposit once");
   if(stage==5)check(inv.items.kofe.kol==9 && inv.items.kofe.vault==0,"host executes joining warehouse withdrawal without duplication");
   if(stage==6) {
    check(inv.items[product].kol==expected.productCount,"native crafting creates exact recipe output",{product:product,actual:inv.items[product].kol,expected:expected.productCount});
    for each(var component:XML in recipe.craft)check(inv.items[String(component.@id)].kol==100-int(component.@kol),"crafting spends native recipe component once",{component:String(component.@id),actual:inv.items[String(component.@id)].kol});
   }
   if(stage==7)check(g.hp==g.maxhp && inv.money.kol==expected.money,"medical service uses joining health and joining payment");
   if(stage==8) {
    check(inv.items[product].kol==expected.productCount,"closed workshop action is rejected on host");
    check(hostActor.unit.invent.money.kol==initial.hostMoney && hostActor.unit.invent.items.kofe.kol==17 && hostActor.unit.invent.items.pot0.kol==17,
     "all joining menu mutations leave host bag and money unchanged");
    check(hostActor.unit.currentWeapon.hp==initial.hostGun && w.pip===hostActor.context.pip && w.stand===hostActor.context.stand && w.gg===hostActor.unit && access.scope.depth==0,
     "native menus restore host weapon, UI and player ownership");
   }
   if(stage==9) {
    var hostPip:PipBuck=hostActor.context.pip as PipBuck,hpage:PipPageVend=hostPip.currentPage as PipPageVend;
    check(inv.items.pot0.kol==7 && vendor.buys2.pot0.kol==1,"joining buy consumes one shared stock while host is shopping");
    check(vendor.kolBou==expected.hostBasket && hpage.assArr.pot0.bou==2,"remote menu opening and transaction preserve host staged basket",{actual:vendor.kolBou,expected:expected.hostBasket});
    hpage.trade(hpage.assArr);
    check(hostActor.unit.invent.items.pot0.kol==17 && vendor.buys2.pot0.kol==1,"host stale basket is also revalidated before native resource mutation");
    hostPip.setPage(1);hpage=hostPip.currentPage as PipPageVend;hpage.selBuy(hpage.assArr.pot0,1);hpage.trade(hpage.assArr);
    check(hostActor.unit.invent.items.pot0.kol==18 && vendor.buys2.pot0.kol==0 && vendor.kolBou==0,"host can reselect remaining stock and clear its completed basket");
   }
   if(stage==10)check(inv.items.pot0.kol==7 && vendor.buys2.pot0.kol==0,"host rejects joining stale stock without granting items");
   if(stage==11)check(inv.weapons.lmg.respect==expected.respect,"weapon stand action executes against the joining native inventory",{expected:expected.respect,actual:inv.weapons.lmg.respect});
   if(stage==12) {
    var confirmed:Object=access.scope.run(joinActor.context,function():Object{return joinActor.context.app.save();});
    check(confirmed.cFur==0x345678,"joining appearance edit reaches the real host-side player");
    check(w.app.save().cFur==initial.hostFur && w.gg===hostActor.unit && access.scope.depth==0,"joining appearance does not replace host appearance or owner");
    finish();return;
   }
   next(session);
  }
  private function next(session:HostSession):void {
   ++stage;var actor:PlayerActor=joinActor,g:Object=actor.unit,inv:Object=g.invent,p:AuthorityPip=actor.context.pip as AuthorityPip;
   expected={};
   if(stage==9) {
    vendor.buys2.pot0.kol=3;inv.items.pot0.kol=5;
    var hp:PipBuck=hostActor.context.pip as PipBuck;hp.vendor=vendor;hp.npcInter="vr";hp.onoff(4,1);
    var hv:PipPageVend=hp.currentPage as PipPageVend;hv.selBuy(hv.assArr.pot0,2);expected.hostBasket=vendor.kolBou;
   }
   access.scope.run(actor.context,function():void {
    p.vendor=vendor;p.npcInter="vr";
    if(stage==1 || stage==2) {
     p.onoff(4,stage);var page:PipPageVend=p.currentPage as PipPageVend,item:Object=page.assArr.pot0;
     expected.money=inv.money.kol+(stage==1?-Math.ceil(item.price*item.mp*2):Math.floor(item.price*2));
    } else if(stage==3) {
     g.currentWeapon.hp=Math.floor(g.currentWeapon.maxhp*.4);p.onoff(4,3);
     expected.money=inv.money.kol-int(visibleRow(p,"lmg").price.text);
    } else if(stage==4 || stage==5)p.onoff(9,inv.items.kofe.invCat);
    else if(stage==6) {
     for each(var scheme:XML in access.definition("fe.AllData")["d"].item) {
      var id:String=String(scheme.@id),candidate:String=id.substr(2);
      if(id.indexOf("s_")!=0 || scheme.craft.length()==0 || inv.items[candidate]==null || inv.weapons[candidate]!=null || inv.armors[candidate]!=null)continue;
      if(inv.items[candidate].xml.@one=="1" || String(inv.items[candidate].xml.@tip)=="impl")continue;
      recipe=scheme;product=candidate;break;
     }
     if(recipe==null)throw new Error("No native consumable recipe for probe");
     inv.items[String(recipe.@id)].kol=1;inv.items[product].kol=0;
     for each(var component:XML in recipe.craft)inv.items[String(component.@id)].kol=100;
     if(recipe.@skill.length())g.pers.skills[String(recipe.@skill)]=100;
     g.pers.potmaster=false;g.pers.setParameters();
     p.workTip=recipe.@work.length()?String(recipe.@work):"work";p.onoff(7,1);
     expected.productCount=recipe.@kol.length()?int(recipe.@kol):1;
    } else if(stage==7) {
     g.hp=g.maxhp-100;g.rad=0;expected.money=inv.money.kol-Math.round(100*g.pers.priceHP);p.npcInter="doc";p.onoff(6,1);
    } else if(stage==8) {
     p.workTip=recipe.@work.length()?String(recipe.@work):"work";p.onoff(7,1);expected.productCount=inv.items[product].kol;
    } else if(stage==9)p.onoff(4,1);
    else if(stage==10) {/* Keep the joining native display's previous quote. */}
    else if(stage==11) {
     check(inv.weapons.lmg.respect==0 || inv.weapons.lmg.respect==2,"stand probe starts with a carried native weapon");
     expected.respect=1;actor.context.stand.onoff(1);
    }
    else if(stage==12) {actor.context.stand.onoff(-1);p.onoff(8,1);}
   });
   if(stage==12)initial.hostFur=access.world.app.save().cFur;
   session.link.send({type:"probe-menu",stage:stage,serial:p.serial,standSerial:actor.context.stand.serial,tick:session.runtime.tick,
    product:product,work:p.workTip,productCount:expected.productCount,respect:expected.respect});
  }
 }
}

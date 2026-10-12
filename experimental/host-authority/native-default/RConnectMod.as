package {
 import flash.display.Sprite;
 import flash.display.DisplayObject;
 import flash.display.DisplayObjectContainer;
 import flash.display.BitmapData;
 import flash.display.Bitmap;
 import flash.display.MovieClip;
 import flash.geom.ColorTransform;
 import flash.geom.Rectangle;
 import flash.utils.getQualifiedClassName;
 import flash.events.MouseEvent;
 import flash.events.KeyboardEvent;
 import flash.utils.getTimer;
 import flash.text.TextField;
 import flash.desktop.NativeApplication;
 import flash.events.Event;
 import flash.filesystem.File;
 import flash.filesystem.FileMode;
 import flash.filesystem.FileStream;
 import flash.utils.Dictionary;
 import flash.media.Sound;
 import flash.media.SoundChannel;
 /** Single-player validation driver. Never installs B hooks or attaches the TDFC API. */
 public class RConnectMod extends Sprite {
  private static var self:RConnectMod;
  private var main:Object,w:Object,started:Boolean=false,travelled:Boolean=false,ready:int=0,tick:int=0;
  private var foe:Object,initialHP:Number,minimumHP:Number,shots:int=0,seen:Dictionary=new Dictionary(true),finished:Boolean=false;
  private var passed:int=0,failed:int=0;
  private var originalPlayer:Object,originalRoom:Object;
  private var timePhase:int=0,timeFrames:int=0,timeBegin:int=0,timeX:Number=0,timeKey:int=220;
  public static function init(main:Object):void {self=new RConnectMod();self.boot(main);}
  private function boot(main:Object):void {
   if(NativeApplication.nativeApplication.applicationID.indexOf("pfe-modsettings-rconnect-default-")!=0)throw new Error("Isolated default probe only");
   this.main=main;w=type("fe.World")["w"];
   main.stage.addEventListener(Event.DEACTIVATE,function(e:Event):void{e.stopImmediatePropagation();},false,100000);
   main.stage.addEventListener(Event.ENTER_FRAME,step,false,100000);
   log("boot",{probe:"native-default"});
  }
  private function type(name:String):Class{return main.loaderInfo.applicationDomain.getDefinition(name) as Class;}
  private function field(object:Object,key:String):* {try{return object[key];}catch(e:Error){return null;}}
  private function log(kind:String,data:Object):void {
   var stream:FileStream=new FileStream();stream.open(File.applicationStorageDirectory.resolvePath("RConnect-B.log"),FileMode.APPEND);
   stream.writeUTFBytes(JSON.stringify({kind:kind,data:data})+"\n");stream.close();
  }
  private function check(ok:Boolean,name:String,details:Object=null):void {if(ok)++passed;else ++failed;log(ok?"PASS":"FAIL",{name:name,details:details});}
  private function finish():void {finished=true;log("DONE",{passed:passed,failed:failed});}
  private function emptyHook(name:String,key:String):Boolean {try{return type(name)[key]==null;}catch(e:Error){}return true;}
  private function hooksEmpty():Boolean {
   for each(var pair:Array in [["fe.loc.Land","rconnectRoomStep"],["fe.loc.Land","rconnectGotoRoom"],["fe.loc.Land","rconnectGotoChallenge"],
    ["fe.loc.Location","rconnectPlayerStep"],["fe.loc.Location","rconnectObjectStep"],["fe.unit.UnitPlayer","rconnectDamage"],
    ["fe.unit.UnitPlayer","rconnectDeath"],["fe.unit.Unit","rconnectFindTarget"],["fe.unit.Unit","rconnectHitPolicy"],["fe.unit.Unit","rconnectTeleported"],["fe.unit.Unit","rconnectDeferDamage"],
    ["fe.unit.Mine","rconnectMineSight"],["fe.World","rconnectSave"],["fe.World","rconnectChangeWorld"],["fe.inter.PipBuck","rconnectMenu"],
    ["fe.loc.Game","rconnectIntent"],["fe.unit.UnitPlayer","rconnectIntent"],["fe.unit.Invent","rconnectIntent"],
    ["fe.unit.Pers","rconnectIntent"],["fe.weapon.Weapon","rconnectIntent"],["fe.Snd","rconnectPlaySound"],
    ["fe.Snd","rconnectHumSound"],["fe.Snd","rconnectStopSound"],
    ["fe.Snd","rconnectPlayMusic"],["fe.Snd","rconnectCombatMusic"],["fe.graph.Grafon","rconnectInk"]])if(!emptyHook(pair[0],pair[1]))return false;
   return true;
  }
  private function step(e:Event):void {
   if(finished)return;
   try {
    if(w.verror.visible)throw new Error(w.verror.txt.text);
    if(!started && w.landData!=null && w.allLandsLoaded){started=true;w.mm.active=false;w.newGame(-1,"B-default-check",null);return;}
    if(w.ctr!=null && w.clickReq==1)w.ctr.onMouseDown1(new MouseEvent(MouseEvent.MOUSE_DOWN));
    if(w.gg==null || w.loc==null || w.land==null || w.ng_wait!=0)return;
    if(timePhase>0){nativeTimeStep();return;}
    if(w.pip.active)w.pip.onoff(-1);
    if(!travelled){travelled=true;if(w.land.act.id!="random_mane"){w.pip.onoff(-1);w.game.beginMission("random_mane");return;}}
    if(w.land.act.id!="random_mane" || w.game.curLandId!="random_mane" || w.t_exit>0 || !w.gg.ggControl || w.gg.work=="change" || w.gg.work=="res")return;
    if(++ready<5)return;
    w.pip.onoff(-1);w.ctr.clearAll();
    if(tick==0)prepare();
    if(w.gg!==originalPlayer || w.loc!==originalRoom || w.t_die>0 || w.t_exit>0)throw new Error("Default probe changed room or player lifecycle");
    ++tick;minimumHP=Math.min(minimumHP,w.gg.hp);
    // Keep the target alive after observing real damage. Never manufacture a
    // huge maxhp that native Pers immediately clamps back to its real maximum.
    if(w.gg.hp<w.gg.maxhp*.5 && w.gg.hp>0)w.gg.heal(w.gg.maxhp-w.gg.hp);
    var obj:Object=w.loc.firstObj,count:int=0;
    while(obj!=null && ++count<10000){if(field(obj,"owner")===foe && field(obj,"weap")!=null && !seen[obj]){seen[obj]=true;++shots;}obj=obj.nobj;}
    if(tick==360) {
     check(w.gg.sost==1 && w.gg.hp>0,"default probe retains the original living body and room");
     check(hooksEmpty(),"default path never installs authority hooks");
     check(shots>0,"single-player enemy fires real native projectiles",{shots:shots});
     check(minimumHP<initialHP,"single-player enemy attacks damage the native player",{before:initialHP,minimum:minimumHP});
     check(w.gg===w.pers.gg && w.invent===w.gg.invent && w.loc.gg===w.gg,"native player ownership remains intact");
     check(main.getChildByName("TDFCAuthorityCarrier")!=null,"new TDFC loads without attaching its authority API");
     nativeMenus();nativeSound();nativeMusic();nativeInkAndTeleport();
     check(hooksEmpty(),"all combat, inventory, menu, travel, sound and lifecycle seams remain unclaimed");beginNativeTime();
    }
   }catch(error:Error){log("FATAL",{message:error.message,stack:error.getStackTrace()});check(false,"default native runtime completed");finish();}
  }
  private function timeKeyPress():void {
   w.swfStage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_DOWN,true,false,0,timeKey));
   w.swfStage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_UP,true,false,0,timeKey));
  }
  private function beginNativeTime():void {
   foe.disabled=true;w.gg.invulner=true;w.ctr.clearAll();
   var stream:FileStream=new FileStream();stream.open(File.applicationDirectory.resolvePath("mods/Sandevistan/release/config.txt"),FileMode.READ);
   var text:String=stream.readUTFBytes(stream.bytesAvailable);stream.close();
   var match:Array=/^\s*hotkey\s*=\s*(\d+)/m.exec(text);if(match!=null)timeKey=int(match[1]);
   var carrier:Object=main.getChildByName("SandyAuthorityAPI");
   check(carrier==null || carrier.attached===false,"default Sandevistan does not attach its optional B interface");
   timePhase=1;timeBegin=getTimer();timeX=w.gg.X;timeFrames=0;timeKeyPress();
  }
  private function nativeTimeStep():void {
   if(getTimer()-timeBegin>30000)throw new Error("Unattached native time control did not return within its bound");
   ++timeFrames;
   if(timePhase==1) {
    w.ctr.keyRight=true;
    if(timeFrames==15) {
     check(w.onPause && w.gg.X>timeX && hooksEmpty(),"unattached single-player time control retains its native manual movement",{before:timeX,after:w.gg.X,paused:w.onPause});
     w.ctr.clearAll();timeKeyPress();timePhase=2;return;
    }
   }else if(!w.onPause) {
    check(w.gg===originalPlayer && w.loc===originalRoom && w.gg.hp>0 && hooksEmpty(),"unattached single-player replay restores the original player and empty B seams");
    log("default-time-result",{key:timeKey,moved:w.gg.X>timeX,frames:timeFrames});finish();
   }
  }
  private function prepare():void {
   check(hooksEmpty(),"native callbacks are empty before gameplay");
   var g:Object=w.gg,room:Object=w.loc,y:Number=Math.floor((room.limY-120)/40)*40-1,row:int=int((y+1)/40);
   room.mirror=false;
   for each(var old:Object in room.units)if(old!==g && old!=null)old.disabled=true;
   for(var x:int=0;x<room.space.length;x++)for(var z:int=0;z<=row;z++) {
    var tile:Object=room.space[x][z];tile.phis=z==row || x==0 || x==room.space.length-1?1:0;tile.phX1=x*40;tile.phX2=(x+1)*40;tile.phY1=z*40;tile.phY2=(z+1)*40;
    tile.water=0;tile.visi=1;tile.t_visi=1;tile.shelf=false;tile.diagon=0;tile.stair=0;tile.door=null;tile.trap=null;
   }
   g.pers.setForcLevel(30);g.pers.healAll();g.pers.setParameters();
   g.setLocPos(500,y);g.hp=g.maxhp;g.invulner=false;g.obs=g.maxObs;initialHP=minimumHP=g.hp;
   originalPlayer=g;originalRoom=room;
   var Raider:Class=type("fe.unit.UnitRaider");foe=new Raider("1",10,<unit tr="1" weap="r32" turn="-1"/>,null);
   foe.putLoc(room,850,y);room.units.push(foe);room.addObj(foe);foe.addVisual();
   foe.disabled=false;foe.oduplenie=0;foe.overLook=true;foe.vision=5;foe.storona=-1;foe.hp=foe.maxhp=10000;
   foe.currentWeapon.damage=75;foe.currentWeapon.damageExpl=0;
  }
  private function find(root:DisplayObjectContainer,id:String,byName:Boolean=false):DisplayObject {
   if(!root.visible)return null;
   if(byName && root.name==id)return root;
   var text:TextField=root.getChildByName("id") as TextField;
   if(!byName && text!=null && text.text==id)return root;
   for(var i:int=0;i<root.numChildren;i++) {
    var child:DisplayObject=root.getChildAt(i),result:DisplayObject;
    if(!child.visible)continue;
    if(byName && child.name==id)return child;
    if(child is DisplayObjectContainer) {result=find(child as DisplayObjectContainer,id,byName);if(result!=null)return result;}
   }
   return null;
  }
  private function click(id:String,byName:Boolean=false):void {
   var row:DisplayObject=find(w.vpip,id,byName);
   if(row==null)throw new Error("Original native UI row/control unavailable: "+id);
   row.dispatchEvent(new MouseEvent(MouseEvent.CLICK));
  }
  private function nativeMenus():void {
   var inv:Object=w.invent,g:Object=w.gg,p:Object=w.pip,Vendor:Class=type("fe.serv.Vendor"),Item:Class=type("fe.serv.Item");
   inv.money.kol=100000;inv.items.pot0.kol=5;inv.items.kofe.kol=9;inv.items.kofe.vault=0;
   var v:Object=new Vendor(0,<vendor id="random"/>,[],"vendor"),stock:Object=new Item(null,"pot0",5);
   v.buys=[stock];v.buys2=[];v.buys2.pot0=stock;v.money=100000;p.vendor=v;p.npcInter="vr";
   p.onoff(4,1);click("pot0");click("pot0");click("butOk",true);
   var bought:int=inv.money.kol;
   check(inv.items.pot0.kol==7 && stock.kol==3 && bought<100000,"unclaimed original buy handler transfers stock and payment");
   p.onoff(4,2);click("pot0");click("pot0");click("butOk",true);
   var sold:int=inv.money.kol;
   check(inv.items.pot0.kol==5 && stock.kol==5 && sold>bought,"unclaimed original sell handler transfers stock and payment");
   p.onoff(9,inv.items.kofe.invCat);
   var row:Object=find(w.vpip,"kofe");
   if(row==null)throw new Error("Native warehouse row missing");
   row.ns.value=4;row.ns.dispatchEvent(new Event(Event.CHANGE));
   check(inv.items.kofe.kol==5 && inv.items.kofe.vault==4,"unclaimed native warehouse deposits exactly four items");
   row.ns.value=0;row.ns.dispatchEvent(new Event(Event.CHANGE));
   check(inv.items.kofe.kol==9 && inv.items.kofe.vault==0,"unclaimed native warehouse returns the same items");
   var recipe:XML,product:String;
   for each(var scheme:XML in type("fe.AllData")["d"].item) {
    var id:String=String(scheme.@id),candidate:String=id.substr(2);
    if(id.indexOf("s_")!=0 || scheme.craft.length()==0 || inv.items[candidate]==null || inv.weapons[candidate]!=null || inv.armors[candidate]!=null)continue;
    if(inv.items[candidate].xml.@one=="1" || String(inv.items[candidate].xml.@tip)=="impl")continue;
    recipe=scheme;product=candidate;break;
   }
   if(recipe==null)throw new Error("Native consumable recipe unavailable");
   inv.items[String(recipe.@id)].kol=1;inv.items[product].kol=0;
   for each(var comp:XML in recipe.craft)inv.items[String(comp.@id)].kol=100;
   if(recipe.@skill.length())g.pers.skills[String(recipe.@skill)]=100;
   g.pers.setParameters();w.helpMess=false;p.workTip=recipe.@work.length()?String(recipe.@work):"work";p.onoff(7,1);
   click(product);var amount:int=recipe.@kol.length()?int(recipe.@kol):1;
   check(inv.items[product].kol==amount,"unclaimed native recipe query produces the expected consumable",{product:product,expected:amount,actual:inv.items[product].kol});
   var costs:Object={};
   for each(comp in recipe.craft) {id=String(comp.@id);costs[id]=inv.items[id].kol;check(inv.items[id].kol==100-int(comp.@kol),"unclaimed native crafting deducts one recipe component",{id:id});}
   g.hp=g.maxhp-100;g.rad=0;p.npcInter="doc";p.onoff(6,1);var paid:int=inv.money.kol;
   click("hp");paid-=inv.money.kol;
   check(g.hp==g.maxhp && paid==Math.round(100*g.pers.priceHP),"unclaimed native doctor uses original healing and price");
   p.onoff(-1);
   log("default-menu-result",{bought:bought,sold:sold,kofe:inv.items.kofe.kol,vault:inv.items.kofe.vault,product:product,amount:inv.items[product].kol,costs:costs,medicalPayment:paid});
  }
  private function nativeSound():void {
   var snd:Class=type("fe.Snd"),enabled:Boolean=snd["onSnd"],off:Boolean=snd["off"],resources:Object={};
   for(var name:String in snd["snd"]) {
    var group:Object=snd["snd"][name],sizes:Array=[];
    if(group is Array){for each(var item:Sound in group)sizes.push(item.bytesTotal);}else if(group is Sound)sizes.push(Sound(group).bytesTotal);
    resources[name]=sizes;
   }
   check(resources.lmg_s!=null && resources.bfg_p!=null && resources.vortex!=null && resources.ali.length==3,
    "default sound resource XML preserves named sounds and native variant groups");
   try {
    snd["off"]=false;snd["onSnd"]=true;
    var channel:SoundChannel=snd["ps"]("bfg_p",w.gg.X,w.gg.Y,100,0.5) as SoundChannel;
    check(channel!=null,"unclaimed sound handler returns a real native playback channel");
    if(channel!=null){if(field(snd,"rconnectStopChannel")!=null)snd["rconnectStopChannel"](channel);else channel.stop();}
    snd["onSnd"]=false;check(snd["ps"]("lmg_s")==null,"original per-user sound disable remains effective");
    snd["onSnd"]=true;snd["off"]=true;check(snd["ps"]("lmg_s")==null,"original world sound suppression remains effective");
   }finally {snd["onSnd"]=enabled;snd["off"]=off;}
   log("default-sound-resources",resources);
  }
  private function nativeMusic():void {
   var snd:Class=type("fe.Snd"),oldOn:Boolean=snd["onMusic"],oldVol:Number=Number(snd["musicVol"]);
   var oldTrack:String=snd["musicName"],oldAmbient:String=w.currentMusic,trace:Array=[];
   try {
    snd["onMusic"]=true;snd["musicVol"]=0;w.currentMusic="music_mane_1";
    snd["t_combat"]=0;snd["currentMusicPrior"]=0;snd["playMusic"](w.currentMusic);
    var channel:SoundChannel=snd["musicCh"] as SoundChannel;
    check(channel!=null,"unclaimed native ambient music creates a real resource channel");
    snd["playMusic"](w.currentMusic,1);
    check(snd["musicCh"]===channel,"unclaimed native same-track request keeps its channel and repeats");
    snd["combatMusic"]("combat_1",2,4);
    trace.push({track:snd["musicName"],priority:snd["currentMusicPrior"],remaining:snd["t_combat"]});
    snd["step"]();snd["combatMusic"]("combat_1",2,4);
    trace.push({track:snd["musicName"],priority:snd["currentMusicPrior"],remaining:snd["t_combat"]});
    snd["combatMusic"]("boss_1",1,3);
    trace.push({track:snd["musicName"],priority:snd["currentMusicPrior"],remaining:snd["t_combat"]});
    for(var i:int=0;i<3;i++) {
     snd["step"]();trace.push({track:snd["musicName"],priority:snd["currentMusicPrior"],remaining:snd["t_combat"]});
    }
    check(trace[0].track=="combat_1" && trace[0].priority==0 && trace[1].priority==2 && trace[2].track=="combat_1",
     "unclaimed native combat refresh and priority ordering remain original");
    check(snd["musicName"]==w.currentMusic && snd["t_combat"]==0,
     "unclaimed native music countdown returns to ambient after three original steps");
    log("default-music-trace",trace);
   }finally {
    w.currentMusic=oldAmbient;snd["musicVol"]=oldVol;snd["onMusic"]=oldOn;
    snd["playMusic"](oldTrack);snd["updateMusicVol"]();
   }
  }
  private function digest(data:BitmapData,area:Rectangle=null):uint {
   var hash:uint=2166136261;for each(var pixel:uint in data.getVector(area==null?data.rect:area))hash=uint((hash^pixel)*16777619);return hash;
  }
  private function nativeInkAndTeleport():void {
   var grafon:Object=w.grafon,front:BitmapData=grafon.frontBmp;
   // backBmp is package-internal. Its public display layer exposes the same
   // native surface without adding a test accessor to either game version.
   var back:BitmapData=Bitmap(grafon.visBack.getChildAt(0)).bitmapData,area:Rectangle=new Rectangle(0,0,640,400);
   var original:Vector.<uint>=back.getVector(area),oldColor:ColorTransform=grafon.brTrans,oldTint:ColorTransform=w.loc.cTransform,trace:Array=[];
   var testFront:BitmapData=new BitmapData(640,400,true,0xffaabbcc);
   try {
    grafon.frontBmp=testFront;back.fillRect(area,0xffaabbcc);grafon.brTrans=new ColorTransform();w.loc.cTransform=new ColorTransform();
    var plain:uint=digest(testFront);
    grafon.decal(DefaultHole,DefaultMark,180,140,1.25,.2);
    trace.push({method:"decal",front:digest(testFront),back:digest(back,area)});
    check(trace[0].front!=plain,"unclaimed native decal changes actual wall pixels");
    grafon.gwall(7,4);trace.push({method:"gwall",front:digest(testFront),back:digest(back,area)});
    check(trace[1].front!=trace[0].front,"unclaimed native magic wall draws its authored tile");
    grafon.paint(180,160,220,175,false);trace.push({method:"brush",front:digest(testFront),back:digest(back,area)});
    grafon.paint(240,180,270,190,true);trace.push({method:"aerosol",front:digest(testFront),back:digest(back,area)});
    check(trace[2].back!=trace[1].back && trace[3].back!=trace[2].back,"unclaimed native brush and aerosol alter the real background surface");
    log("default-ink-trace",trace);
   }finally {grafon.frontBmp=front;back.setVector(area,original);grafon.brTrans=oldColor;w.loc.cTransform=oldTint;testFront.dispose();}
   var g:Object=w.gg,x:Number=g.X,y:Number=g.Y,old:Dictionary=new Dictionary(true),o:Object;
   for(o=g.loc.firstObj;o!=null;o=o.nobj)old[o]=true;
   g.teleport(x+80,y,1);
   var arrivals:int=0;
   for(o=g.loc.firstObj;o!=null;o=o.nobj)if(!old[o] && o.vis!=null && getQualifiedClassName(o.vis)=="visualTele")++arrivals;
   check(g.X==x+80 && g.Y==y && arrivals>0,"unclaimed native short teleport preserves position and real arrival effect",{arrivals:arrivals});
   old=new Dictionary(true);for(o=g.loc.firstObj;o!=null;o=o.nobj)old[o]=true;
   g.teleport(x,y,0);arrivals=0;
   for(o=g.loc.firstObj;o!=null;o=o.nobj)if(!old[o] && o.vis!=null && getQualifiedClassName(o.vis)=="visualTele")++arrivals;
   check(g.X==x && g.Y==y && arrivals==0,"unclaimed silent relocation adds no arrival effect");
  }
 }
}
import flash.display.MovieClip;
internal class DefaultHole extends MovieClip {
  public function DefaultHole(){graphics.beginFill(0);graphics.drawCircle(0,0,7);graphics.endFill();}
 }
 internal class DefaultMark extends MovieClip {
  public function DefaultMark(){graphics.beginFill(0x332211,.8);graphics.drawCircle(0,0,12);graphics.endFill();}
 }

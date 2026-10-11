package {
 import flash.display.Sprite;
 import flash.desktop.NativeApplication;
 import flash.events.Event;
 import flash.filesystem.File;
 import flash.filesystem.FileMode;
 import flash.filesystem.FileStream;
 import flash.utils.Dictionary;
 /** Single-player validation driver. Never installs B hooks or attaches the TDFC API. */
 public class RConnectMod extends Sprite {
  private static var self:RConnectMod;
  private var main:Object,w:Object,started:Boolean=false,travelled:Boolean=false,ready:int=0,tick:int=0;
  private var foe:Object,initialHP:Number,minimumHP:Number,shots:int=0,seen:Dictionary=new Dictionary(true),finished:Boolean=false;
  private var passed:int=0,failed:int=0;
  private var originalPlayer:Object,originalRoom:Object;
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
   return emptyHook("fe.loc.Land","rconnectRoomStep") && emptyHook("fe.loc.Location","rconnectPlayerStep") &&
    emptyHook("fe.loc.Location","rconnectObjectStep") && emptyHook("fe.unit.UnitPlayer","rconnectDamage") && emptyHook("fe.unit.Unit","rconnectFindTarget");
  }
  private function step(e:Event):void {
   if(finished)return;
   try {
    if(w.verror.visible)throw new Error(w.verror.txt.text);
    if(!started && w.landData!=null && w.allLandsLoaded){started=true;w.mm.active=false;w.newGame(-1,"B-default-check",null);return;}
    if(w.gg==null || w.loc==null || w.land==null || w.ng_wait!=0)return;
    if(!travelled){travelled=true;if(w.land.act.id!="random_mane"){w.pip.onoff(-1);w.game.beginMission("random_mane");return;}}
    if(w.land.act.id!="random_mane" || w.game.curLandId!="random_mane" || w.t_exit>0 || !w.gg.ggControl || w.gg.work=="change" || w.gg.work=="res")return;
    if(++ready<5)return;
    w.pip.onoff(-1);w.ctr.clearAll();
    if(tick==0)prepare();
    if(w.gg!==originalPlayer || w.loc!==originalRoom || w.t_die>0 || w.t_exit>0)throw new Error("Default probe changed room or player lifecycle");
    ++tick;minimumHP=Math.min(minimumHP,w.gg.hp);
    var obj:Object=w.loc.firstObj,count:int=0;
    while(obj!=null && ++count<10000){if(field(obj,"owner")===foe && field(obj,"weap")!=null && !seen[obj]){seen[obj]=true;++shots;}obj=obj.nobj;}
    if(tick==360) {
     check(w.gg.sost==1 && w.gg.hp>0,"default probe retains the original living body and room");
     check(hooksEmpty(),"default path never installs authority hooks");
     check(shots>0,"single-player enemy fires real native projectiles",{shots:shots});
     check(minimumHP<initialHP,"single-player enemy attacks damage the native player",{before:initialHP,minimum:minimumHP});
     check(w.gg===w.pers.gg && w.invent===w.gg.invent && w.loc.gg===w.gg,"native player ownership remains intact");
     check(main.getChildByName("TDFCAuthorityCarrier")!=null,"new TDFC loads without attaching its authority API");finish();
    }
   }catch(error:Error){log("FATAL",{message:error.message,stack:error.getStackTrace()});check(false,"default native runtime completed");finish();}
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
   g.setLocPos(500,y);g.hp=g.maxhp=10000;g.invulner=false;g.obs=g.maxObs;initialHP=minimumHP=g.hp;
   originalPlayer=g;originalRoom=room;
   var Raider:Class=type("fe.unit.UnitRaider");foe=new Raider("1",10,<unit tr="1" weap="r32" turn="-1"/>,null);
   foe.putLoc(room,850,y);room.units.push(foe);room.addObj(foe);foe.addVisual();
   foe.disabled=false;foe.oduplenie=0;foe.overLook=true;foe.vision=5;foe.storona=-1;foe.hp=foe.maxhp=10000;
   foe.currentWeapon.damage=75;foe.currentWeapon.damageExpl=0;
  }
 }
}

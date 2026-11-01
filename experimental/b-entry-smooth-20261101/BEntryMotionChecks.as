package {
 import flash.system.ApplicationDomain;
 import flash.utils.ByteArray;
 import flash.net.ServerSocket;
 import flash.display.DisplayObject;
 import flash.events.MouseEvent;
 import flash.geom.Point;
 /** External checks: use the real wire decoder, renderer input and UI actions. */
 public final class BEntryMotionChecks {
  private static function wire(value:*):* {var bytes:ByteArray=new ByteArray();bytes.writeObject(value);bytes.position=0;return bytes.readObject();}
  private static function effective(record:Object):Object {
   var out:Object={},key:String;
   for(key in record.fields)out[key]=record.fields[key];
   for(key in record.fieldsDelta)out[key]=record.fieldsDelta[key];
   return out;
  }
  private static function equal(a:Object,b:Object):Boolean {
   for(var key:String in a)if(!b.hasOwnProperty(key) || a[key]!==b[key])return false;
   for(key in b)if(!a.hasOwnProperty(key))return false;
   return true;
  }
  private static function entity(key:int,x:Number):Object {
   return {key:key,positionEpoch:0,fields:{id:"fixture",X:x,Y:100,X1:x-10,X2:x+10,Y1:80,Y2:100,hp:40,label:"old"},
    pose:{x:x,y:100},weapons:[{id:"gun",fields:{ammo:20,label:"old"},pose:{x:0,y:0}}]};
  }
  private static function frame(x:Number):Object {
   return {session:"sparse-scene",room:"r",pauseEpoch:0,players:[],projectiles:[],
    scene:{key:"r",units:[entity(1,x)],objects:[entity(2,x)],effects:[]}};
  }
  public static function run(domain:ApplicationDomain,check:Function):void {
   var Type:Class=domain.getDefinition("authority.FrameDelta") as Class;
   var Fields:Object=domain.getDefinition("authority.NativeFields"),Tween:Object=domain.getDefinition("authority.PoseTween");
   var enc:Object=new Type(),dec:Object=new Type(),previous:Object=null,previousJSON:String;
   var match:Boolean=true,unchanged:Boolean=true,positions:Boolean=true,deletions:Boolean=true,history:Array=[],frozen:Array=[];
   for(var i:int=0;i<128;i++) {
    var original:Object=frame(100+i*2);
    for each(var group:String in ["units","objects"]) {
     var expected:Object=original.scene[group][0];expected.fields.hp=40-i%17;
     if(i%3==1){delete expected.fields.label;delete expected.weapons[0].fields.label;}
     else {expected.fields.label="state-"+i;expected.weapons[0].fields.label="weapon-"+i;}
    }
    var actual:Object=dec.decode(wire(enc.encode(original)));
    for each(group in ["units","objects"]) {
     var item:Object=actual.scene[group][0];expected=original.scene[group][0];
     match=match && equal(effective(item),expected.fields) && equal(effective(item.weapons[0]),expected.weapons[0].fields);
     deletions=deletions && Fields.has(item,"label")==expected.fields.hasOwnProperty("label") && Fields.get(item,"label")===expected.fields.label;
    }
    if(previous!=null) {
     var presented:Object=Tween.frame(previous,actual,.5);
     for each(group in ["units","objects"]) {
      var model:Object={X:0,Y:0,X1:0,X2:0,Y1:0,Y2:0};
      var state:Object=presented.scene[group][0];Fields.motion(model,state.motion!=null?state.motion:state.fields);
      var wanted:Number=99+i*2;
      positions=positions && model.X===wanted && model.X1===wanted-10 && model.X2===wanted+10 && state.pose.x===wanted;
     }
    }
    history.push(actual);frozen.push(JSON.stringify(actual));
    for(var h:int=0;h<history.length;h++)unchanged=unchanged && JSON.stringify(history[h])===frozen[h];
    previous=actual;
   }
   check(match,"128 actual sparse scene confirmations preserve all unit/object/weapon fields");
   check(deletions,"scene field removals never revive stale baseline values");
   check(positions,"127 moving unit/object presentations align body and interaction bounds");
   check(unchanged,"decoding and interpolation leave all retained confirmations immutable");
   var before:Object=actual,modified:Object=frame(500);modified.scene.objects=[entity(9,500),entity(10,520)];
   var rebuilt:Object=dec.decode(wire(enc.encode(modified)));
   check(equal(effective(rebuilt.scene.objects[0]),modified.scene.objects[0].fields),"array replacement starts a fresh object field baseline");
  }
  public static function click(mod:Object,name:String):void {
   mod.hud.visible=true;mod.hud.openPage("connect");
   var button:DisplayObject=mod.hud.getChildByName("rconnect-"+name);
   if(button==null || !button.visible || !Object(button).mouseEnabled)throw new Error("Connection button is not usable: "+name);
   button.dispatchEvent(new MouseEvent(MouseEvent.CLICK,true));
  }
  public static function beforeLoad(mod:Object,role:String,check:Function):void {
   click(mod,role);
   check(mod.ui.session.mode=="waiting" && mod.ui.session.rooms.status!="" && mod.role=="","pre-load click acknowledges request without acquiring a world/bridge");
   click(mod,"leave");mod.ui.refresh();mod.hud.refresh();
   check(mod.ui.session.mode=="offline" && mod.role=="","pending connection can be cancelled before loading a character");
  }
  public static function beforeConnect(mod:Object,role:String,check:Function):void {
   if(role!="host")return;
   var occupied:ServerSocket=new ServerSocket();occupied.bind(int(mod.preferences.getValue("port")),"127.0.0.1");occupied.listen();
   try {
    click(mod,"host");
    check(mod.role=="" && mod.ui.session.mode=="offline" && mod.ui.session.error!="","occupied port gives a visible failure and releases acquired interfaces");
   }finally{occupied.close();}
   click(mod,"host");
   check(mod.role=="host" && mod.ui.session.mode=="hosting" && mod.ui.session.error=="","same host button retries successfully after a failed bind");
  }
 }
}

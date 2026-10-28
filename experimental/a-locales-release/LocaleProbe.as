package {
 import flash.desktop.NativeApplication;
 import flash.display.Sprite;
 import flash.display.BitmapData;
 import flash.display.PNGEncoderOptions;
 import flash.events.TimerEvent;
 import flash.events.MouseEvent;
 import flash.filesystem.File;
 import flash.filesystem.FileMode;
 import flash.filesystem.FileStream;
 import flash.geom.Matrix;
 import flash.geom.Rectangle;
 import flash.media.SoundMixer;
 import flash.system.ApplicationDomain;
 import flash.text.TextField;
 import flash.utils.Timer;
 import flash.utils.getTimer;
 public class LocaleProbe extends Sprite {
  private var started:int=getTimer(),timer:Timer=new Timer(250),mod:Object,lc:Object,catalog:Object;
  private var checks:Array=[],overflow:Array=[],pages:Array=[],complete:Boolean=false;
  private function check(ok:Boolean,label:String):void {checks.push({ok:ok,label:label});}
  public function LocaleProbe(){timer.addEventListener(TimerEvent.TIMER,tick);timer.start();}
  private function tick(e:TimerEvent):void {
   if(complete)return;
   try {
    var domain:ApplicationDomain=loaderInfo.applicationDomain;
    mod=domain.getDefinition("RConnectMod").instance;
    if(getTimer()-started>60000){finish(false,"startup timeout");return;}
    if(mod==null||mod.game==null||mod.game.world==null||mod.game.gg==null||!mod.session.rooms.ready||mod.session.rooms.busy)return;
    if(mod.session.peers.length+mod.session.remotes.length==0)return;
    lc=domain.getDefinition("modlocales.connect.RCLocale");catalog=domain.getDefinition("modlocales.connect.RCLocaleMessages").DATA;
    run();finish(true);
   }catch(error:*){finish(false,String(error));}
  }
  private function field(id:String):TextField{return mod.hud.getChildByName(id) as TextField;}
  private function run():void {
   var hud:Object=mod.hud,w:Object=mod.game.world;
   var original:String=String(w.lang),nick:String=hud.tfNick.text;
   var input:String="开 {0} Alpha Ж 伙伴",chat:String="菜单同步暂停：开 {1}";
   hud.tfChat.text=input;hud.addChatLine("host {0}",chat);
   var codes:Array=["zh","tw","en","ru","ua","pl","de","es","jp"];
   var atlas:BitmapData=new BitmapData(560,9*264,false,0x30332A);
   for(var index:int=0;index<codes.length;index++) {
    var code:String=codes[index];w.lang=code;
    check(lc.language()==code,code+" native language");
    for(var key:String in catalog)check(lc.text(key)===catalog[key][code],code+" catalog "+key);
    check(lc.render("菜单同步暂停：开")==catalog["菜单同步暂停："][code]+catalog["开"][code],code+" composed toggle");
    check(lc.format("联机已暂停：{0}",input)==String(catalog["联机已暂停：{0}"][code]).replace("{0}",input),code+" literal player placeholders");
    hud.visible=true;hud.collapse(false);
    for each(var page:String in ["connect","peer","chat","settings"]) {
     hud.openPage(page);hud.refresh();
     check(hud.tfChat.text==input&&hud.tfNick.text==nick,code+" "+page+" user input preserved");
     check(field("rconnect-tab-settings").text==catalog["设置"][code],code+" tab translated");
     measure(code,page);
     if(page=="settings")atlas.draw(Sprite(hud),new Matrix(1,0,0,1,0,index*264));
     for(var step:int=0;step<9;step++) {
      hud.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_WHEEL,true,false,0,0,null,false,false,false,false,-3));
      measure(code,page+" scroll "+step);
     }
    }
    hud.getChildByName("rconnect-help").dispatchEvent(new MouseEvent(MouseEvent.CLICK));hud.refresh();
    measure(code,"help");atlas.draw(Sprite(hud),new Matrix(1,0,0,1,280,index*264));
    hud.getChildByName("rconnect-help").dispatchEvent(new MouseEvent(MouseEvent.CLICK));
    check(hud.chatLog.text.indexOf(chat)>=0,code+" chat not translated");
    check(hud.panelHeight<=264,code+" compact outer height");
   }
   for each(var alias:Array in [["zh-TW","tw"],["zh_Hant","tw"],["zh-CN","zh"],["uk-UA","ua"],["ja-JP","jp"],["de-DE","de"],["pl-PL","pl"],["es-ES","es"],["ru-RU","ru"],["unknown","en"]]) {
    w.lang=alias[0];check(lc.language()==alias[1],"alias "+alias[0]);
   }
   w.lang=original;hud.refresh();
   check(overflow.length==0,"all fixed controls fit");
   var stream:FileStream=new FileStream();stream.open(File.applicationStorageDirectory.resolvePath("locale-atlas.png"),FileMode.WRITE);
   stream.writeBytes(atlas.encode(atlas.rect,new PNGEncoderOptions()));stream.close();atlas.dispose();
  }
  private function measure(code:String,page:String):void {
   var count:int=0;
   // DisplayObject.height reports the scrollRect bounds, including intentional
   // clipping. Check actual text against each fixed control's design height.
   // Long explanations and chat use the existing scrolling page instead.
   var heights:Object={"rconnect-state":22,"rconnect-chat":24,"rconnect-expand":24,
    "rconnect-tab-connect":28,"rconnect-tab-peer":28,"rconnect-tab-chat":28,"rconnect-tab-settings":28,
    "rconnect-shortcuts":20,"rconnect-dock":20,"rconnect-help":20,"rconnect-nick-label":26,
    "rconnect-address-label":18,"rconnect-port-label":18,"rconnect-host":28,"rconnect-join":28,"rconnect-leave":28,
    "rconnect-peer":32,"rconnect-peer-health":32,"rconnect-exploration":32,"rconnect-follow":32,"rconnect-teleport":28,
    "rconnect-send":26,"rconnect-chat-hint":20,"rconnect-opacity-label":28,"rconnect-opacity-value":26,
    "rconnect-allow-grip":30,"rconnect-struggle-grip":30,"rconnect-throw-damage":30,
    "rconnect-pause-menus":30,"rconnect-pause-sats":30,"rconnect-friendly-fire":30,"rconnect-security-mode":30};
   for(var i:int=0;i<mod.hud.numChildren;i++) {
    var f:TextField=mod.hud.getChildAt(i) as TextField;
    if(f==null||!f.visible||f.type=="input"||f.name=="rconnect-chat-log"||f.text=="")continue;
    count++;
    if(heights[f.name]!=null && (f.textWidth>f.width-3.5||f.textHeight>Number(heights[f.name])-3.5))overflow.push({code:code,page:page,id:f.name,text:f.text,width:f.width,height:heights[f.name],textWidth:f.textWidth,textHeight:f.textHeight});
   }
   pages.push({code:code,page:page,fields:count});
  }
  private function finish(ok:Boolean,error:String=""):void {
   if(complete)return;complete=true;timer.stop();for each(var c:Object in checks)if(!c.ok)ok=false;
   var stream:FileStream=new FileStream();stream.open(File.applicationStorageDirectory.resolvePath("stutter-result.json"),FileMode.WRITE);
   stream.writeUTFBytes(JSON.stringify({completed:ok,error:error,checks:checks,overflow:overflow,pages:pages,audioVolume:SoundMixer.soundTransform.volume,
    version:mod==null?"":loaderInfo.applicationDomain.getDefinition("RConnectMod").VERSION}));stream.close();
   NativeApplication.nativeApplication.exit(ok?0:1);
  }
 }
}

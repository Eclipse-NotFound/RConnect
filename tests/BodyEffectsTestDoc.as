package {
   import flash.desktop.NativeApplication;
   import flash.display.BitmapData;
   import flash.display.DisplayObject;
   import flash.display.MovieClip;
   import flash.display.PNGEncoderOptions;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.MouseEvent;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.filters.BlurFilter;
   import flash.filters.DropShadowFilter;
   import flash.filters.GlowFilter;
   import flash.geom.ColorTransform;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import rconnect.game.MirrorHitUnit;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;
   import rconnect.net.NetMessageEvent;
   import rconnect.net.TcpLink;

   /** Real item/Spell/Effect -> production Session/TCP -> final ghost pixels.
    * No calls to PlayerBodyEffects, no synthetic production snapshots. An
    * independent oracle reports the sender's native display for comparison.
    * The opposite player remains ordinary, detecting accidental local copying.
    */
   public class BodyEffectsTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private static const CASES:Array=["plain","stealth","clear","shield","clear","combo","clear",
         "shadow","clear","blood","clear","frozen","clear","inhibitor","clear","rat","clear",
         "fetter","clear","crystal","clear","levitation","clear","dash","clear","pause","clear"];
      private static const EFFECTS:Array=["stealth","stealth_armor","potion_shadow","bloodinv","freezing","inhibitor","potion_rat","fetter"];
      private static const PATHS:Array=["shit","inh","cryst","fetter","rat","svet","osn.body.head.morda.magic"];
      private var mod:RConnectMod,host:Boolean,timer:Timer=new Timer(100),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=getTimer(),readyAt:int=0,round:int=-1;
      private var baseX:Number,baseY:Number,old:Object,setupDone:Boolean=false;
      private var oracle:Object,nativeState:Object,previousNative:Object;
      private var samples:int=0,wrong:int=0,firstWrong:String="",sourceOK:Boolean=false;
      private var frames:Object={},nativeFrames:Object={},peerDone:Boolean=false,localDone:Boolean=false,shot:Boolean=false;
      private var pauseOpened:Boolean=false,pauseSeen:Boolean=false,pauseFrame:int=-1,pauseDrift:int=0;
      private var shieldSpell:Object,crystalSpell:Object,fixtureGun:Object;
      private var enemy:Object,enemyOracle:Object,enemyOK:Boolean=false,enemySamples:int=0,enemyWrong:int=0;
      private var pictures:Array=[];
      private var nativeHorn:Array=[],remoteHorn:Array=[];

      public function BodyEffectsTestDoc() {
         var id:String=NativeApplication.nativeApplication.applicationID;
         if(id.indexOf("rconnect-coop-")<0)return;
         host=id.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,onError);
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,message:String):void {
         Log.d("COOP "+(ok?"PASS ":"FAIL ")+"body-effects "+message+" round="+round+" case="+kind()+" role="+(host?"host":"join"));
      }
      private function kind():String {return round<0?"boot":round<CASES.length*2?String(CASES[round%CASES.length]):round==CASES.length*2?"enemy-frozen":"enemy-clear";}
      private function enemyRound():Boolean {return round>=CASES.length*2;}
      private function source():Boolean {return round<CASES.length?host:!host;}
      private function send(stage:String,p:Object=null):void {
         p=p||{};p.type="body-effects-test";p.stage=stage;p.round=round;
         if(host)mod.session.server.broadcast(p);else if(mod.session.link!=null)mod.session.link.send(p);
      }
      private function watch(link:TcpLink):void {
         if(link!=null&&!links[link]){links[link]=true;link.addEventListener(TcpLink.MESSAGE,receive);}
      }
      private function onError(e:UncaughtErrorEvent):void {
         e.preventDefault();fail("uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));
      }
      private function fail(reason:String):void {check(false,reason);if(mod!=null)send("done");finish();}
      private function arena():void {
         var l:Object=mod.game.loc;
         for(var by:int=200;by<l.limY-40;by+=40)for(var bx:int=80;bx<l.limX-340;bx+=40) {
            var clear:Boolean=true;
            for(var ix:int=0;ix<=320&&clear;ix+=20) {
               if(l.getAbsTile(bx+ix,by+1).phis!=1){clear=false;break;}
               for(var iy:int=20;iy<=180;iy+=20)if(l.getAbsTile(bx+ix,by-iy).phis!=0){clear=false;break;}
            }
            if(clear){baseX=bx+40;baseY=by;return;}
         }
         throw new Error("no native floored body-effects corridor");
      }
      private function setup(x:Number=NaN,y:Number=NaN):void {
         var g:Object=mod.game.gg,w:Object=mod.game.world;
         if(w.alicorn)throw new Error("body-effects fixture requires ordinary pony saves for the stealth item");
         if(g.invent.items["stealth"]==null)throw new Error("native stealth item unavailable");
         old={x:g.X,y:g.Y,disabled:g.disabled,invulner:g.invulner,levit:g.levit,frac:g.fracLevit,
            mana:g.mana,shield:g.shithp,stealth:g.invent.items["stealth"].kol,
            pauseMenus:mod.session.pause.policyMenus,pauseSats:mod.session.pause.policySats,
            weapon:g.currentWeapon,children:g.childObjs,base:mod.game.loc.base};
         if(host)arena();else {baseX=x+140;baseY=y;}
         setupDone=true;
         // Both ponies need distinct unobstructed pixels; overlapping at the
         // spawn point cannot visually demonstrate a teammate's stealth/shield.
         var room:Object=mod.game.loc,left:Number=host?baseX:baseX-140,removed:Array=[];
         for(var o:Object=room.firstObj;o!=null;o=o.nobj)
            if(o!==g&&room.units.indexOf(o)<0&&GameBridge.probe(o,"X2")!=null
               &&o.X2>left-40&&o.X1<left+280&&o.Y2>baseY-180&&o.Y1<baseY+20)removed.push(o);
         for each(o in removed){room.remObj(o);var oi:int=room.objs.indexOf(o);if(oi>=0)room.objs.splice(oi,1);if(room.celObj===o)room.celObj=null;}
         // rbl saves can be inside anim("die",true) from the opening story.
         // Exit that real override instead of assigning a fabricated clip pose.
         Log.d("BODY EFFECTS NATIVE ENTRY "+JSON.stringify({animOff:g.animOff,work:g.work,sost:g.sost,pose:g.vis.osn.currentFrameLabel}));
         g.anim();
         check(g.animOff===false,"native scripted animation override released");
         if(host)mod.session.pause.setPolicy(false,true);
         g.invent.items["stealth"].kol=Math.max(20,Number(old.stealth));
         var spellClass:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit.Spell") as Class;
         shieldSpell=new spellClass(g,"sp_mshit");crystalSpell=new spellClass(g,"sp_cryst");
         // SATS requires an equipped usable weapon even when the visual case
         // itself never fires. Fresh isolated saves have no current weapon.
         var weaponFactory:Object=mod.main.loaderInfo.applicationDomain.getDefinition("fe.weapon.Weapon");
         fixtureGun=weaponFactory.create(g,"lmg",0);fixtureGun.setPers(g,g.pers);
         fixtureGun.lvl=fixtureGun.perslvl=0;fixtureGun.loc=mod.game.loc;fixtureGun.hold=90;
         g.currentWeapon=fixtureGun;g.childObjs=[fixtureGun];fixtureGun.addVisual();mod.game.loc.base=false;
         if(host) {
            var unitClass:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit.UnitBloat") as Class;
            enemy=new unitClass("1",100,<unit tr="1"/>,null);enemy.id="rconnect_body_effects_enemy";
            enemy.putLoc(mod.game.loc,baseX+240,baseY-70);mod.game.loc.addObj(enemy);mod.game.loc.units.push(enemy);
            enemy.disabled=true;enemy.invulner=true;enemy.noAgro=true;enemy.doop=true;enemy.xp=0;
         }
         w.pip.onoff(-1);w.sats.onoff(-1);w.clickReq=0;
         mod.stage.addEventListener(Event.ENTER_FRAME,before,false,100000);
         mod.stage.addEventListener(Event.ENTER_FRAME,after,false,-6000);
         mod.stage.addEventListener(Event.RENDER,render,false,-30000);
      }
      private function clear():void {
         if(!setupDone)return;
         var g:Object=mod.game.gg;
         mod.game.world.sats.onoff(-1);
         for each(var id:String in EFFECTS)g.remEffect(id);
         g.shithp=0;g.t_cryst=0;g.levit=0;g.dash_t=0;
         // Inhibitor and ratOn use native changeWeapon("not"). Re-equip for
         // the next independent case so the later SATS premise is still true.
         g.currentWeapon=fixtureGun;g.childObjs=[fixtureGun];fixtureGun.addVisual();
         g.setNull();g.actions();g.animate();
         if(host&&enemy!=null)enemy.remEffect("freezing");
      }
      private function cast(spell:Object):Boolean {
         mod.game.gg.mana=Math.max(10000,Number(mod.game.gg.mana));spell.t_culd=0;
         return spell.cast(mod.game.gg.X,mod.game.gg.Y);
      }
      private function start(n:int):void {
         clear();round=n;phase="show";at=getTimer();oracle=nativeState=previousNative=null;
         samples=wrong=0;firstWrong="";sourceOK=false;frames={inh:{},shit:{}};nativeFrames={inh:{},shit:{}};peerDone=localDone=shot=false;
         enemyOracle=null;enemyOK=false;enemySamples=enemyWrong=0;
         pauseOpened=pauseSeen=false;pauseFrame=-1;pauseDrift=0;
         nativeHorn=[];remoteHorn=[];
         var g:Object=mod.game.gg,k:String=kind();
         if(source()) {
            if(k=="stealth"||k=="combo")check(g.invent.useItem("stealth"),"native inventory consumes stealth item");
            if(k=="shield"||k=="combo"||k=="pause")check(cast(shieldSpell),"native shield Spell.cast succeeds");
            if(k=="shadow")g.addEffect("potion_shadow",0,30,false);
            if(k=="blood")g.addEffect("bloodinv",0,30,false);
            if(k=="frozen")g.addEffect("freezing",0,30,false);
            if(k=="inhibitor")g.addEffect("inhibitor",0,30,false);
            if(k=="rat")g.addEffect("potion_rat",0,30,false);
            if(k=="fetter"){g.addEffect("fetter",0,30,false);g.fetX=g.X-60;g.fetY=g.Y;}
         }
         if(kind()=="enemy-frozen"&&host)enemy.addEffect("freezing",0,30,false);
         Log.d("BODY EFFECTS START "+JSON.stringify({round:round,kind:k,source:source()}));
      }
      private function before(e:Event):void {
         if(phase!="show"&&phase!="sampled")return;
         var g:Object=mod.game.gg,w:Object=mod.game.world;
         g.disabled=true;g.invulner=true;g.storona=host?1:-1;g.dx=g.dy=0;g.stay=true;g.isPlav=false;g.isLaz=0;
         g.setPos(baseX,baseY);g.setVisPos();g.ggControl=true;g.pipOff=0;
         w.ctr.keyAttack=w.ctr.keyMagic=w.ctr.keyGrenad=w.ctr.keyTele=false;
         if(source()&&kind()=="levitation"){g.levit=1;g.fracLevit=g.fraction;}
         if(source()&&kind()=="dash")g.dash_t=g.dash_maxt;
      }
      private function after(e:Event):void {
         if(phase!="show"&&phase!="sampled")return;
         if(!mod.game.coopPaused) {
            if(source()&&kind()=="crystal")cast(crystalSpell);
            // Native public methods, once per frame while the fixture holds
            // physics still. Effects/filters retain their real creation logic.
            mod.game.gg.actions();mod.game.gg.animate();
         }
         mod.stage.invalidate();
      }
      private static function node(root:Object,path:String):Object {
         var o:Object=root;for each(var k:String in path.split("."))o=GameBridge.probe(o,k);return o;
      }
      private static function color(v:DisplayObject):Array {
         var c:ColorTransform=v.transform.colorTransform;
         return [c.redMultiplier,c.greenMultiplier,c.blueMultiplier,c.alphaMultiplier,c.redOffset,c.greenOffset,c.blueOffset,c.alphaOffset];
      }
      private static function effects(v:DisplayObject):Array {
         var out:Array=[];
         for each(var f:Object in v.filters) {
            if(f is BlurFilter)out.push(["blur",f.blurX,f.blurY,f.quality]);
            else if(f is GlowFilter)out.push(["glow",f.color,f.alpha,f.blurX,f.blurY,f.strength,f.inner,f.knockout]);
            else if(f is DropShadowFilter)out.push(["shadow",f.color,f.alpha,f.blurX,f.blurY,f.distance,f.angle,f.hideObject]);
         }
         return out;
      }
      private function read(u:Object):Object {
         var root:DisplayObject=GameBridge.probe(u,"vis") as DisplayObject;
         if(root==null)return null;
         var osn:DisplayObject=node(root,"osn") as DisplayObject;
         if(osn==null)return null;
         var s:Object={a:root.alpha,c:color(root),v:osn.visible,oa:osn.alpha,oc:color(osn),f:effects(osn),parts:{}};
         for each(var path:String in PATHS) {
            var v:DisplayObject=node(root,path) as DisplayObject;
            if(v==null)continue;
            var clip:MovieClip=v as MovieClip;
            s.parts[path]={v:v.visible,a:v.alpha,r:v.rotation,sx:v.scaleX,sy:v.scaleY,
               frame:clip==null?0:clip.currentFrame,play:clip!=null&&clip.isPlaying};
         }
         return s;
      }
      private function contract(s:Object):Boolean {
         if(s==null)return false;
         var k:String=source()&&!enemyRound()?kind():"plain",p:Object=s.parts;
         if(k=="stealth")return s.a<.6&&has(s.f,"blur");
         if(k=="combo")return s.a<.6&&has(s.f,"blur")&&p.shit.v;
         if(k=="shield"||k=="pause")return p.shit.v&&p.shit.frame==20;
         if(k=="shadow")return has(s.f,"shadow");
         if(k=="blood")return count(s.f,"glow")>=2;
         if(k=="frozen")return Number(s.c[4])>0&&Number(s.c[6])>0;
         if(k=="inhibitor")return p.inh.v;
         if(k=="rat")return !s.v&&p.rat.v;
         if(k=="fetter")return p.fetter.v&&Number(p.fetter.sx)>.1;
         if(k=="crystal")return p.cryst.v;
         if(k=="levitation")return has(s.f,"glow");
         if(k=="dash")return has(s.f,"blur");
         return s.a>.99&&s.v&&!p.rat.v&&!p.shit.v&&!p.inh.v&&!p.cryst.v&&!p.fetter.v;
      }
      private static function count(a:Array,k:String):int {var n:int=0;for each(var f:Array in a)if(f[0]==k)n++;return n;}
      private static function has(a:Array,k:String):Boolean {return count(a,k)>0;}
      private static function same(a:*,b:*):Boolean {
         if(a is Array && b is Array) {
            if(a.length!=b.length)return false;
            for(var i:int=0;i<a.length;i++)if(!same(a[i],b[i]))return false;
            return true;
         }
         if(a is Number && b is Number)return Math.abs(Number(a)-Number(b))<.02;
         return a===b;
      }
      private function mismatch(remote:Object,expected:Object):String {
         if(remote==null)return "missing ghost body";
         if(Math.abs(Number(remote.a)-Number(expected.a)*.75)>.02)return "root alpha";
         var marked:Array=expected.c.concat();marked[3]=Number(expected.a)*.75;marked[7]=Number(marked[7])*.75;
         if(!same(remote.c,marked))return "root tint/alpha composition";
         if(remote.v!==expected.v || Math.abs(Number(remote.oa)-Number(expected.oa))>.02)return "pony visibility/alpha";
         if(!same(remote.oc,expected.oc))return "body tint";
         if(!same(remote.f,expected.f))return "body filters";
         for each(var path:String in PATHS) {
            var a:Object=remote.parts[path],b:Object=expected.parts[path];
            if(a==null||b==null){if(a!==b)return path+" missing";continue;}
            // Horn intensity fades in 5% native steps. The production display
            // intentionally trails source time by 100–250ms; comparing only
            // the newest 100ms oracle packet mislabels that fade as a failure.
            // Keep exact visibility/alpha checks against the bounded native
            // history (250ms display + one 100ms oracle sampling interval).
            if(path=="osn.body.head.morda.magic") {
               var hornOK:Boolean=a.v===b.v&&(!b.v||Math.abs(Number(a.a)-Number(b.a))<=.055);
               for each(var h:Object in remoteHorn)if(a.v===h.v&&(!h.v||Math.abs(Number(a.a)-Number(h.a))<=.055))hornOK=true;
               if(!hornOK)return "native horn fade outside display buffer";
               continue;
            }
            if(a.v!==b.v)return path+" visibility";
            if(!b.v)continue;
            // Horn intensity and fetter geometry are stable in this fixture.
            if(Math.abs(Number(a.a)-Number(b.a))>.055)return path+" alpha";
            if(path=="fetter"&&(Math.abs(a.r-b.r)>1||Math.abs(a.sx-b.sx)>.02))return "fetter geometry";
            if(path=="shit"&&b.frame==20&&a.frame!=20)return "shield held frame";
         }
         return "";
      }
      private function findEnemy():Object {
         if(host)return enemy;
         for each(var u:Object in mod.game.loc.units)
            if(!(u is MirrorHitUnit)&&GameBridge.probe(u,"id")=="rconnect_body_effects_enemy")return u;
         return null;
      }
      private function render(e:Event):void {
         if(phase!="show"&&phase!="sampled")return;
         nativeState=read(mod.game.gg);
         if(nativeState!=null) {
            var horn:Object=nativeState.parts["osn.body.head.morda.magic"],now:int=getTimer();
            if(horn!=null)nativeHorn.push({at:now,v:horn.v,a:horn.a});
            while(nativeHorn.length>0&&now-int(nativeHorn[0].at)>350)nativeHorn.shift();
         }
         var ghost:Object=mod.game.getRemoteGhost(host?1:0),s:Object=read(ghost);
         if(phase=="show")for each(var tracked:String in ["inh","shit"]) {
            if(nativeState!=null&&nativeState.parts[tracked].v)nativeFrames[tracked][nativeState.parts[tracked].frame]=true;
            if(s!=null&&s.parts[tracked].v)frames[tracked][s.parts[tracked].frame]=true;
         }
         if(phase!="show"||getTimer()-at<1300)return;
         sourceOK=sourceOK||contract(nativeState);
         if(enemyRound()) {
            var unit:Object=findEnemy(),visual:DisplayObject=GameBridge.probe(unit,"vis") as DisplayObject;
            if(visual!=null) {
               if(host)enemyOK=kind()=="enemy-frozen"?color(visual)[4]>0&&color(visual)[6]>0:true;
               else if(enemyOracle!=null){enemySamples++;if(!same(color(visual),enemyOracle))enemyWrong++;}
            }
         }
         if(oracle==null)return;
         samples++;var reason:String=mismatch(s,oracle);
         if(reason!=""){wrong++;if(firstWrong==""){firstWrong=reason;Log.d("BODY EFFECTS MISMATCH "+JSON.stringify({round:round,reason:reason,expected:oracle,actual:s}));}}
         if(kind()=="pause" && mod.game.coopPaused && getTimer()-at>3000) {
            pauseSeen=true;
            if(!source()&&s!=null){var f:int=s.parts.shit.frame;if(pauseFrame<0)pauseFrame=f;else if(f!=pauseFrame)pauseDrift++;}
         }
         if(!shot&&getTimer()-at>2000&&(kind()=="stealth"||kind()=="shield"||kind()=="combo"||kind()=="rat"||kind()=="shadow")) {
            shot=true;var bitmap:BitmapData=new BitmapData(mod.stage.stageWidth,mod.stage.stageHeight,false,0);
            bitmap.draw(mod.stage);
            if(!source()) {
               var without:BitmapData=new BitmapData(bitmap.width,bitmap.height,false,0),visible:Boolean=ghost.vis.visible;
               try {ghost.vis.visible=false;without.draw(mod.stage);}finally {ghost.vis.visible=visible;}
               var first:Vector.<uint>=bitmap.getVector(bitmap.rect),second:Vector.<uint>=without.getVector(without.rect),changed:int=0;
               for(var pi:int=0;pi<first.length;pi++)if(first[pi]!=second[pi])changed++;
               without.dispose();check(changed>12,"teammate effect contributes actual game pixels="+changed);
            }
            // Compress only after every animation sample. Synchronous PNG
            // encoding can stall the native 30fps timeline for several frames.
            pictures.push({name:"body-effects-"+round+".png",bitmap:bitmap});
         }
      }
      private function complete():void {
         if(localDone)return;localDone=true;phase="sampled";
         check(sourceOK,"native item/status visual contract reached");
         check(samples>=12&&wrong==0,"peer matches authoritative body samples="+samples+" wrong="+wrong+" first="+firstWrong);
         if(enemyRound())check(host?enemyOK:enemySamples>=12&&enemyWrong==0,
            "native enemy freeze/removal matches source color samples="+enemySamples+" wrong="+enemyWrong);
         if(kind()=="inhibitor"||kind()=="shield") {
            var clipName:String=kind()=="inhibitor"?"inh":"shit",n:int=0;
            for(var k:String in (source()?nativeFrames:frames)[clipName])n++;
            check(n>=3,"native one-shot attachment opens across frames count="+n);
         }
         if(kind()=="pause")check(pauseSeen&&(source()||pauseDrift==0),"shared SATS preserves shield holding pose drift="+pauseDrift);
         Log.d("BODY EFFECTS METRIC "+JSON.stringify({round:round,role:host?"host":"join",samples:samples,wrong:wrong,native:sourceOK,paused:pauseSeen,drift:pauseDrift}));
         if(host)advance();else send("result");
      }
      private function advance():void {
         if(!host||!peerDone||!localDone)return;
         if(round+1>=CASES.length*2+2){send("done");finish();return;}
         start(round+1);send("begin");
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;if(p.type!="body-effects-test"||phase=="done")return;
         try {
            if(p.stage!="oracle")Log.d("BODY EFFECTS CONTROL "+JSON.stringify({received:p.stage,phase:phase,at:getTimer()}));
            if(host&&p.stage=="ready"&&phase=="boot"){setup();phase="setup";at=getTimer();send("setup",{x:baseX,y:baseY});}
            else if(!host&&p.stage=="setup"&&phase=="boot"){setup(p.x,p.y);phase="setup";at=getTimer();send("setup-ready");}
            else if(host&&p.stage=="setup-ready"&&phase=="setup"){start(0);send("begin");}
            else if(!host&&p.stage=="begin")start(int(p.round));
            else if(p.stage=="oracle"&&int(p.round)==round){oracle=p.visual;remoteHorn=p.horn is Array?p.horn:[];if(p.enemy is Array)enemyOracle=p.enemy;}
            else if(host&&p.stage=="result"&&int(p.round)==round){peerDone=true;advance();}
            else if(p.stage=="done")finish();
         }catch(error:*){fail("message "+error);}
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null||mod.game==null||mod.game.gg==null||mod.session==null)return;
         if(host)for each(var p:Object in mod.session.peers)watch(p.link as TcpLink);else watch(mod.session.link);
         if(mod.game.world.clickReq==1){mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN,true));mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP,true));}
         if(phase!="done"&&getTimer()-at>(phase=="boot"?180000:45000)){fail("timeout "+phase);return;}
         if(!mod.session.rooms.ready||mod.session.rooms.busy||mod.game.isTransitioning())return;
         if(phase=="boot"&&!host&&timer.currentCount>150&&getTimer()-readyAt>500){readyAt=getTimer();send("ready");}
         if(phase=="show"||phase=="sampled") {
            if(nativeState!=null) {
               var msg:Object={visual:nativeState,horn:nativeHorn};
               if(host&&enemyRound()&&enemy!=null)msg.enemy=color(enemy.vis as DisplayObject);
               send("oracle",msg);
            }
            if(kind()=="pause"&&source()&&!pauseOpened&&getTimer()-at>1800){
               pauseOpened=true;mod.game.world.sats.onoff(1);
               check(mod.game.world.sats.active===true,"native SATS really opens with usable weapon id="+
                  GameBridge.probe(mod.game.gg.currentWeapon,"id")+" status="+(mod.game.gg.currentWeapon==null?-1:mod.game.gg.currentWeapon.status()));
            }
            if(phase=="show"&&getTimer()-at>(kind()=="pause"?4200:2500))complete();
         }
      }
      private function finish():void {
         if(phase=="done")return;phase="done";timer.stop();
         if(setupDone&&mod!=null) {
            mod.stage.removeEventListener(Event.ENTER_FRAME,before);mod.stage.removeEventListener(Event.ENTER_FRAME,after);mod.stage.removeEventListener(Event.RENDER,render);
            clear();var g:Object=mod.game.gg;g.disabled=old.disabled;g.invulner=old.invulner;g.mana=old.mana;
            g.levit=old.levit;g.fracLevit=old.frac;g.shithp=old.shield;g.invent.items["stealth"].kol=old.stealth;
            g.setPos(old.x,old.y);g.setVisPos();
            fixtureGun.remVisual();g.currentWeapon=old.weapon;g.childObjs=old.children;mod.game.loc.base=old.base;
            if(host)mod.session.pause.setPolicy(old.pauseMenus,old.pauseSats);
            if(host&&enemy!=null){var room:Object=enemy.loc;room.remObj(enemy);var index:int=room.units.indexOf(enemy);if(index>=0)room.units.splice(index,1);}
         }
         for(var link:Object in links)TcpLink(link).removeEventListener(TcpLink.MESSAGE,receive);
         loaderInfo.uncaughtErrorEvents.removeEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,onError);
         for each(var picture:Object in pictures) {
            var bitmap:BitmapData=picture.bitmap,fs:FileStream=new FileStream();
            fs.open(File.applicationStorageDirectory.resolvePath(picture.name),FileMode.WRITE);
            fs.writeBytes(bitmap.encode(bitmap.rect,new PNGEncoderOptions()));fs.close();bitmap.dispose();
         }
         pictures=[];
         Log.d("COOP EFFECTS DONE body-effects "+(host?"host":"join"));
      }
   }
}

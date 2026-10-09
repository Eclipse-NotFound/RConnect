package {
   import flash.desktop.NativeApplication;
   import flash.display.BitmapData;
   import flash.display.PNGEncoderOptions;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.MouseEvent;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.text.TextField;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import fe.unit.Unit;
   import rconnect.core.Config;
   import rconnect.core.Log;
   import rconnect.game.PeerHitUnit;
   import rconnect.net.NetMessageEvent;
   import rconnect.net.TcpLink;

   /** Native collision and native player mitigation, over the actual two links.
    * Host and join each attack once in every case; no direct proxy.damage calls. */
   public class FriendlyFireTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private static const CASES:Array=["off","gun","melee","laser","blast","stale","revoked"];
      private var mod:RConnectMod,host:Boolean,timer:Timer=new Timer(50),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=getTimer(),round:int=0,remoteReady:Boolean=false,localReady:Boolean=false;
      private var remoteDone:Boolean=false,localDone:Boolean=false,begun:Boolean=false,installed:Boolean=false;
      private var baseX:Number,baseY:Number,startHp:Number=0,expected:Number=0,received:int=0;
      private var seen:Object={},lastHit:Object,lastAttack:Object,retired:Array=[],oldRoom:Object;
      private var remoteRoom:String="",remoteEpoch:int=-1;
      public function FriendlyFireTestDoc() {
         var id:String=NativeApplication.nativeApplication.applicationID;if(id.indexOf("rconnect-coop-")<0)return;
         host=id.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();finish();
         });timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,s:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"friendly-fire "+s+" round="+round+" kind="+kind());}
      private function change(p:String):void {phase=p;at=getTimer();Log.d("FRIENDLY FIRE PHASE "+(host?"host ":"join ")+p+" round="+round);}
      private function kind():String {return CASES[round%CASES.length];}
      private function shooter():Boolean {return round<CASES.length?host:!host;}
      private function enabledCase():Boolean {return kind()!="off"&&kind()!="revoked";}
      private function send(op:String,p:Object=null):void {
         if(mod==null)return;p=p||{};p.type="friendly-fire-test";p.op=op;
         p.room=mod.game.roomKey();p.epoch=mod.game.roomEpoch;
         if(host&&mod.session.server!=null)mod.session.server.broadcast(p);
         else if(!host&&mod.session.link!=null&&mod.session.link.isOpen)mod.session.link.send(p);
      }
      private function raw(p:Object):void {
         if(host)mod.session.server.broadcast(p);else mod.session.link.send(p);
      }
      private function watch(l:TcpLink):void {
         if(l!=null&&!links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive,false,100000);}
      }
      private function ghost():Object {return mod.game.getRemoteGhost(host?1:0);}
      private function stable():Boolean {return mod.session.rooms.ready&&!mod.session.rooms.busy&&!mod.game.isTransitioning()&&mod.game.gg!=null;}
      private function proxies():Array {
         var result:Array=[];if(mod.game.loc!=null)for each(var u:Object in mod.game.loc.units)if(u is PeerHitUnit)result.push(u);
         return result;
      }
      private function arena():void {
         var l:Object=mod.game.loc;
         for(var y:int=240;y<l.limY-40;y+=40)for(var x:int=80;x<l.limX-360;x+=40) {
            var clear:Boolean=true;for(var ix:int=0;ix<=340&&clear;ix+=20) {
               if(l.getAbsTile(x+ix,y+1).phis!=1){clear=false;break;}
               for(var iy:int=20;iy<=180;iy+=20)if(l.getAbsTile(x+ix,y-iy).phis!=0){clear=false;break;}
            }if(clear){baseX=x;baseY=y;return;}
         }throw new Error("no native friendly fire corridor");
      }
      private function install():void {
         installed=true;mod.game.forceCloseOverlays();mod.config.setValue("followTeammate","0");
         check(!mod.friendlyFire.enabled&&mod.config.getValue("friendlyFire")=="0","safe default is off");
         mod.game.world.godMode=false;mod.game.world.testDam=true;mod.game.world.showHit=0;
         var l:Object=mod.game.loc;
         for each(var o:Object in l.objs.concat())if(o.X2>baseX-20&&o.X1<baseX+360&&o.Y2>baseY-190&&o.Y1<baseY+20) {
            l.remObj(o);l.objs.splice(l.objs.indexOf(o),1);if(l.celObj===o)l.celObj=null;
         }
         mod.stage.addEventListener(Event.ENTER_FRAME,before,false,99000);
      }
      private function before(e:Event):void {
         if(!installed||phase=="done"||phase=="disconnect"||mod.game.gg==null)return;
         var g:Object=mod.game.gg;
         g.setPos(baseX+(host?60:260),baseY);g.dx=g.dy=0;g.stay=true;g.levit=0;
         for each(var u:Object in mod.game.loc.units)if(u!==g&&Number(u.fraction)<100)u.disabled=true;
      }
      private function start(n:int):void {
         round=n;begun=localReady=remoteReady=localDone=remoteDone=false;expected=0;received=0;seen={};lastHit=null;
         var g:Object=mod.game.gg;
         g.pers.inMaxHP=1000000;g.pers.begHP=10000;g.pers.healAll();g.maxhp=g.hp=10000;
         g.currentArmor=null;g.armor_qual=0;g.skin=8;g.marmor=12;g.allVulnerMult=1;g.shithp=0;
         g.healhp=0;g.rad=0;g.invulner=false;g.dexter=g.dexterPlus=g.dodge=0;g.neujaz=0;
         g.vulner[0]=1;g.vulner[1]=1;g.vulner[2]=1;g.vulner[5]=0.5;
         if(host) {
            if(kind()=="revoked")mod.friendlyFire.setEnabled(true);
            mod.friendlyFire.setEnabled(enabledCase());
            check(new Config().getValue("friendlyFire")== (enabledCase()?"1":"0"),"host preference persists");
         }
         change("settle");
      }
      private function oracle(p:Object):void {
         if(shooter()||phase!="firing"||!enabledCase()||p.op!="hit"||seen[p.seq])return;
         if(p.roomKey!=mod.game.roomKey()||p.roomEpoch!=mod.session.rooms.epoch||p.roomTerm!=mod.session.rooms.term)return;
         seen[p.seq]=true;lastHit=p;received++;
         // Independent native oracle on the actual victim. No NativeHit.apply
         // or reimplementation of armor math is used by this test.
         var ad:Object=mod.main.loaderInfo.applicationDomain,g:Object=mod.game.gg;
         var uc:Class=ad.getDefinition("fe.unit.Unit") as Class,bc:Class=ad.getDefinition("fe.weapon.Bullet") as Class;
         var owner:Object=new uc();owner.loc=g.loc;owner.fraction=1;
         var b:Object=new bc(owner,g.X,g.Y-g.scY/2,null,false);
         for each(var k:String in ["armorMult","pier","critCh","critDamMult","critInvis","desintegr","probiv","dx","dy","vel","damage"])
            if(p.hit.bullet[k]!=null)b[k]=p.hit.bullet[k];
         var hp:Number=g.hp;g.damage(p.hit.amount,p.hit.kind,b,p.hit.periodic===true);expected+=hp-g.hp;g.hp=hp;
         check(expected>0&&expected<Number(p.hit.amount),"native victim mitigation applies before network hit");
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;
         try {
            if(p.type=="friendly-fire"){oracle(p);return;}
            if(p.type!="friendly-fire-test")return;
            if(p.op=="ready"){remoteReady=true;remoteRoom=p.room;remoteEpoch=p.epoch;}
            else if(!host&&p.op=="setup"){baseX=p.x;baseY=p.y;install();send("installed");change("waiting");}
            else if(host&&p.op=="installed"){start(0);send("round",{round:0});}
            else if(!host&&p.op=="round")start(p.round);
            else if(host&&p.op=="case-ready"){remoteReady=true;fireWhenReady();}
            else if(!host&&p.op=="fire")fire();
            else if(p.op=="replay") {
               // The original valid packet already applied. Neither a duplicate
               // nor a new sequence with the wrong room is a new native attack.
               raw(p.packet);var stale:Object=JSON.parse(JSON.stringify(p.packet));stale.seq+=100000;stale.roomKey+="/old";raw(stale);
            }
            else if(p.op=="sampled"){remoteDone=true;if(host&&localDone)advance();}
            else if(!host&&p.op=="disconnect"){prepareDisconnect();send("disconnect-ready");}
            else if(host&&p.op=="disconnect-ready"){send("stop");change("disconnect");}
            else if(!host&&p.op=="stop")change("disconnect");
         }catch(err:Error){check(false,err.getStackTrace());finish();}
      }
      private function fireWhenReady():void {
         if(host&&localReady&&remoteReady&&!begun){begun=true;send("fire");fire();}
      }
      private function fire():void {
         startHp=mod.game.gg.hp;change("firing");
         if(!shooter())return;
         var g:Object=mod.game.gg,target:Object=ghost(),ad:Object=mod.main.loaderInfo.applicationDomain;
         check(target!=null,"native teammate target exists");
         if(kind()=="gun"||kind()=="off"||kind()=="revoked"||kind()=="stale") {
            var gun:NativeTestGun=new NativeTestGun(g as Unit),w:Object=gun;w.damage=60;w.critCh=0;
            var shot:Object=gun.fireAt(target,true);check(shot!=null,"native LMG shoots through ordinary collision");
         } else {
            var bc:Class=ad.getDefinition("fe.weapon.Bullet") as Class;
            var b:Object=new bc(g,target.X-25,target.Y-target.scY/2,null,false);
            b.weap=new NativeTestGun(g as Unit);b.damage=60;b.miss=0;b.precision=0;
            b.critCh=b.critInvis=b.desintegr=0;b.armorMult=1;b.pier=0;b.probiv=0;b.knockx=b.knocky=b.otbros=0;
            b.tipDamage=kind()=="laser"?5:kind()=="blast"?2:1;b.tipBullet=kind()=="melee"?1:0;
            if(kind()=="blast") {
               b.damage=0;b.damageExpl=60;b.explTip=1;b.explRadius=65;b.destroy=0;
               b.explosion();check(b.isExpl,"native explosion creates targeted blast bullets");
            } else {
               b.X=target.X;b.Y=target.Y-target.scY/2;b.dx=15;b.dy=0;b.vel=15;
               // Native Bullet.run performs faction, geometry and dodge checks.
               b.run();check(b.babah,"native "+kind()+" collision consumes a hit");
            }
         }
      }
      private function picture():void {
         var h:Object=mod.hud;h.visible=true;h.openPage("settings");
         h.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_WHEEL,true,false,0,0,null,false,false,false,false,-100));h.refresh();
         var t:TextField=h.getChildByName("rconnect-friendly-fire") as TextField;
         check(t!=null&&t.visible&&t.mouseEnabled==host,"visible settings control follows host permission");
         for each(var lang:String in ["en","ru","tw"]) {
            mod.game.world.lang=lang;h.refresh();check(t.textWidth<t.width-4,"friendly fire label fits "+lang);
         }
         var image:BitmapData=new BitmapData(mod.stage.stageWidth,mod.stage.stageHeight,false,0);image.draw(mod.stage);
         var fs:FileStream=new FileStream();fs.open(File.applicationStorageDirectory.resolvePath("friendly-fire-settings.png"),FileMode.WRITE);
         fs.writeBytes(image.encode(image.rect,new PNGEncoderOptions()));fs.close();image.dispose();h.collapse();
      }
      private function prepareDisconnect():void {oldRoom=mod.game.loc;retired=proxies();
         check(retired.length==1,"live receiver exists before disconnect");change("disconnect-prepare");}
      private function advance():void {
         if(round<CASES.length*2-1){start(round+1);send("round",{round:round});}
         else {mod.friendlyFire.setEnabled(true);prepareDisconnect();send("disconnect");}
      }
      private function tick(e:TimerEvent):void {
         if(mod==null){mod=RConnectMod.instance;if(mod==null)return;}
         if(host&&mod.session.server!=null)for each(var l:TcpLink in mod.session.server.clients)watch(l);
         else if(!host)watch(mod.session.link);
         if(phase=="done")return;
         try {
            if(getTimer()-at>(phase=="boot"?180000:30000)){check(false,"timeout "+phase);finish();return;}
            if(phase=="boot"&&stable()&&mod.game.readWorldInfo().curLandId=="random_mane") {
               if(host&&remoteReady&&remoteRoom==mod.game.roomKey()&&remoteEpoch==mod.game.roomEpoch) {
                  arena();install();send("setup",{x:baseX,y:baseY});change("setup");
               } else if(!host)send("ready");
            }
            var elapsed:int=getTimer()-at;
            if(phase=="settle"&&elapsed>1300&&stable()&&ghost()!=null&&mod.friendlyFire.enabled==enabledCase()) {
               if(!localReady) {
                  check(proxies().length==(enabledCase()?1:0),"exactly one receiver only while enabled");
                  check(ghost().fraction==100,"teammate native faction stays friendly");
                  if(!host){check(!mod.friendlyFire.setEnabled(!enabledCase()),"join cannot change global policy");check(mod.friendlyFire.enabled==enabledCase(),"host policy remains authoritative");}
                  if(round==0)picture();localReady=true;if(host)fireWhenReady();else send("case-ready");
               }
            } else if(phase=="firing"&&elapsed>1400) {
               if(!shooter()) {
                  var loss:Number=startHp-mod.game.gg.hp;
                  check(received==(enabledCase()?1:0),"one native attack sends one damage packet received="+received);
                  check(Math.abs(loss-expected)<0.01,"actual victim loss equals native oracle once loss="+loss+" expected="+expected);
                  if(kind()=="stale"&&lastHit!=null){send("replay",{packet:lastHit});change("replay");return;}
               }complete();
            } else if(phase=="replay"&&elapsed>1000) {
               check(Math.abs(startHp-mod.game.gg.hp-expected)<0.01,"duplicate and old-room packets do not deal damage");complete();
            } else if(phase=="disconnect"&&elapsed>300) {
               if(mod.session.mode!="offline"){retired=proxies();oldRoom=mod.game.loc;mod.session.leave();}
               if(elapsed>800){var clean:Boolean=proxies().length==0;for each(var old:Object in retired)clean=clean&&old.disabled&&oldRoom.units.indexOf(old)<0;check(clean,"disconnect removes owned receivers");finish();}
            }
         }catch(err:Error){check(false,err.getStackTrace());finish();}
      }
      private function complete():void {localDone=true;send("sampled");change("sampled");if(host&&remoteDone)advance();}
      private function finish():void {
         if(phase=="done")return;change("done");timer.stop();
         if(mod!=null){mod.stage.removeEventListener(Event.ENTER_FRAME,before);if(mod.game!=null&&mod.game.world!=null)mod.game.world.testDam=false;}
         Log.d("COOP EFFECTS DONE friendly-fire "+(host?"host":"join"));
      }
   }
}

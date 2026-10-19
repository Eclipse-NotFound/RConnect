package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.display.BitmapData;
   import flash.display.PNGEncoderOptions;
   import flash.filesystem.*;
   import flash.events.*;
   import flash.utils.*;
   import flash.text.TextField;
   import fe.unit.RConnectSecurityAccess;
   import rconnect.core.Config;
   import rconnect.core.Log;
   import rconnect.net.NetMessageEvent;
   import rconnect.net.TcpLink;

   /** Real terminal activation, native turret AI/projectiles, and two TCP peers.
    * Skill/minigame prerequisites are arranged in the isolated test characters;
    * the actual success command and allAct path are the native game methods. */
   public class SecurityTerminalTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private const cases:Array=[
         {shared:true,hacker:0,skill:0},{shared:false,hacker:0,skill:0},
         {shared:false,hacker:1,skill:0},{shared:false,hacker:0,skill:1},
         {shared:false,hacker:1,skill:1},{shared:true,hacker:1,skill:2}];
      private var mod:RConnectMod,host:Boolean,timer:Timer=new Timer(100),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=getTimer(),round:int=-1,peerReady:Boolean=false;
      private var fixture:Object,terminal:Object,unit:Object,baseHp:Number,baseMaxHp:Number,peerHp:Number,peerLoss:Number;
      private var seen:Object={},beforeXp:Number,afterXp:Number,checks:int=0,failures:int=0;
      private var baseX:Number=0,baseY:Number=0;
      private var attackKind:int=0;
      private var reverseHp:Number=0;
      public function SecurityTerminalTestDoc() {
         var id:String=NativeApplication.nativeApplication.applicationID;
         if(id.indexOf("rconnect-coop-")<0)return;host=id.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();finish();
         });timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,s:String):void {checks++;if(!ok)failures++;Log.d("COOP "+(ok?"PASS ":"FAIL ")+"security round="+round+" "+s);}
      private function change(p:String):void {phase=p;at=getTimer();Log.d("SECURITY PHASE "+(host?"host ":"join ")+p+" round="+round);}
      private function spec():Object {return cases[round];}
      private function mine():Boolean {return int(spec().hacker)==(host?0:1);}
      private function protectedSelf():Boolean {return spec().shared || mine();}
      private function stable():Boolean {
         if(mod.game.gg==null || mod.game.loc==null || !mod.session.rooms.ready || mod.session.rooms.busy || mod.game.isTransitioning())return false;
         // Native new-game first visits the home base. Its terminals are already
         // unlocked; wait for the requested expedition before creating fixtures.
         return mod.game.world.land!=null && mod.game.world.land.act!=null
            && String(mod.game.world.land.act.id)=="random_mane";
      }
      private function ghost():Object {return mod.game.getRemoteGhost(host?1:0);}
      private function watch(l:TcpLink):void {if(l!=null && !links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);}}
      private function send(op:String,p:Object=null):void {
         p=p||{};p.type="security-test";p.op=op;p.round=round;
         if(host)mod.session.server.broadcast(p);else mod.session.link.send(p);
      }
      private function clearFixtures():void {
         var l:Object=mod.game.loc;
         for each(var u:Object in l.units.concat())if(String(u.id).indexOf("security-fixture-")==0){l.remObj(u);l.units.splice(l.units.indexOf(u),1);}
         for each(var b:Object in l.objs.concat())if(String(b.id)=="term1"){l.remObj(b);l.objs.splice(l.objs.indexOf(b),1);}
      }
      private function create():void {
         clearFixtures();var g:Object=mod.game.gg,l:Object=mod.game.loc;
         var bc:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.loc.Box") as Class;
         terminal=new bc(l,"term1",g.X+80,g.Y);l.objs.push(terminal);l.addObj(terminal);
         var uc:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit.UnitTurret") as Class;
         unit=new uc("",100,<unit tr="1" vis="right"/>,null);unit.id="security-fixture-"+round;
         unit.putLoc(l,g.X+130,g.Y-40);l.units.push(unit);l.addObj(unit);
         unit.fixed=true;unit.stay=true;unit.doop=false;unit.lootIsDrop=true;unit.xp=17;
         unit.hp=unit.maxhp=1000;unit.vision=50;unit.overLook=true;unit.oduplenie=0;
         fixture={unit:mod.game.securityUnitKey(unit),terminal:mod.game.securityObjectKey(terminal),x:baseX,y:baseY};
         check(terminal.inter!=null && terminal.inter.allact=="hack_robot" && terminal.inter.lock>0,"native locked security terminal created");
         check(RConnectSecurityAccess.state(unit).sleep==false,"native turret starts active");
      }
      private function locate():Boolean {
         if(fixture==null)return false;unit=mod.game.unitForKey(fixture.unit);terminal=null;
         for each(var b:Object in mod.game.loc.objs)if(b.id=="term1" && mod.game.securityObjectKey(b)==fixture.terminal)terminal=b;
         return unit!=null && terminal!=null && terminal.inter!=null;
      }
      private function toggle(shared:Boolean):void {
         mod.hud.visible=true;mod.hud.openPage("settings");mod.hud.refresh();
         var control:TextField=mod.hud.getChildByName("rconnect-security") as TextField;
         // The compact HUD owns a scrolling surface; lookup through its public field tree.
         if(control==null)control=findControl(mod.hud);
         check(control!=null,"setting exists in the compact settings page");
         if(control!=null && mod.securityTerminals.shared!=shared)control.dispatchEvent(new MouseEvent(MouseEvent.CLICK,true));
         check(mod.securityTerminals.shared==shared,"HUD policy applied="+shared);
         check(new Config().getValue("sharedSecurityHack")== (shared?"1":"0"),"host preference saved");
         mod.hud.collapse();
      }
      private function findControl(o:Object):TextField {
         if(o is TextField && o.name=="rconnect-security")return o as TextField;
         if(!(o is flash.display.DisplayObjectContainer))return null;
         for(var i:int=0;i<o.numChildren;i++){var f:TextField=findControl(o.getChildAt(i));if(f!=null)return f;}return null;
      }
      private function settingsPicture():void {
         var h:Object=mod.hud;h.openPage("settings");h.refresh();
         h.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_WHEEL,true,false,0,0,null,false,false,false,false,-100));
         var control:TextField=findControl(h);
         check(control!=null && control.visible && control.mouseEnabled==host,"scrolled setting is visible and follows host permission");
         if(control!=null)check(control.textWidth<control.width-4,"security setting label fits compact panel");
         var picture:BitmapData=new BitmapData(mod.stage.stageWidth,mod.stage.stageHeight,false,0);picture.draw(mod.stage);
         var fs:FileStream=new FileStream();fs.open(File.applicationStorageDirectory.resolvePath("presentation-security-"+round+".png"),FileMode.WRITE);
         fs.writeBytes(picture.encode(picture.rect,new PNGEncoderOptions()));fs.close();picture.dispose();h.collapse();
      }
      private function health():void {
         var g:Object=mod.game.gg;
         // Native setParameters recomputes maxhp from Pers; changing only the
         // derived Unit field is undone by ordinary equipment/stat updates.
         // healAll alone leaves trauma stages stale. Native healing updates
         // those stages before we recompute the character's final maximum.
         g.pers.heal(1000000,4);g.pers.heal(1000000,5);g.pers.heal(1000000,6);
         g.pers.begHP=5000;g.pers.setParameters();
         // Measure primary HP damage without secondary injuries also changing
         // the maximum. This affects only these isolated test characters.
         g.pers.organMult=0;g.pers.regenFew=0;
         g.hp=g.maxhp;g.invulner=false;g.neujaz=0;g.currentArmor=null;g.rad=0;
         g.shithp=0;g.armor=g.skin=g.marmor=0;g.armor_qual=0;g.dexter=g.dexterPlus=g.dodge=0;
         g.healhp=0;g.invis=false;g.obs=g.maxObs;mod.game.world.godMode=false;
         baseHp=g.hp;baseMaxHp=g.maxhp;
         check(g.sost<3 && mod.game.world.t_die==0 && baseHp==baseMaxHp && baseMaxHp>=1000,
            "native test character alive and fully healed; HP="+baseHp+" max="+baseMaxHp);
      }
      private function arena():void {
         var l:Object=mod.game.loc;
         for(var y:int=240;y<l.limY-40;y+=40)for(var x:int=80;x<l.limX-360;x+=40) {
            var clear:Boolean=true;
            for(var dx:int=0;dx<=340 && clear;dx+=20) {
               if(l.getAbsTile(x+dx,y+1).phis!=1){clear=false;break;}
               for(var dy:int=20;dy<=180;dy+=20)if(l.getAbsTile(x+dx,y-dy).phis!=0){clear=false;break;}
            }
            if(clear){baseX=x;baseY=y;break;}
         }
         if(baseY==0)throw new Error("No open native corridor for the security test");
         for each(var b:Object in l.objs.concat())if(b.X2>baseX-20 && b.X1<baseX+360 && b.Y2>baseY-190 && b.Y1<baseY+20) {
            l.remObj(b);l.objs.splice(l.objs.indexOf(b),1);
         }
      }
      private function hack():void {
         mod.game.world.pers.security=int(spec().skill);
         Log.d("SECURITY HACK "+JSON.stringify({role:host?"host":"join",phase:phase,round:round,unit:fixture.unit,
            hp:unit.hp,state:RConnectSecurityAccess.state(unit),fraction:unit.fraction,
            ready:mod.session.rooms.ready,busy:mod.session.rooms.busy,transition:mod.game.isTransitioning()}));
         terminal.inter.command("unlock");terminal.inter.allAct();
         check(terminal.inter.lock==0,"actual native unlock command succeeded");
      }
      private function next():void {
         round++;if(round>=cases.length){send("done");change("finish-wait");return;}
         toggle(spec().shared);mod.game.gg.setPos(baseX+60,baseY);create();health();peerReady=false;send("setup",{fixture:fixture});change("setup");
      }
      private function fire(target:Object):void {
         var c:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.weapon.Bullet") as Class;
         var bullet:Object=new c(unit,target.X+(attackKind>0?10:0),target.Y-target.scY/2,null,false);
         bullet.targetObj=target;bullet.damage=100;bullet.tipDamage=0;bullet.probiv=0;bullet.critCh=0;
         bullet.vel=0;bullet.dx=bullet.dy=0;bullet.liv=3;
         if(attackKind==0)bullet.step();
         else {bullet.targetObj=null;bullet.weap=unit.currentWeapon;bullet.damageExpl=100;bullet.destroy=0;bullet.explRadius=65;bullet.explTip=attackKind==1?2:1;bullet.explosion();}
         bullet.off=true;
      }
      private function reverseFire():void {
         var c:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.weapon.Bullet") as Class;
         var bullet:Object=new c(mod.game.gg,unit.X,unit.Y-unit.scY/2,null,false);
         bullet.damage=100;bullet.tipDamage=0;bullet.pier=100;bullet.critCh=0;bullet.precision=0;bullet.miss=0;
         bullet.vel=0;bullet.dx=bullet.dy=0;bullet.liv=3;
         // Ordinary collision, with no targetObj bypass: the reprogrammed
         // turret must remain hittable by the player who has not hacked it.
         bullet.step();bullet.off=true;
      }
      private function switchPolicy():void {toggle(!spec().shared);send("switch");change("switch");}
      private function audit():void {
         check(locate(),"turret/terminal still synchronized after hacking");
         if(round<=1)settingsPicture();
         check((terminal.inter.lock==0)==protectedSelf(),"terminal unlock is personal/shared as requested lock="+terminal.inter.lock);
         if(spec().skill>0)check(unit.fraction==100,"reprogrammed turret remains synchronized as a friendly faction");
         if(host) {
            var expected:Object=spec().hacker==0?ghost():mod.game.gg;
            if(expected.player)expected.obs=expected.maxObs;
            unit.priorUnit=spec().hacker==0?mod.game.gg:ghost();unit.celUnit=unit.priorUnit;
            var found:Boolean=unit.findCel(true);
            if(spec().shared)check(unit.celUnit!==mod.game.gg && unit.celUnit!==ghost(),"shared hack removes both players from native targeting");
            else check(found && unit.celUnit===expected,"native targeting skips hacker and acquires the other player");
         } else check(!mod.securityTerminals.setShared(!spec().shared),"join cannot override host policy");
         if(mine()) {
            beforeXp=unit.xp;terminal.inter.allAct();afterXp=unit.xp;
            check(beforeXp==afterXp,"repeated activation does not change turret XP twice");
         }
      }
      private function offline():void {
         mod.session.leave();
         var c:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit.UnitTurret") as Class;
         var u:Object=new c("",100,<unit tr="1"/>,null);u.putLoc(mod.game.loc,mod.game.gg.X+100,mod.game.gg.Y);
         mod.game.loc.units.push(u);mod.game.world.pers.security=0;terminal.inter.allAct();
         check(RConnectSecurityAccess.state(u).sleep,"offline native terminal retains original whole-room behavior");
      }
      private function secondHack():void {
         send("second-hack");if(!mine())hack();change("second-hack");
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;if(p==null || p.type!="security-test")return;
         try {
            if(host && p.op=="ready"){peerReady=true;return;}
            if(!host && p.op=="setup") {round=p.round;fixture=p.fixture;baseX=fixture.x;baseY=fixture.y;health();change("locate");return;}
            if(p.round!=round && p.op!="done")return;
            if(host && p.op=="located"){send("hack");if(mine())hack();change("settle");}
            else if(!host && p.op=="hack"){if(mine())hack();change("settle");}
            else if(!host && p.op=="audit"){audit();health();send("audited");change("shot-wait");}
            else if(host && p.op=="audited"){attackKind=0;health();send("shot",{kind:attackKind});change("shot-ready");}
            else if(!host && p.op=="shot"){attackKind=p.kind;health();send("shot-ready");change("shot");}
            else if(host && p.op=="shot-ready"){fire(mod.game.gg);fire(ghost());change("shot");}
            else if(!host && p.op=="check-shot") {
               check(mod.game.gg.maxhp==baseMaxHp,"local maximum HP unchanged during the attack");
               var loss:Number=baseHp-mod.game.gg.hp;check(protectedSelf()?loss==0:loss>0,"native turret attack "+attackKind+" obeys local access; HP loss="+loss);
               send("shot-checked");change("wait");
            } else if(host && p.op=="shot-checked") {
               check(mod.game.gg.maxhp==baseMaxHp,"host maximum HP unchanged during the attack");
               loss=baseHp-mod.game.gg.hp;check(protectedSelf()?loss==0:loss>0,"native turret attack "+attackKind+" obeys host access; HP loss="+loss);
               if(attackKind<2){attackKind++;health();send("shot",{kind:attackKind});change("shot-ready");return;}
               if(spec().skill==1) {
                  reverseHp=unit.hp;send("reverse-shot");if(!mine())reverseFire();change("reverse-shot");
               } else switchPolicy();
            } else if(!host && p.op=="reverse-shot") {
               reverseHp=unit.hp;if(!mine())reverseFire();change("reverse-shot");
            } else if(!host && p.op=="check-reverse") {
               check(unit.hp<reverseHp && unit.hp>0,"unhacked player's ordinary bullet damages reprogrammed turret on join HP="+unit.hp+" before="+reverseHp);
               send("reverse-checked");change("wait");
            } else if(host && p.op=="reverse-checked") {
               check(unit.hp<reverseHp && unit.hp>0,"unhacked player's ordinary bullet damage reaches room owner HP="+unit.hp+" before="+reverseHp);
               switchPolicy();
            } else if(!host && p.op=="switch")change("switch");
            else if(!host && p.op=="check-switch") {
               check((terminal.inter.lock==0)==protectedSelf(),"switch keeps already earned terminal permissions");send("switch-checked");change("wait");
            } else if(host && p.op=="switch-checked") {
               var fc:Object=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit.UnitTurret");
               check(fc.rconnectSecurityHit(unit,mod.game.gg,true)==!protectedSelf(),"mode switch preserves host turret access");
               check(fc.rconnectSecurityHit(unit,ghost(),true)==!(spec().shared || spec().hacker==1),"mode switch preserves join turret access");
               if(!spec().shared) {
                  if(round==1) {
                     var checkpoint:Object=mod.game.checkpoint();
                     send("restore-checkpoint",{checkpoint:checkpoint});
                     mod.game.restoreCheckpoint(checkpoint,true,false);change("restore-wait");
                  } else secondHack();
               } else next();
            } else if(!host && p.op=="restore-checkpoint") {
               // Exercise the real room handoff restore with the other player's
               // checkpoint, while this endpoint still has no personal access.
               mod.game.restoreCheckpoint(p.checkpoint,false,true);
               check(locate() && terminal.inter.lock>0,"foreign room restore preserves own locked terminal");
               fc=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit.UnitTurret");
               check(fc.rconnectSecurityHit(unit,mod.game.gg,true),"foreign room restore preserves ungranted player's vulnerability");
               send("restored-checkpoint");change("wait");
            } else if(host && p.op=="restored-checkpoint") {
               check(locate() && terminal.inter.lock==0,"own room restore preserves earned terminal access");
               fc=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit.UnitTurret");
               check(!fc.rconnectSecurityHit(unit,mod.game.gg,true),"own room restore preserves earned turret immunity");
               secondHack();
            } else if(!host && p.op=="second-hack") {if(!mine())hack();change("second-hack");}
            else if(!host && p.op=="check-second") {
               check(terminal.inter.lock==0,"other player completes its own native unlock");send("second-checked");change("wait");
            } else if(host && p.op=="second-checked") {
               fc=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit.UnitTurret");
               check(!fc.rconnectSecurityHit(unit,mod.game.gg,true) && !fc.rconnectSecurityHit(unit,ghost(),true),"second hack grants both permissions");
               // The room handoff serializes neither player's personal lock state.
               var cp:Object=mod.game.checkpoint(),terminalState:Object=null;
               for each(var b:Object in cp.objs)if(b.k==fixture.terminal)terminalState=b;
               check(terminalState!=null && terminalState.inter==null && terminalState.interNative==null,"room checkpoint cannot overwrite teammate's personal lock attempts");
               next();
            } else if(!host && p.op=="done") {round=int(p.round);send("done-ack");finish();}
            else if(host && p.op=="done-ack") {offline();finish();}
         }catch(err:Error){check(false,err.getStackTrace());finish();}
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null || phase=="done")return;
         // Protect the isolated characters during asynchronous map generation,
         // before the two-sided ready barrier. No damage assertion runs here.
         if(phase=="boot" && mod.game.gg!=null){mod.game.gg.invulner=true;mod.game.gg.hp=mod.game.gg.maxhp;}
         if(mod.game.world!=null)mod.game.world.enemyAct=0;
         if(host && mod.session.server!=null)for each(var l:TcpLink in mod.session.server.clients)watch(l);else if(!host)watch(mod.session.link);
         try {
            if(getTimer()-at>(phase=="boot"?150000:25000)){check(false,"timeout "+phase);finish();return;}
            if(!stable())return;
            mod.game.forceCloseOverlays();mod.game.world.enemyAct=0;
            if(baseY>0){mod.game.gg.setPos(baseX+(host?60:260),baseY);mod.game.gg.dx=mod.game.gg.dy=0;mod.game.gg.stay=true;}
            if(phase=="boot") {
               if(!seen.boot){check(mod.securityTerminals.supported,"native security interface present");seen.boot=true;}
               if(!host && mod.securityTerminals.stateReady) {
                  if(!seen.policy){check(true,"initial host security settings received before any policy toggle");seen.policy=true;}
                  send("ready");
               } else if(host && peerReady && ghost()!=null){arena();next();}
            } else if(phase=="locate" && locate() && mod.securityTerminals.shared==spec().shared) {
               check(terminal.inter.lock>0,"other endpoint starts with a locked native terminal");send("located");change("wait-hack");
            } else if(host && phase=="settle" && getTimer()-at>1800) {audit();send("audit");change("audit-wait");}
            else if(host && phase=="shot" && getTimer()-at>1500){send("check-shot");change("shot-check");}
            else if(host && phase=="reverse-shot" && getTimer()-at>1500){send("check-reverse");change("reverse-check");}
            else if(host && phase=="switch" && getTimer()-at>1300){send("check-switch");change("switch-check");}
            else if(host && phase=="second-hack" && getTimer()-at>1500){send("check-second");change("second-check");}
         }catch(err:Error){check(false,err.getStackTrace());finish();}
      }
      private function finish():void {phase="done";timer.stop();Log.d("COOP EFFECTS DONE "+(host?"host":"join")+" security checks="+checks+" failed="+failures);}
   }
}

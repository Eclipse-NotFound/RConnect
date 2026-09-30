package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.utils.Timer;
   import flash.utils.Dictionary;
   import flash.utils.getTimer;
   import flash.utils.getQualifiedClassName;
   import rconnect.core.Log;
   import fe.unit.Unit;
   import fe.unit.CombatStateProbe;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;
   public class GameplayNetworkTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var mod:RConnectMod,host:Boolean,timer:Timer=new Timer(100),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=0,baseX:Number,baseY:Number,baseItems:int=0,xpStart:Number;
      private var enemy:Object,box:Object,points:Array=[],cp:Object,index:int=0,shots:Boolean=false,targeted:Boolean=false;
      private var hpStart:Number=0,beforeCP:Object,oldGun:Object,oldChildren:Object,fireFrames:int=0;
      private var mercTrials:int=0;
      public function GameplayNetworkTestDoc() {
         var app:String=NativeApplication.nativeApplication.applicationID;
         if(app.indexOf("pfe-rconnect-coop-")!=0 && app.indexOf("pfe-modsettings-rconnect-coop-")!=0)return;
         host=app.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();finish();
         });
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,s:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"gameplay-network "+s);}
      private function setPhase(s:String):void {phase=s;at=getTimer();Log.d("GAMEPLAY TCP "+(host?"host ":"join ")+s);}
      private function send(s:String,p:Object=null):void {p=p||{};p.type="gameplay-network-test";p.stage=s;if(host)mod.session.server.broadcast(p);else mod.session.link.send(p);}
      private function watch(l:TcpLink):void {if(l!=null && !links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);}}
      private function finish():void {if(phase=="done")return;setPhase("done");timer.stop();Log.d("COOP EFFECTS DONE gameplay-network "+(host?"host":"join"));}
      private function items():int {var o:Object=mod.game.world.invent.items.kofe;return o==null?0:int(o.kol);}
      private function klass(s:String):Class {return mod.main.loaderInfo.applicationDomain.getDefinition(s) as Class;}
      private function drops():Array {
         var result:Array=[],o:Object=mod.game.loc.firstObj;
         while(o!=null){if(getQualifiedClassName(o).indexOf("Loot")>=0 && o.item.id=="kofe")result.push(o);o=o.nobj;}
         return result;
      }
      private function removeEnemy():void {if(enemy!=null){mod.game.loc.remObj(enemy);var i:int=mod.game.loc.units.indexOf(enemy);if(i>=0)mod.game.loc.units.splice(i,1);enemy=null;}}
      private function combat():void {
         removeEnemy();shots=targeted=false;
         var c:Class=klass(index==0?"fe.unit.UnitTurret":index==1?"fe.unit.UnitMerc":"fe.unit.Mine");
         enemy=index==2?new c("mine",1,null,null):new c(index==0?"land":"1",100,<unit tr="1" vis="left"/>,null);
         enemy.putLoc(mod.game.loc,baseX+(index==2?0:180),baseY);mod.game.loc.addObj(enemy);mod.game.loc.units.push(enemy);
         enemy.storona=-1;enemy.oduplenie=0;enemy.stay=true;enemy.xp=0;
         // Raider control restores its private turn direction each step. Use
         // the native command so this fixture really starts facing the joiner.
         if(index==1)enemy.command("turn","-1");
         if(index<2){enemy.eyeX=enemy.X;enemy.eyeY=baseY-30;enemy.vAngle=Math.PI;}
         send("combat",{index:index});setPhase("combat");
      }
      private function createBox(qty:int):void {
         var c:Class=klass("fe.loc.Box"),xml:XML=<obj cont="custom"><item id="kofe" kol="1"/></obj>;xml.item.@kol=qty;
         box=new c(mod.game.loc,"case",baseX+100+index*45,baseY,xml,null);mod.game.loc.addObj(box);mod.game.loc.objs.push(box);
      }
      private function setupPoints():void {
         var c:Class=klass("fe.loc.Bonus");points=[];
         for(var i:int=0;i<3;i++) {
            var o:Object=null;for each(var existing:Object in mod.game.loc.bonuses)if(existing.id=="xp"&&existing.X==baseX+440+i*60)o=existing;
            if(o==null){o=new c(mod.game.loc,"xp",baseX+440+i*60,baseY,null,null);mod.game.loc.bonuses.push(o);mod.game.loc.addObj(o);}
         }
         mod.game.loc.unXp=10;mod.game.loc.maxXp=mod.game.loc.kolXp=3;mod.game.loc.summXp=0;
         mod.session.progress.prepare();
         for each(o in mod.game.loc.bonuses)if(o.id=="xp" && o.X>=baseX+440 && o.X<=baseX+560)points.push(o);
         points.sortOn("X",Array.NUMERIC);xpStart=mod.game.world.pers.xpCur;
         c=klass("fe.loc.CheckPoint");for each(existing in mod.game.loc.acts)if(existing.id=="checkpoint"&&existing.X==baseX+850)cp=existing;
         if(cp==null){cp=new c(mod.game.loc,"checkpoint",baseX+850,baseY,null,null);mod.game.loc.acts.push(cp);mod.game.loc.addObj(cp);}
         mod.session.progress.prepare();beforeCP=mod.game.world.pers.currentCP;
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;if(p.type!="gameplay-network-test")return;
         try {
            if(p.stage=="done"){finish();return;}
            if(host) {
               if(p.stage=="ready"){baseX=p.x;baseY=p.y;mod.game.gg.setPos(baseX+650,baseY);combat();}
               else if(p.stage=="combat-result") {
                  check(p.damage>0,"native "+["turret","griffon","mine"][index]+" damages joiner hpLoss="+p.damage);
                  if(index<2){check(shots,"native enemy fires without forced attack "+index);check(targeted,"native enemy selects joining player "+index);}
                  if(index==1 && ++mercTrials<3){combat();return;}
                  index++;if(index<3)combat();else {removeEnemy();index=0;createBox(2);send("open-box",{x:box.X});setPhase("wait-drops");}
               } else if(p.stage=="collected") {
                  check(p.gain==2+index,"join inventory receives actual container contents "+index+" gain="+p.gain);
                  check(drops().length==0,"owner removes the collected drop "+index);
                  check(items()==baseItems,"join pickup leaves host inventory unchanged");
                  index++;if(index==1){createBox(3);box.inter.actOsn();send("host-opened");setPhase("wait-drops");}
                  else {createBox(4);box.inter.actOsn();send("race-wait");setPhase("race-wait");}
               } else if(p.stage=="race-ready") {
                  send("race");for each(var lo:Object in drops())lo.take(true);setPhase("race-result");
               } else if(p.stage=="race-result") {
                  check(items()-baseItems+int(p.gain)==4,"simultaneous pickup grants exactly one copy host="+(items()-baseItems)+" join="+p.gain);
                  setupPoints();send("points",{x:baseX,y:baseY});setPhase("points-ready");
               } else if(p.stage=="points-ready") {points[0].take();send("xp-one");setPhase("xp-one");}
               else if(p.stage=="xp-two") {setPhase("xp-two");}
               else if(p.stage=="xp-last") {
                  check(mod.game.world.pers.xpCur-xpStart==20 && points[1].sost==2,"join XP point rewards and disappears on host");
                  points[2].take();send("xp-last");setPhase("xp-last");
               }
               else if(p.stage=="checkpoint") {
                  check(mod.game.world.pers.xpCur-xpStart==50,"last XP point shares native completion bonus once total="+(mod.game.world.pers.xpCur-xpStart));
                  points[2].take();check(mod.game.world.pers.xpCur-xpStart==50,"repeated XP touch gives no extra reward");
                  setPhase("checkpoint");
               }
               else if(p.stage=="finish") {send("done");finish();}
            } else {
               if(p.stage=="combat") {index=p.index;mod.game.gg.hp=mod.game.gg.maxhp=5000;mod.game.gg.pers.begHP=5000;mod.game.gg.pers.inMaxHP=100000;mod.game.gg.pers.healAll();mod.game.gg.healhp=0;hpStart=mod.game.gg.hp;setPhase("combat");}
               else if(p.stage=="open-box"){baseX=mod.game.gg.X;baseY=mod.game.gg.Y;index=0;baseItems=items();setPhase("open-box");}
               else if(p.stage=="host-opened"){index=1;baseItems=items();setPhase("collect");}
               else if(p.stage=="race-wait"){baseItems=items();setPhase("race-wait");}
               else if(p.stage=="race"){for each(lo in drops())lo.take(true);setPhase("race");}
               else if(p.stage=="points"){baseX=p.x;baseY=p.y;setupPoints();send("points-ready");setPhase("points");}
               else if(p.stage=="xp-one")setPhase("xp-one");
               else if(p.stage=="xp-last"){points[2].take();setPhase("xp-last");}
            }
         }catch(err:Error){check(false,err.getStackTrace());send("done");finish();}
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null || mod.game.gg==null)return;
         // Protect the fixture while the second isolated instance starts.
         // Dying during this wait leaves native resurrection state in combat.
         if(phase=="boot"){mod.game.gg.invulner=true;mod.game.gg.disabled=true;}
         if(!mod.session.rooms.ready || mod.session.rooms.busy || mod.game.isTransitioning())return;
         if(host){for each(var l:TcpLink in mod.session.server.clients)watch(l);}else watch(mod.session.link);
         if(timer.currentCount<30)return;
         try {
            var g:Object=mod.game.gg,w:Object=mod.game.world;g.disabled=true;g.dx=g.dy=0;
            if(phase=="boot") {
               w.testDam=true;w.enemyAct=3;g.invulner=host;g.demask=0;g.pers.begHP=5000;g.hp=g.maxhp=5000;g.healhp=0;baseItems=items();
               if(!host)send("ready",{x:g.X,y:g.Y});setPhase("wait");
            }
            if(phase=="combat") {
               if(host && enemy!=null && index<2) {
                  if(enemy.currentWeapon!=null && enemy.currentWeapon.b!=null)shots=true;
                  if(index==1 && timer.currentCount%20==0) {
                     var ghost:Object=mod.game.getRemoteGhost(1);
                     Log.d("COOP PROBE merc "+JSON.stringify({x:enemy.X,y:enemy.Y,facing:enemy.storona,ai:CombatStateProbe.state(enemy as Unit),disabled:enemy.disabled,
                        prior:enemy.priorUnit==null?null:enemy.priorUnit.id,cel:enemy.celUnit==null?null:enemy.celUnit.id,look:ghost==null?-1:enemy.look(ghost,enemy.overLook),
                        gx:ghost==null?0:ghost.X,gy:ghost==null?0:ghost.Y,visibility:ghost==null?0:ghost.visibility,vision:enemy.vision,
                        weapon:enemy.currentWeapon==null?null:enemy.currentWeapon.id}));
                  }
                  if(enemy.celUnit!=null && String(enemy.celUnit.id).indexOf("rconnect_ghost")>=0)targeted=true;
               }
               if(!host && getTimer()-at>12000){send("combat-result",{damage:hpStart-g.hp});setPhase("wait");}
            }
            if(!host && phase=="open-box" && getTimer()-at>1000) {
               for each(var o:Object in mod.game.loc.objs)if(o.id=="case" && Math.abs(o.X-(baseX+100))<2){o.inter.actOsn();setPhase("collect");break;}
            }
            if(host && phase=="wait-drops" && drops().length>0){check(true,"container produces visible host loot "+index);setPhase("collect-wait");}
            if(!host && phase=="collect") {
               for each(var lo:Object in drops())lo.toTake();
               if(items()-baseItems==2+index){send("collected",{gain:items()-baseItems});setPhase("wait");}
            }
            if(!host && phase=="race-wait" && drops().length>0){send("race-ready");setPhase("wait");}
            if(!host && phase=="race" && getTimer()-at>1600){send("race-result",{gain:items()-baseItems});setPhase("wait");}
            if(!host && phase=="xp-one" && getTimer()-at>1000) {
               check(w.pers.xpCur-xpStart==10 && points[0].sost==2,"host XP point rewards and disappears on join");
               points[1].take();send("xp-two");setPhase("xp-two");
            }
            if(!host && phase=="xp-two" && getTimer()-at>1000) {
               check(w.pers.xpCur-xpStart==20 && points[1].sost==2,"join XP point rewards and disappears on "+(host?"host":"join"));
               if(!host)send("xp-last");setPhase("wait-last");
            }
            if(!host && phase=="xp-last" && getTimer()-at>1600) {
               check(w.pers.xpCur-xpStart==50,"last XP point shares native completion bonus once total="+(w.pers.xpCur-xpStart));
               points[2].take();check(w.pers.xpCur-xpStart==50,"repeated XP touch gives no extra reward");
               if(!host){cp.activate(false);send("checkpoint");setPhase("checkpoint-local");}else setPhase("wait-checkpoint");
            }
            if(host && phase=="checkpoint" && getTimer()-at>1500) {
               check(cp.active==1 && cp.inter.active,"join checkpoint activation unlocks host point");
               check(w.pers.currentCP===beforeCP,"remote checkpoint leaves own save selection unchanged");
               send("done");finish();
            }
            if(phase!="done" && getTimer()-at>24000){check(false,"timeout "+phase+" drops="+drops().length+" items="+items());send("done");finish();}
         }catch(err:Error){check(false,err.getStackTrace());send("done");finish();}
      }
   }
}

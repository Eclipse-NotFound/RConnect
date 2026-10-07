package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.KeyboardEvent;
   import flash.events.MouseEvent;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import flash.utils.getQualifiedClassName;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;
   import fe.unit.TelekinesisProbe;

   /** Real Ctr keyboard events -> native UnitPlayer.step/control/actions -> TCP.
    * Only caster location is pinned. Once grabbed, fixtures use native physics.
    * Motion is measured at the final RENDER, once per actual game frame. */
   public class FastHeldTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private static const BOOT_TIMEOUT:int=240000;
      private static const CASES:Array=["box-host","box-join","loot-host","loot-join"];
      private var mod:RConnectMod,host:Boolean,links:Dictionary=new Dictionary(),timer:Timer=new Timer(100);
      private var phase:String="boot",at:int=getTimer(),readyAt:int=0,round:int=0;
      private var nativeSince:int=0,savedProfile:Boolean=false;
      private var loadIssued:Boolean=false,loadCaster:Object,lastConnect:int=0;
      private var bootstrapSince:int=0;
      private var bootLogAt:int=0;
      private var baseX:Number,baseY:Number,box:Object,loot:Object,merc:Object,target:Object,alicorn:Object;
      private var arenaObjects:Array=[];
      private var boxKey:String="",nativeLimit:Number=0,releaseWireAt:int=-1;
      private var nativeReleaseAt:int=0,nativeReceiptAt:int=0,releaseReceiptAt:int=0;
      private var aiSamples:int=0,aiTicks:int=0,aiReclaims:int=0,lastAiClock:int=0;
      private var localDone:Boolean=false,peerDone:Boolean=false,inputAt:int=0,releaseAt:int=0;
      private var keyCode:int=0,keyUntil:int=0,frame:int=0,lastRender:int=-1;
      private var frames:int=0,stalls:int=0,maxJump:Number=0,lastX:Number=NaN,lastY:Number=NaN;
      private var minX:Number,maxX:Number,minY:Number,startY:Number,dropY:Number,held:int=0,throws:int=0;
      private var wire:Array=[],trace:Array=[],capturedStart:Boolean=false;
      private var reference:Array=[],renderTrace:Array=[],sourceOffset:Number=Infinity;
      private var mercId:String="rconnect_tele_merc_4";
      private var lifecycle:MovableGripLifecycle;
      private var beforeNative:Object,heldOnce:Boolean=false,earlyCleared:Boolean=false;

      public function FastHeldTestDoc() {
         var app:String=NativeApplication.nativeApplication.applicationID;
         if(app.indexOf("rconnect-coop-")<0)return;
         host=app.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();finish();
         });
         RemoteMotionPauseRegression.run(check);
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,label:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"tele-motion "+label+" case="+CASES[round]);}
      private function send(stage:String,p:Object=null):void {
         p=p||{};p.type="tele-motion-test";p.stage=stage;
         if(host){if(mod.session.server!=null)mod.session.server.broadcast(p);}
         else if(mod.session.link!=null && mod.session.link.isOpen)mod.session.link.send(p);
      }
      private function watch(l:TcpLink):void {if(l!=null && !links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);}}
      private function klass(name:String):Class {return mod.main.loaderInfo.applicationDomain.getDefinition(name) as Class;}
      private function nativeReady():Boolean {
         var b:Object=mod.game,g:Object=b.gg,w:Object=b.world;
         return g!=null && g.ggControl && !g.disabled && g.work!="res" && Number(g.t_work)<=0
            && !w.onPause && (!w.vblack.visible || w.vblack.alpha<=0);
      }
      private function arena():Object {
         var l:Object=mod.game.loc;
         // Keep native map tiles and native physics. Clear only the fixture's
         // existing scene objects in both isolated copies, before injecting
         // targets: a shelf/container must not invalidate the floor assertion.
         var best:Object=null;
         for(var y:int=160;y<Number(l.limY)-40;y+=40)for(var x:int=80;x<Number(l.limX)-300;x+=40) {
            var clear:Boolean=true;
            for(var ix:int=-20;ix<=280 && clear;ix+=20) {
               if(l.getAbsTile(x+ix,y+1).phis!=1){clear=false;break;}
               for(var iy:int=20;iy<=160;iy+=20)if(l.getAbsTile(x+ix,y-iy).phis!=0){clear=false;break;}
            }
            if(clear) {
               var remove:Array=[];
               for each(var obstacle:Object in l.objs)
                  if(obstacle.X2>x-40 && obstacle.X1<x+300 && obstacle.Y2>y-180 && obstacle.Y1<y+40)
                     remove.push({id:GameBridge.probe(obstacle,"id"),bx:GameBridge.probe(obstacle,"begX"),by:GameBridge.probe(obstacle,"begY")});
               if(best==null || remove.length<best.remove.length)best={x:x,y:y,remove:remove};
               if(remove.length==0)return best;
            }
         }
         if(best!=null)return best;
         throw new Error("No native clear/floored telekinesis arena in saved room");
      }
      private function clearArena():void {
         var l:Object=mod.game.loc,count:int=0;
         for each(var s:Object in arenaObjects)for each(var o:Object in l.objs.concat()) {
            if(GameBridge.probe(o,"id")!=s.id || GameBridge.probe(o,"begX")==null || Math.abs(Number(GameBridge.probe(o,"begX"))-Number(s.bx))>1 || Math.abs(Number(GameBridge.probe(o,"begY"))-Number(s.by))>1)continue;
            l.remObj(o);l.objs.splice(l.objs.indexOf(o),1);++count;
            var u:Object=GameBridge.probe(o,"un"),i:int=l.units.indexOf(u);
            if(i>=0)l.units.splice(i,1);
         }
         Log.d("TELE MOTION ARENA "+JSON.stringify({role:host?"host":"join",x:baseX,y:baseY,removed:count,tiles:"native unchanged"}));
      }
      private function fixture(kind:String):Object {
         if(kind=="box" && box!=null && GameBridge.probe(box,"loc")===mod.game.loc)return box;
         if(kind=="loot" && loot!=null && GameBridge.probe(loot,"in_chain")==true)return loot;
         var best:Object=null,distance:Number=6400,d:Number;
         if(kind=="box") {
            for each(var b:Object in mod.game.loc.objs)if(b.id=="case" && Math.abs(Number(b.begX)-baseX-130)<2) {
               d=Math.pow(b.X-baseX-130,2)+Math.pow(b.Y-baseY,2);
               if(d<distance){best=b;distance=d;}
            }
            if(best!=null)box=best;return best;
         }
         for(var o:Object=mod.game.loc.firstObj;o!=null;o=o.nobj) {
            if(kind=="loot" && GameBridge.probe(GameBridge.probe(o,"item"),"id")=="kofe" && GameBridge.probe(GameBridge.probe(o,"item"),"kol")==27) {
               d=Math.pow(o.X-baseX-180,2)+Math.pow(o.Y-baseY,2);
               if(d<distance){best=o;distance=d;}
            }
            if(kind=="merc" && GameBridge.probe(o,"id")==mercId)return o;
         }
         if(best!=null)loot=best;
         return best;
      }
      private function setup():void {
         clearArena();
         savedProfile=Math.abs(Number(mod.config.getValue("autoLoadSave")))==9;
         if(host) {
            var c:Class=klass("fe.loc.Box");box=new c(mod.game.loc,"case",baseX+130,baseY-20,<obj/>,null);
            mod.game.loc.addObj(box);mod.game.loc.objs.push(box);
            c=klass("fe.serv.Item");var item:Object=new c(null,"kofe",27);
            c=klass("fe.loc.Loot");loot=new c(mod.game.loc,item,baseX+180,baseY-20,false,false,false);loot.auto=false;
            replaceMerc(4);
            for each(var os:Object in mod.game.readObjsSnapshot())
               if(os.id=="case" && os.x==baseX+130 && os.y==baseY-20)boxKey=String(os.k);
            for each(var us:Object in mod.game.readUnitsSnapshot())if(us.id==merc.id)
               check(Number(JSON.parse(JSON.stringify(us)).grip.levit_max)==nativeLimit,"wire preserves the native numerical resistance limit");
            c=klass("fe.unit.UnitAlicorn");alicorn=new c("1",10,<unit tr="1"/>,null);
            alicorn.id="rconnect_tele_alicorn";alicorn.putLoc(mod.game.loc,baseX-50,baseY);
            mod.game.loc.addObj(alicorn);mod.game.loc.units.push(alicorn);
            alicorn.disabled=true;alicorn.invulner=true;alicorn.xp=0;
         }
         mod.stage.addEventListener(Event.ENTER_FRAME,before,false,100000);
         mod.stage.addEventListener(Event.ENTER_FRAME,after,false,-6000);
         mod.stage.addEventListener(Event.RENDER,render,false,-30000);
      }
      private function replaceMerc(n:int):void {
         // Each native enemy trial is independent. Native exhaustion disables
         // eligibility until recovery; resetting its counter to zero would
         // prevent that recovery and invalidate the following Q/E trial.
         if(merc!=null) {
            mod.game.loc.remObj(merc);
            var i:int=mod.game.loc.units.indexOf(merc);if(i>=0)mod.game.loc.units.splice(i,1);
         }
         mercId="rconnect_tele_merc_"+n;
         var c:Class=klass("fe.unit.UnitMerc");merc=new c("1",10,<unit weap="lmg"/>,null);
         merc.id=mercId;merc.putLoc(mod.game.loc,baseX+230,baseY);
         mod.game.loc.addObj(merc);mod.game.loc.units.push(merc);merc.invulner=true;merc.xp=0;
         nativeLimit=Number(merc.levit_max);
      }
      private function holder():Boolean {return String(CASES[round]).indexOf("-host")>=0 ? host : !host;}
      private function kind():String {return String(CASES[round]).split("-")[0];}
      private function throwing():Boolean {return CASES[round]=="merc-throw";}
      private function nativeFloor():Boolean {
         if(target==null || target.stay!==true || Math.abs(Number(target.dy))>.001 || Math.abs(baseY-Number(target.Y))>=8)return false;
         var tile:Object=mod.game.loc.getAbsTile(Number(target.X),baseY+1);
         // Boxes stop at the solid tile's top; native Loot stops one pixel above.
         return tile.phis==1 && Math.abs(Number(tile.phY1)-baseY)<.001
            && Math.abs(Number(target.Y)-Number(tile.phY1))<=(kind()=="loot"?1.01:.01);
      }
      private function start(n:int):void {
         releaseKey();round=n;phase="settle";at=getTimer();localDone=peerDone=false;
         target=fixture(kind());if(target==null)throw new Error("missing "+kind());
         var g:Object=mod.game.gg;if(g.teleObj!=null)g.dropTeleObj();
         savedProfile=Math.abs(Number(mod.config.getValue("autoLoadSave")))==9;
         if(!savedProfile) {
            g.mana=g.maxmana=10000;g.pers.maxTeleMassa=1000;g.pers.teleDist=1000000;g.pers.telemaster=1;
            g.pers.unitLevitMult=100;g.pers.teleMult=1;g.pers.allDManaMult=1;g.pers.teleMana=0;g.pers.telePorog=0;
            g.pers.throwForce=12;g.pers.throwDmagic=2;g.pers.throwDmanaMult=0;g.pers.spellsPoss=1;
         }
         if(host) {
            alicorn.disabled=true;
            alicorn.dropTeleObj();
            target.levit=0;target.fracLevit=0;target.dx=target.dy=0;target.stay=false;
            if(kind()=="merc"){target.setPos(baseX+130,baseY);target.levit_r=0;target.t_throw=0;}
            else {
               target.X=baseX+130;target.Y=baseY-20;
               target.X1=target.X-target.scX/2;target.X2=target.X+target.scX/2;
               target.Y1=target.Y-target.scY;target.Y2=target.Y;
               if(kind()=="box")target.runVis();
            }
            if(CASES[round]=="box-join-alicorn") {
               TelekinesisProbe.grabEnemy(alicorn,target);
               check(target.levit==2 && TelekinesisProbe.enemyHeld(alicorn)===target,"native alicorn owns the box before remote Q");
            }
         }
         frames=stalls=held=throws=0;maxJump=0;lastX=lastY=NaN;wire=[];trace=[];
         reference=[];renderTrace=[];sourceOffset=Infinity;
         minX=Infinity;maxX=-Infinity;minY=Infinity;startY=Number(target.Y);capturedStart=false;
         inputAt=releaseAt=0;releaseWireAt=-1;nativeReleaseAt=nativeReceiptAt=releaseReceiptAt=0;
         aiSamples=aiTicks=aiReclaims=0;lastAiClock=0;
         beforeNative=null;heldOnce=earlyCleared=false;
         if(kind()=="merc")check(Number(target.levit_max)==nativeLimit,"native resistance limit is retained on the real enemy");
         Log.d("TELE MOTION START "+JSON.stringify({role:host?"host":"join",round:round,kind:kind(),cls:getQualifiedClassName(target),mass:target.massa,eligible:target.levitPoss,x:target.X,y:target.Y,
            saved:savedProfile,mana:g.mana,maxmana:g.maxmana,maxMass:g.pers.maxTeleMassa,range:g.pers.teleDist,
            resistance:g.pers.unitLevitMult,limit:Number(GameBridge.probe(target,"levit_max")),limitType:getQualifiedClassName(GameBridge.probe(target,"levit_max")),master:g.pers.telemaster,
            spells:g.pers.spellsPoss,throwForce:g.pers.throwForce,speed:g.teleSpeed,accel:g.teleAccel}));
      }
      private function press(code:int):void {
         releaseKey();keyCode=code;keyUntil=getTimer()+130;
         mod.stage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_DOWN,true,false,0,code));
         Log.d("TELE MOTION KEY "+JSON.stringify({round:round,code:code,active:mod.game.world.ctr.active,tele:mod.game.world.ctr.keyTele,action:mod.game.world.ctr.keyAction,rat:mod.game.gg.rat,spell:GameBridge.probe(mod.game.gg,"spellObj")==null?null:getQualifiedClassName(mod.game.gg.spellObj)}));
      }
      private function releaseKey():void {
         if(keyCode>0 && mod!=null)mod.stage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_UP,true,false,0,keyCode));
         keyCode=0;
      }
      private function before(e:Event):void {
         if(phase=="done" || mod.game.gg==null)return;++frame;
         var b:Object=mod.game,g:Object=b.gg;g.disabled=false;g.invulner=true;g.hp=g.maxhp;
         // UnitPlayer.damage accumulates knockdown before Unit's invulnerability
         // guard. Skip incidental bullets at the native udarBullet boundary;
         // keep all Q/E physics, enemy resistance and movement assertions intact.
         g.transp=true;
         b.world.ctr.active=true; // hidden test windows still exercise the real Ctr key handler
         g.dx=g.dy=0;g.isTake=0;g.setPos(baseX+(host?0:50),baseY);g.setVisPos();
         if(!savedProfile){b.loc.base=false;b.loc.portOn=true;}g.storona=1;
         // Reset the enemy only before Q. Prior rounds must not leave this
         // flyer already at the requested height or outside native grab range.
         if(host && phase=="settle" && kind()=="merc") {
            target.setPos(baseX+130,baseY);target.dx=target.dy=0;target.stay=false;
         }
         if(target!=null) {
            var age:int=inputAt==0?0:getTimer()-inputAt;
            var x:Number=target.X,y:Number=target.Y-target.scY/2;
            if(inputAt>0 && releaseAt==0 && g.teleObj===target){x=baseX+155+65*Math.sin(Math.min(2200,Math.max(0,age-600))*Math.PI*2/1100);y=baseY-120;}
            if(savedProfile && g.teleObj===target) {
               var ax:Number=x-g.X,ay:Number=y-(g.Y-g.scY/2),r:Number=Number(g.pers.teleDist)*.85;
               if(ax*ax+ay*ay>r){var factor:Number=Math.sqrt(r/(ax*ax+ay*ay));x=g.X+ax*factor;y=g.Y-g.scY/2+ay*factor;}
            }
            b.world.celX=x;b.world.celY=y;g.celX=x;g.celY=y;
            // Camera.step converts its screen cursor into world coordinates
            // before Location.step. Feed that native input, not a value it
            // overwrites before the player handles Q/E.
            var camera:Object=b.world.cam;
            camera.celX=int(x*camera.scaleV+camera.vx);camera.celY=int(y*camera.scaleV+camera.vy);
            if(g.teleObj==null)b.loc.celObj=null;
         }
         if(phase=="holding" && holder())beforeNative=nativeState();
      }
      private function nativeState():Object {
         var b:Object=mod.game,g:Object=b.gg,c:Object=b.loc.celObj;
         return {t:getTimer()-inputAt,held:g.teleObj===target,levit:target.levit,eligible:target.levitPoss,
            mana:g.mana,range:g.pers.teleDist,celDist:b.loc.celDist,key:b.world.ctr.keyTele,active:b.world.ctr.active,
            work:g.work,workTicks:g.t_work,sost:g.sost,pinok:g.pinok,ggControl:g.ggControl,
            invulner:g.invulner,transp:g.transp,
            allStat:b.world.allStat,pause:b.world.onPause,room:b.roomKey(),
            selected:c==null?null:{cls:getQualifiedClassName(c),id:GameBridge.probe(c,"id"),x:c.X,y:c.Y},
            x:target.X,y:target.Y,dx:target.dx,dy:target.dy,cx:g.celX,cy:g.celY};
      }
      private function after(e:Event):void {
         if(phase=="done" || target==null)return;
         var g:Object=mod.game.gg,now:int=getTimer();
         if(phase=="holding" && holder()) {
            if(g.teleObj===target)heldOnce=true;
            else if(heldOnce && !earlyCleared && releaseAt==0) {
               earlyCleared=true;
               Log.d("TELE MOTION EARLY NATIVE CLEAR "+JSON.stringify({round:round,before:beforeNative,after:nativeState()}));
            }
         }
         // A slow frame must still run the native control handler once before
         // KEY_UP. Releasing in `before` could cancel a Q/E pulse entirely.
         if(keyCode>0 && now>keyUntil)releaseKey();
         if(phase=="settle" && now-at>1600) {
            phase="holding";at=now;inputAt=now;startY=target.Y;
            if(holder())press(81); // native Q -> Ctr -> control -> actTele
         }
         if(phase=="holding" && !capturedStart && now-at>450) {
            capturedStart=true;
            if(holder())check(g.teleObj===target,"normal Q input selects/grabs the real "+kind());
            if(holder() && CASES[round]=="box-join-alicorn" && g.teleObj===target)send("native-grabbed",{round:round});
            Log.d("TELE MOTION INPUT "+JSON.stringify({role:host?"host":"join",round:round,
               key:mod.game.world.ctr.keyTele,control:g.ggControl,mana:g.mana,
               x:mod.game.world.celX,y:mod.game.world.celY,targetX:target.X,targetY:target.Y,
               held:g.teleObj==null?null:{cls:getQualifiedClassName(g.teleObj),id:GameBridge.probe(g.teleObj,"id"),x:g.teleObj.X,y:g.teleObj.Y},
               selected:GameBridge.probe(mod.game.loc.celObj,"id")}));
         }
         if(host && CASES[round]=="box-join-alicorn" && phase=="holding" && !alicorn.disabled) {
            ++aiSamples;var aiClock:int=TelekinesisProbe.enemyCooldown(alicorn);
            if(aiClock!=lastAiClock)++aiTicks;lastAiClock=aiClock;
            if(TelekinesisProbe.enemyHeld(alicorn)===target)++aiReclaims;
         }
         // Wait for native velocity to settle in the air before releasing.
         // Movement-only reports must also relay a stationary release edge.
         if(phase=="holding" && now-at>(throwing()?1000:5100)) {
            releaseAt=now;dropY=target.Y;
            if(throwing())check(holder()?g.teleObj===target:target.levit>0,"throw is attempted during a real active native grab");
            else {
               check((!holder() || held>3) && minY<startY-30,"real lift observed samples="+held+" rise="+(startY-minY));
               check(frames>12 && maxX-minX>40,"source/display actually moved frames="+frames+" span="+(maxX-minX));
               if(!holder())measureLag();
               if(!holder())check(frames>12 && stalls/Math.max(1,frames)<.5 && maxJump<25,
                  "remote display advances between packets stalls="+stalls+"/"+frames+" maxJump="+maxJump);
            }
            if(holder() && kind()=="box")check(Math.abs(target.dx)+Math.abs(target.dy)<.5,"box release is stationary before native gravity resumes");
            if(host && CASES[round]=="box-join-alicorn") {
               check(TelekinesisProbe.enemyHeld(alicorn)==null,"remote Q relinquishes only this box's native enemy caster");
               check(aiTicks>=5 && aiReclaims==0,"active native AI advances without reclaiming the box ticks="+aiTicks+" reclaims="+aiReclaims);
            }
            Log.d("TELE MOTION RELEASE "+JSON.stringify({role:host?"host":"join",round:round,holding:g.teleObj===target,
               levit:target.levit,resistance:GameBridge.probe(target,"levit_r"),dx:target.dx,dy:target.dy,at:now-inputAt}));
            // Natural resistance may already have released the enemy. Another
            // Q at that point is a fresh grab, not a release operation.
            if(holder() && g.teleObj===target)press(throwing()?69:81);
            phase="released";at=now;
         }
         if(phase=="released" && holder() && nativeReleaseAt==0 && g.teleObj!==target) {
            nativeReleaseAt=now;
            Log.d("TELE MOTION NATIVE RELEASE "+JSON.stringify({round:round,requestedDelay:now-releaseAt,x:target.X,y:target.Y,levit:target.levit}));
            send("native-release",{round:round});
         }
         // Native gravity advances in game frames. Keep the same floor/error
         // assertions while allowing a slow isolated window to finish landing.
         if(phase=="released" && now-at>2400 && (kind()=="merc" || nativeFloor() || now-at>8000)) {
            check(target.levit==0,"release reaches both simulations levit="+target.levit+" frac="+target.fracLevit);
            if(holder())check(g.teleObj==null,"normal release clears caster pointer");
            if(kind()!="merc") {
               check(target.Y>dropY+20,"air release resumes gravity fall="+(target.Y-dropY)+" stay="+target.stay);
               check(nativeFloor(),"release lands on supported native floor gap="+(baseY-target.Y)+" stay="+target.stay+" dy="+target.dy);
            }
            if(kind()=="box" && !holder())check(releaseWireAt>=0 && releaseWireAt<350,"stationary release reaches peer after actual native release promptly ms="+releaseWireAt);
            if(throwing())check(throws>0,"normal E input throws the griffon count="+throws);
            Log.d("TELE MOTION RESULT "+JSON.stringify({role:host?"host":"join",round:round,frames:frames,stalls:stalls,maxJump:maxJump,held:held,throws:throws,fall:target.Y-dropY,x:target.X,y:target.Y,baseY:baseY,dropY:dropY,stay:target.stay,dy:target.dy,floorSupported:kind()=="merc"?null:nativeFloor(),releaseWireAt:releaseWireAt,nativeReceiptAt:nativeReceiptAt,releaseReceiptAt:releaseReceiptAt,releaseFramesMs:now-releaseAt,aiSamples:aiSamples,aiTicks:aiTicks,aiReclaims:aiReclaims,wire:wire,trace:trace}));
            phase="sampled";localDone=true;send("sampled",{round:round});if(host && peerDone)advance();
         }
         mod.stage.invalidate();
      }
      private function render(e:Event):void {
         if(target==null || lastRender==frame)return;lastRender=frame;
         if(Number(GameBridge.probe(target,"t_throw"))>0)++throws;
         if(phase!="holding" || getTimer()-inputAt<500 || getTimer()-inputAt>3100)return;
         if(target.levit>0)++held;minY=Math.min(minY,Number(target.Y));
         var v:Object=GameBridge.probe(target,"vis");if(v==null || v.parent==null)return;
         var x:Number=v.x,y:Number=v.y;
         if(holder())send("native-position",{round:round,sourceTime:getTimer(),x:x});
         else renderTrace.push({at:getTimer(),x:x});
         if(trace.length<160)trace.push({t:getTimer()-inputAt,x:x,y:y,levit:target.levit,local:mod.game.gg.teleObj===target,
            dx:target.dx,dy:target.dy,resistance:GameBridge.probe(target,"levit_r"),cx:mod.game.gg.celX,cy:mod.game.gg.celY});
         if(isFinite(lastX)) {var d:Number=Math.sqrt(Math.pow(x-lastX,2)+Math.pow(y-lastY,2));if(d<.01)++stalls;maxJump=Math.max(maxJump,d);}
         lastX=x;lastY=y;++frames;minX=Math.min(minX,x);maxX=Math.max(maxX,x);
      }
      private function measureLag():void {
         var best:Number=Infinity,bestLag:int=-1,bestN:int=0;
         for(var lag:int=0;lag<=700;lag+=10) {
            var sum:Number=0,n:int=0,index:int=0;
            for each(var shown:Object in renderTrace) {
               var stamp:Number=Number(shown.at)-sourceOffset-lag;
               if(reference.length<2 || stamp<reference[0].at+700 || stamp>reference[reference.length-1].at)continue;
               while(index+1<reference.length && reference[index+1].at<stamp)index++;
               if(index+1>=reference.length)continue;
               var a:Object=reference[index],b:Object=reference[index+1];
               var f:Number=(stamp-a.at)/(b.at-a.at),expected:Number=a.x+(b.x-a.x)*f;
               sum+=Math.pow(shown.x-expected,2);n++;
            }
            var error:Number=n>=12?Math.sqrt(sum/n):Infinity;
            if(error<best){best=error;bestLag=lag;bestN=n;}
         }
         Log.d("FAST HELD METRIC "+JSON.stringify({role:host?"host":"join",round:round,lagMs:bestLag,rmsPixels:best,samples:bestN,sourceOffset:sourceOffset,reference:reference,render:renderTrace}));
         check(bestN>=12 && bestLag>=0 && bestLag<=160,"fast native held item display delay <=160ms actual="+bestLag+" rms="+best+" n="+bestN);
      }
      private function advance():void {
         if(round+1<CASES.length){var n:int=round+1;
            if(String(CASES[n]).indexOf("merc-")==0) {
               if(n!=4)replaceMerc(n);
               start(n);phase="await-round";send("round",{round:n,mercId:mercId});
            } else {start(n);send("round",{round:n});}
         }
         else {send("done");finish();}
      }
      private function startLifecycle():void {
         releaseKey();phase="lifecycle";
         mod.stage.removeEventListener(Event.ENTER_FRAME,before);mod.stage.removeEventListener(Event.ENTER_FRAME,after);
         mod.stage.removeEventListener(Event.RENDER,render);
         if(host){merc.disabled=true;alicorn.disabled=true;}
         lifecycle=new MovableGripLifecycle(mod,host,baseX,baseY,finish);
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;
         if(p.type=="unit-grip" && p.op!="hold" && wire.length<8)wire.push({op:p.op,accept:p.accept,reason:p.reason,k:p.k});
         if(kind()=="box" && !holder() && phase=="released" && releaseReceiptAt==0) {
            var positions:Array=host?(p.moved as Array):(p.objs as Array);
            if(positions!=null)for each(var position:Object in positions)
               if(String(position.k)==boxKey && position.q===false) {
                  releaseReceiptAt=getTimer();
                  if(nativeReceiptAt>0)releaseWireAt=Math.max(0,releaseReceiptAt-nativeReceiptAt);
               }
         }
         if(p.type!="tele-motion-test")return;
         if(p.stage=="native-position" && int(p.round)==round && !holder()) {
            sourceOffset=Math.min(sourceOffset,getTimer()-Number(p.sourceTime));
            reference.push({at:Number(p.sourceTime),x:Number(p.x)});return;
         }
         try {
            if(host && phase=="boot" && p.stage=="ready" && nativeReady()) {
               var a:Object=arena();baseX=a.x;baseY=a.y;arenaObjects=a.remove;setup();phase="prepared";at=getTimer();send("setup",{x:baseX,y:baseY,remove:arenaObjects,boxKey:boxKey,limit:nativeLimit});
            } else if(!host && p.stage=="setup"){baseX=p.x;baseY=p.y;arenaObjects=p.remove;boxKey=p.boxKey;nativeLimit=Number(p.limit);setup();phase="find";at=getTimer();}
            else if(host && p.stage=="prepared"){start(0);send("round",{round:0});}
            else if(!host && p.stage=="round") {
               if(p.mercId!=null){round=int(p.round);mercId=String(p.mercId);phase="find-round";at=getTimer();}
               else start(int(p.round));
            }
            else if(host && p.stage=="round-ready" && int(p.round)==round && phase=="await-round") {phase="settle";at=getTimer();}
            else if(host && p.stage=="sampled" && p.round==round){peerDone=true;if(localDone)advance();}
            else if(p.stage=="native-release" && p.round==round) {
               nativeReceiptAt=getTimer();
               if(releaseReceiptAt>0)releaseWireAt=Math.max(0,releaseReceiptAt-nativeReceiptAt);
            }
            else if(host && p.stage=="native-grabbed" && p.round==round && CASES[round]=="box-join-alicorn") {
               check(TelekinesisProbe.enemyHeld(alicorn)==null,"remote Q clears the native caster pointer before AI resumes");
               lastAiClock=TelekinesisProbe.enemyCooldown(alicorn);alicorn.disabled=false;
            }
            else if(!host && p.stage=="lifecycle")startLifecycle();
            else if(p.stage=="done")finish();
         } catch(error:Error){check(false,error.getStackTrace());send("done");finish();}
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null || mod.game==null || mod.session==null)return;
         if(phase=="lifecycle")return;
         if(phase=="boot") {
            mod.game.refreshWorld();
            var bootWorld:Object=mod.game.world,bootPlayer:Object=mod.game.gg;
            if(bootPlayer!=null){bootPlayer.invulner=true;bootPlayer.hp=bootPlayer.maxhp;bootWorld.ctr.active=true;}
            if(bootWorld!=null && bootWorld.clickReq==1) {
               // Native loading/intro "click to continue", never a shot: Ctr's
               // handler consumes this click before setting keyAttack.
               mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN,true,false));
               mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP,true,false));
            }
            if(getTimer()-bootLogAt>2000) {
               bootLogAt=getTimer();
               Log.d("TELE MOTION BOOT "+JSON.stringify({role:host?"host":"join",elapsed:getTimer()-at,load:loadIssued,changed:bootPlayer!==loadCaster,
                  stats:GameBridge.probe(bootWorld,"allStat"),ng:GameBridge.probe(bootWorld,"ng_wait"),pause:GameBridge.probe(bootWorld,"onPause"),click:GameBridge.probe(bootWorld,"clickReq"),
                  menu:GameBridge.probe(GameBridge.probe(bootWorld,"mm"),"active"),control:GameBridge.probe(bootPlayer,"ggControl"),disabled:GameBridge.probe(bootPlayer,"disabled"),
                  work:GameBridge.probe(bootPlayer,"work"),workTicks:GameBridge.probe(bootPlayer,"t_work"),sost:GameBridge.probe(bootPlayer,"sost"),hp:GameBridge.probe(bootPlayer,"hp"),
                  transition:mod.game.isTransitioning(),room:mod.game.roomKey(),error:GameBridge.probe(GameBridge.probe(bootWorld,"verror"),"visible")}));
            }
         }
         if(phase=="boot" && getTimer()-at>BOOT_TIMEOUT){check(false,"timeout boot before normal control/read/connect");send("done");finish();return;}
         if(phase=="boot" && String(mod.config.getValue("autoLoadSave"))=="-9") {
            // Match manual play: native read/save transition finishes before
            // either endpoint advertises a world. Auto-connect during the
            // newGame bootstrap would seal the temporary beginning map.
            if(!loadIssued) {
               mod.game.refreshWorld();
               var w:Object=mod.game.world,g:Object=mod.game.gg;
               // Session's established autoGame menu driver waits for native
               // assets/menu readiness. Never call newGame immediately from a
               // freshly loaded external driver (Land XML may not be ready).
               if(g==null)return;
               // gg is allocated before newGame2 finishes preparing Land,
               // GUI and SATS. Do not queue comLoad during that bootstrap.
               if(w.loc==null || Number(w.ng_wait)>0 || w.allStat!=1 || w.sats==null || w.sats.gg!==g || mod.game.isTransitioning()) {bootstrapSince=0;return;}
               if(bootstrapSince==0)bootstrapSince=getTimer();
               if(getTimer()-bootstrapSince<1000)return;
               if(mod.game.loadSaveTest(9)){loadIssued=true;loadCaster=g;}
               return;
            }
            mod.game.refreshWorld();
            if(mod.game.gg==null || mod.game.gg===loadCaster || mod.game.isTransitioning() || !nativeReady()) {nativeSince=0;return;}
            if(nativeSince==0)nativeSince=getTimer();
            if(getTimer()-nativeSince<4000)return;
            if(mod.session.mode=="offline" && getTimer()-lastConnect>1000) {
               lastConnect=getTimer();
               Log.d("TELE MOTION REPLAY LOADED "+JSON.stringify({role:host?"host":"join",room:mod.game.roomKey(),mana:mod.game.gg.mana,mass:mod.game.gg.pers.maxTeleMassa}));
               if(host)mod.session.startHost();else mod.session.startJoin();
            }
         }
         if(host)for each(var peer:Object in mod.session.peers)watch(peer.link as TcpLink);else watch(mod.session.link);
         if(phase!="done" && getTimer()-at>(phase=="boot"?BOOT_TIMEOUT:22000)){check(false,"timeout "+phase);send("done");finish();return;}
         if(!mod.session.rooms.ready || mod.session.rooms.busy || mod.game.isTransitioning())return;
         if(phase=="boot") {
            if(nativeReady()){if(nativeSince==0)nativeSince=getTimer();}else nativeSince=0;
         }
         if(phase=="boot" && !host && nativeSince>0 && getTimer()-nativeSince>4000 && getTimer()-readyAt>500){readyAt=getTimer();send("ready");}
         if(phase=="find" && fixture("box")!=null && fixture("loot")!=null && fixture("merc")!=null){phase="prepared";send("prepared");}
         if(phase=="find-round" && fixture("merc")!=null){start(round);send("round-ready",{round:round});}
      }
      private function finish():void {
         if(phase=="done")return;releaseKey();phase="done";timer.stop();
         if(mod!=null){mod.stage.removeEventListener(Event.ENTER_FRAME,before);mod.stage.removeEventListener(Event.ENTER_FRAME,after);mod.stage.removeEventListener(Event.RENDER,render);}
         Log.d("COOP EFFECTS DONE tele-motion "+(host?"host":"join"));
      }
   }
}

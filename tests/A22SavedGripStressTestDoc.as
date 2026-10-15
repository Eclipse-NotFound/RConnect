package {
   import flash.desktop.NativeApplication;
   import flash.display.DisplayObject;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.MouseEvent;
   import flash.events.KeyboardEvent;
   import flash.ui.Keyboard;
   import flash.utils.getQualifiedClassName;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.geom.Point;
   import flash.geom.Rectangle;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;
   import rconnect.game.MirrorHitUnit;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;

   /** Natural cursor selection and native Q/E, copied saved-profile bootstrap.
    * No production changes, direct teleObj selection, injected kick or damage.
    * Player and target positions are set only once per round, before arm.
    * Invulnerability isolates incoming hits; damage/stun remains a separate case.
    * Native + TDFC callbacks are bracketed together, not individually. */
   public class A22SavedGripStressTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var CASES:Array=["join-lift-drag-60","join-near-resistance","join-natural-exhaustion"];
      private var loadIssued:Boolean=false,loadCaster:Object;
      private var bootstrapSince:int=0,nativeSince:int=0,lastConnect:int=0,travelIssued:Boolean=false;
      private var mod:RConnectMod,host:Boolean,timer:Timer=new Timer(100),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=getTimer(),readyAt:int=0,round:int=0,serial:int=0;
      private var bx:Number,by:Number,target:Object,raw:Object,pre:Object,actionBefore:Object;
      private var localReady:Boolean=false,peerReady:Boolean=false,localDone:Boolean=false,peerDone:Boolean=false;
      private var grabbed:Boolean=false,grabAttempted:Boolean=false,grabFrame:int=0,actionSent:Boolean=false;
      private var actionAt:int=0,postFrames:int=0,launch:Object,peerLaunch:Object;
      private var wire:Array=[],trace:Array=[],acks:Array=[],releaseBefore:Object,releaseCount:int=0;
      private var originX:Number=NaN,originY:Number=NaN,minHP:Number=NaN,maxTravel:Number=0,launchTravel:Number=0;
      private var installedHooks:Boolean=false;
      // Independent view evidence. Each process owns its getTimer clock;
      // only received unit.sampleTime is a timestamp on the authority clock.
      // Keep the old execution assertions separate from visual fidelity.
      private var viewEvents:Array=[],viewPackets:Array=[],viewFrames:Array=[],viewRenders:Array=[];
      private var authorityStart:Object,authorityEnd:Object,viewOrigin:Object;
      private var lastRenderFrame:int=-1,viewOverflow:Boolean=false,frameBeginAt:int=0;
      private static const VIEW_LIMIT:int=1024;
      private var armFrame:int=0,keyCode:int=0,keyFrame:int=0;
      private var threshold:Number=0,maxResistance:Number=0,maxLift:Number=0,holdLift:Number=0,aimDistance:Number=0,flightTravel:Number=0;
      private var lastAim:Object,localEnd:Object,peerEnd:Object,localEndAt:int=0;
      private var initialPlayer:Object,initialEnemy:Object,initialAttributes:Object;
      private var exhaustedSeen:Boolean=false,selectorFrames:int=0;
      // Independent oracle: raw accepted wire coordinates, never production's
      // latest-position helper or its interpolation buffer.
      private var latestWirePoint:Object,throwBasis:Object;
      private var changedDirectionCases:int=0;
      private var collisionMode:Boolean=false;
      private var collisionEvidence:Array=[];
      private var attachmentBefore:Object,attachmentSamples:int=0,attachmentChanged:int=0,attachmentContacts:int=0;


      public function A22SavedGripStressTestDoc(wallCollision:Boolean=false) {
         collisionMode=wallCollision;
         if(collisionMode)CASES=["host-wall","join-wall","host-low-near","join-low-near","host-low-far","join-low-far"];
         var app:String=NativeApplication.nativeApplication.applicationID;
         if(app.indexOf("rconnect-coop-")<0)return;
         host=app.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));
            e.preventDefault();finish();
         });
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,s:String):void {
         Log.d("COOP "+(ok?"PASS ":"FAIL ")+"a22-saved-grip-stress "+s+" case="+CASES[round]+" phase="+phase);
      }
      private function change(s:String):void {phase=s;at=getTimer();}
      private function owner():Boolean {return collisionMode && round%2==0?host:!host;}
      private function send(op:String,p:Object=null):void {
         p=p||{};p.type="a22-saved-grip-stress-test";p.op=op;p.round=round;
         if(host)mod.session.server.broadcast(p);else mod.session.link.send(p);
      }
      private function watch(link:TcpLink):void {
         if(link==null||links[link])return;links[link]=true;
         link.addEventListener(TcpLink.MESSAGE,wireBefore,false,100);
         link.addEventListener(TcpLink.MESSAGE,receive);
         link.addEventListener(TcpLink.MESSAGE,wireAfter,false,-100);
      }
      private function state(o:Object):Object {
         if(o==null)return null;
         // A natural cursor can select a sealed Box or interactable on its way
         // to the enemy. Missing Unit fields are diagnostic nulls, not #1069.
         return {x:GameBridge.probe(o,"X"),y:GameBridge.probe(o,"Y"),
            dx:GameBridge.probe(o,"dx"),dy:GameBridge.probe(o,"dy"),t:GameBridge.probe(o,"t_throw"),
            levit:GameBridge.probe(o,"levit"),stay:GameBridge.probe(o,"stay"),hp:GameBridge.probe(o,"hp"),
            sost:GameBridge.probe(o,"sost"),disabled:GameBridge.probe(o,"disabled"),mass:GameBridge.probe(o,"massa"),
            possible:GameBridge.probe(o,"levitPoss"),resistance:GameBridge.probe(o,"levit_r"),
            resistanceMax:GameBridge.probe(o,"levit_max"),className:getQualifiedClassName(o),
            body:o===target,proxy:o is MirrorHitUnit,stun:GameBridge.probe(o,"stun"),
            cursor:GameBridge.probe(o,"onCursor"),damWall:GameBridge.probe(o,"damWall"),
            damWallSpeed:GameBridge.probe(o,"damWallSpeed"),invulner:GameBridge.probe(o,"invulner"),
            slow:GameBridge.probe(o,"slow"),isPlav:GameBridge.probe(o,"isPlav")};
      }
      private function attributes():Object {
         var g:Object=mod.game.gg,p:Object=g.pers;
         return {level:p.level,mana:g.mana,maxmana:g.maxmana,massLimit:p.maxTeleMassa,range:p.teleDist,
            force:p.throwForce,cost:p.throwDmagic,manaMultiplier:p.allDManaMult,
            strainMultiplier:p.throwDmanaMult,holdCost:p.teleMult,resistanceMultiplier:p.unitLevitMult,
            speed:g.teleSpeed,accel:g.teleAccel,spells:p.spellsPoss,manaTrauma:p.manaSt,
            playerManaTrauma:GameBridge.probe(g,"manaSt"),master:p.telemaster,
            pinok:GameBridge.probe(g,"pinok"),stun:g.stun,invulner:g.invulner,
            weapon:g.currentWeapon==null?null:GameBridge.probe(g.currentWeapon,"id")};
      }
      private function wireBefore(e:NetMessageEvent):void {
         captureUnitPacket(e.data);
         if(e.data==null||e.data.type!="unit-grip")return;
         if(!host&&e.data.op=="ack") {
            acks.push(JSON.parse(JSON.stringify(e.data)));
            viewEvent("ack",JSON.parse(JSON.stringify(e.data)));
         }
         if(!host||target==null||e.data.op!="release"||String(e.data.k)!=mod.game.unitKey(target))return;
         releaseBefore=state(target);
      }
      private function wireAfter(e:NetMessageEvent):void {
         if(!host||releaseBefore==null||e.data.type!="unit-grip"||e.data.op!="release")return;
         var after:Object=state(target),message:Object=JSON.parse(JSON.stringify(e.data));
         wire.push({frame:serial,before:releaseBefore,after:after,message:message});
         releaseCount++;releaseBefore=null;
         if(isNaN(originX)){originX=target.X;originY=target.Y;minHP=target.hp;}
         if(message.kick!=null && after.t==45)authorityStart={at:getTimer(),frame:serial,x:after.x,y:after.y,t:after.t,source:"release-wire",token:message.token};
         viewEvent("authority-release",{before:wire[wire.length-1].before,after:after,message:message});
      }
      private function viewEvent(name:String,data:Object=null):void {
         if(viewEvents.length<VIEW_LIMIT)viewEvents.push({at:getTimer(),frame:serial,event:name,data:data});
         else viewOverflow=true;
      }
      private function captureUnitPacket(p:Object):void {
         if(host||target==null||phase=="boot"||phase=="done"||phase=="round-done"
            ||p==null)return;
         var units:Array=p.type=="unitsync"?p.units as Array:p.type=="worldstate"?p.enemyMotion as Array:null;
         if(units==null)return;
         for each(var u:Object in units)if(String(u.id)=="a22_saved_grip_stress") {
            var accepted:Boolean=mod.session.rooms.accepts(p);
            if(accepted&&String(u.k)==mod.game.unitKey(target)&&isFinite(Number(u.sampleTime))
               &&isFinite(Number(u.x))&&isFinite(Number(u.y))
               &&(latestWirePoint==null||Number(u.sampleTime)>=Number(latestWirePoint.sourceAt)))
               latestWirePoint={x:Number(u.x),y:Number(u.y),sourceAt:Number(u.sampleTime),receivedAt:getTimer(),k:u.k};
            if(viewPackets.length>=VIEW_LIMIT){viewOverflow=true;return;}
            // This callback runs before production applies the packet. Do not
            // call any native simulation or reconstruct missing source frames.
            viewPackets.push({at:getTimer(),frame:serial,phase:phase,tick:p.tick,
               sourceAt:u.sampleTime,x:u.x,y:u.y,k:u.k,hp:u.hp,
               motion:u.motion,grip:u.grip,anim:u.anim,pose:u.pose,accepted:accepted});
            return;
         }
      }
      private function viewActive():Boolean {
         return target!=null&&(phase=="arm"||phase=="hold");
      }
      private function captureViewFrame(e:Event):void {
         if(!viewActive())return;
         var sample:Object={at:getTimer(),beginAt:frameBeginAt,frame:serial,phase:phase,x:target.X,y:target.Y,
            dx:target.dx,dy:target.dy,t:target.t_throw,levit:target.levit,hp:target.hp,
            resistance:target.levit_r,possible:target.levitPoss,raw:state(raw),
            player:{x:mod.game.gg.X,y:mod.game.gg.Y,mana:mod.game.gg.mana,
               cx:mod.game.gg.celX,cy:mod.game.gg.celY},held:mod.game.gg.teleObj!=null};
         maxResistance=Math.max(maxResistance,Number(target.levit_r));
         maxLift=Math.max(maxLift,by-Number(target.Y));
         if(Number(target.levit)>0&&authorityStart==null)holdLift=Math.max(holdLift,by-Number(target.Y));
         if(host && Number(target.levit_r)>threshold)exhaustedSeen=true;
         if(host&&authorityStart!=null&&authorityEnd==null) {
            var fx:Number=Number(target.X)-Number(authorityStart.x),fy:Number=Number(target.Y)-Number(authorityStart.y);
            flightTravel=Math.max(flightTravel,Math.sqrt(fx*fx+fy*fy));
         }
         if(viewFrames.length<VIEW_LIMIT)viewFrames.push(sample);else viewOverflow=true;
         // Include the first collision/recovery frame that consumes t_throw.
         if(host&&authorityStart!=null&&authorityEnd==null&&Number(target.t_throw)<=0)
            authorityEnd={at:sample.at,frame:serial,x:target.X,y:target.Y,t:target.t_throw};
      }
      private function captureViewRender(e:Event):void {
         if(!viewActive()||lastRenderFrame==serial)return;
         lastRenderFrame=serial;
         var display:Object=null,vis:DisplayObject=GameBridge.probe(target,"vis") as DisplayObject;
         if(vis!=null) {
            var p:Point=vis.localToGlobal(new Point()),bounds:Rectangle=vis.getBounds(mod.stage);
            var visible:Boolean=true,alpha:Number=1,parent:DisplayObject=vis;
            while(parent!=null){visible=visible&&parent.visible;alpha*=parent.alpha;parent=parent.parent;}
            display={x:vis.x,y:vis.y,screenX:p.x,screenY:p.y,left:bounds.x,top:bounds.y,
               width:bounds.width,height:bounds.height,attached:vis.stage===mod.stage,
               visible:visible,alpha:alpha,frame:GameBridge.probe(vis,"currentFrame")};
         }
         if(viewRenders.length<VIEW_LIMIT)viewRenders.push({at:getTimer(),frame:serial,phase:phase,
            x:target.X,y:target.Y,t:target.t_throw,anim:GameBridge.probe(target,"animState"),display:display});else viewOverflow=true;
      }
      private function trajectoryRange(samples:Array,from:Number,to:Number,origin:Object):Object {
         if(origin==null)return null;
         var result:Object={from:from,to:to,originX:origin.x,originY:origin.y,samples:0,
            minX:origin.x,maxX:origin.x,minY:origin.y,maxY:origin.y,maxDistance:0,
            firstOver1Ms:null,firstOver30Ms:null};
         for each(var s:Object in samples)if(Number(s.at)>=from&&Number(s.at)<=to) {
            result.samples++;
            result.minX=Math.min(result.minX,Number(s.x));result.maxX=Math.max(result.maxX,Number(s.x));
            result.minY=Math.min(result.minY,Number(s.y));result.maxY=Math.max(result.maxY,Number(s.y));
            var dx:Number=Number(s.x)-Number(origin.x),dy:Number=Number(s.y)-Number(origin.y);
            var distance:Number=Math.sqrt(dx*dx+dy*dy);
            result.maxDistance=Math.max(result.maxDistance,distance);
            if(result.firstOver1Ms==null&&distance>1)result.firstOver1Ms=Number(s.at)-from;
            if(result.firstOver30Ms==null&&distance>30)result.firstOver30Ms=Number(s.at)-from;
         }
         result.up=Number(origin.y)-Number(result.minY);
         return result;
      }
      private function reportView():void {
         var now:int=getTimer(),end:Number=authorityEnd==null?now:Number(authorityEnd.at);
         var summary:Object={caseName:CASES[round],role:host?"host":"join",clock:"local getTimer ms",
            packetClock:"sourceAt is host getTimer; at is receiver getTimer",overflow:viewOverflow,
            actionAt:actionAt,viewOrigin:viewOrigin,authorityStart:authorityStart,authorityEnd:authorityEnd,
            authorityFlight:authorityStart==null?null:trajectoryRange(viewFrames,authorityStart.at,end,authorityStart),
            // This is deliberately labelled the WHOLE post-action window. It
            // can include AI movement after landing; it is not the flight peak.
            postActionRenderWindow:trajectoryRange(viewRenders,actionAt,now,viewOrigin),
            frameSamples:viewFrames.length,renderSamples:viewRenders.length,packetSamples:viewPackets.length,
            scope:"display-tree position/visibility, not viewport pixel proof; no latency pass threshold"};
         Log.d("A22 GRIP VIEW SUMMARY "+JSON.stringify(summary));
         Log.d("A22 GRIP VIEW EVENTS "+JSON.stringify(viewEvents));
         Log.d("A22 GRIP VIEW PACKETS "+JSON.stringify(viewPackets));
         Log.d("A22 GRIP VIEW FRAMES "+JSON.stringify(viewFrames));
         Log.d("A22 GRIP VIEW RENDERS "+JSON.stringify(viewRenders));
      }
      private function find():Object {
         for each(var u:Object in mod.game.loc.units)
            if(!(u is MirrorHitUnit)&&String(u.id)=="a22_saved_grip_stress")return u;
         return null;
      }
      private function arena():Object {
         var l:Object=mod.game.loc;
         // Proven 280px native runway, with 200px of headroom for the lift.
         // Both players are placed on this floor once, then move normally.
         for(var y:int=240;y<Number(l.limY)-40;y+=40)
            for(var x:int=80;x<Number(l.limX)-320;x+=40) {
               var clear:Boolean=true;
               for(var xx:int=0;xx<=280&&clear;xx+=20) {
                  if(l.getAbsTile(x+xx,y+1).phis!=1){clear=false;break;}
                  for(var yy:int=20;yy<=200;yy+=20)
                     if(l.getAbsTile(x+xx,y-yy).phis!=0){clear=false;break;}
               }
               if(clear && collisionMode) {
                  for(var wallY:int=20;wallY<=200;wallY+=20)
                     if(l.getAbsTile(x+320,y-wallY).phis!=1){clear=false;break;}
               }
               if(clear)return {x:x,y:y};
            }
         throw new Error("No 280px native low-throw runway; do not replace native floor to force a pass");
      }
      private function prepare():void {
         var a:Object=arena();bx=a.x;by=a.y;
         var c:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit.UnitRaider") as Class;
         target=collisionMode?new A22CollisionRaider():new c("1",10,<unit weap="lmg"/>,null);target.id="a22_saved_grip_stress";
         target.putLoc(mod.game.loc,bx+100,by);mod.game.loc.addObj(target);mod.game.loc.units.push(target);
         target.xp=0;target.doop=true;target.invulner=false;target.hp=target.maxhp=1000;
         Log.d("A22 GRIP STRESS native-raider "+JSON.stringify(state(target)));
         attach();start(0);send("setup",{x:bx,y:by});
      }
      private function nativeCollision(kind:String,u:Object,before:Object,after:Object,other:Object):void {
         if(!collisionMode||u!==target||collisionEvidence.length>=256)return;
         var e:Object={kind:kind,before:before,after:after,other:other,at:getTimer(),frame:serial};
         collisionEvidence.push(e);Log.d("A22 COLLISION "+JSON.stringify(e));
      }
      private function attach():void {
         if(installedHooks)return;installedHooks=true;
         if(collisionMode)A22CollisionRaider.observed=nativeCollision;
         mod.stage.addEventListener(Event.ENTER_FRAME,drive,false,100005);
         mod.stage.addEventListener(Event.ENTER_FRAME,captureThrowBasis,false,99001);
         mod.stage.addEventListener(Event.ENTER_FRAME,beforeDefaults,false,1);
         mod.stage.addEventListener(Event.ENTER_FRAME,afterDefaults,false,-1);
         mod.stage.addEventListener(Event.ENTER_FRAME,beforeAttachments,false,-99);
         mod.stage.addEventListener(Event.ENTER_FRAME,afterAttachments,false,-101);
         mod.stage.addEventListener(Event.ENTER_FRAME,afterRelay,false,-8001);
         // Production movement runs at -10000. RENDER at -20000 follows its
         // final visibility/pose work too; EXIT_FRAME can fire inside gotoAndStop.
         mod.stage.addEventListener(Event.ENTER_FRAME,captureViewFrame,false,-20000);
         mod.stage.addEventListener(Event.RENDER,captureViewRender,false,-20000);
      }
      private function start(n:int):void {
         releaseKey();round=n;raw=null;pre=null;actionBefore=null;launch=peerLaunch=null;
         localReady=peerReady=localDone=peerDone=false;grabbed=grabAttempted=actionSent=false;
         actionAt=postFrames=grabFrame=releaseCount=0;wire=[];trace=[];acks=[];releaseBefore=null;
         originX=originY=minHP=NaN;maxTravel=launchTravel=0;
         viewEvents=[];viewPackets=[];viewFrames=[];viewRenders=[];
         authorityStart=authorityEnd=viewOrigin=null;lastRenderFrame=-1;viewOverflow=false;
         localEnd=peerEnd=lastAim=null;localEndAt=0;maxResistance=maxLift=holdLift=aimDistance=flightTravel=0;
         exhaustedSeen=false;selectorFrames=0;
         collisionEvidence=[];
         attachmentBefore=null;attachmentSamples=attachmentChanged=attachmentContacts=0;
         latestWirePoint=throwBasis=null;
         var g:Object=mod.game.gg;
         if(round==0&&collisionMode) {
            var lamps:int=0,leaked:int=0;
            for each(var sceneUnit:Object in mod.game.loc.units)
               if(getQualifiedClassName(sceneUnit)=="lad.native::LadLampTarget")lamps++;
            if(lamps>0) {
               for each(var snap:Object in mod.game.readUnitsSnapshot())
                  if(snap.cls=="lad.native::LadLampTarget")leaked++;
               check(leaked==0,"scene-only lamp targets remain owned by their module count="+lamps);
            }
         }
         if(g.teleObj!=null)g.dropTeleObj();
         mod.game.forceCloseOverlays();mod.game.world.ctr.active=true;mod.stage.focus=null;
         g.ctr.clearAll();g.ctr.keyAction=false;g.invulner=true;
         // Initial placement only. Both stand on the established native runway.
         g.dx=g.dy=0;g.setPos(bx+(collisionMode?(owner()?40:0):(host?260:40)),by);g.setVisPos();
         mod.game.loc.base=false;
         if(host) {
            target.setPos(bx+100,by);target.dx=target.dy=0;target.stun=0;
            target.levit=0;target.levit_r=0;target.levitPoss=true;target.hp=target.maxhp;
            target.controlOn=true;target.disabled=true;target.storona=1;
         }
         threshold=target==null?0:Number(target.levit_max)*Number(g.pers.unitLevitMult);
         initialPlayer={x:g.X,y:g.Y};initialEnemy=state(target);initialAttributes=attributes();
         Log.d("A22 GRIP STRESS INITIAL "+JSON.stringify({caseName:CASES[round],attributes:initialAttributes,
            player:initialPlayer,enemy:initialEnemy,threshold:threshold,invulnerability:true,
            note:"one-time placement; original saved skills/mana/equipment; no per-frame pin"}));
         change("settle");
      }
      private function arm():void {
         threshold=Number(target.levit_max)*Number(mod.game.gg.pers.unitLevitMult);
         initialEnemy=state(target);
         if(host){target.disabled=false;target.alarma(bx+(collisionMode?40:260),by);}
         armFrame=serial;change("arm");viewEvent("arm",state(target));
      }
      private function press(code:int):void {
         releaseKey();keyCode=code;keyFrame=serial;
         mod.stage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_DOWN,true,false,0,code));
      }
      private function releaseKey():void {
         if(keyCode>0&&mod!=null)mod.stage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_UP,true,false,0,keyCode));
         keyCode=0;
      }
      private function aim(x:Number,y:Number):void {
         var g:Object=mod.game.gg,w:Object=mod.game.world;
         if(lastAim!=null)aimDistance+=Math.sqrt((x-lastAim.x)*(x-lastAim.x)+(y-lastAim.y)*(y-lastAim.y));
         lastAim={x:x,y:y};
         g.celX=w.celX=x;g.celY=w.celY=y;
         w.cam.celX=int(x*w.cam.scaleV+w.cam.vx);w.cam.celY=int(y*w.cam.scaleV+w.cam.vy);
      }
      private function drive(e:Event):void {
         serial++;frameBeginAt=getTimer();
         if(keyCode>0&&serial>keyFrame)releaseKey();
         if(phase=="boot"||phase=="done"||mod.game.gg==null)return;
         if(target==null){target=find();if(target==null)return;}
         var g:Object=mod.game.gg,b:Object=mod.game;
         if(!owner() || phase=="round-done")return;
         if(phase=="arm"&&!grabAttempted) {
            aim(Number(target.X),Number(target.Y)-Number(target.scY)/2);
            // Allow normal body cursor selection to run. Never assign celObj,
            // onCursor, celDist, teleObj or replace the natural target by proxy.
            if(serial-armFrame>=4) {
               var selected:Object=b.loc.celObj;
               if(selected!=null&&b.grabBody(selected)===target&&Number(selected.onCursor)>0)selectorFrames++;
               else selectorFrames=0;
               if(selectorFrames>=2) {
                  grabAttempted=true;press(Keyboard.Q);
                  viewEvent("Q",{selected:state(selected),attributes:attributes(),player:{x:g.X,y:g.Y}});
               }
            }
         }
         if(phase=="hold"&&grabbed&&g.teleObj!=null&&!actionSent) {
            var r:Number=Number(raw.levit_r);
            var lift:Number=Math.min(1,Math.max(0,r)/20);
            var drag:Number=Math.min(1,Math.max(0,r-20)/20);
            var low:Boolean=collisionMode&&round>=2;
            aim(bx+100+(low?(round>=4?120:0):(collisionMode?70:120))*drag,
               by-Number(target.scY)/2-(low?-10:110)*lift);
            // Use only what the local player can see; the authority counter is
            // measured separately. The near-boundary case may legitimately
            // reach native resistance before E arrives and must record that.
            // A wall-damage trial needs a trajectory clear of the caster.
            // Native enemy contact can exchange momentum before any wall is
            // reached. Wait using only natural Q/mouse movement; never move the
            // enemy, suppress its AI/collisions or extend resistance to pass.
            // Full vertical separation already clears the caster's body.
            // Requiring horizontal separation as well can prevent E forever
            // when a resisting Raider drifts over the caster. Native throwTele
            // then aims upward; the real ceiling is also a damageWall surface.
            // Keep the actual impact/HP-drop assertions unchanged below.
            var clearLaunch:Boolean=!collisionMode||round>=2
               || Number(target.Y)<Number(g.Y)-Number(g.scY)-10;
            // High-wall coverage begins as soon as the natural trajectory is
            // clear. A fixed extra hold can let native Raider resistance pull
            // it back into the caster; long holds have a separate stress case.
            var readyThrow:Boolean=collisionMode?(low?r>=45:clearLaunch)
               :round<2&&r>=(round==0?60:threshold-5);
            if(readyThrow&&clearLaunch) {
               actionSent=true;actionAt=getTimer();actionBefore=state(raw);
               viewOrigin={x:target.X,y:target.Y};
               viewEvent("E",{raw:actionBefore,body:state(target),player:{x:g.X,y:g.Y},attributes:attributes()});
               press(Keyboard.E);
            }
         }
      }
      private function beforeDefaults(e:Event):void {
         if(target==null||phase=="done"||phase=="boot")return;
         pre={frame:serial,body:state(target),raw:state(raw),attributes:attributes(),
            held:mod.game.gg.teleObj===raw&&raw!=null,keyAction:mod.game.gg.ctr.keyAction,
            selected:state(mod.game.loc.celObj),caster:{x:mod.game.gg.X,y:mod.game.gg.Y,cx:mod.game.gg.celX,cy:mod.game.gg.celY},
            onPause:mod.game.world.onPause,allStat:mod.game.world.allStat};
      }
      private function captureThrowBasis(e:Event):void {
         if(!owner()||!actionSent||launch!=null||raw==null||mod.game.gg.teleObj!==raw)return;
         var g:Object=mod.game.gg;
         throwBasis={at:getTimer(),frame:serial,dx:Number(raw.dx),dy:Number(raw.dy),
            rawX:Number(raw.X),rawY:Number(raw.Y),height:Number(raw.scY),
            playerX:Number(g.X),playerY:Number(g.Y),playerHeight:Number(g.scY),
            point:latestWirePoint==null?null:{x:latestWirePoint.x,y:latestWirePoint.y,
               sourceAt:latestWirePoint.sourceAt,receivedAt:latestWirePoint.receivedAt,k:latestWirePoint.k}};
      }
      private function expectedDirection():Object {
         if(throwBasis==null)return null;
         var dx:Number=Number(raw.dx)-Number(throwBasis.dx),dy:Number=Number(raw.dy)-Number(throwBasis.dy);
         var strength:Number=Math.sqrt(dx*dx+dy*dy),expected:Object={x:dx,y:dy};
         var point:Object=throwBasis.point,usable:Boolean=false;
         if(point!=null&&isFinite(strength)&&strength>0) {
            // Re-state native throwTele's geometry using the raw packet cache.
            // No production helper supplies the expected vector or magnitude.
            var x:Number=Number(point.x)-Number(throwBasis.playerX);
            var y:Number=Number(point.y)-Number(throwBasis.height)/2-Number(throwBasis.playerY)
               +Number(throwBasis.playerHeight)/2-10;
            var distance:Number=Math.sqrt(x*x+y*y);
            if(isFinite(distance)&&distance>0){expected={x:x/distance*strength,y:y/distance*strength};usable=true;}
         }
         return {basis:throwBasis,nativeKick:{x:dx,y:dy},strength:strength,expected:expected,usesLatest:usable,
            change:Math.sqrt((expected.x-dx)*(expected.x-dx)+(expected.y-dy)*(expected.y-dy))};
      }
      private function afterDefaults(e:Event):void {
         if(target==null||phase=="done"||phase=="boot")return;
         var g:Object=mod.game.gg;
         if(phase=="arm"&&owner()&&grabAttempted&&!grabbed&&g.teleObj!=null&&mod.game.grabBody(g.teleObj)===target) {
            raw=g.teleObj;grabbed=true;grabFrame=serial;
            viewEvent("grabbed",state(raw));
            check(true,"native Q actually acquires the enemy");
            change("hold");send("grabbed",{frame:serial,raw:state(raw),attributes:attributes()});
         }
         if(actionSent&&owner()&&launch==null) {
            var released:Boolean=g.teleObj==null;
            // A native collision can consume the timer before this callback.
            // A failed/no-op input cannot pass on the requested key alone.
            var evidence:Boolean=released&&pre!=null&&pre.held&&pre.keyAction
               && !g.ctr.keyAction&&(Number(raw.t_throw)>0||Number(target.hp)<Number(actionBefore.hp));
            launch={verified:evidence,released:released,frame:serial,raw:state(raw),body:state(target),
               at:getTimer(),actionAt:actionAt,before:pre,attributes:attributes(),expectedNoImpulse:false,
               direction:expectedDirection()};
            if(round==0||collisionMode)check(evidence,"native E produced a real throw before flight assertions");
            Log.d("A22 GRIP STRESS native-result "+JSON.stringify(launch));
            if(host&&isNaN(originX)){originX=actionBefore.x;originY=actionBefore.y;minHP=actionBefore.hp;}
            if(host&&evidence)authorityStart={at:actionAt,frame:serial,x:actionBefore.x,y:actionBefore.y,t:raw.t_throw,source:"native-E"};
            viewEvent("native-result",launch);
            send("action-result",{result:launch});
         }
         if(owner()&&grabbed&&localEnd==null&&g.teleObj!==raw) {
            localEndAt=getTimer();localEnd={at:localEndAt,frame:serial,actionSent:actionSent,
               raw:state(raw),body:state(target),attributes:attributes(),acks:acks.concat(),launch:launch};
            if(actionAt==0)actionAt=localEndAt;
            viewEvent("local-ended",localEnd);send("ended",{result:localEnd});
         }
         if((actionAt>0||releaseCount>0)&&trace.length<120) {
            postFrames++;
            trace.push({frame:serial,beforeDefaultCallbacks:pre,afterDefaultCallbacks:{body:state(target),raw:state(raw),
               held:g.teleObj===raw&&raw!=null,keyAction:g.ctr.keyAction}});
            if(!isNaN(originX)) {
               var traveled:Number=Math.sqrt((target.X-originX)*(target.X-originX)+(target.Y-originY)*(target.Y-originY));
               maxTravel=Math.max(maxTravel,traveled);
               if(postFrames<=5)launchTravel=Math.max(launchTravel,traveled);
            }
         }
      }
      private function afterRelay(e:Event):void {
         if(trace.length>0&&trace[trace.length-1].frame==serial)
            trace[trace.length-1].afterGripRelay={body:state(target),raw:state(raw),held:mod.game.gg.teleObj!=null};
      }
      private function beforeAttachments(e:Event):void {
         attachmentBefore=null;
         if(!collisionMode||!host||target==null||!viewActive())return;
         var carrier:Object=mod.main.getChildByName("FirearmAttachmentsCarrier");
         if(carrier==null||carrier.api==null)return;
         attachmentBefore={dx:target.dx,dy:target.dy,levit:target.levit,t:target.t_throw,hits:carrier.api.hits};
      }
      private function afterAttachments(e:Event):void {
         if(attachmentBefore==null)return;
         var carrier:Object=mod.main.getChildByName("FirearmAttachmentsCarrier");
         var contact:Boolean=int(carrier.api.hits)>int(attachmentBefore.hits);
         if(contact)attachmentContacts++;
         if(Number(attachmentBefore.levit)<=0&&Number(attachmentBefore.t)<=0)return;
         // A new real blade hit may legitimately change momentum. Between
         // hits, the retained slow must never overwrite native held/throw speed.
         if(!contact) {
            attachmentSamples++;
            if(Math.abs(Number(target.dx)-Number(attachmentBefore.dx))>.0001
               ||Math.abs(Number(target.dy)-Number(attachmentBefore.dy))>.0001)attachmentChanged++;
         }
         if(contact||attachmentChanged>0)Log.d("A22 ATTACHMENT "+JSON.stringify({frame:serial,before:attachmentBefore,after:state(target),contact:contact}));
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;if(p.type!="a22-saved-grip-stress-test")return;
         try {
            if(p.op=="done"){finish();return;}
            if(host&&phase=="boot"&&p.op=="ready")prepare();
            else if(!host&&p.op=="setup"){
               bx=p.x;by=p.y;target=find();
               if(collisionMode&&target==null){target=new A22CollisionRaider();target.id="a22_saved_grip_stress";
                  target.putLoc(mod.game.loc,bx+100,by);mod.game.loc.addObj(target);mod.game.loc.units.push(target);}
               attach();start(0);
            }
            else if(!host&&p.op=="round")start(int(p.round));
            else if(host&&p.op=="settled")peerReady=true;
            else if(!host&&p.op=="arm")arm();
            else if(p.op=="grabbed"&&!owner()){grabbed=true;threshold=Number(target.levit_max)*Number(p.attributes.resistanceMultiplier);change("hold");}
            else if(p.op=="action-result"&&!owner()){
               peerLaunch=p.result;actionAt=getTimer();viewOrigin={x:target.X,y:target.Y};
               viewEvent("peer-action-result",{senderAt:p.result.at,senderActionAt:p.result.actionAt,body:state(target)});
            }
            else if(!owner()&&p.op=="ended"){peerEnd=p.result;if(actionAt==0)actionAt=getTimer();viewEvent("peer-ended",p.result);}
            else if(host&&p.op=="round-done"){peerDone=true;advance();}
         }catch(error:Error){check(false,error.getStackTrace());send("done");finish();}
      }
      private function conclude():void {
         reportView();
         var proof:Object=owner()?launch:peerLaunch,end:Object=owner()?localEnd:peerEnd;
         var rec:Object=wire.length==1?wire[0]:null,kick:Object=rec==null?null:rec.message.kick;
         var applied:Boolean=rec!=null&&kick!=null&&rec.after.t==45
            &&Math.abs(rec.after.dx-rec.before.dx-Number(kick.x))<0.0001
            &&Math.abs(rec.after.dy-rec.before.dy-Number(kick.y))<0.0001;
         var eligibleAtReceipt:Boolean=rec!=null&&rec.before.levit==1&&rec.before.possible
            &&Number(rec.before.resistance)<=threshold;
         var classification:String=round==2?"natural-release":proof==null||!proof.verified?"no-native-throw":
            !host?"await-authority-evidence":rec==null?"no-release-received":!applied?"authority-did-not-apply":
            flightTravel<=1?"applied-without-flight":"authoritative-flight";
         Log.d("A22 GRIP STRESS ACKS "+JSON.stringify(acks));
         Log.d("A22 GRIP STRESS WIRE "+JSON.stringify(wire));
         Log.d("A22 GRIP STRESS FRAMES "+JSON.stringify(trace));
         Log.d("A22 GRIP STRESS SUMMARY "+JSON.stringify({caseName:CASES[round],host:host,
            classification:classification,eligibleAtReceipt:eligibleAtReceipt,impulseApplied:applied,
            native:proof,ended:end,threshold:threshold,maxResistance:maxResistance,exhaustedSeen:exhaustedSeen,
            maxLift:maxLift,holdLift:holdLift,aimDistance:aimDistance,maxTravel:maxTravel,flightTravel:flightTravel,firstFiveFrameTravel:launchTravel,
            initialPlayer:initialPlayer,finalPlayer:{x:mod.game.gg.X,y:mod.game.gg.Y},
            initialEnemy:initialEnemy,finalEnemy:state(target),attributes:attributes(),overflow:viewOverflow}));
         check(!viewOverflow,"bounded diagnostic capture did not overflow");
         check(end!=null,"local grip ending observed without forcing drop");
         if(collisionMode) {
            check(proof!=null&&proof.verified===true,"wall trial has an actual native E release");
            if(host) {
               if(!owner())check(applied,"wall trial applies the received native impulse exactly once");
               check(Number(initialEnemy.damWall)>0&&Number(initialEnemy.damWallSpeed)>0,"native target has collision damage parameters");
               check(authorityStart!=null&&authorityEnd!=null,"authority observed a complete thrown interval");
               check(attachmentSamples>0&&attachmentChanged==0,"FA preserves protected native motion between hits "+JSON.stringify({samples:attachmentSamples,changed:attachmentChanged,contacts:attachmentContacts}));
               var impact:Object=null;
               for each(var contact:Object in collisionEvidence)
                  if(contact.kind=="wall"&&Number(contact.before.t_throw)>0&&Number(contact.after.hp)<Number(contact.before.hp))impact=contact;
                  else if(contact.kind=="attack-momentum"&&Number(contact.before.t_throw)>0&&contact.other.collisionTip==1) {
                     var hit:Object=contact.other.before,old:Object=contact.before;
                     var vx:Number=(Number(old.dx)*Number(old.massa)+Number(hit.dx)*Number(hit.massa))/(Number(old.massa)+Number(hit.massa));
                     var vy:Number=(Number(old.dy)*Number(old.massa)+Number(hit.dy)*Number(hit.massa))/(Number(old.massa)+Number(hit.massa));
                     check(Math.abs(Number(contact.after.dx)-((-Number(old.dx)+vx)*Number(old.knocked)+vx))<.0001
                        && Math.abs(Number(contact.after.dy)-((-Number(old.dy)+vy)*Number(old.knocked)+vy))<.0001,
                        "contact momentum follows native mass/recoil equation "+JSON.stringify(contact));
                  }
               check(flightTravel>60||impact!=null,"authoritative native throw travels or reaches a damaging collision distance="+flightTravel);
               // High throws deliberately aim at the verified wall. A low
               // near-body throw can naturally go left or land first; absence
               // of a wall call there is not evidence of suppressed damage.
               if(round<2)check(impact!=null,"native damageWall call within thrown interval really reduces HP "+JSON.stringify(impact));
               else Log.d("A22 LOW THROW IMPACT "+JSON.stringify({caseName:CASES[round],impact:impact}));
            }
            localDone=true;change("round-done");if(host)advance();else send("round-done");
            return;
         }
         if(host&&proof!=null&&proof.verified===true&&kick!=null) {
            var direction:Object=proof.direction;
            check(direction!=null&&direction.usesLatest===true,"throw oracle has an independently received finite position");
            if(direction!=null) {
               check(Math.abs(Number(kick.x)-Number(direction.expected.x))<0.0001
                  &&Math.abs(Number(kick.y)-Number(direction.expected.y))<0.0001,
                  "relayed direction matches latest raw packet and same-frame caster geometry");
               check(Math.abs(Math.sqrt(Number(kick.x)*Number(kick.x)+Number(kick.y)*Number(kick.y))
                  -Number(direction.strength))<0.0001,"relay preserves native impulse magnitude");
               if(Number(direction.change)>0.001)changedDirectionCases++;
            }
         }
         if(owner()) {
            check(raw===target||raw is MirrorHitUnit,"actual native Q target identity recorded");
            check(aimDistance>=100,"real aiming path includes lift and horizontal movement distance="+aimDistance);
         }
         if(round==0) {
            check(proof!=null&&proof.verified===true,"normal long hold emits native throw");
            if(host){check(applied,"normal long hold reaches authority with exact impulse");
               check(holdLift>40,"native target actually lifted before throwing");
               check(flightTravel>30||Number(target.hp)<minHP,"native thrown enemy travels or collides during its throw timer");}
         } else if(round==1) {
            // No assertion says a release after resistance expiration must fly.
            if(host)check(maxResistance>=threshold-5,"near-boundary case actually reaches resistance boundary");
            if(host&&eligibleAtReceipt&&proof!=null&&proof.verified)check(applied,"eligible near-boundary release retains exact impulse");
            else Log.d("A22 GRIP STRESS BOUNDARY diagnostic-only eligibility="+eligibleAtReceipt+" class="+classification);
         } else {
            check(proof==null,"natural exhaustion uses no E or synthetic throw");
            if(owner())check(!actionSent,"exhaustion case never presses E");
            if(host){check(exhaustedSeen,"native authority resistance exceeded its actual threshold");
               check(kick==null&&!applied,"natural exhaustion produces no thrown impulse");}
         }
         localDone=true;change("round-done");if(host)advance();else send("round-done");
      }
      private function advance():void {
         if(!host||!localDone||!peerDone)return;
         if(round+1<CASES.length){start(round+1);send("round",{round:round});}
         else {if(!collisionMode)check(changedDirectionCases>0,"at least one real release distinguishes buffered and received position directions");send("done");finish();}
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null||mod.session==null||mod.game==null)return;
         if(phase=="boot"&&mod.game.gg!=null)mod.game.gg.invulner=true;
         if(host)for each(var peer:Object in mod.session.peers)watch(peer.link);else watch(mod.session.link);
         try {
            if(phase=="done")return;
            if(getTimer()-at>(phase=="boot"?150000:60000)){check(false,"phase timeout; unissued throw is not a successful flight test");send("done");finish();return;}
            if(phase=="boot"&&!savedBootstrap())return;
            if(!mod.session.rooms.ready||mod.session.rooms.busy||mod.game.isTransitioning()||mod.game.gg==null)return;
            if(String(mod.game.readWorldInfo().curLandId)!="rbl") {
               if(host&&!travelIssued){travelIssued=true;mod.game.travelToLand("rbl");}
               return;
            }
            if(phase=="boot"&&!host&&getTimer()-readyAt>500){readyAt=getTimer();send("ready");}
            if(phase=="settle"&&getTimer()-at>1200&&!localReady) {
               target=find();localReady=target!=null;
               if(localReady){check(target.hp>0&&target.sost<3&&target.in_chain,"living native raider present");if(!host)send("settled");}
            }
            if(host&&phase=="settle"&&localReady&&peerReady){arm();send("arm");}
            if(phase=="arm"&&owner()&&getTimer()-at>6000) {
               check(false,"native Q did not acquire target: "+JSON.stringify({raw:state(raw),selected:state(mod.game.loc.celObj),target:state(target),attributes:attributes(),acks:acks}));
               send("done");finish();return;
            }
            if(phase=="hold"&&actionAt>0&&getTimer()-actionAt>6000&&postFrames>=60)conclude();
         }catch(error:Error){check(false,error.getStackTrace());send("done");finish();}
      }
      private function savedBootstrap():Boolean {
         if(String(mod.config.getValue("autoLoadSave"))!="-9")throw new Error("Saved replay requires isolated slot nine and connect-after-load");
         mod.game.refreshWorld();
         var w:Object=mod.game.world,g:Object=mod.game.gg;
         if(w==null)return false;
         if(w.clickReq==1) {
            mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN,true,false));
            mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP,true,false));
         }
         if(g==null)return false;
         mod.game.forceCloseOverlays();w.ctr.active=true;
         if(!loadIssued) {
            if(w.loc==null||Number(w.ng_wait)>0||w.allStat!=1||w.sats==null||w.sats.gg!==g||mod.game.isTransitioning()) {bootstrapSince=0;return false;}
            if(bootstrapSince==0)bootstrapSince=getTimer();
            if(getTimer()-bootstrapSince<1000)return false;
            if(mod.game.loadSaveTest(9)){loadIssued=true;loadCaster=g;}
            return false;
         }
         if(g===loadCaster||mod.game.isTransitioning()||!g.ggControl||g.disabled||g.work=="res"
            ||Number(g.t_work)>0||w.onPause||(w.vblack.visible&&w.vblack.alpha>0)) {nativeSince=0;return false;}
         if(nativeSince==0)nativeSince=getTimer();
         if(getTimer()-nativeSince<4000)return false;
         if(mod.session.mode=="offline"&&getTimer()-lastConnect>1000) {
            lastConnect=getTimer();
            var stored:Object=w.getSave(9);
            check(stored!=null&&stored.pers!=null&&g.pers.level==stored.pers.level,
               "actual saved profile loaded before connecting level="+g.pers.level);
            Log.d("A22 GRIP SAVED PROFILE "+JSON.stringify({role:host?"host":"join",attributes:attributes(),room:mod.game.roomKey()}));
            if(host)mod.session.startHost();else mod.session.startJoin();
         }
         return true;
      }
      private function finish():void {
         if(phase=="done")return;
         if(phase!="round-done"&&viewFrames.length>0) {
            // Preserve the original failure, including cursor/visibility and
            // actual motion, when input selection or a lifecycle phase aborts.
            reportView();
            Log.d("A22 GRIP STRESS ABORT "+JSON.stringify({phase:phase,acks:acks,wire:wire,
               raw:state(raw),body:state(target),ended:localEnd,peerEnded:peerEnd}));
         }
         releaseKey();phase="done";timer.stop();
         if(mod!=null&&installedHooks) {
            mod.stage.removeEventListener(Event.ENTER_FRAME,drive);
            mod.stage.removeEventListener(Event.ENTER_FRAME,captureThrowBasis);
            mod.stage.removeEventListener(Event.ENTER_FRAME,beforeDefaults);
            mod.stage.removeEventListener(Event.ENTER_FRAME,afterDefaults);
            mod.stage.removeEventListener(Event.ENTER_FRAME,afterRelay);
            mod.stage.removeEventListener(Event.ENTER_FRAME,captureViewFrame);
            mod.stage.removeEventListener(Event.RENDER,captureViewRender);
         }
         Log.d("COOP EFFECTS DONE a22-saved-grip-stress "+(host?"host":"join"));
      }
   }
}

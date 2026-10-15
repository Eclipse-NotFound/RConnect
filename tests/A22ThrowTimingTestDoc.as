package {
   import flash.desktop.NativeApplication;
   import flash.display.DisplayObject;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.MouseEvent;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.geom.Point;
   import flash.geom.Rectangle;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getQualifiedClassName;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;
   import rconnect.game.MirrorHitUnit;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;

   /** Native Q -> native E -> the installed A22 grip relay, with ordinary
    * telekinesis values from AllData. No injected throw/impulse/damage/timer.
    * The +1/-1 samples bracket BOTH native MainMenu and TDFC (priority zero).
    * They must not be described as an isolated measurement of TDFC's writes. */
   public class A22ThrowTimingTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var CASES:Array=["host-low","join-low","join-quick","join-no-throw-perk"];
      private var savedProfile:Boolean=false,loadIssued:Boolean=false,loadCaster:Object;
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
      private static const VIEW_LIMIT:int=512;
      // Read-only collision evidence around release and the first five native
      // frames. The assertions below intentionally do not consume this data.
      private var collisionTrace:Array=[],collisionOverflow:Boolean=false;
      private static const COLLISION_LIMIT:int=16;
      private static const NEARBY_LIMIT:int=8;

      public function A22ThrowTimingTestDoc(preserveSavedProfile:Boolean=false) {
         savedProfile=preserveSavedProfile;
         if(savedProfile)CASES=["host-saved","join-saved","join-saved-quick"];
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
         Log.d("COOP "+(ok?"PASS ":"FAIL ")+"a22-throw-timing "+s+" case="+CASES[round]+" phase="+phase);
      }
      private function change(s:String):void {phase=s;at=getTimer();}
      private function owner():Boolean {return round==0?host:!host;}
      private function send(op:String,p:Object=null):void {
         p=p||{};p.type="a22-throw-timing-test";p.op=op;p.round=round;
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
         return {x:o.X,y:o.Y,dx:o.dx,dy:o.dy,t:o.t_throw,levit:o.levit,stay:o.stay,
            hp:o.hp,sost:o.sost,disabled:o.disabled,mass:o.massa,possible:o.levitPoss,
            resistance:o.levit_r,resistanceMax:o.levit_max};
      }
      private function attributes():Object {
         var g:Object=mod.game.gg,p:Object=g.pers;
         return {level:p.level,mana:g.mana,maxmana:g.maxmana,massLimit:p.maxTeleMassa,range:p.teleDist,
            force:p.throwForce,cost:p.throwDmagic,manaMultiplier:p.allDManaMult,
            strainMultiplier:p.throwDmanaMult,holdCost:p.teleMult,resistanceMultiplier:p.unitLevitMult,
            speed:g.teleSpeed,accel:g.teleAccel,spells:p.spellsPoss,manaTrauma:p.manaSt,
            playerManaTrauma:GameBridge.probe(g,"manaSt")};
      }
      private function collisionState(u:Object):Object {
         if(u==null)return null;
         var result:Object={className:getQualifiedClassName(u)};
         for each(var key:String in ["id","X","Y","X1","X2","Y1","Y2","massa","knocked",
            "collisionTip","dx","dy","neujaz","hp","t_throw","fraction","disabled","in_chain"])
            result[key]=GameBridge.probe(u,key);
         return result;
      }
      private function captureCollisions(where:String):void {
         if(target==null)return;
         if(collisionTrace.length>=COLLISION_LIMIT){collisionOverflow=true;return;}
         var own:Object=collisionState(target),seen:Dictionary=new Dictionary(),nearby:Array=[];
         var count:int=0,room:Object=mod.game.loc,unit:Object;
         // Retain only the nearest eight, but count every nearby unique body
         // so truncation cannot masquerade as an empty collision neighborhood.
         var collect:Function=function(u:Object):void {
            if(u==null||u===target||seen[u])return;
            seen[u]=true;
            var item:Object=collisionState(u),gapX:Number,gapY:Number;
            if(item.X1!=null&&item.X2!=null&&item.Y1!=null&&item.Y2!=null
               &&own.X1!=null&&own.X2!=null&&own.Y1!=null&&own.Y2!=null) {
               gapX=Math.max(0,Number(item.X1)-Number(own.X2),Number(own.X1)-Number(item.X2));
               gapY=Math.max(0,Number(item.Y1)-Number(own.Y2),Number(own.Y1)-Number(item.Y2));
               item.overlap=gapX==0&&gapY==0;
            } else {
               if(item.X==null||item.Y==null)return;
               gapX=Number(item.X)-Number(own.X);gapY=Number(item.Y)-Number(own.Y);
               item.overlap=null;
            }
            item.gap2=gapX*gapX+gapY*gapY;
            if(!isFinite(Number(item.gap2))||Number(item.gap2)>120*120)return;
            item.localPlayer=u===mod.game.gg;
            count++;nearby.push(item);nearby.sortOn("gap2",Array.NUMERIC);
            if(nearby.length>NEARBY_LIMIT)nearby.pop();
         };
         collect(GameBridge.probe(room,"gg"));collect(mod.game.gg);
         var units:Object=GameBridge.probe(room,"units");
         if(units is Array)for each(unit in units)collect(unit);
         var selected:Object={available:false};
         try {
            unit=target["celUnit"];
            selected={available:true,unit:collisionState(unit)};
         } catch(unavailable:Error) {}
         collisionTrace.push({at:getTimer(),frame:serial,where:where,postFrames:postFrames,
            target:own,celUnit:selected,nearby:nearby,nearbyCount:count,nearbyOverflow:count>NEARBY_LIMIT});
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
         captureCollisions("before-release-wire");
      }
      private function wireAfter(e:NetMessageEvent):void {
         if(!host||releaseBefore==null||e.data.type!="unit-grip"||e.data.op!="release")return;
         var after:Object=state(target),message:Object=JSON.parse(JSON.stringify(e.data));
         wire.push({frame:serial,before:releaseBefore,after:after,message:message});
         releaseCount++;releaseBefore=null;
         if(isNaN(originX)){originX=target.X;originY=target.Y;minHP=target.hp;}
         authorityStart={at:getTimer(),frame:serial,x:after.x,y:after.y,t:after.t,source:"release-wire",token:message.token};
         viewEvent("authority-release",{before:wire[wire.length-1].before,after:after,message:message});
         captureCollisions("after-release-wire");
      }
      private function viewEvent(name:String,data:Object=null):void {
         if(viewEvents.length<VIEW_LIMIT)viewEvents.push({at:getTimer(),frame:serial,event:name,data:data});
         else viewOverflow=true;
      }
      private function captureUnitPacket(p:Object):void {
         if(host||target==null||phase=="boot"||phase=="done"||phase=="round-done"
            ||p==null||p.type!="unitsync"||!(p.units is Array))return;
         for each(var u:Object in p.units)if(String(u.id)=="a22_throw_timing") {
            if(viewPackets.length>=VIEW_LIMIT){viewOverflow=true;return;}
            // This callback runs before production applies the packet. Do not
            // call any native simulation or reconstruct missing source frames.
            viewPackets.push({at:getTimer(),frame:serial,phase:phase,tick:p.tick,
               sourceAt:u.sampleTime,x:u.x,y:u.y,k:u.k,hp:u.hp,
               motion:u.motion,grip:u.grip,anim:u.anim,pose:u.pose,accepted:mod.session.rooms.accepts(p)});
            return;
         }
      }
      private function viewActive():Boolean {
         return target!=null&&(phase=="arm"||phase=="hold");
      }
      private function captureViewFrame(e:Event):void {
         if(!viewActive())return;
         var sample:Object={at:getTimer(),beginAt:frameBeginAt,frame:serial,phase:phase,x:target.X,y:target.Y,
            dx:target.dx,dy:target.dy,t:target.t_throw,levit:target.levit,hp:target.hp};
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
         Log.d("A22 THROW VIEW SUMMARY "+JSON.stringify(summary));
         Log.d("A22 THROW VIEW EVENTS "+JSON.stringify(viewEvents));
         Log.d("A22 THROW VIEW PACKETS "+JSON.stringify(viewPackets));
         Log.d("A22 THROW VIEW FRAMES "+JSON.stringify(viewFrames));
         Log.d("A22 THROW VIEW RENDERS "+JSON.stringify(viewRenders));
      }
      private function find():Object {
         for each(var u:Object in mod.game.loc.units)
            if(!(u is MirrorHitUnit)&&String(u.id)=="a22_throw_timing")return u;
         return null;
      }
      private function arena():Object {
         var l:Object=mod.game.loc;
         // Only the target's 280px runway needs a native floor. The host is
         // pinned 340px from it; terrain between host and target is not a
         // runway requirement. This uses A22BehaviorTestDoc's proven search.
         for(var y:int=240;y<Number(l.limY)-40;y+=40)
            for(var x:int=80;x<Number(l.limX)-320;x+=40) {
               var clear:Boolean=true;
               for(var xx:int=0;xx<=280&&clear;xx+=20) {
                  if(l.getAbsTile(x+xx,y+1).phis!=1){clear=false;break;}
                  for(var yy:int=20;yy<=200;yy+=20)
                     if(l.getAbsTile(x+xx,y-yy).phis!=0){clear=false;break;}
               }
               if(clear)return {x:x,y:y};
            }
         throw new Error("No 280px native low-throw runway; do not replace native floor to force a pass");
      }
      private function prepare():void {
         var a:Object=arena();bx=a.x;by=a.y;
         var c:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit.UnitRaider") as Class;
         target=new c("1",10,<unit weap="lmg"/>,null);target.id="a22_throw_timing";
         target.putLoc(mod.game.loc,bx+100,by);mod.game.loc.addObj(target);mod.game.loc.units.push(target);
         target.xp=0;target.doop=true;target.invulner=false;target.hp=target.maxhp=1000;
         Log.d("A22 THROW TIMING native-raider "+JSON.stringify(state(target)));
         attach();start(0);send("setup",{x:bx,y:by});
      }
      private function attach():void {
         if(installedHooks)return;installedHooks=true;
         mod.stage.addEventListener(Event.ENTER_FRAME,drive,false,100005);
         mod.stage.addEventListener(Event.ENTER_FRAME,beforeDefaults,false,1);
         mod.stage.addEventListener(Event.ENTER_FRAME,afterDefaults,false,-1);
         mod.stage.addEventListener(Event.ENTER_FRAME,afterRelay,false,-8001);
         // Production movement runs at -10000. RENDER at -20000 follows its
         // final visibility/pose work too; EXIT_FRAME can fire inside gotoAndStop.
         mod.stage.addEventListener(Event.ENTER_FRAME,captureViewFrame,false,-20000);
         mod.stage.addEventListener(Event.RENDER,captureViewRender,false,-20000);
      }
      private function start(n:int):void {
         round=n;raw=null;pre=null;actionBefore=null;launch=peerLaunch=null;
         localReady=peerReady=localDone=peerDone=false;grabbed=grabAttempted=actionSent=false;
         actionAt=postFrames=grabFrame=releaseCount=0;wire=[];trace=[];acks=[];releaseBefore=null;
         originX=originY=minHP=NaN;maxTravel=launchTravel=0;
         viewEvents=[];viewPackets=[];viewFrames=[];viewRenders=[];
         collisionTrace=[];collisionOverflow=false;
         authorityStart=authorityEnd=viewOrigin=null;lastRenderFrame=-1;viewOverflow=false;
         var g:Object=mod.game.gg,p:Object=g.pers;
         if(g.teleObj!=null)g.dropTeleObj();
         Log.d("A22 THROW TIMING prior-attributes "+JSON.stringify(attributes()));
         // Ordinary telekinesis level 2 / throw perk level 1, not the earlier
         // 100x resistance / 2-mana-cost probe. Only no-perk changes force to 0.
         if(!savedProfile) {
            p.maxTeleMassa=3;p.teleDist=360000;p.telemaster=0;p.unitLevitMult=1.3;
            p.telePorog=0.3;p.teleMult=1.6;p.allDManaMult=1;p.throwDmanaMult=0.05;
            p.throwDmagic=200;p.throwForce=round==3?0:25;p.spellsPoss=1;
            g.teleSpeed=11;g.teleAccel=1.2;g.maxmana=500;g.mana=500;
         }
         if(host) {
            target.setPos(bx+100,by);target.dx=target.dy=0;target.stun=0;
            target.levit=0;target.levit_r=0;target.levitPoss=true;target.hp=target.maxhp;
            target.controlOn=true;target.disabled=true;target.storona=1;
         }
         change("settle");
      }
      private function arm():void {
         if(host){target.disabled=false;target.alarma(bx+440,by);}
         change("arm");
         viewEvent("arm",state(target));
      }
      private function drive(e:Event):void {
         serial++;frameBeginAt=getTimer();
         if(phase=="boot"||phase=="done"||mod.game.gg==null)return;
         if(target==null){target=find();if(target==null)return;}
         var g:Object=mod.game.gg,b:Object=mod.game;
         b.forceCloseOverlays();g.invulner=true;g.disabled=false;g.isTake=0;g.work="";
         g.dx=g.dy=0;g.setPos(bx+(host?440:40),by);g.setVisPos();
         g.ctr.clearAll();g.ctr.keyAction=false;b.loc.base=false;
         // Target feet remain within eight pixels of the floor. No position,
         // velocity, levitation or throw timer is written after arm().
         g.celX=b.world.celX=bx+100;g.celY=b.world.celY=by-Number(target.scY)/2-2;
         if(phase=="arm"&&owner()&&!grabAttempted) {
            raw=target;
            if(!host)for each(var u:Object in b.loc.units)
               if(u is MirrorHitUnit&&MirrorHitUnit(u).body===target){raw=u;break;}
            if(!host)check(raw is MirrorHitUnit,"Q selects the actual mirror receiver");
            raw.onCursor=1;b.loc.celObj=raw;
            b.loc.celDist=(g.X-raw.X)*(g.X-raw.X)+(g.Y-raw.Y)*(g.Y-raw.Y);
            grabAttempted=true;g.ctr.keyTele=true;
            viewEvent("Q",state(raw));
            Log.d("A22 THROW TIMING Q "+JSON.stringify({frame:serial,raw:state(raw),attributes:attributes()}));
         }
         if(phase=="hold"&&owner()&&!actionSent&&grabbed&&serial-grabFrame>=(round==2?1:12)) {
            actionSent=true;actionAt=getTimer();actionBefore=state(raw);
            viewOrigin={x:target.X,y:target.Y};viewEvent("E",{raw:actionBefore,body:state(target)});
            g.ctr.keyAction=true;
            Log.d("A22 THROW TIMING E "+JSON.stringify({frame:serial,raw:actionBefore,attributes:attributes(),held:g.teleObj===raw}));
         }
      }
      private function beforeDefaults(e:Event):void {
         if(target==null||phase=="done"||phase=="boot")return;
         pre={frame:serial,body:state(target),raw:state(raw),attributes:attributes(),
            held:mod.game.gg.teleObj===raw&&raw!=null,keyAction:mod.game.gg.ctr.keyAction,
            onPause:mod.game.world.onPause,allStat:mod.game.world.allStat};
         if((actionAt>0||releaseCount>0)&&postFrames<5)captureCollisions("before-default-callbacks");
      }
      private function afterDefaults(e:Event):void {
         if(target==null||phase=="done"||phase=="boot")return;
         var g:Object=mod.game.gg;
         if(phase=="arm"&&owner()&&grabAttempted&&!grabbed&&g.teleObj===raw) {
            grabbed=true;grabFrame=serial;
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
               at:getTimer(),actionAt:actionAt,before:pre,attributes:attributes(),expectedNoImpulse:round==3};
            check(evidence,"native E produced a real throw before flight assertions");
            Log.d("A22 THROW TIMING native-result "+JSON.stringify(launch));
            if(host&&isNaN(originX)){originX=actionBefore.x;originY=actionBefore.y;minHP=actionBefore.hp;}
            if(host&&evidence)authorityStart={at:actionAt,frame:serial,x:actionBefore.x,y:actionBefore.y,t:raw.t_throw,source:"native-E"};
            viewEvent("native-result",launch);
            send("action-result",{result:launch});
         }
         if((actionAt>0||releaseCount>0)&&trace.length<90) {
            if(postFrames<5)captureCollisions("after-default-callbacks");
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
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;if(p.type!="a22-throw-timing-test")return;
         try {
            if(p.op=="done"){finish();return;}
            if(host&&phase=="boot"&&p.op=="ready")prepare();
            else if(!host&&p.op=="setup"){bx=p.x;by=p.y;target=find();attach();start(0);}
            else if(!host&&p.op=="round")start(int(p.round));
            else if(host&&p.op=="settled")peerReady=true;
            else if(!host&&p.op=="arm")arm();
            else if(p.op=="grabbed"&&!owner()){grabbed=true;change("hold");}
            else if(p.op=="action-result"&&!owner()){
               peerLaunch=p.result;actionAt=getTimer();viewOrigin={x:target.X,y:target.Y};
               viewEvent("peer-action-result",{senderAt:p.result.at,senderActionAt:p.result.actionAt,body:state(target)});
            }
            else if(host&&p.op=="round-done"){peerDone=true;advance();}
         }catch(error:Error){check(false,error.getStackTrace());send("done");finish();}
      }
      private function conclude():void {
         reportView();
         Log.d("A22 THROW TIMING ACKS "+JSON.stringify(acks));
         Log.d("A22 THROW TIMING WIRE "+JSON.stringify(wire));
         Log.d("A22 THROW TIMING FRAMES "+JSON.stringify(trace));
         Log.d("A22 THROW COLLISION "+JSON.stringify({caseName:CASES[round],role:host?"host":"join",
            scope:"release and first five native frames; read-only nearby bodies, not a collision call trace",
            overflow:collisionOverflow,records:collisionTrace}));
         Log.d("A22 THROW TIMING SUMMARY "+JSON.stringify({caseName:CASES[round],host:host,maxTravel:maxTravel,
            origin:[originX,originY],firstFiveFrameTravel:launchTravel,hpAtLaunch:minHP,hp:target.hp,postFrames:postFrames,body:state(target)}));
         var proof:Object=owner()?launch:peerLaunch;
         check(proof!=null&&proof.verified===true,"launch evidence received before judging replicated movement");
         if(host&&proof!=null&&proof.verified===true) {
            if(round!=0) {
               check(releaseCount==1,"one release reached the authority count="+releaseCount);
               if(releaseCount==1) {
                  var rec:Object=wire[0],kick:Object=rec.message.kick;
                  check(kick!=null&&rec.after.t==45,"release retains native throw rather than becoming a plain drop");
                  if(kick!=null)check(Math.abs(rec.after.dx-rec.before.dx-Number(kick.x))<0.0001
                     &&Math.abs(rec.after.dy-rec.before.dy-Number(kick.y))<0.0001,"authority applies exactly the native impulse");
               }
            }
            if(round==3) {
               // Native throwTele still arms t_throw when throwForce==0. It is
               // an intentional no-impulse release, not a replication failure.
               if(wire.length==1&&wire[0].message.kick!=null) {
                  var k:Object=wire[0].message.kick;
                  check(Math.abs(k.x)+Math.abs(k.y)<0.0001,"no throw perk preserves native zero impulse");
               }
            } else check(launchTravel>30||Number(target.hp)<minHP,
               "authoritative body moves in first five frames or hits terrain travel="+launchTravel+" hp="+target.hp);
         }
         localDone=true;change("round-done");if(host)advance();else send("round-done");
      }
      private function advance():void {
         if(!host||!localDone||!peerDone)return;
         if(round+1<CASES.length){start(round+1);send("round",{round:round});}
         else {send("done");finish();}
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null||mod.session==null||mod.game==null)return;
         if(phase=="boot"&&mod.game.gg!=null)mod.game.gg.invulner=true;
         if(host)for each(var peer:Object in mod.session.peers)watch(peer.link);else watch(mod.session.link);
         try {
            if(phase=="done")return;
            if(getTimer()-at>(phase=="boot"?150000:60000)){check(false,"phase timeout; unissued throw is not a successful flight test");send("done");finish();return;}
            if(phase=="boot"&&savedProfile&&!savedBootstrap())return;
            if(!mod.session.rooms.ready||mod.session.rooms.busy||mod.game.isTransitioning()||mod.game.gg==null)return;
            if(String(mod.game.readWorldInfo().curLandId)!="rbl") {
               if(savedProfile&&host&&!travelIssued){travelIssued=true;mod.game.travelToLand("rbl");}
               return;
            }
            if(phase=="boot"&&!host&&getTimer()-readyAt>500){readyAt=getTimer();send("ready");}
            if(phase=="settle"&&getTimer()-at>1200&&!localReady) {
               target=find();localReady=target!=null;
               if(localReady){check(target.hp>0&&target.sost<3&&target.in_chain,"living native raider present");if(!host)send("settled");}
            }
            if(host&&phase=="settle"&&localReady&&peerReady){arm();send("arm");}
            if(phase=="arm"&&owner()&&grabAttempted&&getTimer()-at>2500) {
               check(false,"native Q did not acquire target: "+JSON.stringify({raw:state(raw),attributes:attributes(),acks:acks}));
               send("done");finish();return;
            }
            if(phase=="hold"&&actionAt>0&&getTimer()-actionAt>3000
               &&(postFrames>=15||getTimer()-actionAt>8000))conclude();
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
            Log.d("A22 THROW SAVED PROFILE "+JSON.stringify({role:host?"host":"join",attributes:attributes(),room:mod.game.roomKey()}));
            if(host)mod.session.startHost();else mod.session.startJoin();
         }
         return true;
      }
      private function finish():void {
         if(phase=="done")return;phase="done";timer.stop();
         if(mod!=null&&installedHooks) {
            mod.stage.removeEventListener(Event.ENTER_FRAME,drive);
            mod.stage.removeEventListener(Event.ENTER_FRAME,beforeDefaults);
            mod.stage.removeEventListener(Event.ENTER_FRAME,afterDefaults);
            mod.stage.removeEventListener(Event.ENTER_FRAME,afterRelay);
            mod.stage.removeEventListener(Event.ENTER_FRAME,captureViewFrame);
            mod.stage.removeEventListener(Event.RENDER,captureViewRender);
         }
         Log.d("COOP EFFECTS DONE a22-throw-timing "+(host?"host":"join"));
      }
   }
}

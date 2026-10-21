package {
   import flash.desktop.NativeApplication;
   import flash.display.BitmapData;
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.MovieClip;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.MouseEvent;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.geom.Matrix;
   import flash.geom.Rectangle;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getQualifiedClassName;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   import rconnect.net.NetMessageEvent;
   import rconnect.net.TcpLink;

   /** External, real-game flight probe. Each trial uses ONE native projectile:
    * Weapon.attack/step -> ordinary Location/Bullet.step -> production TCP ->
    * final Stage.RENDER. Never calls the production projectile receiver/clock,
    * never integrates a synthetic trajectory, never changes Bullet velocity.
    * The source's actual final-render trace is the independent reference.
    * Functional sampled-flight checks only; not a dense-fire/FPS qualification. */
   public class NativeFlightContinuityTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private static const CASES:Array=[
         {id:"lmg",host:true,left:false,npc:false},
         {id:"lmg",host:false,left:true,npc:false},
         {id:"quick",host:true,left:false,npc:false},
         {id:"quick",host:false,left:true,npc:false},
         {id:"plamg",host:true,left:true,npc:false},
         {id:"plamg",host:false,left:false,npc:false},
         {id:"alilight",host:true,left:false,npc:true},
         {id:"alilight",host:true,left:true,npc:true}
      ];
      private var mod:RConnectMod,host:Boolean,timer:Timer=new Timer(100),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=getTimer(),readyAt:int=0,round:int=-1,source:Boolean=false;
      private var gun:Object,actor:Object,ali:Object,oldGun:Object,oldChildren:Object,oldWeapons:Array,oldMagic:Object,oldThrow:Object;
      private var oldZoom:int,baseX:Number,baseY:Number,angle:Number,gunInfo:Object,nativeInfo:Object,expectedClass:String="";
      private var bullet:Object,shotCount:int=0,issued:Boolean=false,sourceEnd:Object,traceSent:Boolean=false,traceAt:int=0;
      private var frames:Array=[],nativeFrames:Array=[],renderNo:int=0,gameFrame:int=0,clipIds:Dictionary=new Dictionary(true),nextClip:int=1;
      private var sourceMeta:Object,pixelProof:Object,pixelTried:Boolean=false,peak:int=0,lastVisibleWall:Number=0;
      private var sourceContact:Object,contactProof:Object,contactTried:Boolean=false;
      private var phases:Array=[],phaseSeen:Object={},wire:Array=[];

      public function NativeFlightContinuityTestDoc() {
         var app:String=NativeApplication.nativeApplication.applicationID;
         if(app.indexOf("rconnect-coop-")<0)return;host=app.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();send("done");finish();
         });
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,s:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"native-flight-continuity "+s+" case="+round);}
      private function send(s:String,p:Object=null):void {
         if(mod==null)return;p=p||{};p.type="native-flight-continuity-test";p.stage=s;p.round=round;
         if(host)mod.session.server.broadcast(p);else if(mod.session.link!=null)mod.session.link.send(p);
      }
      private function watch(l:TcpLink):void {if(l!=null && !links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);}}
      private function active():Boolean {return phase=="armed" || phase=="flight" || phase=="drain";}
      private function mark(name:String,detail:Object=null):void {
         if(phaseSeen[name])return;phaseSeen[name]=true;
         phases.push({name:name,at:getTimer(),wall:new Date().time,frame:gameFrame,render:renderNo,detail:detail});
      }
      private function setup():void {
         var g:Object=mod.game.gg;oldGun=g.currentWeapon;oldChildren=g.childObjs.concat();oldWeapons=g.invent.weapons;
         oldMagic=g.magicWeapon;oldThrow=g.throwWeapon;oldZoom=mod.game.world.cam.isZoom;
         var owned:Array=[];for(var key:String in oldWeapons)owned[key]=oldWeapons[key];g.invent.weapons=owned;
         g.changeWeapon("not",true);g.magicWeapon=null;g.throwWeapon=null;
         mod.stage.addEventListener(Event.ENTER_FRAME,before,false,100000);
         mod.stage.addEventListener(Event.ENTER_FRAME,after,false,-6000);
         // RConnect and native camera/display listeners have already run.
         // Sampling source and replica at the same final phase avoids measuring
         // a correct in-memory position which never reaches the painted frame.
         mod.stage.addEventListener(Event.RENDER,render,false,-2147483647);
      }
      private function removeGun():void {
         if(gun!=null){gun.remVisual();gun=null;}
         if(ali!=null){var loc:Object=ali.loc;loc.remObj(ali);var i:int=loc.units.indexOf(ali);if(i>=0)loc.units.splice(i,1);ali=null;}
      }
      private function prepare(n:int):void {
         var enteredAt:int=getTimer(),enteredWall:Number=new Date().time;
         removeGun();round=n;phase="prepared";at=getTimer();source=host==Boolean(CASES[n].host);
         issued=traceSent=pixelTried=false;bullet=null;sourceEnd=null;nativeInfo=null;sourceMeta=null;pixelProof=null;
         shotCount=traceAt=renderNo=gameFrame=peak=0;lastVisibleWall=0;frames=[];nativeFrames=[];
         sourceContact=contactProof=null;contactTried=false;wire=[];phases=[];phaseSeen={};
         phases.push({name:"prepare-enter",at:enteredAt,wall:enteredWall,frame:0,render:0});phaseSeen["prepare-enter"]=true;
         expectedClass="";clipIds=new Dictionary(true);nextClip=1;
         var b:Object=mod.game,g:Object=b.gg,loc:Object=b.loc;
         g.changeWeapon("not",true);g.magicWeapon=null;g.throwWeapon=null;
         b.forceCloseOverlays();loc.base=false;loc.black=false;b.world.black=false;
         // Isolated room fixture: maximize real flight length; retain real
         // collision boundaries. No projectile speed/lifetime/damage changes.
         var floor:int=Math.max(8,Math.min(loc.spaceY-2,int(loc.spaceY*.72)));baseY=floor*40;
         baseX=CASES[n].left?loc.spaceX*40-220:220;angle=CASES[n].left?Math.PI:0;
         for(var x:int=1;x<loc.spaceX-1;x++)for(var y:int=1;y<loc.spaceY-1;y++) {
            var tile:Object=loc.space[x][y];tile.phis=(y>=floor || x==1 || x==loc.spaceX-2)?1:0;
            tile.opac=tile.phis;tile.front="";tile.water=0;
            tile.phX1=x*40;tile.phX2=(x+1)*40;tile.phY1=y*40;tile.phY2=(y+1)*40;
         }
         // Prevent accidental native enemy/body collisions in the flight lane.
         // Only fixture-owned isolated copies are used; no save is written.
         for each(var u:Object in loc.units)if(u!==g){u.disabled=true;u.noAgro=true;u.trigDis=true;u.setPos(80,loc.spaceY*40-60);u.setVisPos();}
         g.invulner=true;g.disabled=true;g.dx=g.dy=0;g.setPos(baseX,baseY);g.setVisPos();
         b.world.redrawLoc();b.world.cam.setZoom(2); // Native full-map camera, not altered projectile coordinates.
         actor=g;
         if(source) {
            if(CASES[n].npc) {
               var ac:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit.UnitAlicorn") as Class;
               ali=new ac("1",100,<unit tr="1"/>,null);ali.putLoc(loc,baseX,baseY-160);loc.addObj(ali);loc.units.push(ali);
               ali.disabled=true;ali.noAgro=true;ali.trigDis=true;ali.xp=0;ali.shithp=0;actor=ali;gun=ali.currentWeapon;
               check(gun!=null && gun.id=="alilight","real UnitAlicorn owns native moving-lightning weapon");
            } else {
               g.invent.weapons[CASES[n].id]=null;gun=g.invent.addWeapon(String(CASES[n].id));
               if(gun==null)throw new Error("Native inventory cannot create "+CASES[n].id);
               // Permit a fresh test character to equip these weapons. This
               // does not change native physics, spread, recoil or cadence.
               gun.lvl=0;gun.perslvl=0;g.changeWeapon(String(CASES[n].id),true);
               gun.hold=Math.max(1,int(gun.rashod));
               check(g.currentWeapon===gun && g.invent.weapons[CASES[n].id]===gun && g.childObjs.indexOf(gun)>=0,
                  "native inventory owns equipped weapon "+gun.id);
            }
            check(gun.vis!=null && gun.vis.stage!=null,"native source weapon is staged");
            var vc:Class=gun.vBullet as Class,probe:DisplayObject=new vc();expectedClass=getQualifiedClassName(probe);
            gunInfo={weapon:gun.id,cls:expectedClass,speed:gun.speed,speedMult:gun.speedMult,grav:gun.grav,accel:gun.accel,
               deviation:gun.deviation,rapid:gun.rapid,prep:gun.prep,bulAnim:gun.bulAnim,rashod:gun.rashod,spring:gun.spring};
         }
         check(loc.spaceX*40-440>=1000,"native room provides at least 1000 world-pixel flight corridor width="+(loc.spaceX*40));
         Log.d("FLIGHT PREPARE "+JSON.stringify({round:n,role:host?"host":"join",source:source,caseSpec:CASES[n],
            width:loc.spaceX*40,height:loc.spaceY*40,cameraScale:b.world.cam.scaleV,stageRate:mod.stage.frameRate}));
         mark("prepare-complete");
      }
      private function before(e:Event):void {
         gameFrame++;if(mod==null || round<0 || phase=="done")return;
         if(active())mark("first-active-enter");
         var b:Object=mod.game,g:Object=b.gg;b.forceCloseOverlays();g.disabled=true;g.invulner=true;
         g.dx=g.dy=0;g.setPos(baseX,baseY);g.setVisPos();g.storona=CASES[round].left?-1:1;b.world.ctr.keyAttack=false;
         if(source && active() && gun!=null) {
            actor.disabled=true;actor.dx=actor.dy=0;actor.storona=g.storona;
            actor.celX=actor.X+Math.cos(angle)*1200;actor.celY=actor.Y-actor.scY*.7;
            if(actor===g) {
               b.world.celX=g.celX;b.world.celY=g.celY;var cam:Object=b.world.cam;
               cam.celX=int(g.celX*cam.scaleV+cam.vx);cam.celY=int(g.celY*cam.scaleV+cam.vy);
            }
            actor.setWeaponPos(gun.tip);gun.findCel=false;gun.forceRot=angle;
            // Retain native preparation, recoil, RNG spread and bullet speed.
            if(!issued && getTimer()-at>=900)gun.attack();
         }
         mod.stage.invalidate();
      }
      private function after(e:Event):void {
         if(!source || !active() || gun==null)return;
         gun.step(); // Disabled actor: exactly one native weapon step. Bullet.step remains native.
         if(gun.b!=null && gun.b!==bullet) {
            bullet=gun.b;shotCount++;issued=true;phase="flight";
            nativeInfo={weapon:gun.id,cls:getQualifiedClassName(bullet.vis),bullet:getQualifiedClassName(bullet),
               begx:bullet.begx,begy:bullet.begy,dx:bullet.dx,dy:bullet.dy,ddx:bullet.ddx,ddy:bullet.ddy,
               vel:bullet.vel,liv:bullet.liv,rot:bullet.rot,spring:bullet.spring,at:getTimer(),wall:new Date().time,gun:gunInfo};
            check(nativeInfo.cls==expectedClass,"source native class agrees with receiver selection "+nativeInfo.cls);
            Log.d("FLIGHT NATIVE SHOT "+JSON.stringify({round:round,info:nativeInfo}));
            mark("native-shot");
         }
      }
      private function point(v:DisplayObject):Object {
         if(clipIds[v]==null)clipIds[v]=nextClip++;
         var root:DisplayObject=mod.main as DisplayObject,r:Rectangle=v.getBounds(root);
         var hit:Rectangle=r.intersection(new Rectangle(0,0,mod.stage.stageWidth,mod.stage.stageHeight));
         return {id:clipIds[v],x:v.x,y:v.y,rot:v.rotation,sx:v.scaleX,sy:v.scaleY,alpha:v.alpha,
            f:v is MovieClip?MovieClip(v).currentFrame:1,viewport:hit.width>0 && hit.height>0,
            screen:{x:r.x,y:r.y,w:r.width,h:r.height}};
      }
      private function compositedPixels(v:DisplayObject):Object {
         var start:int=getTimer(),root:DisplayObject=mod.main as DisplayObject,r:Rectangle=v.getBounds(root);
         r=r.intersection(new Rectangle(0,0,mod.stage.stageWidth,mod.stage.stageHeight));
         if(r.width<1 || r.height<1 || r.width*r.height>150000)return {pixels:0,reason:"outside viewport or oversized",costMs:getTimer()-start};
         var a:BitmapData=new BitmapData(Math.ceil(r.width),Math.ceil(r.height),false,0),b:BitmapData=a.clone();
         var m:Matrix=new Matrix(1,0,0,1,-r.x,-r.y),visible:Boolean=v.visible,n:int=0;
         try {
            a.draw(root,m);v.visible=false;b.draw(root,m);
            var av:Vector.<uint>=a.getVector(a.rect),bv:Vector.<uint>=b.getVector(b.rect);
            for(var i:int=0;i<av.length;i++)if(av[i]!=bv[i])n++;
         } finally {v.visible=visible;a.dispose();b.dispose();}
         return {pixels:n,costMs:getTimer()-start,wall:new Date().time,frame:gameFrame};
      }
      private function render(e:Event):void {
         if(!active())return;
         try {
            mark("first-active-render");
            var stamp:int=getTimer(),record:Object={at:stamp,wall:new Date().time,render:++renderNo,frame:gameFrame,clips:[]};
            var v:DisplayObject,probeVisual:DisplayObject;
            if(source) {
               if(bullet!=null) {
                  v=bullet.vis as DisplayObject;
                  record.native={x:bullet.X,y:bullet.Y,dx:bullet.dx,dy:bullet.dy,liv:bullet.liv,
                     inChain:bullet.in_chain,ended:bullet.babah};
                  if(v!=null && v.visible && v.stage!=null && v.alpha>0){record.clips.push(point(v));probeVisual=v;}
                  if(bullet.babah===true && sourceContact==null) {
                     sourceContact={at:stamp,wall:record.wall,x:bullet.X,y:bullet.Y};mark("native-contact");
                     // One diagnostic notification at actual native contact,
                     // so the receiver can probe the buffered contact artwork.
                     // It never drives production playback or filters frames.
                     send("contact",{contact:sourceContact});
                  }
                  if(!bullet.in_chain && sourceEnd==null) {
                     sourceEnd={at:stamp,wall:record.wall,x:bullet.X,y:bullet.Y,liv:bullet.liv};phase="drain";
                     mark("native-end");
                  }
               }
            } else {
               var layer:DisplayObjectContainer=mod.game.world.grafon.visObjs[2];
               for(var i:int=0;i<layer.numChildren;i++) {
                  v=layer.getChildAt(i);
                  if(getQualifiedClassName(v)!=expectedClass || !v.visible || v.alpha<=0 || v.stage==null)continue;
                  record.clips.push(point(v));if(probeVisual==null)probeVisual=v;
               }
               peak=Math.max(peak,record.clips.length);
            }
            if(record.clips.length>0) {
               mark("first-visible-render");
               lastVisibleWall=record.wall;
               // One paired final-composite pixel probe per side/trial. Its
               // raw cost stays in the trace; no slow frames are discarded.
               if(!pixelTried) {
                  pixelTried=true;pixelProof=compositedPixels(probeVisual);record.probe=pixelProof;
               }
               if(sourceContact!=null && delta(record.clips[0],sourceContact)<=.25) {
                  mark("first-contact-render");
                  if(!contactTried) {
                     contactTried=true;contactProof=compositedPixels(probeVisual);record.contactProbe=contactProof;
                  }
               }
            }
            frames.push(record);
         } catch(err:Error){check(false,"render "+err.getStackTrace());send("done");finish();}
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;if(p.type!="native-flight-continuity-test"){observeWire(p);return;}
         try {
            if(p.stage=="ready" && host && phase=="boot"){setup();prepare(0);send("prepare",{cls:expectedClass});}
            else if(p.stage=="prepare" && !host){if(phase=="boot")setup();prepare(int(p.round));if(!source)expectedClass=p.cls;send("prepared",{cls:expectedClass});}
            else if(p.stage=="prepared" && host && int(p.round)==round){if(!source)expectedClass=p.cls;phase="armed";at=getTimer();mark("armed");send("start");}
            else if(p.stage=="start" && !host && int(p.round)==round){phase="armed";at=getTimer();mark("armed");}
            else if(p.stage=="contact" && !source && int(p.round)==round){sourceContact=p.contact;mark("contact-received");}
            else if(p.stage=="trace" && !source && int(p.round)==round) {
               nativeFrames=p.frames;nativeInfo=p.info;sourceEnd=p.end;sourceMeta=p.meta;traceAt=getTimer();phase="drain";
               sourceContact=p.contact;mark("trace-received");
            }
            else if(p.stage=="result" && source && int(p.round)==round){if(host)advance();else{phase="wait";send("advance");}}
            else if(p.stage=="advance" && host && !source && int(p.round)==round)advance();
            else if(p.stage=="done")finish();
         } catch(err:Error){check(false,err.getStackTrace());send("done");finish();}
      }
      // Passive incoming production packets only; no private state access,
      // no hooks and no per-packet log writes. Single-shot traces stay bounded.
      private function observeWire(p:Object):void {
         if(source || !active() || round<0 || p==null)return;
         if(p.snap!=null)observeGuns(p.snap.weapons,p.snap.sampleTime,String(p.type));
         if(p.players is Array)for each(var player:Object in p.players)if(player.snap!=null)
            observeGuns(player.snap.weapons,player.snap.sampleTime,String(p.type));
         if(p.units is Array)for each(var unit:Object in p.units)observeGuns(unit.weapons,unit.sampleTime,String(p.type));
         if(p.enemyMotion is Array)for each(unit in p.enemyMotion){observeGuns(unit.effects,unit.sampleTime,String(p.type));observeGuns(unit.weapons,unit.sampleTime,String(p.type));}
      }
      private function observeGuns(guns:*,ownerStamp:*,type:String):void {
         if(!(guns is Array))return;
         for each(var g:Object in guns)if(g!=null && g.id==CASES[round].id && g.events is Array)
            for each(var event:Object in g.events) {
               var f:Object=event.flight;if(f==null || f.cls!=expectedClass)continue;
               var samples:Array=[];if(f.frames is Array)for each(var p:Object in f.frames)samples.push({at:p.at,x:p.x,y:p.y,f:p.f});
               if(wire.length>=1024){check(false,"passive wire trace capacity exceeded");return;}
               wire.push({at:getTimer(),wall:new Date().time,frame:gameFrame,type:type,ownerStamp:ownerStamp,
                  sampleTime:g.sampleTime,stream:g.stream,seq:event.seq,stopAt:f.stopAt,end:f.end,samples:samples});
               mark("first-production-flight-received");
            }
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null || mod.game==null || mod.game.gg==null)return;
         if(host)for each(var l:TcpLink in mod.session.server.clients)watch(l);else watch(mod.session.link);
         mod.game.gg.invulner=true;
         if(mod.game.world.clickReq==1){mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN,true));mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP,true));}
         if(!mod.session.rooms.ready || mod.session.rooms.busy || mod.game.isTransitioning())return;
         try {
            if(phase=="boot" && !host && timer.currentCount>160 && getTimer()-readyAt>500){readyAt=getTimer();send("ready");}
            if(source && sourceEnd!=null && !traceSent && getTimer()-int(sourceEnd.at)>=500) {
               traceSent=true;
               check(shotCount==1,"exactly one native projectile count="+shotCount);
               check(pixelProof!=null && pixelProof.pixels>0,"source final-composite artwork "+JSON.stringify(pixelProof));
               mark("source-trace-send");
               var meta:Object={stageRate:mod.stage.frameRate,pixelProof:pixelProof,contactProof:contactProof,shotCount:shotCount};
               Log.d("FLIGHT SOURCE TRACE "+JSON.stringify({round:round,role:host?"host":"join",info:nativeInfo,end:sourceEnd,contact:sourceContact,meta:meta,phases:phases,frames:frames}));
               send("trace",{frames:frames,info:nativeInfo,end:sourceEnd,contact:sourceContact,meta:meta});
            }
            if(!source && traceAt>0 && phase=="drain" && getTimer()-traceAt>=900){evaluate();phase="wait";send("result");}
            if(phase!="boot" && phase!="done" && getTimer()-at>18000){check(false,"timeout "+phase);send("done");finish();}
            if(phase=="boot" && getTimer()-at>180000){check(false,"boot timeout");send("done");finish();}
         } catch(err:Error){check(false,err.getStackTrace());send("done");finish();}
      }
      private static function visibleSamples(list:Array):Array {
         var out:Array=[];for each(var row:Object in list)if(row.clips.length>0) {
            var p:Object=row.clips[0];out.push({at:row.at,wall:row.wall,frame:row.frame,render:row.render,
               x:p.x,y:p.y,rot:p.rot,f:p.f,id:p.id,viewport:p.viewport});
         }return out;
      }
      private static function delta(a:Object,b:Object):Number {var x:Number=b.x-a.x,y:Number=b.y-a.y;return Math.sqrt(x*x+y*y);}
      private static function summary(rows:Array):Object {
         var p:Array=visibleSamples(rows),gaps:Array=[],maxGap:Number=0,hold:Number=0,maxHold:Number=0,moves:int=0,offscreen:int=0;
         var frameHold:Number=0,maxFrameHold:Number=0,animationChanges:int=0;
         for(var i:int=0;i<p.length;i++) {
            if(!p[i].viewport)offscreen++;
            if(i>0){var dt:Number=p[i].at-p[i-1].at;maxGap=Math.max(maxGap,dt);gaps.push(dt);
               if(delta(p[i],p[i-1])<=.25)hold+=dt;else{moves++;hold=0;}maxHold=Math.max(maxHold,hold);
               if(p[i].f==p[i-1].f)frameHold+=dt;else{animationChanges++;frameHold=0;}maxFrameHold=Math.max(maxFrameHold,frameHold);}
         }
         gaps.sort(Array.NUMERIC);
         var entireGap:Number=0;for(i=1;i<rows.length;i++)entireGap=Math.max(entireGap,rows[i].at-rows[i-1].at);
         return {visibleSamples:p.length,moves:moves,offscreen:offscreen,maxHoldMs:maxHold,maxVisibleGapMs:maxGap,
            visibleGameFrames:distinctGameFrames(rows),
            animationChanges:animationChanges,maxAnimationHoldMs:maxFrameHold,
            p95VisibleGapMs:gaps.length?gaps[Math.min(gaps.length-1,int(gaps.length*.95))]:0,
            maxRecordedRenderGapMs:entireGap,first:p.length?p[0]:null,last:p.length?p[p.length-1]:null,
            visibleDurationMs:p.length?p[p.length-1].at-p[0].at:0};
      }
      private static function phasesOf(rows:Array,contact:Object):Object {
         var split:int=-1,last:int=-1;
         for(var i:int=0;i<rows.length;i++)if(rows[i].clips.length>0) {
            last=i;if(split<0 && contact!=null && delta(rows[i].clips[0],contact)<=.25)split=i;
         }
         return {flight:split<0?rows:rows.slice(0,split+1),contact:split<0?[]:rows.slice(split,last+1)};
      }
      private static function distinctGameFrames(rows:Array):int {
         var seen:Object={},count:int=0;
         for each(var row:Object in rows)if(row.clips.length>0 && !seen[String(row.frame)]){seen[String(row.frame)]=true;count++;}
         return count;
      }
      private function evaluate():void {
         mark("evaluate");
         var sp:Array=visibleSamples(nativeFrames),rp:Array=visibleSamples(frames),ss:Object=summary(nativeFrames),rs:Object=summary(frames);
         var splitS:Object=phasesOf(nativeFrames,sourceContact),splitR:Object=phasesOf(frames,sourceContact);
         var sf:Object=summary(splitS.flight),rf:Object=summary(splitR.flight),sc:Object=summary(splitS.contact),rc:Object=summary(splitR.contact);
         var path:Array=sp.concat(),total:Number=0,maxStep:Number=0,maxDistance:Number=0,minProgress:Number=Number.POSITIVE_INFINITY;
         var maxProgress:Number=0,prior:Number=-1,reverse:int=0,arc:Array=[0];
         // The native muzzle is an observed creation point, not a predicted
         // position. Include it so a correct first interpolated sample does
         // not fail merely because source RENDER first saw one step later.
         if(nativeInfo!=null)path.unshift({x:nativeInfo.begx,y:nativeInfo.begy});
         if(path.length>0 && sourceEnd!=null)path.push({x:sourceEnd.x,y:sourceEnd.y});
         for(var i:int=1;i<path.length;i++){var len:Number=delta(path[i-1],path[i]);total+=len;maxStep=Math.max(maxStep,len);arc.push(total);}
         for each(var p:Object in rp) {
            var best:Number=Number.POSITIVE_INFINITY,progress:Number=0;
            for(i=0;i<path.length-1;i++) {
               var a:Object=path[i],b:Object=path[i+1],dx:Number=b.x-a.x,dy:Number=b.y-a.y,d2:Number=dx*dx+dy*dy;
               var u:Number=d2>0?Math.max(0,Math.min(1,((p.x-a.x)*dx+(p.y-a.y)*dy)/d2)):0;
               var ex:Number=p.x-a.x-dx*u,ey:Number=p.y-a.y-dy*u,d:Number=Math.sqrt(ex*ex+ey*ey);
               if(d<best){best=d;progress=arc[i]+Math.sqrt(d2)*u;}
            }
            maxDistance=Math.max(maxDistance,best);minProgress=Math.min(minProgress,progress);maxProgress=Math.max(maxProgress,progress);
            if(prior>=0 && progress<prior-1)reverse++;prior=progress;
         }
         var tailGap:Number=Math.max(0,total-maxProgress),coverage:Number=total>0?(maxProgress-minProgress)/total:0;
         var allowedGap:Number=Math.max(85,Number(ss.p95VisibleGapMs)*1.5+15);
         var result:Object={source:ss,remote:rs,sourceFlight:sf,remoteFlight:rf,sourceContact:sc,remoteContact:rc,
            peak:peak,pixelProof:pixelProof,contactProof:contactProof,sourceMeta:sourceMeta,
            maxPathError:maxDistance,maxNativeStep:maxStep,sourcePathLength:total,tailGap:tailGap,coverage:coverage,reverse:reverse,
            startLagMs:sp.length && rp.length?rp[0].wall-sp[0].wall:null,
            lastVisibleVsNativeEndMs:rp.length?rp[rp.length-1].wall-sourceEnd.wall:null,
            allowedRenderGapMs:allowedGap,functionalOnly:true,performanceQualified:false};
         check(sp.length>=3 && rp.length>=3 && ss.visibleGameFrames>=3 && rs.visibleGameFrames>=3,
            "actual native and final-render trajectories source="+sp.length+" remote="+rp.length+" gameFrames="+ss.visibleGameFrames+"/"+rs.visibleGameFrames);
         check(peak==1 && reverse==0,"one remote projectile with no reversed progress peak="+peak+" reverse="+reverse);
         check(pixelProof!=null && pixelProof.pixels>0 && rs.offscreen==0,"remote final-composite native artwork "+JSON.stringify(pixelProof)+" offscreen="+rs.offscreen);
         check(rp.length>0 && maxDistance<=3,"final-render path follows source maxError="+maxDistance);
         check(rp.length>0 && rf.moves>=2 && rf.maxHoldMs<=85,"flight has no 85ms position stall maxHold="+rf.maxHoldMs+" moves="+rf.moves);
         check(rp.length>0 && rs.maxVisibleGapMs<=allowedGap,"final-render gaps sourceP95="+ss.p95VisibleGapMs+" remoteMax="+rs.maxVisibleGapMs+" limit="+allowedGap);
         if(sf.animationChanges>=2)check(rf.animationChanges>=1 && rf.maxAnimationHoldMs<=Number(sf.maxAnimationHoldMs)*1.5+85,
            "native animated flight frames advance sourceChanges="+sf.animationChanges+" remoteChanges="+rf.animationChanges+" remoteFrameHold="+rf.maxAnimationHoldMs);
         var contactFrames:Object={},tailFrames:Boolean=true,stationary:Boolean=true;
         for each(var cp:Object in visibleSamples(splitS.contact))contactFrames[String(cp.f)]=true;
         for each(cp in visibleSamples(splitR.contact)) {
            if(!contactFrames[String(cp.f)])tailFrames=false;
            if(sourceContact==null || delta(cp,sourceContact)>.25)stationary=false;
         }
         check(sourceContact!=null && sourceMeta.contactProof!=null && sourceMeta.contactProof.pixels>0 && contactProof!=null && contactProof.pixels>0,
            "native contact tail has source and remote composite pixels source="+JSON.stringify(sourceMeta.contactProof)+" remote="+JSON.stringify(contactProof));
         check(distinctGameFrames(splitR.contact)>=2 && stationary && tailFrames &&
            Math.abs(Number(rc.visibleDurationMs)-Number(sc.visibleDurationMs))<=allowedGap,
            "contact tail retains native position/frame/duration sourceMs="+sc.visibleDurationMs+" remoteMs="+rc.visibleDurationMs+" gameFrames="+distinctGameFrames(splitR.contact));
         if(sc.animationChanges>=2)check(rc.animationChanges>=1 && rc.maxAnimationHoldMs<=Number(sc.maxAnimationHoldMs)*1.5+85,
            "native animated contact tail advances sourceChanges="+sc.animationChanges+" remoteChanges="+rc.animationChanges);
         check(total>0 && coverage>=.65 && tailGap<=Math.max(20,maxStep*1.1),"visible tail preserved coverage="+coverage+" tailGap="+tailGap+" sourceMaxStep="+maxStep);
         check(lastVisibleWall>0 && new Date().time-lastVisibleWall>=500,"native end clears remote projectile age="+(new Date().time-lastVisibleWall));
         Log.d("FLIGHT REMOTE TRACE "+JSON.stringify({round:round,role:host?"host":"join",info:nativeInfo,end:sourceEnd,contact:sourceContact,result:result,phases:phases,wire:wire,frames:frames}));
      }
      private function advance():void {if(round+1<CASES.length){prepare(round+1);send("prepare",{cls:expectedClass});}else{send("done");finish();}}
      private function finish():void {
         if(phase=="done")return;phase="done";timer.stop();
         if(mod!=null) {
            mod.stage.removeEventListener(Event.ENTER_FRAME,before);mod.stage.removeEventListener(Event.ENTER_FRAME,after);mod.stage.removeEventListener(Event.RENDER,render);
            removeGun();
            if(oldWeapons!=null){var g:Object=mod.game.gg;g.changeWeapon("not",true);g.invent.weapons=oldWeapons;
               g.currentWeapon=oldGun;g.childObjs=oldChildren;g.magicWeapon=oldMagic;g.throwWeapon=oldThrow;
               if(oldGun!=null)oldGun.addVisual();mod.game.world.cam.setZoom(oldZoom);}
         }
         Log.d("COOP EFFECTS DONE native-flight-continuity "+(host?"host":"join"));
      }
   }
}

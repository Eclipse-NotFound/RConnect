package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.MovieClip;
   import flash.display.BitmapData;
   import flash.display.PNGEncoderOptions;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.events.MouseEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.geom.Matrix;
   import flash.geom.Rectangle;
   import flash.utils.Dictionary;
   import flash.utils.ByteArray;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import flash.utils.getQualifiedClassName;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;
   import rconnect.game.MirrorHitUnit;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;

   /** Native Weapon.attack/step -> Bullet -> Part, with final rendered pixels
    * observed on both ends of real Session/TCP. No energy helper is imported:
    * the same driver also runs against the installed build as a negative control.
    */
   public class EnergyImpactTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private static const DEFAULT_CASES:Array=[
         {id:"nova",actor:"host",target:"wall"},{id:"nova",actor:"join",target:"wall"},
         {id:"plam",actor:"host",target:"wall"},{id:"plam",actor:"join",target:"wall"},
         {id:"blaster",actor:"host",target:"unit"},{id:"blaster",actor:"join",target:"unit"},
         {id:"prism",actor:"host",target:"wall"},{id:"prism",actor:"join",target:"wall"},
         {id:"alilight",actor:"enemy",target:"wall"},
         {id:"plamg",actor:"host",target:"expiry"},{id:"plamg",actor:"join",target:"expiry"}];
      private var cases:Array=DEFAULT_CASES,ballistic:Boolean=false;
      private static const CLIPS:Object={flPlasma:true,flPlasma2:true,flLaser:true,flLaser2:true,
         flSpark:true,flSparkl:true,flDray:true,visualTeleFlare:true,visualIceFlare:true,
         flPlevok:true,flPinkPlevok:true,visualBum:true,visualBumNecro:true,visualBlast:true,visualGwall:true,visualFlame:true};
      private var mod:RConnectMod,host:Boolean,timer:Timer=new Timer(100),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=getTimer(),readyAt:int=0,round:int=0;
      private var baseX:Number,baseY:Number,wallX:int,gun:Object,actor:Object,target:Object;
      private var oldGun:Object,oldChildren:Object,oldMagic:Object,oldThrown:Object,enemyActor:Object,shot:Boolean=false,localSource:Boolean=false;
      private var nativeObjects:Dictionary=new Dictionary(true),copies:Dictionary=new Dictionary(true),shots:Dictionary=new Dictionary(true);
      private var contacts:Dictionary=new Dictionary(true),nativeContacts:int=0;
      private var source:Array=[],remote:Array=[],sourcePixels:int=0,remotePixels:int=0,nativeShots:int=0;
      private var localResult:Object,peerResult:Object,compared:Boolean=false,peerDone:Boolean=false;
      private var localPrepared:Boolean=false,peerPrepared:Boolean=false,targetHp:Number=0,frames:int=0;
      private var nativeSpell:Object;
      private var wireSeen:Object={};
      private var wirePackets:int=0,wireImpactPackets:int=0,wireSummary:String="";
      private var diagnosticParts:Dictionary=new Dictionary(true),diagnosticPartCount:int=0;
      private var pixelMs:int=0,pixelMax:int=0,pixelCalls:int=0,renderGap:int=0,previousRender:int=0;
      private var pixelMeasures:Array=[],lastPixel:Object,pendingPictures:Array=[];
      private var waitLand:String,flightClasses:Object={},flightPoints:Object={},flightSeen:Dictionary=new Dictionary();
      private var flightFrames:int=0,flightMoves:int=0,flightHolds:int=0,flightIntermediate:int=0;

      public function EnergyImpactTestDoc(scenarios:Array=null,hardImpact:Boolean=false,expectedLand:String="") {
         waitLand=expectedLand;
         if(scenarios!=null)cases=scenarios;ballistic=hardImpact;
         var id:String=NativeApplication.nativeApplication.applicationID;
         if(id.indexOf("rconnect-coop-")<0)return;host=id.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();send("done");finish();
         });
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,label:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"energy-impact "+label+" case="+round);}
      private function send(stage:String,data:Object=null):void {
         data=data||{};data.type="energy-impact-test";data.stage=stage;data.round=round;
         if(host)mod.session.server.broadcast(data);else if(mod.session.link!=null)mod.session.link.send(data);
      }
      private function watch(link:TcpLink):void {if(link!=null && !links[link]) {links[link]=true;link.addEventListener(TcpLink.MESSAGE,receive);}}
      private function setup(x:Number,y:Number):void {
         baseX=x;baseY=y;wallX=int((baseX+280)/40);
         var g:Object=mod.game.gg;oldGun=g.currentWeapon;oldChildren=g.childObjs.concat();
         oldMagic=g.magicWeapon;oldThrown=g.throwWeapon;
         // This driver isolates actual hit artwork. Flight interpolation is
         // qualified by the separate cadence suite, not by this impact fixture.
         mod.game.gg.anim();
         mod.game.loc.black=false;mod.game.world.black=false;mod.game.loc.tileSpawn=0;
         mod.stage.addEventListener(Event.ENTER_FRAME,before,false,100000);
         mod.stage.addEventListener(Event.ENTER_FRAME,after,false,-6000);
         mod.stage.addEventListener(Event.RENDER,render,false,-30000);
      }
      private function prepare(n:int):void {
         round=n;phase="prepare";at=getTimer();shot=false;compared=peerDone=localPrepared=peerPrepared=false;
         source=[];remote=[];nativeObjects=new Dictionary(true);copies=new Dictionary(true);shots=new Dictionary(true);
         contacts=new Dictionary(true);nativeContacts=0;
         sourcePixels=remotePixels=nativeShots=frames=0;localResult=peerResult=null;
         pixelMs=pixelMax=pixelCalls=renderGap=previousRender=0;
         pixelMeasures=[];lastPixel=null;
         wireSeen={};
         wirePackets=wireImpactPackets=diagnosticPartCount=0;wireSummary="";diagnosticParts=new Dictionary(true);
         flightClasses={};flightPoints={};flightSeen=new Dictionary();flightFrames=flightMoves=flightHolds=flightIntermediate=0;
         cleanupGun();
         localSource=cases[n].actor==(host?"host":"join") || (host && cases[n].actor=="enemy");
         target=null;
         var loc:Object=mod.game.loc;
         if(host) {
            var layout:Array=[];
            for(var x:int=Math.max(1,int(baseX/40)-2);x<=Math.min(loc.spaceX-2,wallX+2);x++)
               for(var y:int=Math.max(1,int(baseY/40)-6);y<=Math.min(loc.spaceY-2,int(baseY/40));y++) {
                  var wall:Boolean=x==wallX && cases[n].target!="expiry";
                  layout.push({x:x,y:y,p:wall?1:0,f:wall?"A":"",h:300,o:wall?1:0});
               }
            mod.game.applyTilePatch(layout);
            // Damage is disabled for fixture terrain, while the real material
            // still goes through native collision and Bullet.popadalo.
            for(y=Math.max(1,int(baseY/40)-6);y<=Math.min(loc.spaceY-2,int(baseY/40));y++) {
               loc.space[wallX][y].mat=cases[n].mat==null?2:int(cases[n].mat);loc.space[wallX][y].indestruct=true;loc.space[wallX][y].water=0;
            }
            if(cases[n].target=="unit")target=spawn(cases[n].metal===true?"UnitRobobrain":"UnitZombie","1",<unit tr="1" dig="0"/>,baseX+targetOffset());
            if(cases[n].actor=="enemy")enemyActor=spawn("UnitAlicorn","1",<unit tr="1"/>,baseX);
            mod.game.readUnitsSnapshot();mod.game.readTilePatch();
            send("case",{layout:layout});
         }
         if(localSource) {
            actor=cases[n].actor=="enemy"?enemyActor:mod.game.gg;
            if(actor===mod.game.gg){actor.mana=10000;actor.pers.manaHP=10000;actor.pers.spellsPoss=1;}
            if(cases[n].spell===true) {
               var spellClass:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit.Spell") as Class;
               nativeSpell=new spellClass(actor,String(cases[n].id));
               check(nativeSpell!=null,"real Spell constructed "+cases[n].id);return;
            }
            var factory:Object=mod.main.loaderInfo.applicationDomain.getDefinition("fe.weapon.Weapon");
            if(actor===mod.game.gg) {
               // The full mod set observes Invent-owned weapons. A detached
               // Weapon.create fixture can trigger FA's missing-state error.
               gun=mod.game.world.invent.addWeapon(String(cases[n].id));
               if(actor.currentWeapon!==gun)actor.changeWeapon(String(cases[n].id),true);
               check(gun!=null && actor.currentWeapon===gun && mod.game.world.invent.weapons[String(cases[n].id)]===gun,
                  "native inventory owns equipped "+cases[n].id);
            } else {
               gun=factory.create(actor,String(cases[n].id),0);
               actor.currentWeapon=gun;actor.childObjs=[gun];gun.addVisual();
            }
            gun.hold=10000;gun.t_reload=0;gun.precision=0;gun.deviation=0;gun.recoil=0;gun.recoilUp=0;
            gun.lvl=0;gun.perslvl=0;
            gun.skillConf=1;gun.damage=10;gun.destroy=0;gun.damageExpl=0;gun.critCh=0;gun.dopCh=0;
            // Explicit long-flight fixture for the 700 ms record-retirement
            // boundary. Native attack, Bullet.step and collision still execute.
            if(cases[n].slow===true)gun.speed=10;
            check(gun.vis!=null && gun.vis.stage!=null,"real "+cases[n].id+" weapon staged with "+gun.kol+" native projectiles");
         }
      }
      private function spawn(name:String,id:String,xml:XML,x:Number):Object {
         var cls:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit."+name) as Class;
         var u:Object=new cls(id,100,xml,null);u.putLoc(mod.game.loc,x,baseY);mod.game.loc.units.push(u);
         // Keep a real stationary native Unit in the collision list without
         // running its AI; this is a fixture target, not a second implementation.
         u.addVisual();u.setVisPos();u.hp=u.maxhp=54321+round;u.skin=0;u.armor=0;u.dexter=0;u.dodge=0;
         u.invulner=false;u.disabled=false;u.trigDis=false;u.doop=true;u.lootIsDrop=true;u.xp=0;
         u.scX=40;u.scY=80;u.setPos(x,baseY);u.animate();return u;
      }
      private function findTarget():Object {
         for each(var u:Object in mod.game.loc.units)
            if(!(u is MirrorHitUnit) && getQualifiedClassName(u)==(cases[round].metal===true?"fe.unit::UnitRobobrain":"fe.unit::UnitZombie") && Number(u.maxhp)==54321+round)return u;
         return null;
      }
      private function begin():void {phase="run";at=getTimer();targetHp=target==null?0:Number(target.hp);}
      private function targetOffset():Number {return cases[round].melee===true?60:180;}
      private function before(e:Event):void {
         if(phase=="done" || phase=="boot")return;
         var g:Object=mod.game.gg,w:Object=mod.game.world;
         g.setPos(baseX,baseY);g.dx=g.dy=0;g.disabled=true;g.invulner=true;g.storona=1;
         mod.game.forceCloseOverlays();w.testDam=true;
         for each(var u:Object in mod.game.loc.units) {
            if(u===g || u===target || u===enemyActor || u is MirrorHitUnit || String(u.id).indexOf("rconnect_ghost")==0)continue;
            u.disabled=true;
            // A disabled mirror body can still have a live collision receiver.
            // Move unrelated source enemies behind the muzzle; the setup wait
            // lets their authoritative positions arrive before the test shot.
            if(host) {u.setPos(baseX-60,baseY);u.dx=u.dy=0;u.setVisPos();}
         }
         if(target!=null && host) {target.disabled=false;target.dx=target.dy=0;target.setPos(baseX+targetOffset(),baseY);target.setVisPos();}
         if(nativeSpell!=null && phase=="run" && !shot && getTimer()-at>1000) {
            shot=true;
            var castOK:Boolean=nativeSpell.cast(baseX+160,baseY-80);
            check(castOK,"native Spell.cast succeeds with native mana and line checks");
            if(castOK)nativeShots++;
         }
         if(gun==null)return;
         actor.celX=baseX+(cases[round].melee===true?targetOffset():500);actor.celY=baseY-40;
         if(actor===g) {
            w.celX=actor.celX;w.celY=actor.celY;
            w.cam.celX=int(w.celX*w.cam.scaleV+w.cam.vx);w.cam.celY=int(w.celY*w.cam.scaleV+w.cam.vy);
         } else {actor.storona=1;actor.setWeaponPos(gun.tip);}
         // alilight has native preparation time. Keep requesting the attack
         // until native Weapon.step actually creates a projectile.
         if(phase=="run" && (!shot || int(cases[round].burst)>0 && nativeShots<int(cases[round].burst)*gun.kol) && getTimer()-at>1000) {
            if(!cases[round].burst){gun.hold=10000;gun.t_reload=0;}
            // Semi-automatic weapons require a real release interval. Holding
            // attack() every frame extends native t_auto and never fires again.
            if(!cases[round].burst || gun.auto || gun.t_auto<=0)gun.attack();
         }
      }
      private function after(e:Event):void {
         if(phase=="done" || phase=="boot")return;
         if(gun!=null) {
            gun.step();
            if(cases[round].melee===true && !shot && Number(gun.t_attack)>0) {nativeShots=1;shot=true;}
            for(var b:Object=mod.game.loc.firstObj;b!=null;b=b.nobj) {
               if(GameBridge.probe(b,"weap")!==gun || GameBridge.probe(b,"begx")==null)continue;
               if(GameBridge.probe(b,"tilehit")===true && !contacts[b]){
                  contacts[b]=true;nativeContacts++;
                  if(ballistic && round<=1) {
                     var nearby:Array=[];
                     for(var part:Object=mod.game.loc.firstObj;part!=null;part=part.nobj) {
                        if(getQualifiedClassName(part)!="fe.graph::Part" || Math.abs(Number(part.X)-Number(b.X))>40 || Math.abs(Number(part.Y)-Number(b.Y))>40)continue;
                        nearby.push({x:part.X,y:part.Y,liv:part.liv,mliv:part.mliv,age:Number(part.mliv)-Number(part.liv),
                           dx:part.dx,dy:part.dy,withinCaptureBox:Math.abs(Number(part.X)-Number(b.X))<=20 && Math.abs(Number(part.Y)-Number(b.Y))<=25,
                           sparks:part.blitData===mod.game.world.grafon.getSpriteList("sprIskr",1)});
                     }
                     Log.d("BALLISTIC SOURCE CONTACT "+JSON.stringify({round:round,at:getTimer(),wall:new Date().time,
                        x:b.X,y:b.Y,vel:b.vel,dx:b.dx,dy:b.dy,tipDecal:b.tipDecal,babah:b.babah,
                        inChain:b.in_chain,explRadius:b.explRadius,ownerMatches:gun.owner===actor,weaponLocMatches:gun.loc===mod.game.loc,
                        roomHold:mod.game.roomHold,active:mod.game.loc.active,
                        clip:b.vis==null?null:getQualifiedClassName(b.vis),frame:b.vis is MovieClip?MovieClip(b.vis).currentFrame:0,
                        nearby:nearby}));
                  }
               }
               if(shots[b])continue;
               shots[b]=true;nativeShots++;b.miss=0;b.critCh=0;b.critInvis=0;b.desintegr=0;b.probiv=0;b.precision=0;
               if(cases[round].target=="expiry")b.liv=1;
            }
            if(nativeShots>0)shot=true;
         }
         mod.stage.invalidate();
      }
      private function point(v:DisplayObject):Object {
         return {x:v.x,y:v.y,r:v.rotation,sx:v.scaleX,sy:v.scaleY,a:v.alpha,f:v is MovieClip?MovieClip(v).currentFrame:1};
      }
      private function record(map:Dictionary,list:Array,key:Object,v:DisplayObject):void {
         var s:Object=map[key];
         if(s==null) {s=map[key]={cls:getQualifiedClassName(v),first:getTimer()-at,last:0,frames:[]};list.push(s);}
         s.last=getTimer()-at;s.frames.push(point(v));
         // Prove the native and remote effect artwork in the final game once
         // per case, then keep observing every distinct particle and pose.
         // CPU BitmapData draws per particle distort short animation timing.
         if((list===source && sourcePixels==0) || (list===remote && remotePixels==0)) {
            var began:int=getTimer(),beganWall:Number=new Date().time,count:int=pixels(v),cost:int=getTimer()-began;
            pixelCalls++;pixelMs+=cost;pixelMax=Math.max(pixelMax,cost);
            if(pixelMeasures.length<32)pixelMeasures.push({call:pixelCalls,renderFrame:frames,started:began,
               ended:getTimer(),wallStart:beganWall,wallEnd:new Date().time,totalMs:cost,pixels:count,
               source:list===source,stages:lastPixel});
            if(count>0) {if(list===source)sourcePixels=1;else remotePixels=1;}
         }
      }
      private function pixels(v:DisplayObject):int {
         lastPixel={allocationMs:0,pairDrawMs:0,pixelCompareMs:0,screenshotAllocationMs:0,screenshotDrawMs:0,pngDeferred:true};
         if(v==null || !v.visible || v.stage==null || v.alpha<=0)return 0;
         var root:DisplayObject=mod.main as DisplayObject;
         var r:Rectangle=v.getBounds(root).intersection(new Rectangle(0,0,mod.stage.stageWidth,mod.stage.stageHeight));
         if(r.width<1 || r.height<1 || r.width*r.height>150000)return 0;
         var began:int=getTimer();
         var a:BitmapData=new BitmapData(Math.ceil(r.width),Math.ceil(r.height),false,0),b:BitmapData=a.clone();
         lastPixel.allocationMs=getTimer()-began;began=getTimer();
         var m:Matrix=new Matrix(1,0,0,1,-r.x,-r.y);a.draw(root,m);v.visible=false;
         try {b.draw(root,m);}finally {v.visible=true;}
         lastPixel.pairDrawMs=getTimer()-began;began=getTimer();
         var av:Vector.<uint>=a.getVector(a.rect),bv:Vector.<uint>=b.getVector(b.rect),count:int=0;
         for(var i:int=0;i<av.length;i++)if(av[i]!=bv[i])count++;
         lastPixel.pixelCompareMs=getTimer()-began;
         if(count>0 && (round==0 || round==2 || round==6)) {
            // Keep the exact successful native display now. PNG compression
            // and disk I/O must not block this particle loop or the next shot.
            // At most the three legacy screenshot rounds retain a full bitmap.
            began=getTimer();
            var picture:BitmapData=new BitmapData(mod.stage.stageWidth,mod.stage.stageHeight,false,0);
            lastPixel.screenshotAllocationMs=getTimer()-began;
            began=getTimer();var captureWall:Number=new Date().time;
            picture.draw(root);
            var captureEnd:int=getTimer(),captureEndWall:Number=new Date().time;
            lastPixel.screenshotDrawMs=captureEnd-began;
            // Preserve the old last-write-wins filename when both source and
            // copy evidence happen to be sampled in one case.
            for(i=pendingPictures.length-1;i>=0;i--)if(int(pendingPictures[i].round)==round) {
               BitmapData(pendingPictures[i].picture).dispose();pendingPictures.splice(i,1);
            }
            pendingPictures.push({round:round,picture:picture,capturedAt:began,capturedWall:captureWall,
               captureEndedAt:captureEnd,captureEndedWall:captureEndWall,drawMs:lastPixel.screenshotDrawMs,
               allocationMs:lastPixel.screenshotAllocationMs,renderFrame:frames});
         }
         a.dispose();b.dispose();return count;
      }
      private function exportPictures():void {
         // Called only after phase=done and the action observers are removed.
         // This work is evidence export, never part of an impact timing sample.
         while(pendingPictures.length>0) {
            var item:Object=pendingPictures.shift(),picture:BitmapData=item.picture as BitmapData;
            var encoded:ByteArray=null,stream:FileStream=null,opened:Boolean=false;
            var began:int=getTimer(),wall:Number=new Date().time,encodedAt:int=0;
            try {
               encoded=picture.encode(picture.rect,new PNGEncoderOptions());encodedAt=getTimer();
               var path:File=File.applicationStorageDirectory.resolvePath("presentation-impact-"+item.round+".png");
               stream=new FileStream();stream.open(path,FileMode.WRITE);opened=true;
               stream.writeBytes(encoded);stream.close();opened=false;
               Log.d("IMPACT PNG EXPORT "+JSON.stringify({role:host?"host":"join",round:item.round,
                  capturedAt:item.capturedAt,capturedWall:item.capturedWall,captureEndedAt:item.captureEndedAt,
                  captureEndedWall:item.captureEndedWall,screenshotAllocationMs:item.allocationMs,
                  screenshotDrawMs:item.drawMs,renderFrame:item.renderFrame,
                  exportStarted:began,exportWall:wall,encodeMs:encodedAt-began,writeMs:getTimer()-encodedAt,
                  exportEnded:getTimer(),exportEndedWall:new Date().time,bytes:encoded.length,afterSampling:true}));
            } catch(error:Error) {
               check(false,"deferred PNG export failed for sampled case="+item.round+": "+error);
            } finally {
               if(opened)try {stream.close();}catch(ignored:*){}
               if(encoded!=null)encoded.clear();
               if(picture!=null)picture.dispose();
            }
         }
      }
      private function render(e:Event):void {
         if(phase!="run")return;frames++;
         var now:int=getTimer();if(previousRender>0)renderGap=Math.max(renderGap,now-previousRender);previousRender=now;
         var nativeVis:Dictionary=new Dictionary(true);
         for(var o:Object=mod.game.loc.firstObj;o!=null;o=o.nobj) {
            if(getQualifiedClassName(o)!="fe.graph::Part")continue;
            var v:DisplayObject=o.vis as DisplayObject;
            // Observe received native Parts even when the final display filter
            // rejects them. Do not call capture/readSnapshot: those consume or
            // age production records and would change the fault under test.
            if(ballistic && round<=1 && diagnosticPartCount<20 && !diagnosticParts[o]
               && o.blitData===mod.game.world.grafon.getSpriteList("sprIskr",1)) {
               diagnosticParts[o]=true;diagnosticPartCount++;
               Log.d("BALLISTIC NATIVE PART "+JSON.stringify({at:getTimer(),wall:new Date().time,round:round,
                  elapsed:getTimer()-at,renderFrame:frames,role:host?"host":"join",localSource:localSource,shot:shot,nativeShots:nativeShots,
                  x:o.X,y:o.Y,liv:o.liv,mliv:o.mliv,inChain:o.in_chain,active:mod.game.loc.active,roomHold:mod.game.roomHold,
                  hasVis:v!=null,visible:v!=null && v.visible,staged:v!=null && v.stage!=null,alpha:v==null?null:v.alpha}));
            }
            if(v==null)continue;
            if(ballistic) {
               var atlas:String=cases[round].target=="unit"
                  ?["","sprBlood","sprGBlood","sprPBlood"][int(GameBridge.probe(target,"blood"))]:"sprIskr";
               if(atlas=="")continue;
               if(o.blitData!==mod.game.world.grafon.getSpriteList(atlas,1))continue;
               if(v.visible && v.stage!=null) {
                  if(localSource)record(nativeObjects,source,o,v);
                  else record(copies,remote,o,v);
               }
               continue;
            }
            if(CLIPS[getQualifiedClassName(v)]!==true)continue;
            nativeVis[v]=true;
            if(v.visible && v.stage!=null)record(nativeObjects,source,o,v);
         }
         if(ballistic)return;
         for(var layerIndex:int=0;layerIndex<5;layerIndex++) {
            var layer:DisplayObjectContainer=mod.game.world.grafon.visObjs[layerIndex] as DisplayObjectContainer;
            if(layer==null)continue;
            for(var i:int=0;i<layer.numChildren;i++) {
               v=layer.getChildAt(i);
               if(cases[round].burst && !localSource && flightClasses[getQualifiedClassName(v)] && v.visible) {
                  flightFrames++;
                  var last:Object=flightSeen[v];
                  if(last!=null){if(Math.abs(v.x-last.x)>.01 || Math.abs(v.y-last.y)>.01)flightMoves++;else flightHolds++;}
                  if(flightPoints[v.x.toFixed(4)+","+v.y.toFixed(4)]!==true)flightIntermediate++;
                  flightSeen[v]={x:v.x,y:v.y};
               }
               if(nativeVis[v] || !v.visible || v.stage==null || CLIPS[getQualifiedClassName(v)]!==true)continue;
               record(copies,remote,v,v);
            }
         }
      }
      private function collect():void {
         phase="sampled";
         Log.d("IMPACT PIXEL TIMING "+JSON.stringify({role:host?"host":"join",round:round,pixelMs:pixelMs,
            pixelMax:pixelMax,pixelCalls:pixelCalls,renderGap:renderGap,samples:pixelMeasures,
            boundedSamples:32,pngEncodingDuringSampling:false}));
         if(ballistic && round<=1)Log.d("BALLISTIC DIAGNOSTIC SUMMARY "+JSON.stringify({role:host?"host":"join",round:round,
            wirePackets:wirePackets,wireImpactPackets:wireImpactPackets,observedParts:diagnosticPartCount,
            sourceContacts:nativeContacts,renderedSource:source.length,renderedRemote:remote.length}));
         localResult={source:source,remote:remote,sourcePixels:sourcePixels,remotePixels:remotePixels,
            measurement:{pixelMs:pixelMs,pixelMax:pixelMax,pixelCalls:pixelCalls,renderGap:renderGap,pngEncodingDuringSampling:false},
            flight:{frames:flightFrames,moves:flightMoves,holds:flightHolds,intermediate:flightIntermediate},
            shots:nativeShots,contacts:nativeContacts,frames:frames,kol:nativeSpell!=null?1:gun==null?0:int(gun.kol),loss:target==null?0:targetHp-Number(target.hp)};
         send("result",{result:localResult});compare();
      }
      private function distance(a:Object,b:Object):Number {
         return Math.max(Math.abs(a.x-b.x),Math.abs(a.y-b.y),Math.abs(a.r-b.r),
            Math.abs(a.sx-b.sx)*100,Math.abs(a.sy-b.sy)*100,Math.abs(a.f-b.f)*100,Math.abs(a.a-b.a)*100);
      }
      private function compare():void {
         if(compared || localResult==null || peerResult==null)return;compared=true;
         var nativeResult:Object=localSource?localResult:peerResult;
         var copyResult:Object=localSource?peerResult:localResult;
         var expected:Array=nativeResult.source as Array,actual:Array=copyResult.remote as Array;
         var expectedShots:int=nativeResult.kol*Math.max(1,int(cases[round].burst));
         check(nativeResult.shots==expectedShots && nativeResult.shots>0,"native attack creates all projectiles count="+nativeResult.shots+" expected="+expectedShots);
         if(cases[round].target=="wall")check(nativeResult.contacts>0,"real native Bullet reports wall contact count="+nativeResult.contacts);
         if(cases[round].burst && cases[round].interpolate) {
            check(copyResult.flight.frames>0 && copyResult.flight.moves>0 && copyResult.flight.intermediate>0,
               "sustained native shots show intermediate remote flight "+JSON.stringify(copyResult.flight));
         }
         if(ballistic) {
            check(copyResult.shots==0,"impact display creates no damaging receiver Bullet");
            if(cases[round].target=="expiry" || cases[round].noParticles===true)
               check(expected.length==0 && actual.length==0,"native non-sparking material or unhit expiry has no invented sparks");
            else {
               check(expected.length>0 && nativeResult.sourcePixels>0,"native impact actually emits rendered particles");
               check(actual.length>0 && copyResult.remotePixels>0,"remote impact renders native particle artwork");
               check(Math.abs(actual.length-expected.length)<=4,"one native randomized spark burst source="+expected.length+" remote="+actual.length);
               var nearby:Boolean=actual.length>0;
               var impactX:Number=cases[round].target=="unit"?baseX+180:wallX*40;
               for each(var impact:Object in actual)nearby=nearby && Math.abs(Number(impact.frames[0].x)-impactX)<=65;
               check(nearby,"particles originate at the native hit target");
               if(cases[round].target=="unit") {
                  check(nativeResult.loss>0,"native flesh hit damages target loss="+nativeResult.loss);
                  check(Math.abs(localResult.loss-peerResult.loss)<.01,"blood display adds no damage local="+localResult.loss+" peer="+peerResult.loss);
               }
            }
            Log.d("BALLISTIC IMPACT METRIC "+JSON.stringify({round:round,source:expected.length,remote:actual.length,
               nativePixels:nativeResult.sourcePixels,remotePixels:copyResult.remotePixels}));
            send("compared");advance();return;
         }
         check(copyResult.source.length==0,"receiver never creates a native energy Part");
         if(cases[round].target=="expiry") {
            check(expected.length==0 && actual.length==0,"unhit native expiry produces no invented flash");
         } else if(cases[round].noFlare===true) {
            // Bullet.popadalo with tipDecal 1..6 emits its flare only on hard
            // material. These real flesh hits deliberately produce no flare.
            check(nativeResult.loss>0,"native flesh strike really hits loss="+nativeResult.loss);
            check(expected.length==0 && actual.length==0,"native flesh hit produces no invented hard-material flare");
            check(Math.abs(localResult.loss-peerResult.loss)<.01,"native flesh strike settles exactly once");
         } else {
            var partCount:int=cases[round].id=="sp_gwall"?3:cases[round].melee===true?expected.length:int(nativeResult.shots);
            check(expected.length==partCount && nativeResult.sourcePixels>0,"real native impacts render pixels count="+expected.length+" pixels="+nativeResult.sourcePixels);
            var intended:Boolean=expected.length>0;
            for each(var hit:Object in expected) {
               var hitX:Number=Number(hit.frames[0].x);
               if(cases[round].target=="wall") {
                  var jitter:Number=hit.cls=="visualFlame"?14:0;
                  intended=intended && hitX>=wallX*40-jitter && hitX<=(wallX+1)*40+jitter;
               }
               else if(cases[round].spell===true)intended=intended && Math.abs(hitX-(cases[round].id=="sp_blast"?baseX:(Math.floor((baseX+160)/40)+.5)*40))<.05;
               else intended=intended && hitX>=baseX+targetOffset()-20 && hitX<=baseX+targetOffset()+20;
            }
            check(intended,"native effects originate at the intended "+cases[round].target+" collision");
            check(actual.length==expected.length && actual.length>0,"every impact appears exactly once across TCP actual="+actual.length+" expected="+expected.length);
            check(copyResult.remotePixels>0,"remote impact contributes actual final game pixels="+copyResult.remotePixels);
            var wrong:int=0,progressed:int=0,maxError:Number=0;
            for each(var a:Object in actual) {
               var changed:Boolean=false,first:int=int(a.frames[0].f);
               for each(var pa:Object in a.frames) {
                  if(int(pa.f)!=first)changed=true;
                  var best:Number=1e9;
                  for each(var b:Object in expected)if(a.cls==b.cls)for each(var pb:Object in b.frames)best=Math.min(best,distance(pa,pb));
                  maxError=Math.max(maxError,best);if(best>.05)wrong++;
               }
               if(changed)progressed++;
               // Gwall is a 12-tick spell, not a 3/4-tick bullet flare. Its
               // lifetime is measured from its actual first display, since
               // receipt and first rendering can lag under parallel load.
               // Still require a clear interval before collection.
               var expiryLimit:Number=2600;
               if(cases[round].burst)expiryLimit=4800;
               if(cases[round].id=="sp_gwall") {
                  var nativeLife:Number=0;
                  for each(var nativeEnd:Object in expected)nativeLife=Math.max(nativeLife,Number(nativeEnd.last)-Number(nativeEnd.first));
                  expiryLimit=Math.min(3400,Number(a.first)+nativeLife+150);
               }
               check(a.last<expiryLimit,"effect expires without a frozen clip last="+a.last+" limit="+expiryLimit);
            }
            check(actual.length>0 && wrong==0,"native impact position/scale/frame retained wrong="+wrong+" maxError="+maxError);
            var nativeProgress:int=0;
            for each(b in expected) {first=int(b.frames[0].f);for each(pb in b.frames)if(int(pb.f)!=first) {nativeProgress++;break;}}
            check(progressed>=nativeProgress,"short impact animation advances source="+nativeProgress+" remote="+progressed);
            if(cases[round].target=="unit") {
               check(nativeResult.loss>0,"real source projectile damages the fixture enemy loss="+nativeResult.loss);
               check(Math.abs(localResult.loss-peerResult.loss)<.01,"display replay adds no second damage local="+localResult.loss+" peer="+peerResult.loss);
            }
         }
         Log.d("ENERGY IMPACT METRIC "+JSON.stringify({role:host?"host":"join",round:round,scenario:cases[round],local:localResult,peer:peerResult}));
         send("compared");advance();
      }
      private function advance():void {
         if(!host || !compared || !peerDone)return;
         if(round+1<cases.length)prepare(round+1);else {send("done");finish();}
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;
         if(phase=="run" && !localSource) {
            if(p.snap!=null)wire(p.snap,host?1:0,String(p.type));
            if(p.players is Array)for each(var player:Object in p.players)
               if(int(player.id)==0)wire(player.snap,0,String(p.type));
         }
         if(p.type!="energy-impact-test")return;
         try {
            if(p.stage=="ready" && host && phase=="boot") {
               setup(Math.max(120,Math.min(mod.game.gg.X,mod.game.loc.spaceX*40-600)),mod.game.gg.Y);
               send("setup",{x:baseX,y:baseY});prepare(0);
            } else if(p.stage=="setup" && !host && phase=="boot")setup(p.x,p.y);
            else if(p.stage=="case" && !host) {
               prepare(int(p.round));mod.game.applyTilePatch(p.layout as Array);
               for(var y:int=Math.max(1,int(baseY/40)-6);y<=Math.min(mod.game.loc.spaceY-2,int(baseY/40));y++) {
                  mod.game.loc.space[wallX][y].mat=cases[round].mat==null?2:int(cases[round].mat);mod.game.loc.space[wallX][y].indestruct=true;mod.game.loc.space[wallX][y].water=0;
               }
            } else if(p.stage=="prepared" && host && int(p.round)==round)peerPrepared=true;
            else if(p.stage=="go" && !host && int(p.round)==round)begin();
            else if(p.stage=="result" && int(p.round)==round) {peerResult=p.result;compare();}
            else if(p.stage=="compared" && host && int(p.round)==round) {peerDone=true;advance();}
            else if(p.stage=="done")finish();
         } catch(error:Error) {check(false,error.getStackTrace());send("done");finish();}
      }
      private function wire(snap:Object,peerId:int=-1,packetType:String=""):void {
         if(snap==null)return;
         if(ballistic) {
            if(round==0) {
               wirePackets++;
               var guns:Array=[],hasImpact:Boolean=false,stored:Boolean=false;
               if(snap.weapons is Array)for each(var state:Object in snap.weapons) {
                  var events:Array=state.events as Array,impactCount:int=0,endedCount:int=0;
                  if(events!=null)for each(var ev:Object in events) {
                     if(ev.impact!=null || ev.flight!=null && ev.flight.impact!=null)impactCount++;
                     if(ev.flight!=null && ev.flight.ended===true)endedCount++;
                  }
                  hasImpact=hasImpact || impactCount>0;
                  guns.push({id:state.id,stream:state.stream,events:events==null?0:events.length,
                     first:events==null||events.length==0?null:events[0].seq,last:events==null||events.length==0?null:events[events.length-1].seq,
                     impacts:impactCount,ended:endedCount});
               }
               if(hasImpact)wireImpactPackets++;
               var records:Array=host?mod.session.peers:mod.session.remotes;
               for each(var rec:Object in records)if(int(rec.id)==peerId && rec.snap===snap)stored=true;
               var ghost:Object=mod.game.getRemoteGhost(peerId);
               // This listener runs after Session's normal MESSAGE listener.
               // Stored means Session retained this exact object, not that the
               // private projectile queue necessarily accepted its impact.
               var envelope:Object={packetType:packetType,peerId:peerId,guns:guns,sessionStored:stored,
                  incomingRoom:snap.roomKey,incomingEpoch:snap.roomEpoch,incomingLoc:snap.locId,
                  localRoom:mod.game.roomKey(),localEpoch:mod.game.roomEpoch,localLoc:mod.game.loc.id,
                  active:mod.game.loc.active,roomHold:mod.game.roomHold,paused:mod.game.coopPaused,
                  ghost:ghost!=null,ghostSameLoc:ghost!=null && ghost.loc===mod.game.loc};
               var summary:String=JSON.stringify(envelope);
               if(summary!=wireSummary) {
                  wireSummary=summary;envelope.at=getTimer();envelope.wall=new Date().time;
                  envelope.sampleTime=snap.sampleTime;envelope.packetCount=wirePackets;
                  Log.d("BALLISTIC WIRE ENVELOPE "+JSON.stringify(envelope));
               }
            }
            if(round==0 && snap.weapons is Array)for each(var bw:Object in snap.weapons)
               for each(var be:Object in bw.events) {
                  var bf:Object=be.flight,bi:Object=be.impact!=null?be.impact:(bf==null?null:bf.impact);
                  var sig:String=String(bw.stream)+"/"+String(be.seq)+"/"+(bf==null?"none":String(bf.ended)+"/"+String(bf.end))+"/"+JSON.stringify(bi);
                  if(wireSeen[sig])continue;wireSeen[sig]=true;
                  Log.d("BALLISTIC IMPACT WIRE "+JSON.stringify({round:round,at:getTimer(),wall:new Date().time,
                     stream:bw.stream,seq:be.seq,sampleTime:bw.sampleTime,born:be.at,hasFlight:bf!=null,
                     points:bf==null||!(bf.frames is Array)?0:bf.frames.length,ended:bf==null?null:bf.ended,impact:bi}));
               }
            return;
         }
         if(cases[round].burst && snap.weapons is Array)for each(var gunState:Object in snap.weapons)
            for each(var event:Object in gunState.events)if(event.flight!=null) {
               var flight:Object=event.flight;flightClasses[String(flight.cls)]=true;
               for each(var flightPoint:Object in flight.frames)flightPoints[Number(flightPoint.x).toFixed(4)+","+Number(flightPoint.y).toFixed(4)]=true;
            }
         var list:Array=snap.spellVisuals is Array?snap.spellVisuals.concat():[];
         if(snap.weapons is Array)for each(var w:Object in snap.weapons)
            if(w.impacts is Array)list=list.concat(w.impacts);
         for each(var impact:Object in list) {
            var signature:String=impact.cls+":"+impact.id+":"+impact.end+":"+JSON.stringify(impact.frames);
            if(wireSeen[signature])continue;wireSeen[signature]=true;
            var points:Array=[];for each(var frame:Object in impact.frames)points.push([frame.at,frame.f]);
            Log.d("ENERGY IMPACT WIRE "+JSON.stringify({round:round,received:getTimer()-at,
               stamp:snap.sampleTime,id:impact.id,cls:impact.cls,end:impact.end,frames:points}));
         }
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null || mod.game==null || mod.game.gg==null || mod.session==null)return;
         if(phase=="boot")mod.game.gg.invulner=true;
         if(host)for each(var p:Object in mod.session.peers)watch(p.link as TcpLink);else watch(mod.session.link);
         if(mod.game.world.clickReq==1) {mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN,true));mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP,true));}
         // Boot includes native menu/new-game/map construction and the runner's
         // deliberate host-first launch. Use its 180 s bootstrap watchdog here;
         // keep the existing 60 s bound for every actual test action. Loading
         // performance is measured separately, never inferred from this bound.
         if(phase!="done" && getTimer()-at>(phase=="boot"?180000:60000)) {check(false,"timeout "+phase);send("done");finish();return;}
         if(!mod.session.rooms.ready || mod.session.rooms.busy || mod.game.isTransitioning())return;
         if(phase=="boot" && waitLand!="" && String(mod.game.readWorldInfo().curLandId)!=waitLand)return;
         if(phase=="boot" && !host && timer.currentCount>160 && getTimer()-readyAt>500) {readyAt=getTimer();send("ready");}
         if(phase=="prepare") {
            if(cases[round].target=="unit" && target==null)target=findTarget();
            if(!localPrepared && getTimer()-at>700 && (cases[round].target!="unit" || target!=null)) {
               localPrepared=true;if(!host)send("prepared");
            }
            if(host && localPrepared && peerPrepared) {begin();send("go");}
         }
         if(phase=="run" && getTimer()-at>(cases[round].burst?5000:3600))collect();
      }
      private function cleanupGun():void {
         nativeSpell=null;
         if(gun!=null) {gun.remVisual();gun=null;}
         if(mod!=null && oldChildren!=null) {
            mod.game.gg.currentWeapon=oldGun;mod.game.gg.childObjs=oldChildren.concat();
            mod.game.gg.magicWeapon=oldMagic;mod.game.gg.throwWeapon=oldThrown;
         }
         if(host && target!=null) {mod.game.loc.remObj(target);target.remVisual();var i:int=mod.game.loc.units.indexOf(target);if(i>=0)mod.game.loc.units.splice(i,1);}
         if(host && enemyActor!=null) {mod.game.loc.remObj(enemyActor);enemyActor.remVisual();i=mod.game.loc.units.indexOf(enemyActor);if(i>=0)mod.game.loc.units.splice(i,1);enemyActor=null;}
      }
      private function finish():void {
         if(phase=="done")return;phase="done";timer.stop();
         if(mod!=null) {mod.stage.removeEventListener(Event.ENTER_FRAME,before);mod.stage.removeEventListener(Event.ENTER_FRAME,after);mod.stage.removeEventListener(Event.RENDER,render);cleanupGun();}
         exportPictures();
         Log.d("COOP EFFECTS DONE energy-impact "+(host?"host":"join"));
      }
   }
}

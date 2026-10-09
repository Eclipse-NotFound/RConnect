package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.BitmapData;
   import flash.geom.Matrix;
   import flash.geom.Rectangle;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.utils.Timer;
   import flash.utils.Dictionary;
   import flash.utils.getTimer;
   import flash.utils.getQualifiedClassName;
   import fe.unit.Unit;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;
   import rconnect.game.ProjectileVisuals;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;

   /** Real native beams and enemy-owned wall damage across Session/TCP. */
   public class BeamTerrainTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var mod:RConnectMod,host:Boolean,timer:Timer=new Timer(100),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=0,readyAt:int=0,baseX:Number,baseY:Number;
      private var owners:Array=[],guns:Array=[],nativeBullets:Array=[],kinds:Array=["turret2","robolaser"];
      private var beamClass:String="",gunIndex:int=0,serial:int=0,sampled:int=-1,clock:int=0,lastShot:int=0,shots:int=0;
      private var frames:int=0,shown:int=0,gap:int=0,maxGap:int=0,visTrace:Array=[];
      private var periodMs:Number=333,nativeResult:Object,peerResult:Object;
      private var visibleMs:Number=0,darkMs:Number=0,maxDarkMs:Number=0,previousFrame:int=0;
      private var wallX:int,wallY:int,wall:Object,wallBroken:Boolean=false,wallParticles:Dictionary=new Dictionary();
      private var pieceFrames:int=0,pieceChanges:int=0,pieceCount:int=0,knownPiece:Object,wallBefore:int=0;
      private var frontBefore:Object,frontReplaced:Boolean=false;
      private var deathFired:Boolean=false,deathEnded:Boolean=false;
      private var timeTrace:Array=[],shotTrace:Array=[],packetTrace:Array=[],packetSeen:Object={};
      private var packetOffset:Number=Infinity;
      public function BeamTerrainTestDoc() {
         var id:String=NativeApplication.nativeApplication.applicationID;if(id.indexOf("rconnect-coop-")<0)return;
         host=id.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();finish();
         });
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,s:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"beam-terrain "+s);}
      private function send(s:String,p:Object=null):void {p=p||{};p.type="beam-terrain-test";p.stage=s;if(host)mod.session.server.broadcast(p);else mod.session.link.send(p);}
      private function watch(l:TcpLink):void {if(l!=null && !links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);}}
      private function setPhase(s:String):void {phase=s;at=getTimer();frames=shown=gap=maxGap=0;visTrace=[];lastShot=0;shots=0;visibleMs=darkMs=maxDarkMs=0;previousFrame=0;timeTrace=[];shotTrace=[];packetTrace=[];packetSeen={};packetOffset=Infinity;}
      /** Arrival diagnostics only; actual native pixels remain the oracle. */
      private function observePacket(message:Object):void {
         if(host || phase!="beam" || message.type!="unitsync")return;
         var now:int=getTimer();
         for each(var unit:Object in message.units) {
            if(String(unit.id).indexOf("beam_fixture_")!=0)continue;
            packetOffset=Math.min(packetOffset,now-Number(unit.sampleTime));
            for each(var weapon:Object in unit.weapons)for each(var event:Object in weapon.events) {
               var key:String=weapon.stream+":"+event.seq,flight:Object=event.flight;
               if(packetSeen[key] || flight==null || String(flight.cls)!=beamClass || !(flight.frames is Array) || flight.frames.length==0)continue;
               packetSeen[key]=true;packetTrace.push({key:key,received:now,sample:unit.sampleTime,
                  first:flight.frames[0].at,last:flight.frames[flight.frames.length-1].at,count:flight.frames.length,end:flight.end});
            }
         }
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;observePacket(p);if(p.type!="beam-terrain-test")return;
         if(host && p.stage=="ready" && phase=="boot") {setup();send("setup",{x:baseX,y:baseY,wx:wallX,wy:wallY,layout:layout()});setPhase("ready");}
         else if(!host && p.stage=="setup" && phase=="boot") {
            baseX=p.x;baseY=p.y;wallX=p.wx;wallY=p.wy;
            // Keep the reduced 300 -> 60 fixture case deterministic. A direct
            // local HP assignment would be a real client terrain-damage report.
            mod.game.applyTilePatch([{x:wallX,y:wallY,p:1,f:"A",h:300,o:1}]);
            check(mod.game.loc.space[wallX][wallY].hp==300,"fixture starts from a real 300 HP baseline");
            mod.game.applyTilePatch(p.layout as Array);
            check(mod.game.loc.space[wallX][wallY].hp==60,"host fixture layout establishes the 60 HP baseline");
            setup();setPhase("ready");send("prepared");
         }
         else if(host && p.stage=="prepared" && phase=="ready")startBeam(0);
         else if(!host && p.stage=="beam"){beamClass=p.cls;gunIndex=p.index;periodMs=p.period;setPhase("beam");}
         else if(host && p.stage=="beam-result") {
            peerResult=p;finishBeam();
         }
         else if(!host && p.stage=="cooldown")setPhase("cooldown");
         else if(host && p.stage=="cooldown-result") {
            check(p.empty && p.dark,"join ends beams after native fire stops; repeated snapshots do not relight them");
            gunIndex=0;setPhase("death");var b:Object=fire();beamClass=getQualifiedClassName(b.vis);
            send("death",{cls:beamClass});
         }
         else if(!host && p.stage=="death"){beamClass=p.cls;setPhase("death");}
         else if(host && p.stage=="death-result") {
            check(deathFired && deathEnded,"source keeps observing an already-fired beam after its owner dies");
            check(p.empty && p.dark,"owner death cannot leave a frozen beam on join");
            send("wall");setPhase("wall");
         }
         else if(!host && p.stage=="wall"){setPhase("wall");frontBefore=mod.game.world.grafon.visObjs[2];send("wall-ready");}
         else if(host && p.stage=="wall-ready"){wallBefore=getTimer();frontBefore=mod.game.world.grafon.visObjs[2];breakWall();}
         else if(host && p.stage=="wall-result") {
            check(p.broken,"enemy wall destruction reaches join");
            check(pieceCount>=3,"host native wall fragments count="+pieceCount);
            check(p.count==pieceCount && p.frames>=5 && p.changes>=3,"join native wall fragments animate exactly once count="+p.count+" frames="+p.frames+" changes="+p.changes);
            check(!p.redraw,"remote wall destruction retains native object layer instead of rebuilding the whole room");
            send("done");finish();
         } else if(p.stage=="done")finish();
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null || mod.game==null || mod.session==null)return;
         if(host)for each(var p:Object in mod.session.peers)watch(p.link as TcpLink);else watch(mod.session.link);
         if(mod.game.gg==null || !mod.session.rooms.ready || mod.session.rooms.busy || mod.game.isTransitioning())return;
         if(phase=="boot" && !host && getTimer()-readyAt>500){readyAt=getTimer();send("ready");}
         if(phase!="done" && at>0 && getTimer()-at>25000){check(false,"timeout "+phase);send("done");finish();}
      }
      private function spawn(cls:String,id:String,tr:int,dx:Number):Object {
         var c:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit."+cls) as Class,xml:XML=<unit/>;xml.@tr=tr;
         var u:Object=new c(id,100,xml,null);u.id="beam_fixture_"+id;
         u.putLoc(mod.game.loc,baseX+dx,baseY);mod.game.loc.addObj(u);mod.game.loc.units.push(u);
         u.disabled=true;u.doop=true;u.lootIsDrop=true;u.xp=0;owners.push(u);return u;
      }
      private function setup():void {
         var b:Object=mod.game;quietArena();clearIncidentalBullets();
         if(host){baseX=b.gg.X;baseY=b.gg.Y;wallX=int(baseX/40)+4;wallY=int(baseY/40)-2;}
         b.gg.invulner=true;b.gg.disabled=true;b.gg.isTake=0;b.gg.dx=b.gg.dy=0;b.gg.anim("stay",true);
         b.loc.base=false;b.loc.black=false;b.world.black=false;b.loc.destroyOn=true;b.loc.tileSpawn=0;
         // Identical open corridor and one ordinary stone wall in both worlds.
         for(var x:int=Math.max(1,int(baseX/40)-1);x<=Math.min(b.loc.spaceX-2,wallX+5);x++)
            for(var y:int=Math.max(1,wallY-3);y<=wallY+2;y++){var t:Object=b.loc.space[x][y];t.phis=0;t.opac=0;t.front="";}
         wall=b.loc.space[wallX][wallY];wall.mainFrame("A");wall.indestruct=false;wall.hp=60;wall.thre=0;wall.mat=2;wall.fake=false;wall.door=null;wall.trap=null;
         b.world.redrawLoc();
         var emitter:Object=mod.main.loaderInfo.applicationDomain.getDefinition("fe.graph.Emitter");
         var piece:Object=emitter.arr["kusok"].cast(b.loc,baseX,baseY-100);
         knownPiece={cls:piece.vClass,blit:piece.blitData};b.loc.remObj(piece);
         if(host){
            var u:Object=spawn("UnitTurret","land",2,-20);
            var gun:NativeBeamGun=new NativeBeamGun(u as Unit,kinds[0]);u.currentWeapon=gun;u.childObjs=[gun];Object(gun).addVisual();
            check(Object(gun).loc===u.loc,"native beam weapon is equipped in its owner room");guns.push(gun);
            u=spawn("UnitSpriteBot","1",1,20);gun=new NativeBeamGun(u as Unit,kinds[1]);u.currentWeapon=gun;u.childObjs=[gun];Object(gun).addVisual();
            check(Object(gun).loc===u.loc,"native beam weapon is equipped in its owner room");guns.push(gun);
            b.readUnitsSnapshot();b.readTilePatch();
         }
         mod.stage.addEventListener(Event.ENTER_FRAME,beginFrame,false,100001);
         mod.stage.addEventListener(Event.ENTER_FRAME,drive,false,-5000);
         mod.stage.addEventListener(Event.RENDER,sample,false,-30000);
      }
      private function startBeam(i:int):void {
         gunIndex=i;nativeResult=peerResult=null;setPhase("beam");periodMs=Math.max(33,Number(Object(guns[i]).rapid)*1000/30);
         var b:Object=fire();beamClass=getQualifiedClassName(b.vis);
         var g:Object=guns[i];Log.d("BEAM native "+kinds[i]+" cls="+beamClass+" rapid="+g.rapid+" spring="+b.spring+" liv="+b.liv);
         check(b.spring>=2,"native "+kinds[i]+" is a beam");send("beam",{index:i,cls:beamClass,period:periodMs});
      }
      private function finishBeam():void {
         if(nativeResult==null || peerResult==null)return;
         Log.d("BEAM METRIC "+kinds[gunIndex]+" native="+JSON.stringify(nativeResult)+" join="+JSON.stringify(peerResult));
         check(peerResult.frames>50 && peerResult.visibleMs>=nativeResult.visibleMs*.8 && peerResult.visibleMs<=nativeResult.visibleMs*1.3+100,
            "join "+kinds[gunIndex]+" retains native visible duration native="+nativeResult.visibleMs+" join="+peerResult.visibleMs);
         check(peerResult.maxDarkMs<=nativeResult.maxDarkMs+100,
            "join "+kinds[gunIndex]+" has no additional long blank gap native="+nativeResult.maxDarkMs+" join="+peerResult.maxDarkMs);
         if(gunIndex==0)startBeam(1);else {send("cooldown");setPhase("cooldown");}
      }
      private function fire():Object {
         lastShot=clock;shots++;var b:Object=NativeBeamGun(guns[gunIndex]).fire(baseX+20,baseY-140,0);
         if(shots==1) {
            check(b.loc.getAbsTile(b.begx,b.begy).phis==0,"native beam muzzle is inside the open fixture corridor");
            Log.d("BEAM ORIGIN "+JSON.stringify({id:kinds[gunIndex],requestedX:baseX+20,requestedY:baseY-140,
               actualX:b.begx,actualY:b.begy,gunX:Object(guns[gunIndex]).vis.x,gunY:Object(guns[gunIndex]).vis.y}));
         }
         shotTrace.push({at:getTimer(),x:b.begx,y:b.begy});nativeBullets.push(b);return b;
      }
      private function beginFrame(e:Event):void {serial++;clock=getTimer();quietArena();}
      /** Publish the host's constructed corridor through the actual terrain
       * receiver before the join fixture touches native tile fields. */
      private function layout():Array {
         var out:Array=[],fields:Object={p:"phis",f:"front",b:"back",z:"zad",zf:"zForm",w:"water",st:"stair",h:"hp",o:"opac",v:"vid",v2:"vid2",d:"diagon",sh:"shelf"};
         for(var x:int=Math.max(1,int(baseX/40)-1);x<=Math.min(mod.game.loc.spaceX-2,wallX+5);x++)
            for(var y:int=Math.max(1,wallY-3);y<=wallY+2;y++) {
               var t:Object=mod.game.loc.space[x][y],s:Object={x:x,y:y};
               for(var key:String in fields)s[key]=t[fields[key]];
               out.push(s);
            }
         return out;
      }
      private function quietArena():void {
         for each(var u:Object in mod.game.loc.units)
            if(u!==mod.game.gg && int(GameBridge.probe(u,"fraction"))<100 && owners.indexOf(u)<0)u.disabled=true;
      }
      private function clearIncidentalBullets():void {
         var list:Array=[];
         for(var o:Object=mod.game.loc.firstObj;o!=null;o=o.nobj)
            if(getQualifiedClassName(o).indexOf("fe.weapon::")===0 && getQualifiedClassName(o).indexOf("Bullet")>=0)list.push(o);
         for each(o in list)mod.game.loc.remObj(o);
      }
      private function drive(e:Event):void {
         if(phase=="done")return;
         mod.game.forceCloseOverlays();mod.game.gg.disabled=true;mod.game.gg.invulner=true;
         for each(var u:Object in owners){u.disabled=true;u.dx=u.dy=0;}
         if(host && phase=="beam" && clock-lastShot>=periodMs)fire();
         mod.stage.invalidate();
      }
      private function beamVisible():Boolean {
         var layer:DisplayObjectContainer=mod.game.world.grafon.visObjs[2];
         for(var i:int=0;i<layer.numChildren;i++) {
            var v:DisplayObject=layer.getChildAt(i);
            if(getQualifiedClassName(v)==beamClass && v.visible && v.alpha>.05 && pixels(v)>5)return true;
         }
         return false;
      }
      private function pixels(v:DisplayObject):int {
         var root:DisplayObject=mod.main as DisplayObject,r:Rectangle=v.getBounds(root).intersection(new Rectangle(0,0,mod.stage.stageWidth,mod.stage.stageHeight));
         if(r.width<2 || r.height<1 || r.width*r.height>100000)return 0;
         var a:BitmapData=new BitmapData(Math.ceil(r.width),Math.ceil(r.height),false,0),b:BitmapData=a.clone(),m:Matrix=new Matrix(1,0,0,1,-r.x,-r.y);
         a.draw(root,m);v.visible=false;b.draw(root,m);v.visible=true;
         var av:Vector.<uint>=a.getVector(a.rect),bv:Vector.<uint>=b.getVector(b.rect),n:int=0;
         for(var i:int=0;i<av.length;i++)if(av[i]!=bv[i])n++;
         a.dispose();b.dispose();return n;
      }
      private function collectPieces():void {
         var any:Boolean=false,changed:Boolean=false;
         for(var o:Object=mod.game.loc.firstObj;o!=null;o=o.nobj) {
            if(getQualifiedClassName(o)!="fe.graph::Part")continue;
            if(knownPiece.blit!=null?o.blitData!==knownPiece.blit:o.vClass!==knownPiece.cls)continue;
            var old:Object=wallParticles[o];
            if(old==null){wallParticles[o]={x:o.X,y:o.Y};pieceCount++;}
            else {if(Math.abs(old.x-o.X)+Math.abs(old.y-o.Y)>.05)changed=true;old.x=o.X;old.y=o.Y;}
            if(o.vis!=null && o.vis.visible && o.vis.stage!=null)any=true;
         }
         if(any)pieceFrames++;if(changed)pieceChanges++;
      }
      /** Exercise delayed/repeated snapshots against real native display classes.
       * Explicit times make expiry and layer replacement independent of scheduling. */
      private function playbackBoundaries():void {
         var player:ProjectileVisuals=new ProjectileVisuals(),owner:Object={loc:mod.game.loc};
         var stamp:int=getTimer(),objects:Array=[],o:Object;
         for(o=mod.game.loc.firstObj;o!=null;o=o.nobj)objects.push(o);
         var flight:Object={cls:beamClass,x:baseX+20,y:baseY-140,rot:0,spring:2,blend:"add",end:stamp+200,
            frames:[{at:stamp,x:baseX+20,y:baseY-140,rot:0,sx:1,sy:1,a:1,f:1,ls:4,lf:1}]};
         var event:Object={seq:1,at:stamp,flight:flight};
         var gun:Object={slot:0,id:"boundary",variant:0,stream:1,sampleTime:stamp,events:[event]};
         player.receive(owner,[gun],mod.main);
         player.tick(mod.game.loc,stamp+400);
         check(player.count==1 && beamVisible(),"queued source frame produces real beam pixels");
         player.receive(owner,[gun],mod.main);
         check(player.count==1,"duplicate event keeps one visual");
         var previous:Object=mod.game.world.grafon.visObjs[2];
         mod.game.world.redrawLoc();player.tick(mod.game.loc,stamp+400);
         check(previous!==mod.game.world.grafon.visObjs[2] && beamVisible(),"native room redraw reattaches the live beam");
         player.tick(mod.game.loc,stamp+800);
         player.receive(owner,[gun],mod.main);player.tick(mod.game.loc,stamp+900);
         check(player.count==0 && !beamVisible(),"ended duplicate event cannot restart a beam");
         event.seq=2;player.receive(owner,[gun],mod.main);player.reset();
         check(player.count==0,"session reset clears queued beams");
         event.seq=3;player.receive(owner,[gun],mod.main);player.tick({},stamp+400);
         check(player.count==0,"room change clears queued beams");
         var after:Array=[];for(o=mod.game.loc.firstObj;o!=null;o=o.nobj)after.push(o);
         var same:Boolean=objects.length==after.length;
         for each(o in objects)if(after.indexOf(o)<0)same=false;
         check(same,"cosmetic beam playback creates no simulation objects");
         player.reset();
      }
      private function sample(e:Event):void {
         if(phase=="done" || serial==sampled)return;sampled=serial;
         try {
            if(phase=="beam" && clock-at>1000 && clock-at<6500) {
               var visible:Boolean=beamVisible(),dt:int=previousFrame>0?clock-previousFrame:0;previousFrame=clock;
               frames++;if(visible){shown++;gap=0;visibleMs+=dt;darkMs=0;}else{gap++;maxGap=Math.max(maxGap,gap);darkMs+=dt;maxDarkMs=Math.max(maxDarkMs,darkMs);}
               visTrace.push(visible?1:0);timeTrace.push({at:clock,t:clock-at,shown:visible});
            }
            if(phase=="beam" && clock-at>=6500){
               Log.d("BEAM TRACE "+kinds[gunIndex]+" "+visTrace.join(""));
               var result:Object={frames:frames,shown:shown,maxGap:maxGap,visibleMs:visibleMs,maxDarkMs:maxDarkMs,timeTrace:timeTrace,shotTrace:shotTrace,packetTrace:packetTrace,packetOffset:packetOffset};
               if(!host){send("beam-result",result);setPhase("wait");}
               else {check(frames>50 && shown>10,"host native "+kinds[gunIndex]+" beam visible "+shown+"/"+frames);nativeResult=result;setPhase("wait");finishBeam();}
            }
            if(phase=="wall") {
               if(frontBefore!=null && mod.game.world.grafon.visObjs[2]!==frontBefore)frontReplaced=true;
               collectPieces();if(wall.phis==0)wallBroken=true;
               if(!host && clock-at>4500){send("wall-result",{broken:wallBroken,count:pieceCount,frames:pieceFrames,changes:pieceChanges,redraw:frontReplaced});setPhase("wait");}
            }
            if(phase=="cooldown" && !host && clock-at>1600) {
               var empty:Boolean=mod.game.projectileVisualCount==0,dark:Boolean=!beamVisible();
               playbackBoundaries();send("cooldown-result",{empty:empty,dark:dark});setPhase("wait");
            }
            if(phase=="death") {
               if(host) {
                  if(!deathFired && beamVisible()){owners[0].hp=0;owners[0].die();deathFired=true;}
                  for each(var unit:Object in mod.game.readUnitsSnapshot())if(unit.id==owners[0].id)
                     for each(var weapon:Object in unit.weapons)for each(var shot:Object in weapon.events)
                        if(shot.flight!=null && int(shot.flight.end)>0)deathEnded=true;
               } else if(clock-at>1800){send("death-result",{empty:mod.game.projectileVisualCount==0,dark:!beamVisible()});setPhase("wait");}
            }
         }catch(err:Error){check(false,err.getStackTrace());send("done");finish();}
      }
      private function breakWall():void {
         check(wall.phis==1 && wall.hp==60,"fixture survives until the deliberate enemy wall hit");
         var c:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.weapon.Bullet") as Class;
         var b:Object=new c(owners[1],wallX*40+20,wallY*40+20,null,false);
         b.damage=0;b.destroy=1000;b.dx=1;b.dy=0;b.precision=0;b.partEmit=false;b.run();
         check(wall.phis==0,"native enemy-owned bullet destroys stone wall");
      }
      private function finish():void {
         if(phase=="done")return;phase="done";timer.stop();
         if(mod!=null){mod.stage.removeEventListener(Event.ENTER_FRAME,beginFrame);mod.stage.removeEventListener(Event.ENTER_FRAME,drive);mod.stage.removeEventListener(Event.RENDER,sample);}
         Log.d("COOP EFFECTS DONE beam-terrain "+(host?"host":"join"));
      }
   }
}

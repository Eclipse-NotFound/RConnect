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
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.geom.ColorTransform;
   import flash.geom.Matrix;
   import flash.geom.Rectangle;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getQualifiedClassName;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;
   import rconnect.net.NetMessageEvent;
   import rconnect.net.TcpLink;

   /** Real offline play -> first TCP session -> final rendered peer effects.
    * No readSnapshot, collector reset, synthetic production packets or weapon.step. */
   public final class OfflineFirstConnectTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private static const VERSION:String="0.2.24-offline1",TYPE:String="offline-first-connect-test";
      private static const TOTAL_MS:int=300000,BOOT_MS:int=180000,CONNECT_MS:int=150000,WINDOW_MS:int=2200;
      private var mod:RConnectMod,bridge:Object,session:Object,config:Object,world:Object,actor:Object,inventory:Object;
      private var gun:Object,bullet:Object,offlineBullet:Object,originalHook:Function,old:Object,privateWeapons:Array;
      private var host:Boolean,finished:Boolean=false,prepared:Boolean=false,loadIssued:Boolean=false,travelIssued:Boolean=false;
      private var loadActor:Object,stableAt:int=0,bootStableAt:int=0,began:int=getTimer(),phaseAt:int=began;
      private var phase:String="boot",frame:int=0,lastRender:int=-1,checks:int=0,failed:int=0,attempts:int=0;
      private var version:String="",abortReason:String="",links:Dictionary=new Dictionary(),server:Object;
      private var timer:Timer=new Timer(100),observations:Array=[],coverage:Object={virgin:false,offlineShot:false,
         offlineBody:false,offlineClear:false,firstConnection:false,quietNoReplay:false,hostFire:false,joinFire:false,bodyApplied:false,bodyCleared:false};
      private var lane:Object,onlineLane:Object,plain:Object,peerPlain:Object,expectedClass:String="",peerClass:String="";
      private var aimLeft:Boolean=false,issued:Boolean=false,shotBase:int=0,nativeFrames:Array=[],lastBullet:Object;
      private var shotAmmo:Number=0,sourceShotCount:int=0,attackState:Object;
      private var offlineFrozen:Boolean=false,freezeAt:int=0,clearFrames:int=0,offlineClearAt:int=0;
      private var peerReady:Boolean=false,readySent:Boolean=false,prepareSent:Boolean=false,welcomeSeen:Boolean=false,helloSeen:Boolean=false;
      private var roomKey:String="",round:int=-1,localDone:Boolean=false,peerDone:Boolean=false,peerReport:Object,oracle:Object;
      private var renderSamples:int=0,visibleSamples:int=0,bodyMatches:int=0,packetSamples:int=0,wireEvents:int=0;
      private var tombstones:int=0,playable:int=0,muzzleFrames:int=0,pixelCount:int=0,sourcePixels:int=0;
      private var lastOracleAt:int=0,trace:Array=[],eventKeys:Object={},peerShotProof:Object,finishRequested:Boolean=false,finishAckSeen:Boolean=false;
      private var sharedRun:File,runToken:String="",ownedFlags:Array=[],remoteFrames:Array=[];
      private var preQuietRenders:int=0,quietPacketStart:int=0,attemptAt:int=0;
      private var arrivalClosed:Boolean=false,arrivalBytes:int=0;

      public function OfflineFirstConnectTestDoc() {
         var id:String=NativeApplication.nativeApplication.applicationID;
         if(id.indexOf("pfe-modsettings-rconnect-coop-")!=0)return;
         host=id.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,uncaught);
         addEventListener(Event.ENTER_FRAME,boot);
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,label:String):void {
         ++checks;Log.d("COOP "+(ok?"PASS ":"FAIL ")+"offline-first-connect "+label);
         if(!ok){++failed;throw new Error(label);}
      }
      private function note(label:String,data:Object=null):void {
         if(observations.length>=96)throw new Error("Observation capacity exceeded");
         observations.push({label:label,at:getTimer(),frame:frame,phase:phase,round:round,data:data});
      }
      private function change(next:String):void {phase=next;phaseAt=getTimer();note("phase");}
      private function readyNative():Boolean {
         var b:Object=mod.game,g:Object=b.gg,w:Object=b.world;
         return g!=null && g.ggControl && !g.disabled && g.work!="res" && Number(g.t_work)<=0
            && !w.onPause && w.allStat==1 && int(w.ng_wait)==0 && int(w.comLoad)<0
            && !b.isTransitioning() && (!w.vblack.visible || w.vblack.alpha<=0);
      }
      private function boot(e:Event):void {
         if(finished || phase!="boot")return;
         try {
            mod=RConnectMod.instance;if(mod==null || mod.game==null || mod.game.gg==null)return;
            var w:Object=mod.game.world,g:Object=mod.game.gg;
            if(w.verror!=null && w.verror.visible)throw new Error("Native boot error dialog");
            if(w.clickReq==1){mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN,true));mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP,true));}
            if(String(mod.config.getValue("autoRole"))!="" || String(mod.config.getValue("autoLoadSave"))!="-9")
               throw new Error("Requires isolated slot-nine connect-after-load and no auto role");
            if(!loadIssued) {
               if(w.loc==null || w.sats==null || w.sats.gg!==g || !readyNative()){bootStableAt=0;return;}
               if(bootStableAt==0)bootStableAt=getTimer();if(getTimer()-bootStableAt<1000)return;
               if(mod.game.loadSaveTest(9)){loadIssued=true;loadActor=g;note("native-slot-nine-load");}return;
            }
            if(g===loadActor || mod.game.isTransitioning())return;
            if(w.allStat==2 && w.pip!=null && w.pip.active)w.pip.onoff(0);
            if(!readyNative()){stableAt=0;return;}
            if(String(w.game.curLandId)!="rbl" || w.land==null || String(w.land.act.id)!="rbl") {
               if(!travelIssued){travelIssued=true;w.game.gotoLand("rbl");stableAt=0;note("native-travel-rbl");}return;
            }
            if(stableAt==0)stableAt=getTimer();if(getTimer()-stableAt<4000)return;
            setup();removeEventListener(Event.ENTER_FRAME,boot);
         }catch(error:*){abort(error);}
      }
      private function setup():void {
         bridge=Object(mod.game);session=Object(mod.session);config=Object(mod.config);world=bridge.world;actor=bridge.gg;inventory=actor.invent;
         version=String(Object(MOD_CLASS)["VERSION"]);
         check(version==VERSION,"exact offline1 production version");
         check(session.canSkipOfflinePresentation is Function && bridge.offlinePresentationEligibility is Function,"public eligibility API exists");
         originalHook=bridge.offlinePresentationEligibility as Function;
         check(session.mode=="offline" && session.server==null && session.link==null && session.peers.length==0
            && session.remotes.length==0 && session.canSkipOfflinePresentation()===true && originalHook()===true,"original Session is truly never-networked");
         coverage.virgin=true;plain=body(actor);
         check(plain!=null && !frozen(plain),"loaded player has a plain native body reference");
         var appURI:File=File.applicationDirectory,nativeAppPath:String=appURI.nativePath;
         var pathInfo:Object={url:appURI.url,nativePath:nativeAppPath,applicationId:NativeApplication.nativeApplication.applicationID};
         note("coordination-path-raw",pathInfo);Log.d("OFFLINE FIRST CONNECT PATH "+JSON.stringify(pathInfo));
         if(nativeAppPath==null || nativeAppPath.length==0 || nativeAppPath.length>4096)
            throw new Error("Invalid or unbounded applicationDirectory.nativePath before coordination traversal");
         // app:/ is an AIR virtual root and can have no parent. Traverse its real disk counterpart.
         var app:File=new File(nativeAppPath);sharedRun=app.parent;
         var cooperation:File=sharedRun==null?null:sharedRun.parent;
         var buildRoot:File=cooperation==null?null:cooperation.parent;
         var modRoot:File=buildRoot==null?null:buildRoot.parent;
         runToken=sharedRun==null?"":sharedRun.name;
         check(app.url.indexOf("file:")==0 && app.name==(host?"host":"join") && /^[0-9a-f]{10}$/.test(runToken)
            && cooperation!=null && cooperation.name=="cooperation" && buildRoot!=null && buildRoot.name=="build"
            && modRoot!=null && modRoot.name.toLowerCase()=="rconnect"
            && NativeApplication.nativeApplication.applicationID=="pfe-modsettings-rconnect-coop-"+app.name+"-"+runToken,
            "coordination path belongs to this exact isolated role and run");
         old={weapons:inventory.weapons,gun:actor.currentWeapon,children:actor.childObjs,childEntries:actor.childObjs.concat(),
            magic:actor.magicWeapon,thrown:actor.throwWeapon,x:actor.X,y:actor.Y,side:actor.storona,invulner:actor.invulner,
            cx:actor.celX,cy:actor.celY,wx:world.celX,wy:world.celY,camx:world.cam.celX,camy:world.cam.celY,
            key:world.ctr.keyAttack,port:config.getValue("port"),ip:config.getValue("hostIp")};
         privateWeapons=[];for(var key:String in old.weapons)privateWeapons[key]=old.weapons[key];
         inventory.weapons=privateWeapons;prepared=true;actor.changeWeapon("not",true);privateWeapons.lmg=null;
         gun=inventory.addWeapon("lmg",16777215,200);check(gun!=null,"native inventory creates one owned LMG");
         gun.lvl=0;gun.perslvl=0;actor.changeWeapon("lmg",true);
         check(actor.currentWeapon===gun && gun.owner===actor && actor.childObjs.indexOf(gun)>=0,"native inventory equips fixture LMG");
         var visual:Class=gun.vBullet as Class;expectedClass=getQualifiedClassName(new visual());
         actor.invulner=true;lane=findLane();place(lane.x,lane.y,false);
         mod.stage.addEventListener(Event.ENTER_FRAME,before,false,100000);
         mod.stage.addEventListener(Event.RENDER,render,false,-2147483647);
         armShot();change("offline-shot");
      }
      private function findLane():Object {
         var loc:Object=bridge.loc,speed:Number=Math.abs(Number(gun.speed)*Number(gun.speedMult));
         if(!isFinite(speed) || speed<=0)throw new Error("Unknown native LMG speed");
         // Both turns fire right from the same front position; the receiver stands 140px behind.
         // Preserve two real movement samples and the old 14-tile / four-row projectile corridor.
         var clearance:Number=2*speed+80,cells:int=Math.max(14,Math.ceil((clearance+60)/40));
         var rejected:Object={},samples:Array=[],searched:int=0;
         // Existing terrain only: no tile edits, world redraw or NPC removal.
         for(var y:int=4;y<int(loc.spaceY)-2;y++)for(var x:int=4;x-1+cells<=int(loc.spaceX);x++) {
            var result:Object={x:x*40+20,y:(y+1)*40,left:(x-1)*40,right:(x-1+cells)*40,
               top:(y-3)*40,bottom:(y+1)*40,cells:cells,speed:speed,clearance:clearance,receiverX:x*40+20-140};
            ++searched;var reason:String=laneIssue(result);
            if(reason==""){note("existing-lane",result);return result;}
            var category:String=reason.split(":")[0];rejected[category]=int(rejected[category])+1;
            if(samples.length<6)samples.push({x:result.x,y:result.y,reason:reason});
         }
         note("lane-search-failed",{searched:searched,cells:cells,speed:speed,clearance:clearance,
            roomWidth:loc.spaceX,roomHeight:loc.spaceY,bodyWidth:actor.scX,bodyHeight:actor.scY,rejected:rejected,samples:samples});
         throw new Error("No existing dry enemy-free one-way lane for two native LMG samples; required cells="+cells);
      }
      private function laneIssue(value:Object):String {
         var loc:Object=bridge.loc,speed:Number=Math.abs(Number(gun.speed)*Number(gun.speedMult));
         if(value==null || !isFinite(Number(value.x)) || !isFinite(Number(value.y))
            || !isFinite(Number(value.left)) || !isFinite(Number(value.right)) || !isFinite(Number(value.top)) || !isFinite(Number(value.bottom))
            || !isFinite(speed) || speed<=0 || Number(value.receiverX)!=Number(value.x)-140
            || Number(value.left)!=Number(value.x)-60 || Number(value.bottom)!=Number(value.y)
            || Number(value.top)!=Number(value.y)-160 || Number(value.right)<Number(value.x)+2*speed+80
            || Number(value.right)-Number(value.left)<560
            || Number(value.left)<0 || Number(value.right)>int(loc.spaceX)*40
            || Number(value.top)<0 || Number(value.bottom)>=int(loc.spaceY)*40)return "bounds: invalid lane or insufficient native forward travel";
         for(var cx:int=int(value.left/40);cx<int(value.right/40);cx++)
            for(var cy:int=int(value.top/40);cy<int(value.bottom/40);cy++) {
               var t:Object=loc.space[cx][cy];
               if(t==null || Number(t.water)>0 || t.fake || t.door!=null || Number(t.phis)!=0)
                  return "projectile: tile "+cx+","+cy;
            }
         // Standing players need their actual body clearance and floor, not four air rows over the rear room.
         for each(var px:Number in [Number(value.x),Number(value.receiverX)]) {
            var reason:String=standingIssue(px,Number(value.y));if(reason!="")return reason;
         }
         var ghost:Object=remoteGhost();
         for each(var u:Object in loc.units)if(u!==actor && u!==ghost && int(u.sost)<3
            && u.X>Number(value.left)-120 && u.X<Number(value.right)+120
            && u.Y>Number(value.top)-120 && u.Y<Number(value.bottom)+160)
            return "projectile-npc: "+getQualifiedClassName(u)+" at "+u.X+","+u.Y;
         return "";
      }
      private function standingIssue(px:Number,py:Number):String {
         var loc:Object=bridge.loc,half:Number=Math.max(Number(actor.scX),Number(actor.stayX))*.5;
         var height:Number=Math.max(Number(actor.scY),Number(actor.stayY));
         if(!isFinite(half) || half<=0 || !isFinite(height) || height<=0)return "body: unknown native dimensions";
         var left:int=Math.floor((px-half)/40),right:int=Math.floor((px+half-.01)/40);
         var top:int=Math.floor((py-height)/40),bottom:int=Math.floor((py-.01)/40),floor:int=Math.floor(py/40);
         if(left<0 || right>=int(loc.spaceX) || top<0 || floor>=int(loc.spaceY))return "body: outside room";
         for(var cx:int=left;cx<=right;cx++) {
            for(var cy:int=top;cy<=bottom;cy++) {
               var t:Object=loc.space[cx][cy];
               if(t==null || Number(t.phis)!=0 || Number(t.water)>0 || t.fake || t.door!=null)return "body: tile "+cx+","+cy;
            }
            t=loc.space[cx][floor];
            if(t==null || Number(t.phis)<1 || Number(t.water)>0 || t.fake || t.door!=null)return "floor: tile "+cx+","+floor;
         }
         var ghost:Object=remoteGhost();
         for each(var u:Object in loc.units)if(u!==actor && u!==ghost && int(u.sost)<3) {
            var uh:Number=Number(u.scX)*.5,uv:Number=Number(u.scY);
            if(!isFinite(uh) || uh<0 || !isFinite(uv) || uv<0)return "standing-npc: unknown native dimensions";
            if(uh>0 && uv>0 && Number(u.X)+uh>px-half && Number(u.X)-uh<px+half && Number(u.Y)>py-height && Number(u.Y)-uv<py)
               return "standing-npc: "+getQualifiedClassName(u)+" at "+u.X+","+u.Y;
         }
         return "";
      }
      private function place(x:Number,y:Number,left:Boolean):void {
         lane={x:x,y:y};aimLeft=left;actor.setPos(x,y);actor.setVisPos();
      }
      private function identity():void {
         if(RConnectMod.instance!==mod || Object(mod.game)!==bridge || Object(mod.session)!==session || Object(mod.config)!==config
            || bridge.gg!==actor || actor.invent!==inventory || inventory.weapons!==privateWeapons
            || actor.currentWeapon!==gun || inventory.weapons.lmg!==gun || gun.owner!==actor)
            throw new Error("Original player/inventory/same equipped gun identity changed; no repair permitted");
         if(bridge.offlinePresentationEligibility!==originalHook)throw new Error("Original collection hook replaced");
         if(world.verror!=null && world.verror.visible)throw new Error("Native error dialog");
      }
      private function armShot():void {
         issued=false;bullet=null;lastBullet=gun.b;shotBase=int(gun.kol_shoot);shotAmmo=Number(gun.hold);sourceShotCount=0;nativeFrames=[];sourcePixels=0;attackState=null;
      }
      private function before(e:Event):void {
         if(finished || phase=="finishing")return;
         try {
            ++frame;identity();
            mod.stage.invalidate(); // Initial arrival must render before roomReady/prepare can finish.
            if(phase=="connecting" || phase=="prepare" || phase=="rendezvous")return;
            if(phase=="offline-shot" || phase=="offline-freeze" || phase=="offline-clear" || round>=0) {
               world.ctr.keyAttack=false;actor.storona=aimLeft?-1:1;
               actor.celX=world.celX=actor.X+(aimLeft?-500:500);actor.celY=world.celY=actor.Y-actor.scY*.7;
               world.cam.celX=int(world.celX*world.cam.scaleV+world.cam.vx);world.cam.celY=int(world.celY*world.cam.scaleV+world.cam.vy);
               actor.setWeaponPos(gun.tip);gun.findCel=false;gun.forceRot=aimLeft?Math.PI:0;
               if((phase=="offline-shot" || phase=="round" && shotSource()) && !issued && getTimer()-phaseAt>=600) {
                  if(round==1){closeArrival();send("fresh-shot-start");}
                  attackState={at:getTimer(),frame:frame,hold:Number(gun.hold),holder:Number(gun.holder),rashod:Number(gun.rashod),
                     kolShoot:int(gun.kol_shoot),tAttack:Number(gun.t_attack),tReload:Number(gun.t_reload),tPrep:Number(gun.t_prep),
                     bSamePrevious:gun.b===lastBullet,bNull:gun.b==null,armedAmmo:shotAmmo};
                  check(gun.b===lastBullet,"no extra native shot during preparation");
                  shotAmmo=Number(attackState.hold);
                  check(gun.attack()===true,"one native attack accepted "+phase+" round="+round);issued=true;
               }
            }
            mod.stage.invalidate();
         }catch(error:*){abort(error);}
      }
      private function shotSource():Boolean {return round==1&&host || round==2&&!host;}
      private function watch(link:TcpLink):void {
         if(link!=null && !links[link]){links[link]=true;link.addEventListener(TcpLink.MESSAGE,receive);}
      }
      private function accepted(e:NetMessageEvent):void {watch(e.data as TcpLink);}
      private function flag(role:String,name:String):File {return sharedRun.resolvePath("offline-first-connect-"+role+"-"+name+".json");}
      private function writeFlag(name:String):void {
         var role:String=host?"host":"join",path:File=flag(role,name),temporary:File=flag(role,name+"-writing");
         check(!path.exists && !temporary.exists,"new owned coordination flag "+name);
         var value:Object={run:runToken,role:role,phase:name,version:VERSION,port:int(config.getValue("port")),
            applicationId:NativeApplication.nativeApplication.applicationID};
         var f:FileStream=new FileStream();
         ownedFlags.push(temporary);ownedFlags.push(path);
         try {f.open(temporary,FileMode.WRITE);f.writeUTFBytes(JSON.stringify(value));}finally {f.close();}
         temporary.moveTo(path,false); // Publish only the completely closed file.
         note("owned-flag",value);
      }
      private function hasFlag(role:String,name:String):Boolean {
         var path:File=flag(role,name);if(!path.exists)return false;
         if(path.size<=0 || path.size>2048)throw new Error("Invalid coordination flag size");
         var f:FileStream=new FileStream(),value:Object;
         try {f.open(path,FileMode.READ);value=JSON.parse(f.readUTFBytes(f.bytesAvailable));}finally {f.close();}
         if(value.run!==runToken || value.role!==role || value.phase!==name || value.version!==VERSION
            || int(value.port)!=int(config.getValue("port"))
            || value.applicationId!=="pfe-modsettings-rconnect-coop-"+role+"-"+runToken)
            throw new Error("Foreign or stale coordination flag");
         return true;
      }
      private function connectOnce():void {
         check(attempts==0 && session.mode=="offline" && session.canSkipOfflinePresentation()===true,"no prior hidden network attempt");
         ++attempts;attemptAt=getTimer();change("connecting");
         if(host){session.startHost();server=session.server;check(server!=null && server.bound,"first host call really listens");
            server.addEventListener("clientAdded",accepted);for each(var c:TcpLink in server.clients)watch(c);
            writeFlag("listening");
         }else {session.startJoin();watch(session.link as TcpLink);}
         check(session.canSkipOfflinePresentation()===false && originalHook()===false,"first attempt restores collection permanently");
      }
      private function send(op:String,data:Object=null):void {
         data=data||{};data.type=TYPE;data.op=op;data.round=round;
         if(host){if(session.server!=null)session.server.broadcast(data);}
         else if(session.link!=null && session.link.isOpen)session.link.send(data);
      }
      private function roomReady():Boolean {
         return !bridge.isTransitioning() && !world.onPause && world.allStat==1 && session.rooms.ready && !session.rooms.busy && remoteGhost()!=null
            && (host?session.peers.length==1:session.mode=="connected" && session.remotes.length==1);
      }
      private function remoteGhost():Object {
         if(session==null || bridge==null || host && session.peers.length!=1)return null;
         return bridge.getRemoteGhost(host?int(session.peers[0].id):0);
      }
      private function begin(n:int):void {
         if(n==0){check(peerClass==expectedClass && playable==0,"same LMG class and no playable old event during first arrival");quietPacketStart=packetSamples;}
         round=n;change("round");localDone=peerDone=false;peerReport=null;oracle=null;peerShotProof=null;
         renderSamples=visibleSamples=bodyMatches=muzzleFrames=pixelCount=0;
         // Keep the first-attempt ledger across begin(0) and begin(1), right up to the real first shot.
         if(arrivalClosed)resetWire();remoteFrames=[];lastRender=-1;
         if(n==1 || n==2) {
            var issue:String=laneIssue(onlineLane);check(issue=="","same existing one-way firing lane remains valid: "+issue);
            place(shotSource()?Number(onlineLane.x):Number(onlineLane.receiverX),Number(onlineLane.y),false);armShot();
         }
         if(n==3 && host)actor.addEffect("freezing",0,30,false);
         if(n==4 && host)actor.remEffect("freezing");
      }
      private function resetWire():void {packetSamples=wireEvents=tombstones=playable=0;trace=[];eventKeys={};}
      private function closeArrival():void {
         check(!arrivalClosed && round==1 && coverage.quietNoReplay===true && playable==0 && peerClass==expectedClass,
            "complete first-attempt silence before first fresh attack");
         note("first-attempt-through-fresh-shot",{start:attemptAt,end:getTimer(),packets:packetSamples,events:wireEvents,
            tombstones:tombstones,playable:playable,renders:preQuietRenders,rawBytes:arrivalBytes,wire:trace});
         arrivalClosed=true;resetWire();
      }
      private function receive(e:NetMessageEvent):void {
         if(finished)return;
         try {
            var p:Object=e.data;
            if(p.type=="hello")helloSeen=true;if(p.type=="welcome")welcomeSeen=true;
            if(p.type!=TYPE){observePacket(p);return;}
            if(p.op=="ready" && host && phase=="connecting") {
               peerReady=true;peerPlain=p.plain;peerClass=String(p.cls);
               check(peerClass==expectedClass,"peer first-arrival class matches locally observed same LMG");
            }else if(p.op=="prepare" && !host && phase=="connecting") {
               check(roomReady() && String(p.key)==String(bridge.roomKey()),"same real room before visual fixture");
               peerPlain=p.plain;peerClass=String(p.cls);roomKey=String(p.key);onlineLane=p.lane;
               check(peerClass==expectedClass,"peer first-arrival class matches locally observed same LMG");
               var issue:String=laneIssue(onlineLane);check(issue=="","received existing lane supports local native gun and body: "+issue);
               place(Number(onlineLane.receiverX),Number(onlineLane.y),false);change("prepare");send("prepared",{plain:body(actor),cls:expectedClass});
            }else if(p.op=="prepared" && host && phase=="prepare") {
               peerPlain=p.plain;peerClass=String(p.cls);check(peerClass==expectedClass,"prepared peer retains same LMG class");begin(0);send("begin",{n:0});
            }else if(p.op=="begin" && !host && (phase=="prepare" || phase=="round")) {
               check(int(p.n)==round+1,"round order is sequential");begin(int(p.n));
            }else if(p.op=="fresh-shot-start" && !host){check(int(p.round)==1,"first fresh shot marker belongs to host stage");closeArrival();}
            else if(p.op=="oracle" && int(p.round)==round)oracle=p.body;
            else if(p.op=="shot-proof" && int(p.round)==round)peerShotProof=p.proof;
            else if(p.op=="report" && host && int(p.round)==round){peerDone=true;peerReport=p.report;advance();}
            else if(p.op=="finish" && !host){check(phase=="round" && round==4 && localDone,"all local stages completed before finish");
               finishRequested=true;change("finishing");send("finish-ack");finish();}
            else if(p.op=="finish-ack" && host && phase=="finishing" && finishRequested) {
               check(int(p.round)==4 && localDone && peerDone,"final peer acknowledgment follows both completed proofs");
               finishAckSeen=true;finish();
            }
         }catch(error:*){abort(error);}
      }
      private function observePacket(p:Object):void {
         if(phase!="round" && phase!="connecting" && phase!="prepare")return;
         if(host && p.type=="playerstate" && p.snap!=null)observeSnapshot(p.snap);
         if(!host && p.type=="worldstate" && p.players is Array)
            for each(var player:Object in p.players)if(int(player.id)==0 && player.snap!=null)observeSnapshot(player.snap);
      }
      private function observeSnapshot(s:Object):void {
         ++packetSamples;if(!(s.weapons is Array))return;
         for each(var w:Object in s.weapons)if(w.id=="lmg" && w.events is Array)
            for each(var ev:Object in w.events) {
               var f:Object=ev.flight,raw:String=JSON.stringify(ev);
               if(raw.length>8192)throw new Error("Related LMG event exceeds raw evidence bound");
               // Preserve updates to a seq too: an empty first ending must not hide a later playable payload.
               var key:String=String(w.stream)+":"+String(ev.seq);if(eventKeys[key]===raw)continue;eventKeys[key]=raw;++wireEvents;
               if(trace.length>=64)throw new Error("Wire event revision capacity exceeded");
               var known:Boolean=w.main===true && f!=null && String(f.cls)==expectedClass;
               // ended alone is NOT a tombstone: legacy packets create a visual even when ended.
               var isTomb:Boolean=known && f.frames is Array && f.frames.length==0 && f.ended===true;
               if(isTomb)++tombstones;else ++playable;
               var row:Object={at:getTimer(),stream:w.stream,seq:ev.seq,main:w.main,known:known,
                  flight:f==null?null:{cls:f.cls,ended:f.ended,hasFrames:f.frames is Array,frames:f.frames is Array?f.frames.length:-1,end:f.end,x:f.x,y:f.y,ex:f.ex,ey:f.ey}};
               if(!arrivalClosed){arrivalBytes+=raw.length;if(arrivalBytes>65536)throw new Error("First arrival raw evidence capacity exceeded");row.raw=JSON.parse(raw);}
               trace.push(row);
               if(!known || !arrivalClosed && !isTomb){note("unclassified-or-old-playable-event",row);throw new Error("Related LMG event is unclassified or playable before fresh attack");}
            }
      }
      private static function color(v:DisplayObject):Array {
         var c:ColorTransform=v.transform.colorTransform;
         return [c.redMultiplier,c.greenMultiplier,c.blueMultiplier,c.alphaMultiplier,c.redOffset,c.greenOffset,c.blueOffset,c.alphaOffset];
      }
      private static function body(u:Object):Object {
         if(u==null || !(u.vis is DisplayObject) || !(u.vis.osn is DisplayObject))return null;
         return {c:color(u.vis),oc:color(u.vis.osn),a:Number(u.vis.alpha),oa:Number(u.vis.osn.alpha),v:Boolean(u.vis.osn.visible)};
      }
      private static function frozen(b:Object):Boolean {return b!=null && Number(b.c[4])>0 && Number(b.c[6])>0;}
      private static function sameBody(a:Object,b:Object,peer:Boolean=false):Boolean {
         if(a==null || b==null || a.v!==b.v || Math.abs(a.a-(peer ? .75*b.a : b.a))>.02 || Math.abs(a.oa-b.oa)>.02)return false;
         for(var i:int=0;i<8;i++) {
            var expected:Number=peer&&i==3 ? .75*Number(b.a) : peer&&i==7 ? .75*Number(b.c[i]) : Number(b.c[i]);
            if(Math.abs(Number(a.c[i])-expected)>.02 || Math.abs(Number(a.oc[i])-Number(b.oc[i]))>.02)return false;
         }
         return true;
      }
      private static function peerNeutral(b:Object):Array {var c:Array=b.c.concat();c[3]=.75*b.a;c[7]=.75*Number(c[7]);return c;}
      private function pixels(v:DisplayObject,neutral:Array=null):int {
         var root:DisplayObject=mod.main as DisplayObject,r:Rectangle=v.getBounds(root);
         r=r.intersection(new Rectangle(0,0,mod.stage.stageWidth,mod.stage.stageHeight));
         if(r.width<1 || r.height<1 || r.width*r.height>150000)return 0;
         var a:BitmapData=new BitmapData(Math.ceil(r.width),Math.ceil(r.height),false,0),b:BitmapData=a.clone();
         var m:Matrix=new Matrix(1,0,0,1,-r.x,-r.y),visible:Boolean=v.visible,c:ColorTransform=v.transform.colorTransform,n:int=0;
         try {
            a.draw(root,m);
            if(neutral==null)v.visible=false;
            else v.transform.colorTransform=new ColorTransform(neutral[0],neutral[1],neutral[2],neutral[3],neutral[4],neutral[5],neutral[6],neutral[7]);
            b.draw(root,m);var av:Vector.<uint>=a.getVector(a.rect),bv:Vector.<uint>=b.getVector(b.rect);
            for(var i:int=0;i<av.length;i++)if(av[i]!=bv[i])++n;
         }finally {v.visible=visible;v.transform.colorTransform=c;a.dispose();b.dispose();}
         return n;
      }
      private function matchingClips():Array {
         var layer:DisplayObjectContainer=world.grafon.visObjs[2] as DisplayObjectContainer,out:Array=[];
         if(layer==null)throw new Error("Native projectile display layer missing");
         for(var i:int=0;i<layer.numChildren;i++) {
            var v:DisplayObject=layer.getChildAt(i);
            if(getQualifiedClassName(v)==(peerClass==""?expectedClass:peerClass) && v.visible && v.alpha>0 && v.stage!=null)out.push(v);
         }
         return out;
      }
      private function sourceFrame():void {
         if(!issued)return;
         if(gun.b!==lastBullet && bullet==null){bullet=gun.b;++sourceShotCount;}
         if(bullet==null)return;
         // Native Weapon.step resets kol_shoot after preparation, so it is not a lifetime counter.
         if(gun.b!==bullet || bullet.owner!==actor || bullet.weap!==gun || Math.abs(shotAmmo-Number(gun.hold)-Math.max(1,Number(gun.rashod)))>.001) {
            var raw:Object={gunBSameBullet:gun.b===bullet,gunBSamePrevious:gun.b===lastBullet,gunBNull:gun.b==null,
               ownerIsActor:bullet.owner===actor,weapIsGun:bullet.weap===gun,gunOwnerIsActor:gun.owner===actor,
               ownerNull:bullet.owner==null,weapNull:bullet.weap==null,
               bulletClass:getQualifiedClassName(bullet),ownerClass:bullet.owner==null?null:getQualifiedClassName(bullet.owner),
               weapClass:bullet.weap==null?null:getQualifiedClassName(bullet.weap),inChain:bullet.in_chain,
               shotAmmo:shotAmmo,hold:Number(gun.hold),holder:Number(gun.holder),rashod:Number(gun.rashod),
               expectedDebit:Math.max(1,Number(gun.rashod)),observedDebit:shotAmmo-Number(gun.hold),
               armedKolShoot:shotBase,kolShoot:int(gun.kol_shoot),sourceShotCount:sourceShotCount,nativeSamples:nativeFrames.length,
               ammo:String(gun.ammo),kol:Number(gun.kol),dkol:Number(gun.dkol),recharg:Number(gun.recharg),
               tAttack:Number(gun.t_attack),tReload:Number(gun.t_reload),tPrep:Number(gun.t_prep),attackBefore:attackState};
            note("native-shot-invariant-failed",raw);Log.d("OFFLINE FIRST CONNECT SHOT "+JSON.stringify(raw));
            throw new Error("Unexpected extra shot or native projectile ownership change");
         }
         var v:DisplayObject=bullet.vis as DisplayObject;
         if(bullet.in_chain===true && v!=null && v.visible && v.alpha>0 && v.stage!=null) {
            if(nativeFrames.length>=64)throw new Error("Native flight sample capacity exceeded");
            nativeFrames.push({at:getTimer(),frame:frame,x:v.x,y:v.y});
            if(sourcePixels==0)sourcePixels=pixels(v);
         }
      }
      private function render(e:Event):void {
         if(finished || phase=="finishing" || !prepared || lastRender==frame)return;lastRender=frame;
         try {
            identity();
            if(attempts>0 && !arrivalClosed) {
               // This includes connecting/prepare and begin(1)'s wait before the host's actual attack.
               var remote:Object=remoteGhost(),oldClips:int=matchingClips().length;
               if(oldClips>0){note("early-projectile-display",{clips:oldClips});throw new Error("Old projectile displayed before first fresh attack");}
               if(remote!=null && remote!==actor && remote.loc===bridge.loc && remote.vis!=null && remote.vis.stage===mod.stage) {
                  ++preQuietRenders;
                  var earlyBody:Object=body(remote),earlyMuzzle:Object=GameBridge.probe(GameBridge.probe(remote.currentWeapon,"vis"),"currentLabel");
                  if(frozen(earlyBody) || earlyMuzzle=="shoot") {
                     note("early-body-or-muzzle-display",{body:earlyBody,muzzle:earlyMuzzle});
                     throw new Error("Old body or muzzle displayed before first fresh attack");
                  }
               }
            }
            if(phase=="offline-shot") {
               sourceFrame();
               if(bullet!=null && bullet.in_chain!==true) {
                  check(nativeFrames.length>=2 && moved(nativeFrames) && sourcePixels>0,"offline same-gun native shot visibly moved then ended");
                  coverage.offlineShot=true;offlineBullet=bullet;note("offline-shot",{native:nativeFrames,pixels:sourcePixels,kol:gun.kol_shoot});
                  actor.addEffect("freezing",0,30,false);change("offline-freeze");
               }
            }else if(phase=="offline-freeze") {
               var b:Object=body(actor);
               if(frozen(b) && !offlineFrozen){check(pixels(actor.vis,plain.c)>0,"offline freezing changes actual final pixels");offlineFrozen=true;freezeAt=getTimer();coverage.offlineBody=true;note("offline-freeze",b);}
               if(offlineFrozen && getTimer()-freezeAt>=500){actor.remEffect("freezing");change("offline-clear");}
            }else if(phase=="offline-clear") {
               if(sameBody(body(actor),plain)){++clearFrames;if(offlineClearAt==0)offlineClearAt=getTimer();}else{clearFrames=0;offlineClearAt=0;}
               if(clearFrames>=12 && getTimer()-offlineClearAt>=1200){check(offlineBullet.in_chain!==true,"old bullet stays naturally ended before first connect");coverage.offlineClear=true;note("offline-clear",{frames:clearFrames,body:body(actor)});writeFlag("ready");change("rendezvous");}
            }else if(phase=="round")renderRound();
         }catch(error:*){abort(error);}
      }
      private static function moved(points:Array):Boolean {
         if(points.length<2)return false;var a:Object=points[0];
         for each(var b:Object in points)if(Math.abs(b.x-a.x)+Math.abs(b.y-a.y)>.1)return true;return false;
      }
      private function renderRound():void {
         if(!roomReady() || String(bridge.roomKey())!=roomKey)throw new Error("Ready room identity changed during observation");
         ++renderSamples;
         var ghost:Object=remoteGhost(),v:DisplayObject=ghost.vis as DisplayObject,b:Object=body(ghost),clips:Array;
         if(ghost===actor || ghost.loc!==bridge.loc || v==null || v.stage!==mod.stage)throw new Error("Remote ghost is not a distinct staged entity in this room");
         if(round==0) {
            clips=matchingClips();if(clips.length>0)throw new Error("Old bullet artwork rendered during initial silent window");
            if(GameBridge.probe(GameBridge.probe(ghost.currentWeapon,"vis"),"currentLabel")=="shoot")throw new Error("Old muzzle animation replayed in silence");
            if(getTimer()-phaseAt>600){checkNoCount(sameBody(b,peerPlain,true),"Old body effect replayed in silence");++bodyMatches;}
            if(pixelCount==0 && v!=null)pixelCount=pixels(v);
         }else if(round==1 || round==2) {
            if(shotSource())sourceFrame();
            else {
               clips=matchingClips();if(clips.length>1)throw new Error("Ambiguous multiple projectile visuals in single-shot fixture");
               if(clips.length==1){++visibleSamples;if(remoteFrames.length>=64)throw new Error("Remote sample capacity exceeded");
                  remoteFrames.push({at:getTimer(),frame:frame,x:clips[0].x,y:clips[0].y});if(pixelCount==0)pixelCount=pixels(clips[0]);}
               if(GameBridge.probe(GameBridge.probe(ghost.currentWeapon,"vis"),"currentLabel")=="shoot")++muzzleFrames;
            }
         }else if(round==3 || round==4) {
            var local:Object=body(actor),expected:Object=host?local:oracle,actual:Object=host?local:b;
            if(getTimer()-phaseAt>700 && expected!=null && (round==3?frozen(expected):sameBody(expected,plainForSource()))) {
               checkNoCount(sameBody(actual,expected,!host),"Final ghost body differs from source native body");++bodyMatches;
               if(round==3 && pixelCount==0)pixelCount=pixels(host?actor.vis:v,host?plain.c:peerNeutral(peerPlain));
               if(round==4 && pixelCount==0)pixelCount=pixels(host?actor.vis:v);
            }
         }
      }
      private static function checkNoCount(ok:Boolean,label:String):void {if(!ok)throw new Error(label);}
      private function plainForSource():Object {return host?plain:peerPlain;}
      private function completeRound():void {
         var proof:Object={round:round,renders:renderSamples,packets:packetSamples,events:wireEvents,tombstones:tombstones,
            playable:playable,visible:visibleSamples,muzzle:muzzleFrames,pixels:pixelCount,bodyMatches:bodyMatches,wire:trace};
         if(round==0){check(renderSamples>=12 && packetSamples-quietPacketStart>=3 && bodyMatches>=12 && pixelCount>0 && playable==0,"first connected quiet window contains no replay and a visible peer");coverage.quietNoReplay=true;proof.quietPackets=packetSamples-quietPacketStart;}
         else if(round==1 || round==2) {
            if(shotSource()) {
               check(issued && bullet!=null && bullet.in_chain!==true && nativeFrames.length>=2 && moved(nativeFrames) && sourcePixels>0,"new native shot visibly moved and naturally ended");
               proof.native=nativeFrames;proof.spawn={x:bullet.begx,y:bullet.begy};proof.sourcePixels=sourcePixels;proof.oneShot=sourceShotCount==1;send("shot-proof",{proof:proof});
            }else {
               check(peerShotProof!=null && peerShotProof.oneShot===true && peerShotProof.sourcePixels>0,"receiver has source proof of one real native shot");
               check(playable>=1 && visibleSamples>=2 && moved(remoteFrames) && pixelCount>0 && muzzleFrames>0,"new peer shot has production event, moving final bullet pixels and muzzle animation");
               check(matchesSource(peerShotProof,remoteFrames),"remote motion lies on independently observed native source flight");proof.remote=remoteFrames;
            }
            coverage[round==1?"hostFire":"joinFire"]=true;
         }else {check(bodyMatches>=12 && pixelCount>0,"native freezing/clear reaches final peer display round="+round);coverage[round==3?"bodyApplied":"bodyCleared"]=true;}
         localDone=true;note("round-proof",proof);if(!host)send("report",{report:proof});else advance();
      }
      private function advance():void {
         if(!host || phase!="round" || !localDone || !peerDone)return;
         check(peerReport!=null && int(peerReport.round)==round,"other real game completed same stage");
         if(round<4){var next:int=round+1;begin(next);send("begin",{n:next});}
         else {finishRequested=true;change("finishing");send("finish");}
      }
      private static function matchesSource(proof:Object,points:Array):Boolean {
         if(!(proof.native is Array) || proof.native.length<2 || proof.spawn==null)return false;
         var minX:Number=proof.spawn.x,maxX:Number=minX,minY:Number=proof.spawn.y,maxY:Number=minY;
         for each(var p:Object in proof.native){minX=Math.min(minX,p.x);maxX=Math.max(maxX,p.x);minY=Math.min(minY,p.y);maxY=Math.max(maxY,p.y);}
         for each(p in points)if(p.x<minX-80 || p.x>maxX+80 || p.y<minY-80 || p.y>maxY+80)return false;
         return points.length>=2;
      }
      private function tick(e:TimerEvent):void {
         if(finished)return;
         try {
            var now:int=getTimer();
            if(now-began>TOTAL_MS || now-phaseAt>(phase=="boot"?BOOT_MS:phase=="connecting" || phase=="rendezvous"?CONNECT_MS:20000))throw new Error("Bounded deadline exceeded: "+phase);
            if(phase=="finishing")return; // Completed observations; only the bounded final acknowledgment remains.
            if(!prepared)return;identity();
            if(attempts>0 && (session.mode=="offline" || String(session.error)!=""))throw new Error("First connection failed; automatic retry is not accepted");
            if(phase=="rendezvous" && hasFlag(host?"join":"host","ready")) {
               if(host || hasFlag("host","listening"))connectOnce();
            }
            if(phase=="connecting" && roomReady() && readyNative()) {
               checkNoCount(session.canSkipOfflinePresentation()===false && originalHook()===false,"Connected capture shortcut unexpectedly resumed");
               if(!readySent){check(host?helloSeen:welcomeSeen,"real first handshake observed");coverage.firstConnection=true;readySent=true;
                  note("first-room-ready",{key:bridge.roomKey(),sameGun:actor.currentWeapon===gun,attempts:attempts});
                  if(!host)send("ready",{plain:body(actor),cls:expectedClass});}
               if(host && peerReady && !prepareSent){prepareSent=true;onlineLane=findLane();roomKey=String(bridge.roomKey());
                  place(onlineLane.x,onlineLane.y,false);change("prepare");send("prepare",{lane:onlineLane,key:roomKey,plain:body(actor),cls:expectedClass});}
            }
            if(phase=="round" && !localDone) {
               if(host && round>=3 && now-lastOracleAt>=100){lastOracleAt=now;send("oracle",{body:body(actor)});}
               if(now-phaseAt>=WINDOW_MS) {
                  if((round==1 || round==2) && (shotSource()?bullet==null || bullet.in_chain===true:peerShotProof==null))return;
                  completeRound();
               }
            }else if(phase=="round" && host && round>=3 && now-lastOracleAt>=100){lastOracleAt=now;send("oracle",{body:body(actor)});}
         }catch(error:*){abort(error);}
      }
      private function uncaught(e:UncaughtErrorEvent):void {e.preventDefault();abort(e.error);}
      private function abort(error:*):void {
         if(finished)return;abortReason=String(error is Error?(Error(error).getStackTrace()||String(error)):error);
         ++failed;Log.d("COOP FAIL offline-first-connect "+abortReason);finish();
      }
      private function finish():void {
         if(finished)return;finished=true;
         removeEventListener(Event.ENTER_FRAME,boot);timer.stop();timer.removeEventListener(TimerEvent.TIMER,tick);
         loaderInfo.uncaughtErrorEvents.removeEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,uncaught);
         if(mod!=null){mod.stage.removeEventListener(Event.ENTER_FRAME,before);mod.stage.removeEventListener(Event.RENDER,render);}
         for(var l:Object in links)TcpLink(l).removeEventListener(TcpLink.MESSAGE,receive);
         if(server!=null)server.removeEventListener("clientAdded",accepted);
         var cleanup:Object={errors:[],equipmentRestored:false,configRestored:false,sessionReleased:false,bodyCleared:false,hookUnchanged:false,flagsRemoved:false};
         if(prepared) {
            try {
               if(RConnectMod.instance!==mod || Object(mod.session)!==session)throw new Error("Owned Session no longer belongs to this mod");
               session.leave();cleanup.sessionReleased=session.mode=="offline" && session.server==null && session.link==null;
               if(!cleanup.sessionReleased)throw new Error("Owned Session did not release");
            }catch(sessionError:*){++failed;cleanup.errors.push(String(sessionError));Log.d("COOP FAIL offline-first-connect session cleanup "+sessionError);}
            try {
               identity();actor.remEffect("freezing");cleanup.bodyCleared=!frozen(body(actor));
               // Native animation may restore the tint on a later frame; do not forge its fields.
               cleanup.bodyRemovalRequested=true;
               actor.changeWeapon("not",true);inventory.weapons=old.weapons;actor.changeWeapon(old.gun==null?"not":String(old.gun.id),true);
               var childrenOK:Boolean=actor.childObjs===old.children && actor.childObjs.length==old.childEntries.length;
               for(var i:int=0;i<old.childEntries.length;i++)if(actor.childObjs[i]!==old.childEntries[i])childrenOK=false;
               cleanup.equipmentRestored=inventory.weapons===old.weapons && actor.currentWeapon===old.gun && childrenOK
                  && actor.magicWeapon===old.magic && actor.throwWeapon===old.thrown;
               actor.invulner=old.invulner;actor.storona=old.side;actor.setPos(old.x,old.y);actor.setVisPos();
               actor.celX=old.cx;actor.celY=old.cy;world.celX=old.wx;world.celY=old.wy;world.cam.celX=old.camx;world.cam.celY=old.camy;world.ctr.keyAttack=old.key;
               cleanup.hookUnchanged=bridge.offlinePresentationEligibility===originalHook;
               if(!cleanup.equipmentRestored || !cleanup.hookUnchanged)throw new Error("Required equipment cleanup identity failed");
            }catch(error:*){++failed;cleanup.errors.push(String(error));Log.d("COOP FAIL offline-first-connect cleanup "+error);}
            try {
               cleanup.configRestored=Object(mod.config)===config && config.getValue("port")===old.port && config.getValue("hostIp")===old.ip;
               if(!cleanup.configRestored)throw new Error("Private configuration changed unexpectedly");
            }catch(configError:*){++failed;cleanup.errors.push(String(configError));Log.d("COOP FAIL offline-first-connect configuration cleanup "+configError);}
         }else {cleanup.errors.push("Fixture never prepared");}
         try {
            // Each role removes only files it created; never the shared directory or peer files.
            for each(var owned:File in ownedFlags)if(owned.exists)owned.deleteFile();
            cleanup.flagsRemoved=true;for each(owned in ownedFlags)if(owned.exists)cleanup.flagsRemoved=false;
         }catch(flagError:*){++failed;cleanup.errors.push(String(flagError));Log.d("COOP FAIL offline-first-connect flag cleanup "+flagError);}
         var all:Boolean=true;for(var k:String in coverage)if(coverage[k]!==true)all=false;
         var complete:Boolean=finishRequested && (!host || finishAckSeen) && all && failed==0 && attempts==1 && arrivalClosed && cleanup.errors.length==0
            && cleanup.sessionReleased && cleanup.equipmentRestored && cleanup.configRestored && cleanup.bodyCleared
            && cleanup.hookUnchanged && cleanup.flagsRemoved;
         var endPhase:String=phase;phase="done";
         Log.d("OFFLINE FIRST CONNECT RESULT "+JSON.stringify({version:version,role:host?"host":"join",passed:complete,failed:failed,checks:checks,
            phase:phase,endedFrom:endPhase,abortReason:abortReason,attempts:attempts,coverage:coverage,cleanup:cleanup,observations:observations,
            elapsedMs:getTimer()-began,firstHandshake:{hello:helloSeen,welcome:welcomeSeen},finishAckReceived:finishAckSeen,performanceQualified:false,
            sameGunFirstConnectQualified:complete,scope:"one first session; two LMG shots and host freezing/clear; no cadence/performance claim"}));
         Log.d("COOP EFFECTS DONE offline-first-connect");
      }
   }
}

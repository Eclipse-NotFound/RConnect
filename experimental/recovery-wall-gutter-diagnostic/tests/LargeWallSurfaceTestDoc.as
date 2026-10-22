package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.display.Loader;
   import flash.display.BitmapData;
   import flash.display.PNGEncoderOptions;
   import flash.events.Event;
   import flash.events.MouseEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.geom.Rectangle;
   import flash.utils.ByteArray;
   import flash.utils.Dictionary;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;
   import rconnect.net.NetMessageEvent;
   import rconnect.net.TcpLink;

   /** Four true native Weapon.attack/step -> Bullet.tilehit -> Grafon marks.
    * Never calls production wall receive/capture/tick, Emitter, dyrka, pixel
    * write APIs or native chunk construction. No synthetic expected marks. */
   public class LargeWallSurfaceTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private static const SEED:uint=1380142925;
      private static const CASES:Array=[{weapon:"lmg",role:"host",shots:1},{weapon:"lmg",role:"join",shots:1},
         {weapon:"plamg",role:"host",shots:8},{weapon:"plamg",role:"join",shots:8}];
      private static const SAMPLE_MS:int=10000,MAX_SAMPLES:int=480;
      private var mod:RConnectMod,host:Boolean,source:Boolean,phase:String="boot",at:int=getTimer(),round:int=0;
      private var links:Dictionary=new Dictionary(),configured:Boolean=false,peerReady:Boolean=false,readySent:Boolean=false;
      private var sceneClass:Object,landClass:Object,oldSeed:Function,newSeed:Function;
      private var target:Object,targets:Array,area:Rectangle,gun:Object,oldGun:Object,oldChildren:Object,oldDisabled:Boolean,oldInventory:Object;
      private var bullets:Dictionary,contacts:Dictionary,shots:int=0,hits:Array=[],samples:Array=[],nativePairs:Array=[];
      private var baseline:Object,pre:Object,local:Object,peer:Object,peerSampled:Boolean=false,sampledSent:Boolean=false;
      private var sampleStart:int=0,sampleStartWall:Number=0,sampleEnd:int=0,wire:Array=[],lastReady:int=0;
      private var sampleCaptureMax:int=0,prepareWait:String="";
      private var attackAttempts:int=0,attackAccepted:int=0,firstAttack:Object,firstRejected:Object,weaponPreparation:Object;
      private var allRows:Array=[],proofs:Array=[],failed:int=0;
      private var colorProbe:NativeWallColorProbe=new NativeWallColorProbe();

      public function LargeWallSurfaceTestDoc() {
         var id:String=NativeApplication.nativeApplication.applicationID;if(id.indexOf("rconnect-coop-")<0)return;
         host=id.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            fail("uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();});
         addEventListener(Event.ENTER_FRAME,tick);
      }
      private function check(ok:Boolean,label:String):void {
         if(!ok)failed++;Log.d("COOP "+(ok?"PASS ":"FAIL ")+"large-wall-surfaces "+label+" case="+round);
      }
      private function fail(label:String):void {check(false,label);send("stop");finish();}
      private function send(op:String,p:Object=null):void {
         if(mod==null || mod.session==null)return;p=p||{};p.type="large-wall-test";p.op=op;p.round=round;
         if(host)mod.session.server.broadcast(p);else if(mod.session.link)mod.session.link.send(p);
      }
      private function watch(link:TcpLink):void {if(link!=null&&!links[link]){links[link]=true;link.addEventListener(TcpLink.MESSAGE,receive);colorProbe.attach(link);}}
      private function stable(land:String):Boolean {
         var w:Object=mod.game.world;return w!=null && w.loc!=null && w.land!=null && String(w.game.curLandId)==land
            && !mod.game.isTransitioning() && mod.session.rooms.ready && !mod.session.rooms.busy
            && !mod.session.rooms.entryPending && !w.onPause && w.allStat==1 && (!w.vblack.visible || w.vblack.alpha<=0);
      }
      private function configure():void {
         configured=true;mod.config.setValue("followTeammate","0");
         var native:MainFE=mod.game.main as MainFE;
         for(var k:Object in native.modEntryByLoader) {
            var loader:Loader=k as Loader;if(loader==null || !loader.contentLoaderInfo.applicationDomain.hasDefinition("ContinuousSceneMod"))continue;
            sceneClass=loader.contentLoaderInfo.applicationDomain.getDefinition("ContinuousSceneMod");
            sceneClass.nativeEnabled=host;break;
         }
         if(sceneClass==null || Boolean(sceneClass.nativeEnabled)!=host)throw new Error("CS native scene preference unavailable");
         landClass=mod.game.main.loaderInfo.applicationDomain.getDefinition("fe.loc.Land");oldSeed=landClass.rconnectSeedSource;
         newSeed=function(land:Object):uint {if(!host)return oldSeed(land);Object(mod.session.rooms).prepareMap(land,SEED,true);return SEED;};
         landClass.rconnectSeedSource=newSeed;
         mod.stage.addEventListener(Event.ENTER_FRAME,before,false,100000);
         mod.stage.addEventListener(Event.ENTER_FRAME,after,false,-6000);
         mod.stage.addEventListener(Event.RENDER,render,false,-40000);
      }
      private function choose():Array {
         // Existing world geometry only. No tile/decor/CS content writes.
         var loc:Object=mod.game.loc,out:Array=[],counts:Object={beyond:0,solid:0,material:0,lane:0,spaced:0};
         for(var x:int=8;x<loc.spaceX-3;x++)for(var y:int=3;y<loc.spaceY-4;y++) {
            if(x*40<=1920 && y*40<=1000)continue;
            counts.beyond++;
            var tile:Object=loc.space[x][y];if(tile==null || tile.phis!=1 || tile.fake || tile.door!=null || tile.water>0
               || tile.hp<100)continue;
            counts.solid++;
            // Native hitTile still draws dyrka when armor/indestructibility
            // rejects HP loss. This fixture tests that real mark, not damage.
            if([1,2,3,4,6].indexOf(int(tile.mat))<0)continue;
            counts.material++;
            var clear:Boolean=true;
            for(var cx:int=x-7;cx<x;cx++)for(var cy:int=y-1;cy<=y+1;cy++)
               if(loc.space[cx][cy]==null || loc.space[cx][cy].phis!=0 || loc.space[cx][cy].water>0)clear=false;
            if(clear)counts.lane++;
            for each(var old:Object in out)if(Math.abs(old.x-x*40)<160 && Math.abs(old.y-y*40)<160)clear=false;
            if(clear)out.push({tx:x,ty:y,x:x*40,y:y*40+20,sx:x*40-240,sy:y*40+60,mat:int(tile.mat),hp:Number(tile.hp)});
            if(clear)counts.spaced++;
            if(out.length==4){Log.d("LARGE WALL SELECT "+JSON.stringify(counts));return out;}
         }
         Log.d("LARGE WALL SELECT "+JSON.stringify(counts));
         throw new Error("Native generated large scene has fewer than four separated, dry, solid-wall shot lanes");
      }
      private function prepare(n:int,p:Object):void {
         release();round=n;target=p;area=new Rectangle(p.x-64,p.y-64,128,128);
         source=CASES[n].role==(host?"host":"join");phase="prepare";at=getTimer();readySent=peerReady=false;
         peerSampled=sampledSent=false;local=peer=null;shots=0;hits=[];wire=[];samples=[];nativePairs=[];
         sampleCaptureMax=0;prepareWait="";
         attackAttempts=attackAccepted=0;firstAttack=firstRejected=weaponPreparation=null;
         bullets=new Dictionary(true);contacts=new Dictionary(true);oldGun=mod.game.gg.currentWeapon;oldChildren=mod.game.gg.childObjs;
         oldDisabled=Boolean(mod.game.gg.disabled);
         if(source) {
            // FA's native before/after loop snapshots owned inventory weapons.
            // Use the same real inventory/equip path as the successful MSW
            // native fixture, rather than an orphan currentWeapon reference.
            var g:Object=mod.game.gg,id:String=String(CASES[n].weapon);
            oldInventory={weapons:g.invent.weapons,fav:g.invent.fav,favIds:g.invent.favIds};
            g.invent.weapons=copyArray(g.invent.weapons);g.invent.fav=copyArray(g.invent.fav);g.invent.favIds=copyArray(g.invent.favIds);
            g.childObjs=g.childObjs.concat();g.changeWeapon("not",true);g.invent.weapons[id]=null;
            gun=g.invent.addWeapon(id);
            var disabled:Boolean=g.disabled;g.disabled=false;try{g.changeWeapon(id,true);}finally{g.disabled=disabled;}
            weaponPreparation=attackState();
            // Match the proven WallImpactTestDoc fixture: these fresh isolated
            // characters otherwise fail native checkAvail (LMG 5 / plamg 4).
            // Apply AFTER setPers, preserving its native damage/skill values.
            gun.lvl=gun.perslvl=0;
            gun.hold=gun.holder;gun.t_reload=0;gun.precision=0;gun.deviation=0;gun.recoil=0;gun.recoilUp=0;
            // Accuracy/low terrain damage isolate native visual output. Keep
            // native projectile, speed, decal, cooldown, ammo and burst rules.
            gun.destroy=1;gun.damageExpl=0;gun.critCh=0;gun.dopCh=0;
         }
         Log.d("LARGE WALL PREPARE "+JSON.stringify({round:round,role:host?"host":"join",source:source,target:p,weapon:CASES[n].weapon,
            land:String(mod.game.world.game.curLandId),key:mod.game.roomKey(),seed:mod.game.readWorldInfo().layoutSeed,
            weaponBeforeFixture:weaponPreparation,weaponAfterFixture:source?attackState():null}));
      }
      private static function copyArray(a:Array):Array {var out:Array=[];for(var key:String in a)out[key]=a[key];return out;}
      private function attackState():Object {
         var g:Object=mod.game.gg,p:Object=g.pers;
         return {at:getTimer(),wall:new Date().time,lvl:int(gun.lvl),perslvl:int(gun.perslvl),skill:int(gun.skill),
            skillLevel:int(p.getWeapLevel(gun.skill)),playerLevel:int(p.level),hp:Number(gun.hp),maxhp:Number(gun.maxhp),
            hold:int(gun.hold),holder:int(gun.holder),rashod:int(gun.rashod),ammo:String(gun.ammo),
            jammed:Boolean(gun.jammed),respect:int(gun.respect),alicorn:Boolean(gun.alicorn),worldAlicorn:Boolean(mod.game.world.alicorn),
            t_attack:int(gun.t_attack),t_reload:int(gun.t_reload),t_prep:int(gun.t_prep),prep:int(gun.prep),rapid:int(gun.rapid),
            current:g.currentWeapon===gun,owner:gun.owner===g,owned:g.invent.weapons[gun.id]===gun,ownerDisabled:Boolean(g.disabled)};
      }
      private function pose():void {
         var g:Object=mod.game.gg,w:Object=mod.game.world;
         g.invulner=true;g.disabled=true;g.dx=g.dy=0;g.storona=1;g.setPos(target.sx,target.sy);g.setVisPos();g.setWeaponPos(gun==null?0:gun.tip);
         g.celX=target.x+30;g.celY=target.y;w.celX=g.celX;w.celY=g.celY;
         w.cam.celX=int(w.celX*w.cam.scaleV+w.cam.vx);w.cam.celY=int(w.celY*w.cam.scaleV+w.cam.vy);
         if(gun!=null){gun.findCel=false;gun.forceRot=Math.atan2(g.celY-g.weaponY,g.celX-g.weaponX);}
         mod.game.forceCloseOverlays();
         for each(var u:Object in mod.game.loc.units)if(u!==g && String(u.id).indexOf("rconnect_ghost")!=0)u.disabled=true;
      }
      private function before(e:Event):void {
         if(target==null || phase=="done" || phase=="boot" || phase=="travel")return;
         pose();colorProbe.nextFrame();
         if(phase=="sample" && source) {
            NativeWallSurfaceProbe.dispose(pre);pre=NativeWallSurfaceProbe.capture(mod.game.world.grafon,area);
            sampleCaptureMax=Math.max(sampleCaptureMax,pre.cost);
            if(getTimer()-sampleStart>=500 && shots<int(CASES[round].shots)) {
               // At most two diagnostic snapshots; no per-attempt disk IO.
               var initial:Object=attackAttempts==0?attackState():null;
               attackAttempts++;var accepted:Boolean=gun.attack();if(accepted)attackAccepted++;
               if(initial!=null){initial.accepted=accepted;initial.afterAttack=int(gun.t_attack);firstAttack=initial;}
               if(!accepted && firstRejected==null)firstRejected=initial!=null?initial:attackState();
            }
         }
      }
      private function remember(o:Object):void {
         if(o==null || GameBridge.probe(o,"weap")!==gun || GameBridge.probe(o,"begx")===undefined)return;
         if(!bullets[o]) {bullets[o]=true;shots++;}
      }
      private function after(e:Event):void {
         if(target==null || phase=="done" || phase=="boot" || phase=="travel")return;
         if(gun!=null)gun.step();
         if(phase=="sample" && source) {
            remember(gun.b);for(var o:Object=mod.game.loc.firstObj;o!=null;o=o.nobj)remember(o);
            var fresh:int=0;
            for(o in bullets)if(o.tilehit===true && !contacts[o]) {
               contacts[o]=true;fresh++;hits.push({at:getTimer(),wall:new Date().time,x:Number(o.X),y:Number(o.Y),begx:Number(o.begx),begy:Number(o.begy)});
            }
            if(fresh>0 && pre!=null) {
               colorProbe.observe("native-after-hits",hits.slice(hits.length-fresh));
               var a:int=getTimer(),wall:Number=new Date().time;
               var post:Object=NativeWallSurfaceProbe.capture(mod.game.world.grafon,area);
               sampleCaptureMax=Math.max(sampleCaptureMax,post.cost);
               nativePairs.push({before:pre,after:post,at:a,wall:wall,cost:getTimer()-a,hits:fresh});pre=null;
            }
         }
         mod.stage.invalidate();
      }
      private function begin():void {
         baseline=NativeWallSurfaceProbe.capture(mod.game.world.grafon,area);
         colorProbe.begin(round,target,mod.game.world.grafon,source,host?"host":"join");
         check(mod.game.world.grafon.sceneLarge===true && (mod.game.loc.spaceX>48 || mod.game.loc.spaceY>25),"native merged large scene admitted");
         check(Number(mod.game.readWorldInfo().layoutSeed)==SEED,"native generation uses the same isolated comparison seed");
         check(target.x>1920 || target.y>1000,"actual target lies beyond old small-room limits");
         check(baseline.surfaces.length>0,"independent nativeBuffers and staged chunk cores cover world crop");
         check(!source || (gun!=null && gun.vis!=null && gun.vis.stage!=null),"native weapon staged when firing");
         if(source) {
            var state:Object=attackState();
            check(state.owner && state.current && state.owned && state.hp>0 && state.lvl-state.skillLevel<=2 &&
               (state.perslvl==0 || state.playerLevel>=state.perslvl) && state.respect!=1 &&
               (!state.alicorn || state.worldAlicorn) && !state.jammed &&
               (state.holder<=0 || state.hold>=state.rashod),"native weapon eligibility and loaded ammunition prepared");
         }
         sampleStart=getTimer();sampleStartWall=new Date().time;phase="sample";at=sampleStart;
      }
      private function render(e:Event):void {
         if(phase!="sample")return;
         if(samples.length>=MAX_SAMPLES){fail("bounded observation capacity exhausted; no dropped-frame success");return;}
         var start:int=getTimer(),wall:Number=new Date().time;
         var value:Object=NativeWallSurfaceProbe.capture(mod.game.world.grafon,area);
         samples.push({at:start,wall:wall,cost:getTimer()-start,value:value});
         if(start-sampleStart>=SAMPLE_MS) {
            sampleEnd=getTimer();phase="sampled";colorProbe.stopSampling();sampledSent=true;send("sampled");
            if(host && peerSampled){send("analyze");analyze();}
         }
      }
      private function savePNG(name:String,b:BitmapData):void {
         var file:File=File.applicationStorageDirectory.resolvePath("large-wall-proof/round-"+round+"-"+name+".png");
         file.parent.createDirectory();var start:int=getTimer(),bytes:ByteArray=b.encode(b.rect,new PNGEncoderOptions());
         var f:FileStream=new FileStream();f.open(file,FileMode.WRITE);try{f.writeBytes(bytes);}finally{f.close();}
         proofs.push({name:file.name,bytes:bytes.length,width:b.width,height:b.height,cost:getTimer()-start});
      }
      private function analyze():void {
         if(phase!="sampled")throw new Error("Readback must wait until BOTH sides stop sampling");phase="analysis";
         var started:int=getTimer(),base:Array=NativeWallSurfaceProbe.words(baseline.native),baseDisplay:Array=NativeWallSurfaceProbe.words(baseline.display);
         var end:Object=samples[samples.length-1].value,finalNative:Array=NativeWallSurfaceProbe.words(end.native),finalDisplay:Array=NativeWallSurfaceProbe.words(end.display);
         var canonical:Object={},nativeOracle:Array=[],sourceFirst:Number=0,sourceFirstBefore:Number=0;
         for each(var pair:Object in nativePairs) {
            var a:Array=NativeWallSurfaceProbe.words(pair.before.native),b:Array=NativeWallSurfaceProbe.words(pair.after.native),patch:Array=NativeWallSurfaceProbe.patch(a,b);
            if(patch.length>0 && sourceFirst==0){sourceFirst=pair.wall;sourceFirstBefore=pair.before.wall;}
            for(var i:int=0;i<patch.length;i+=2) {
               var ix:int=int(patch[i]);if(uint(patch[i+1])==uint(base[ix]))delete canonical[String(ix)];else canonical[String(ix)]=patch[i+1];
            }
         }
         var keys:Array=[];for(var key:String in canonical)keys.push(int(key));keys.sort(Array.NUMERIC);
         for each(ix in keys)nativeOracle.push(ix,canonical[String(ix)]);
         var frames:Array=[],maxCost:int=sampleCaptureMax;
         for each(var frame:Object in samples) {
            var nn:Array=NativeWallSurfaceProbe.words(frame.value.native),dd:Array=NativeWallSurfaceProbe.words(frame.value.display);
            frames.push({at:frame.at,wall:frame.wall,cost:frame.cost,native:NativeWallSurfaceProbe.patch(base,nn),display:NativeWallSurfaceProbe.patch(baseDisplay,dd)});
            maxCost=Math.max(maxCost,frame.cost);
         }
         local={round:round,role:host?"host":"join",source:source,weapon:CASES[round].weapon,target:target,area:{x:area.x,y:area.y,w:area.width,h:area.height},
            start:sampleStart,startWall:sampleStartWall,end:sampleEnd,shots:shots,hits:hits,sourceFirst:sourceFirst,sourceFirstBefore:sourceFirstBefore,nativeOracle:nativeOracle,
            attackAttempts:attackAttempts,attackAccepted:attackAccepted,firstAttack:firstAttack,firstRejected:firstRejected,weaponPreparation:weaponPreparation,
            baseline:base,baselineDisplay:baseDisplay,finalNative:finalNative,finalDisplay:finalDisplay,frames:frames,wire:wire,
            surfaces:baseline.surfaces,finalSurfaces:end.surfaces,maxCaptureMs:maxCost,readbackMs:getTimer()-started};
         check(samples.length>1,"bounded RENDER observations retained before pixel readback");
         check(!source || (attackAttempts>0 && attackAccepted>0 && firstAttack!=null && firstAttack.accepted===true),"native attack accepts first source attempt");
         check(!source || (shots>=int(CASES[round].shots) && hits.length>0 && nativeOracle.length>0),"native bullets and native collision interval produce persistent world pixels");
         savePNG("before-native",baseline.native);savePNG("after-native",end.native);
         savePNG("before-display",baseline.display);savePNG("after-display",end.display);
         local.gutterDiagnostic=colorProbe.exportEvidence();
         var payload:String=JSON.stringify(local),file:File=File.applicationStorageDirectory.resolvePath("large-wall-proof/round-"+round+"-proof.json");
         var fs:FileStream=new FileStream();fs.open(file,FileMode.WRITE);try{fs.writeUTFBytes(payload);}finally{fs.close();}
         Log.d("LARGE WALL PROOF "+JSON.stringify({round:round,role:local.role,bytes:payload.length,target:target,source:source,shots:shots,hits:hits.length,
            attackAttempts:attackAttempts,attackAccepted:attackAccepted,firstAttack:firstAttack,firstRejected:firstRejected,
            sourceFirst:sourceFirst,samples:samples.length,nativePixels:nativeOracle.length/2,maxCaptureMs:maxCost,readbackMs:local.readbackMs,files:proofs.slice(-4)}));
         // Send only round completion, never expected pixels to production.
         phase="analyzed";send("analyzed");if(host && peerReady)advance();
      }
      private function advance():void {
         if(phase!="analyzed" || !peerReady)return;
         if(round==3){send("done");finish();return;}
         var n:int=round+1;send("case",{next:n,target:targets[n]});prepare(n,targets[n]);
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;
         if(phase=="sample" && (p.wallPaint is Array || p.wall is Array) && wire.length<256) {
            var cells:Array=(p.wallPaint is Array?p.wallPaint:p.wall) as Array,coords:Array=[];
            for each(var cell:Object in cells)coords.push({x:cell.x,y:cell.y,v:cell.v});
            wire.push({at:getTimer(),wall:new Date().time,type:String(p.type),cells:coords});
         }
         if(p.type!="large-wall-test")return;
         try {
            if(p.op=="stop"){check(false,"peer stopped after fixture failure");finish();return;}
            if(p.op=="done"){finish();return;}
            if(host && p.op=="ready" && phase=="boot") {
               phase="travel";at=getTimer();send("depart");mod.game.forceCloseOverlays();mod.game.world.pers.healAll();mod.game.world.game.beginMission("random_mane");
            }else if(!host && p.op=="depart"){phase="travel";at=getTimer();}
            else if(host && p.op=="arrived" && phase=="travel")peerReady=true;
            else if(!host && p.op=="case"){prepare(int(p.next),p.target);}
            else if(host && p.op=="prepared" && int(p.round)==round)peerReady=true;
            else if(!host && p.op=="go" && int(p.round)==round)begin();
            else if(p.op=="sampled" && int(p.round)==round) {
               peerSampled=true;if(host && sampledSent){send("analyze");analyze();}
            }else if(!host && p.op=="analyze" && int(p.round)==round)analyze();
            else if(host && p.op=="analyzed" && int(p.round)==round){peerReady=true;advance();}
         }catch(err:Error){fail(err.getStackTrace());}
      }
      private function tick(e:Event):void {
         mod=RConnectMod.instance;if(mod==null || mod.game==null || mod.game.gg==null || mod.session==null)return;
         try {
            if(phase=="done")return;if(!configured)configure();
            if(host)for each(var p:Object in mod.session.peers)watch(p.link as TcpLink);else watch(mod.session.link);
            mod.game.gg.invulner=true;
            if(mod.game.world.clickReq==1){mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN,true));mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP,true));}
            if(getTimer()-at>(phase=="boot"||phase=="travel"?240000:45000)){fail("timeout "+phase);return;}
            if(phase=="boot" && !host && stable("rbl") && getTimer()-lastReady>500){lastReady=getTimer();send("ready");}
            else if(phase=="travel" && stable("random_mane")) {
               if(!host && getTimer()-lastReady>500){lastReady=getTimer();send("arrived");}
               else if(host && peerReady){targets=choose();send("case",{next:0,target:targets[0]});prepare(0,targets[0]);}
            }else if(phase=="prepare" && stable("random_mane") && getTimer()-at>2500) {
               if(!readySent) {
                  // Native camera/chunk readiness may require several frames.
                  // Wait for real residency; do not call sceneEnsure or create
                  // synthetic chunks. The existing 45s phase timeout remains.
                  var test:Object;
                  try{test=NativeWallSurfaceProbe.capture(mod.game.world.grafon,area);}
                  catch(wait:Error){if(prepareWait!=wait.message){prepareWait=wait.message;Log.d("LARGE WALL WAIT "+wait.message);}return;}
                  NativeWallSurfaceProbe.dispose(test);
                  readySent=true;if(!host)send("prepared");
               }
               if(host && readySent && peerReady){peerReady=false;begin();send("go");}
            }
         }catch(err:Error){fail(err.getStackTrace());}
      }
      private function release():void {
         if(oldInventory!=null && mod!=null) {
            var g:Object=mod.game.gg;g.changeWeapon("not",true);
            g.invent.weapons=oldInventory.weapons;g.invent.fav=oldInventory.fav;g.invent.favIds=oldInventory.favIds;
            g.currentWeapon=oldGun;g.childObjs=oldChildren;g.disabled=oldDisabled;
            if(oldGun!=null){g.disabled=false;try{oldGun.addVisual();}finally{g.disabled=oldDisabled;}}
            oldInventory=null;
         }else {
            if(gun!=null)gun.remVisual();
            if(oldChildren!=null && mod!=null){mod.game.gg.currentWeapon=oldGun;mod.game.gg.childObjs=oldChildren;mod.game.gg.disabled=oldDisabled;}
         }
         gun=oldGun=null;oldChildren=null;
         NativeWallSurfaceProbe.dispose(pre);pre=null;NativeWallSurfaceProbe.dispose(baseline);baseline=null;
         for each(var s:Object in samples)NativeWallSurfaceProbe.dispose(s.value);
         for each(var pair:Object in nativePairs){NativeWallSurfaceProbe.dispose(pair.before);NativeWallSurfaceProbe.dispose(pair.after);}
         samples=[];nativePairs=[];
      }
      private function finish():void {
         if(phase=="done")return;phase="done";removeEventListener(Event.ENTER_FRAME,tick);
         if(mod!=null){mod.stage.removeEventListener(Event.ENTER_FRAME,before);mod.stage.removeEventListener(Event.ENTER_FRAME,after);mod.stage.removeEventListener(Event.RENDER,render);}
         colorProbe.close();release();if(landClass!=null && landClass.rconnectSeedSource===newSeed)landClass.rconnectSeedSource=oldSeed;
         Log.d("COOP EFFECTS DONE large-wall-surfaces "+(host?"host":"join"));
      }
   }
}

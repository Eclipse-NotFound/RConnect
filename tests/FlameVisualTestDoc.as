package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.MovieClip;
   import flash.display.BitmapData;
   import flash.display.PNGEncoderOptions;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.events.MouseEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.geom.Matrix;
   import flash.geom.Rectangle;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import flash.utils.getQualifiedClassName;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;

   /** Native Weapon.attack/step and Bullet.step, observed after final RENDER.
    * No synthetic trajectory, copied production samples or bullet field edits.
    * Each peer fires independently; native randomness remains in every shot. */
   public class FlameVisualTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private static const CASES:Array=[
         {id:"flamer",variant:0,deg:0,cls:"visbulflame"},
         {id:"flamer",variant:0,deg:180,cls:"visbulflame"},
         {id:"flamer",variant:0,deg:-35,cls:"visbulflame"},
         {id:"cflamer",variant:0,deg:0,cls:"visbulflame"},
         {id:"cflamer",variant:0,deg:180,cls:"visbulflame"},
         {id:"cflamer",variant:0,deg:-35,cls:"visbulflame"},
         {id:"cflamer",variant:1,deg:0,cls:"visbulflame2"},
         {id:"cflamer",variant:1,deg:180,cls:"visbulflame2"},
         {id:"cflamer",variant:1,deg:-35,cls:"visbulflame2"}];
      private var mod:RConnectMod,host:Boolean,timer:Timer=new Timer(100),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=getTimer(),readyAt:int=0,round:int=0;
      private var gun:Object,oldGun:Object,oldChildren:Object,baseX:Number,baseY:Number;
      private var nativeBullets:Dictionary=new Dictionary(),allNative:Dictionary=new Dictionary(true);
      private var nativeRecords:Array=[],remoteRecords:Array=[],remoteSeen:Dictionary=new Dictionary(true);
      private var localNative:Array,peerNative:Array,peerSummary:Object,localDone:Boolean=false,peerDone:Boolean=false;
      private var sourcePixels:int=0,remotePixels:int=0,visibleSource:int=0,visibleRemote:int=0;
      private var latestSource:int=0,latestRemote:int=0,maxConcurrent:int=0;
      private var renderCount:int=0,maxRenderGap:int=0,lastRender:int=0;
      private var pictureCount:int=0;
      private var pictures:Array=[];
      private var pixelWorkMs:int=0,pictureWorkMs:int=0;
      private var packetTrace:Array=[],packetSeen:Object={},packetOffset:Number=Infinity;

      public function FlameVisualTestDoc() {
         var app:String=NativeApplication.nativeApplication.applicationID;
         if(app.indexOf("rconnect-coop-")<0)return;host=app.indexOf("-host-")>=0;
         NativeEffectRateRegression.run(check);
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,onError);
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function onError(e:UncaughtErrorEvent):void {
         check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));
         e.preventDefault();if(mod!=null)send("done");finish();
      }
      private function check(ok:Boolean,s:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"flame-visual "+s+" case="+round);}
      private function send(s:String,p:Object=null):void {
         p=p||{};p.type="flame-visual-test";p.stage=s;
         if(host)mod.session.server.broadcast(p);else if(mod.session.link!=null)mod.session.link.send(p);
      }
      private function watch(link:TcpLink):void {
         if(link!=null&&!links[link]){links[link]=true;link.addEventListener(TcpLink.MESSAGE,receive);}
      }
      private function setup():void {
         var g:Object=mod.game.gg;oldGun=g.currentWeapon;oldChildren=g.childObjs;
         baseX=Math.round(mod.game.loc.spaceX*20);baseY=g.Y;
         // Erase only this isolated room's shot corridor. Native Bullet.step
         // still performs its original collision, braking and removal work.
         for(var x:int=Math.max(1,int(baseX/40)-16);x<=Math.min(mod.game.loc.spaceX-2,int(baseX/40)+16);x++)
            for(var y:int=Math.max(1,int(baseY/40)-13);y<int(baseY/40);y++) {
               var tile:Object=mod.game.loc.space[x][y];tile.phis=0;tile.opac=0;tile.front="";tile.water=0;
            }
         mod.game.loc.black=false;mod.game.world.black=false;mod.game.world.redrawLoc();
         mod.stage.addEventListener(Event.ENTER_FRAME,before,false,100000);
         mod.stage.addEventListener(Event.ENTER_FRAME,after,false,-6000);
         mod.stage.addEventListener(Event.RENDER,render,false,-30000);
      }
      private function start(n:int):void {
         round=n;phase="show";at=getTimer();localNative=peerNative=null;peerSummary=null;
         localDone=peerDone=false;sourcePixels=remotePixels=visibleSource=visibleRemote=0;
         latestSource=latestRemote=maxConcurrent=renderCount=maxRenderGap=lastRender=0;
         pictureCount=0;
         pixelWorkMs=pictureWorkMs=0;packetTrace=[];packetSeen={};packetOffset=Infinity;
         nativeBullets=new Dictionary();nativeRecords=[];remoteSeen=new Dictionary(true);remoteRecords=[];
         if(gun!=null)gun.remVisual();
         var factory:Object=mod.main.loaderInfo.applicationDomain.getDefinition("fe.weapon.Weapon");
         gun=factory.create(mod.game.gg,CASES[round].id,CASES[round].variant);
         gun.setPers(mod.game.gg,mod.game.gg.pers);gun.addVisual();
         mod.game.gg.currentWeapon=gun;mod.game.gg.childObjs=[gun];
         // Remove only accuracy/recoil/level prerequisites; keep each family's
         // native velocity, gravity, brakeR, lifetime, timeline and collision.
         gun.precision=0;gun.lvl=gun.perslvl=0;gun.recoil=gun.recoilUp=0;gun.deviation=0;gun.hold=999;
         check(gun.vis!=null&&gun.vis.stage!=null,"native "+gun.id+" variant="+gun.variant+" staged");
         Log.d("FLAME START "+JSON.stringify({role:host?"host":"join",round:round,id:gun.id,
            variant:gun.variant,deg:CASES[round].deg,x:baseX,y:baseY}));
      }
      private function before(e:Event):void {
         if(phase!="show"&&phase!="sampled")return;
         var g:Object=mod.game.gg,w:Object=mod.game.world,a:Number=CASES[round].deg*Math.PI/180;
         // Identical bursts admit arbitrary geometric matches: a later shot's
         // lifetime must never be compared with an earlier shot. Give each
         // actual native shot a small deterministic aim increment, preserving
         // its real velocity/gravity/lifetime and the original error bounds.
         a+=nativeRecords.length*.004;
         g.setPos(baseX,baseY);g.setVisPos();g.dx=g.dy=0;g.invulner=true;g.disabled=true;g.ggControl=true;
         g.storona=Math.cos(a)>=0?1:-1;g.isTake=0;g.setWeaponPos(gun.tip);
         g.celX=w.celX=baseX+Math.cos(a)*600;g.celY=w.celY=g.weaponY+Math.sin(a)*600;
         w.cam.celX=int(g.celX*w.cam.scaleV+w.cam.vx);w.cam.celY=int(g.celY*w.cam.scaleV+w.cam.vy);
         w.ctr.keyAttack=false;w.testDam=true;
         for each(var u:Object in mod.game.loc.units)
            if(u!==g&&int(GameBridge.probe(u,"fraction"))<100){u.disabled=true;u.trigDis=true;}
         gun.findCel=false;gun.forceRot=a;
         var age:int=getTimer()-at;
         if(phase=="show"&&age>=1000&&age<1450){gun.t_reload=0;gun.hold=999;gun.attack();}
      }
      private function after(e:Event):void {
         if(phase!="show"&&phase!="sampled")return;
         gun.step();mod.stage.invalidate();
      }
      private function point(v:DisplayObject,stamp:int=-1):Object {
         if(v==null||!v.visible||v.stage==null)return null;
         var bounds:Rectangle=v.getBounds(v);
         return {at:stamp<0?getTimer():stamp,x:v.x,y:v.y,r:v.rotation,sx:v.scaleX,sy:v.scaleY,a:v.alpha,
            f:v is MovieClip?MovieClip(v).currentFrame:1,
            bx:bounds.x,by:bounds.y,bw:bounds.width,bh:bounds.height};
      }
      private function pixels(v:DisplayObject):int {
         var started:int=getTimer();
         if(v==null||!v.visible||v.stage==null)return 0;
         var root:DisplayObject=mod.main as DisplayObject,bounds:Rectangle=v.getBounds(root);
         bounds=bounds.intersection(new Rectangle(0,0,mod.stage.stageWidth,mod.stage.stageHeight));
         if(bounds.width<1||bounds.height<1||bounds.width*bounds.height>300000)return 0;
         var first:BitmapData=new BitmapData(Math.ceil(bounds.width),Math.ceil(bounds.height),false,0),second:BitmapData=first.clone();
         var matrix:Matrix=new Matrix(1,0,0,1,-bounds.x,-bounds.y);
         try {
            first.draw(root,matrix);v.visible=false;second.draw(root,matrix);
            var a:Vector.<uint>=first.getVector(first.rect),b:Vector.<uint>=second.getVector(second.rect),count:int=0;
            for(var i:int=0;i<a.length;i++)if(a[i]!=b[i])count++;
            return count;
         } finally {v.visible=true;first.dispose();second.dispose();pixelWorkMs+=getTimer()-started;}
         return 0; // Flex's return analysis does not follow try/finally.
      }
      private function render(e:Event):void {
         if(phase!="show")return;
         // All visible points belong to this same final-render boundary. Pixel
         // inspection must not give later objects a different sample timestamp.
         // One real pixel observation per stream satisfies the existing visual
         // assertion; whole trajectories are still recorded for every Bullet.
         var now:int=getTimer();renderCount++;if(lastRender>0)maxRenderGap=Math.max(maxRenderGap,now-lastRender);lastRender=now;
         var record:Object,v:DisplayObject,p:Object,scan:Object=mod.game.loc.firstObj;
         for(var registration:int=0;scan!=null&&registration++<5000;scan=scan.nobj)
            if(GameBridge.probe(scan,"weap")===gun)registerBullet(scan,now);
         if(gun.b!=null)registerBullet(gun.b,now);
         for(var nativeBullet:Object in nativeBullets) {
            record=nativeBullets[nativeBullet];v=nativeBullet.vis as DisplayObject;p=point(v,now);
            if(p!=null) {
               record.points.push(p);visibleSource++;latestSource=now-at;
               record.minVel=Math.min(Number(record.minVel),Number(nativeBullet.vel));
               if(record.points.length>1&&angle(Number(record.points[0].r),Number(p.r))>1)record.turned=true;
               if(record.points.length>=2&&sourcePixels==0){record.pixels=pixels(v);sourcePixels+=record.pixels;}
            }
            if(record.end==0&&nativeBullet.in_chain!==true)record.end=now;
         }
         // Distinguish cosmetics from every native Bullet visual, including
         // detached/recently-ended ones. Do not use production active records.
         var o:Object=mod.game.loc.firstObj;
         for(var guard:int=0;o!=null&&guard++<5000;o=o.nobj)
            if(GameBridge.probe(o,"begx")!=null&&GameBridge.probe(o,"owner")!=null)allNative[o.vis]=true;
         var layer:DisplayObjectContainer=mod.game.world.grafon.visObjs[2],current:int=0;
         for(var i:int=0;i<layer.numChildren;i++) {
            v=layer.getChildAt(i);
            if(allNative[v]||getQualifiedClassName(v)!=CASES[round].cls)continue;
            p=point(v,now);if(p==null)continue;
            record=remoteSeen[v];
            if(record==null){record={id:remoteRecords.length,points:[],born:now,pixels:0};remoteSeen[v]=record;remoteRecords.push(record);}
            record.points.push(p);visibleRemote++;current++;latestRemote=now-at;
            if(record.points.length>=2&&remotePixels==0){record.pixels=pixels(v);remotePixels+=record.pixels;}
         }
         maxConcurrent=Math.max(maxConcurrent,current);
         if(current>0&&getTimer()-at>1600&&pictureCount==0) {
            picture("flame-visual-"+round+"-active");pictureCount++;
         }
      }
      private function picture(name:String):void {
         var started:int=getTimer();
         var bitmap:BitmapData=new BitmapData(mod.stage.stageWidth,mod.stage.stageHeight,false,0);
         bitmap.draw(mod.main as DisplayObject);pictures.push({name:name,bitmap:bitmap});
         pictureWorkMs+=getTimer()-started;
         // PNG compression blocks AIR's single thread. Preserve these exact
         // final-render pixels now, encode only after all timing samples end.
      }
      private function savePictures():void {
         for each(var p:Object in pictures) {
            var stream:FileStream=new FileStream(),bitmap:BitmapData=p.bitmap;
            try {
               stream.open(File.applicationStorageDirectory.resolvePath(p.name+".png"),FileMode.WRITE);
               stream.writeBytes(bitmap.encode(bitmap.rect,new PNGEncoderOptions()));
            } finally {try{stream.close();}catch(error:*){}bitmap.dispose();}
         }
         pictures=[];
      }
      private function registerBullet(bullet:Object,now:int):void {
         if(!nativeBullets[bullet]) {
            var record:Object;
            record={id:nativeRecords.length,cls:getQualifiedClassName(bullet.vis),points:[],begx:bullet.begx,begy:bullet.begy,
               born:now,end:0,flame:bullet.flame,brakeR:bullet.brakeR,gravity:bullet.ddy,firstVel:bullet.vel,
               minVel:bullet.vel,turned:false,pixels:0};
            nativeBullets[bullet]=record;nativeRecords.push(record);allNative[bullet.vis]=true;
         }
      }
      private static function angle(a:Number,b:Number):Number {
         var d:Number=(a-b)%360;if(d>180)d-=360;if(d< -180)d+=360;return Math.abs(d);
      }
      private static function pointError(a:Object,b:Object):Number {
         if(int(a.f)!=int(b.f))return 1e9;
         return Math.max(Math.abs(a.x-b.x),Math.abs(a.y-b.y),angle(a.r,b.r),
            Math.abs(a.sx-b.sx)*100,Math.abs(a.sy-b.sy)*100,Math.abs(a.a-b.a)*100,
            Math.abs(a.bx-b.bx),Math.abs(a.by-b.by),Math.abs(a.bw-b.bw),Math.abs(a.bh-b.bh));
      }
      /** Continuous positions may interpolate two real adjacent source frames.
       * Clip shape/frame still comes from the earlier real native frame. */
      private static function segmentError(a:Object,b:Object,c:Object):Number {
         var dx:Number=c.x-b.x,dy:Number=c.y-b.y,den:Number=dx*dx+dy*dy;
         if(den<.0001||int(a.f)!=int(b.f))return 1e9;
         var t:Number=((a.x-b.x)*dx+(a.y-b.y)*dy)/den;
         if(t<0||t>1)return 1e9;
         var rot:Number=(c.r-b.r)%360;if(rot>180)rot-=360;if(rot< -180)rot+=360;
         var p:Object={x:b.x+dx*t,y:b.y+dy*t,r:b.r+rot*t,sx:b.sx+(c.sx-b.sx)*t,
            sy:b.sy+(c.sy-b.sy)*t,a:b.a+(c.a-b.a)*t,f:b.f,bx:b.bx,by:b.by,bw:b.bw,bh:b.bh};
         return pointError(a,p);
      }
      private static function traceError(remote:Array,native:Array):Number {
         var worst:Number=0;
         for each(var p:Object in remote) {
            var best:Number=1e9;
            for(var i:int=0;i<native.length;i++) {
               best=Math.min(best,pointError(p,native[i]));
               if(i+1<native.length)best=Math.min(best,segmentError(p,native[i],native[i+1]));
            }
            worst=Math.max(worst,best);
         }
         return remote.length>0?worst:1e9;
      }
      /** One whole remote DisplayObject must match ONE original Bullet.
       * An injective pairing prevents choosing a different native flame for
       * every point, or counting two copies as the same original shot. */
      private static function pair(remoteId:int,edges:Array,owners:Array,visited:Object):Boolean {
         // Equal-speed combat-flamer shots can have identical entire paths.
         // Preserve their independently observed birth order before trying
         // reassignment. The old augment-first matcher reversed every such
         // burst and compared the first shot's duration with the last shot.
         for each(var freeId:int in edges[remoteId])if(owners[freeId]==null && !visited[freeId]) {
            owners[freeId]=remoteId;return true;
         }
         for each(var nativeId:int in edges[remoteId]) {
            if(visited[nativeId])continue;visited[nativeId]=true;
            if(owners[nativeId]==null||pair(int(owners[nativeId]),edges,owners,visited)) {
               owners[nativeId]=remoteId;return true;
            }
         }
         return false;
      }
      private function compare():void {
         if(localNative==null||peerNative==null||peerSummary==null||localDone)return;
         check(nativeRecords.length>=3,"real native burst emits several independently recorded shots count="+nativeRecords.length);
         check(visibleSource>=8&&sourcePixels>0,"source fire produces actual staged pixels samples="+visibleSource+" pixels="+sourcePixels);
         var ended:Boolean=true,braked:Boolean=false,turned:Boolean=false,correctClass:Boolean=true;
         for each(var n:Object in nativeRecords) {
            ended=ended&&int(n.end)>0;correctClass=correctClass&&n.cls==CASES[round].cls;
            braked=braked||Number(n.minVel)<Number(n.firstVel)*.8;turned=turned||n.turned===true;
         }
         check(correctClass,"family uses original "+CASES[round].cls+" visual");
         check(ended,"every original shot removes itself through native lifetime/collision");
         if(CASES[round].id=="flamer")check(braked&&turned,"native flamer really brakes and changes direction");
         else check(turned,"native combat flamer really changes direction under gravity");
         check(peerNative.length>=3&&remoteRecords.length>=3,"peer burst and cosmetic copies observed source="+peerNative.length+" remote="+remoteRecords.length);
         check(visibleRemote>=8&&remotePixels>0,"remote fire produces actual final pixels samples="+visibleRemote+" pixels="+remotePixels);
         var wrong:int=0,total:int=0,maxError:Number=0,firstWrong:Object=null,edges:Array=[],owners:Array=[],ambiguous:int=0;
         for each(var r:Object in remoteRecords) {
            var candidates:Array=[],best:Number=1e9;
            for(var j:int=0;j<peerNative.length;j++) {
               var error:Number=traceError(r.points,peerNative[j].points);
               best=Math.min(best,error);if(error<=.08)candidates.push(j);
            }
            edges.push(candidates);if(candidates.length!=1)ambiguous++;total+=r.points.length;maxError=Math.max(maxError,best);
            if(candidates.length==0){wrong++;if(firstWrong==null)firstWrong={remoteId:r.id,error:best};}
         }
         check(ambiguous==0,"each visible trajectory identifies exactly one original shot ambiguous="+ambiguous);
         var paired:int=0;
         for(j=0;j<remoteRecords.length;j++)if(pair(j,edges,owners,{}))paired++;
         check(remoteRecords.length==peerNative.length&&paired==peerNative.length,
            "one remote object per original Bullet; unique whole-trajectory pairs="+paired+"/"+peerNative.length+" remote="+remoteRecords.length);
         check(total>=8&&wrong==0,"native direction/position/stretch/clip length and frame preserved wrongShots="+wrong+"/"+remoteRecords.length+" samples="+total+" max="+maxError);
         var lifetimeWrong:int=0,lifetimeMax:Number=0;
         for(j=0;j<owners.length;j++)if(owners[j]!=null) {
            var remotePoints:Array=remoteRecords[int(owners[j])].points,nativePoints:Array=peerNative[j].points;
            var durationError:Number=Math.abs((remotePoints[remotePoints.length-1].at-remotePoints[0].at)
               -(nativePoints[nativePoints.length-1].at-nativePoints[0].at));
            lifetimeMax=Math.max(lifetimeMax,durationError);if(durationError>180)lifetimeWrong++;
         }
         check(paired>0&&lifetimeWrong==0,"per-shot visible duration agrees within 180ms (100ms player buffer + send/render frames) wrong="+lifetimeWrong+" max="+lifetimeMax);
         var layer:DisplayObjectContainer=mod.game.world.grafon.visObjs[2],remaining:int=0;
         for(var i:int=0;i<layer.numChildren;i++) {
            var v:DisplayObject=layer.getChildAt(i);
            if(!allNative[v]&&getQualifiedClassName(v)==CASES[round].cls&&point(v)!=null)remaining++;
         }
         check(remaining==0,"fire has ended before next case; no frozen flames remaining="+remaining);
         check(pictureCount==1,"actual final display screenshot retained");picture("flame-visual-"+round+"-cleared");
         Log.d("FLAME METRIC "+JSON.stringify({role:host?"host":"join",round:round,id:gun.id,variant:gun.variant,
            deg:CASES[round].deg,sourceShots:nativeRecords.length,remoteShots:remoteRecords.length,sourcePixels:sourcePixels,
            remotePixels:remotePixels,latestSource:latestSource,latestRemote:latestRemote,maxConcurrent:maxConcurrent,
            maxRenderGap:maxRenderGap,pixelWorkMs:pixelWorkMs,pictureWorkMs:pictureWorkMs,total:total,wrong:wrong,maxError:maxError,firstWrong:firstWrong,
            uniquePairs:paired,ambiguous:ambiguous,pairing:owners,pairEdges:edges,packetTrace:packetTrace,packetOffset:packetOffset,lifetimeMax:lifetimeMax,lifetimeWrong:lifetimeWrong,
            source:nativeRecords,peer:peerNative,remote:remoteRecords}));
         localDone=true;send("result",{round:round});advance();
      }
      /** Read-only timing diagnostics; no assertion uses production samples. */
      private function observePacket(message:Object):void {
         if(phase!="show")return;
         var snap:Object=null,now:int=getTimer();
         if(host && message.type=="playerstate")snap=message.snap;
         if(!host && message.type=="worldstate")for each(var peer:Object in message.players)
            if(int(peer.id)==0)snap=peer.snap;
         if(snap==null || !isFinite(Number(snap.sampleTime)))return;
         packetOffset=Math.min(packetOffset,now-Number(snap.sampleTime));
         for each(var w:Object in snap.weapons) {
            if(String(w.id)!=String(CASES[round].id) || int(w.variant)!=int(CASES[round].variant))continue;
            for each(var event:Object in w.events) {
               var key:String=w.stream+":"+event.seq,flight:Object=event.flight;
               if(packetSeen[key] || flight==null || !(flight.frames is Array) || flight.frames.length==0)continue;
               packetSeen[key]=true;
               packetTrace.push({key:key,received:now,sample:snap.sampleTime,offset:packetOffset,
                  first:flight.frames[0],last:flight.frames[flight.frames.length-1],count:flight.frames.length,end:flight.end});
            }
         }
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;observePacket(p);if(p.type!="flame-visual-test")return;
         if(host&&p.stage=="ready"&&phase=="boot"){setup();send("setup");start(0);}
         else if(!host&&p.stage=="setup"&&phase=="boot"){setup();start(0);}
         else if(!host&&p.stage=="round")start(int(p.round));
         else if(p.stage=="native"&&int(p.round)==round){peerNative=p.frames;peerSummary=p.summary;compare();}
         else if(host&&p.stage=="result"&&int(p.round)==round){peerDone=true;advance();}
         else if(p.stage=="done")finish();
      }
      private function advance():void {
         if(!host||!localDone||!peerDone)return;
         if(round+1<CASES.length){start(round+1);send("round",{round:round});}else{send("done");finish();}
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null||mod.game==null||mod.game.gg==null)return;
         if(host)for each(var peer:Object in mod.session.peers)watch(peer.link as TcpLink);else watch(mod.session.link);
         if(mod.game.world.clickReq==1){mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN,true));mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP,true));}
         if(phase!="done"&&getTimer()-at>60000){check(false,"timeout "+phase);send("done");finish();return;}
         if(!mod.session.rooms.ready||mod.session.rooms.busy||mod.game.isTransitioning())return;
         if(phase=="boot"&&!host&&timer.currentCount>160&&getTimer()-readyAt>500){readyAt=getTimer();send("ready");}
         if(phase=="show"&&getTimer()-at>6000) {
            phase="sampled";localNative=nativeRecords;
            send("native",{round:round,frames:nativeRecords,summary:{latest:latestSource,pixels:sourcePixels}});compare();
         }
      }
      private function finish():void {
         if(phase=="done")return;phase="done";timer.stop();
         if(mod!=null) {
            mod.stage.removeEventListener(Event.ENTER_FRAME,before);mod.stage.removeEventListener(Event.ENTER_FRAME,after);
            mod.stage.removeEventListener(Event.RENDER,render);
            if(gun!=null)gun.remVisual();if(oldGun!=null){mod.game.gg.currentWeapon=oldGun;mod.game.gg.childObjs=oldChildren;}
         }
         savePictures();Log.d("COOP EFFECTS DONE flame-visual "+(host?"host":"join"));
      }
   }
}

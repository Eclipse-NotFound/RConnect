package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.Shape;
   import flash.display.BitmapData;
   import flash.display.Bitmap;
   import flash.display.GraphicsBitmapFill;
   import flash.display.PNGEncoderOptions;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.utils.Timer;
   import flash.utils.Dictionary;
   import flash.utils.getTimer;
   import flash.utils.getQualifiedClassName;
   import flash.geom.Matrix;
   import flash.geom.Rectangle;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;
   import rconnect.game.MirrorHitUnit;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;

   /** Actual installed RV + production replay seam after a real TCP handshake.
    * Native fixtures are added by the driver, never by injectEnemy: they must
    * survive Session.leave. A same-geometry decoy is explicitly a synthetic
    * ownership negative control; actual receiver masks undergo RV's sweep. */
   public class MirrorMaskRestoreTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var mod:RConnectMod,host:Boolean,timer:Timer=new Timer(100),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=getTimer(),readyAt:int=0,round:int=0,frames:int=0;
      private var body:Object,proxy:MirrorHitUnit,baseX:Number,baseY:Number;
      private var originals:Array=[],borrowed:Array=[],nativeWeaponMask:DisplayObject;
      private var retiredMasks:Array=[];
      private var cleanupMasks:Array=[];
      private var decoys:Array=[],copies:Array=[],template:Object;
      private var partialFrames:int=0,visibleFields:int=0,replaced:Boolean=false;
      public function MirrorMaskRestoreTestDoc() {
         var id:String=NativeApplication.nativeApplication.applicationID;
         if(id.indexOf("rconnect-coop-")<0)return;host=id.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();finish();
         });
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,s:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"mask-restore "+s+" case="+round);}
      private function state(s:String):void {phase=s;at=getTimer();frames=0;}
      private function watch(l:TcpLink):void {if(l!=null && !links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);}}
      private function send(s:String):void {var p:Object={type:"mask-restore-test",stage:s};if(host)mod.session.server.broadcast(p);else mod.session.link.send(p);}
      private function receive(e:NetMessageEvent):void {
         if(e.data.type!="mask-restore-test")return;
         if(host && phase=="boot" && e.data.stage=="ready"){send("begin");state("drain");}
         else if(!host && e.data.stage=="begin"){mod.session.leave();begin();}
      }
      private function ready():Boolean {
         var w:Object=mod.game.world,g:Object=mod.game.gg;
         return g!=null && !g.disabled && g.work!="res" && !w.onPause
            && (!w.vblack.visible || w.vblack.alpha<=0);
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null || mod.game==null || mod.session==null)return;
         if(phase=="done")return;
         try {
            if(phase=="boot") {
               if(mod.game.gg!=null)mod.game.gg.invulner=true;
               if(host && mod.session.server!=null)for each(var l:TcpLink in mod.session.server.clients)watch(l);else if(!host)watch(mod.session.link);
               if(mod.session.rooms.ready && !mod.session.rooms.busy && !mod.game.isTransitioning() && ready()
                  && !host && getTimer()-readyAt>500){readyAt=getTimer();send("ready");}
               return;
            }
            if(phase=="drain" && getTimer()-at>500){mod.session.leave();begin();return;}
            if(getTimer()-at>15000){check(false,"timeout "+phase);finish();return;}
            if(phase=="native" && originals.length==2 && frames>=4){mirror();return;}
            if(phase=="mirror" && partialFrames>=4 && borrowed.length==2 && frames>=12) {
               if(round==2 && !replaced){replaceVisuals();return;}
               if(round==3 && !replaced){mod.game.loc.addObj(body.currentWeapon);replaced=true;partialFrames=0;state("mirror");return;}
               leave();return;
            }
            if(phase=="after" && frames>=40){after();return;}
            if(phase=="inactive" && frames>=3) {
               check(mod.game.roomHold && !mod.game.world.black,"RV inactive cleanup runs while roomHold is set");
               for each(var oldMask:DisplayObject in cleanupMasks)check(oldMask!=null && oldMask.parent==null,"owned transitional shape is removed after RV becomes inactive");
               check(body.vis.mask==null && body.hpbar.mask==null,"inactive renderer leaves both fields without stale clips");
               mod.game.roomHold=false;mod.game.world.black=true;endCase();return;
            }
            if(phase=="replacement" && frames>=40) {
               for each(oldMask in cleanupMasks)check(oldMask!=null && oldMask.parent==null,"owned transitional shape is removed after native field replacement");
               check(body.vis.stage!=null && body.hpbar.stage!=null && body.vis.mask!=null && body.hpbar.mask!=null,
                  "new native fields receive live RV masks without being overwritten by old cleanup");
               endCase();return;
            }
         } catch(error:Error){check(false,error.getStackTrace());finish();}
      }
      private function begin():void {
         var b:Object=mod.game,g:Object=b.gg;b.forceCloseOverlays();
         baseX=g.X;baseY=g.Y;
         if(b.roomKey()=="random_mane//0,4,0"){baseX=1681.8;baseY=320;}
         g.disabled=true;g.invulner=true;g.dx=g.dy=0;g.work="";g.anim("stay",true);
         g.setPos(baseX,baseY);g.setVisPos();b.loc.base=false;b.freezeAI=true;
         mod.stage.addEventListener(Event.ENTER_FRAME,drive,false,-5000);
         mod.stage.addEventListener(Event.ENTER_FRAME,capture,false,-9500);
         mod.stage.addEventListener(Event.RENDER,render,false,-30000);
         create();
      }
      private function create():void {
         originals=[];borrowed=[];retiredMasks=[];decoys=[];nativeWeaponMask=null;partialFrames=visibleFields=0;replaced=false;
         var c:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit.UnitRaider") as Class;
         body=new c("1",100,<unit tr="1" weap="lmg"/>,null);
         body.id="mask_restore_native_"+round;body.putLoc(mod.game.loc,baseX+170,baseY);
         mod.game.loc.addObj(body);mod.game.loc.units.push(body);
         // RV's public weapon scan follows firstObj. The constructor's held
         // weapon is normally only a child; explicitly cover a native Weapon
         // with this owner in the real object chain, rather than setting mask.
         if(round==1)mod.game.loc.addObj(body.currentWeapon);
         body.disabled=true;body.invulner=true;body.xp=0;body.hp=body.maxhp-1;body.visDetails();
         check(body.vis!=null && body.hpbar!=null && body.vis.stage!=null,"native body owns two live display fields");
         if(round==1 || round>=4) {
            // Receiver registration before RV's first draw is an ordinary case.
            check(body.vis.mask==null && body.hpbar.mask==null,"first registration has no native mask");
            if(round==1) {
               if(template==null)throw new Error("missing partial-mask template");
               for each(var layerIndex:int in [2,3]) {
                  var d:Shape=makeDecoy(template);d.name="MaskRestoreUnrelatedDecoy";
                  mod.game.world.grafon.visObjs[layerIndex].addChild(d);d.visible=false;decoys.push(d);
               }
            }
            mirror();
         } else state("native");
      }
      private function snapshot():Object {
         for each(var s:Object in mod.game.readUnitsSnapshot())if(s.id===body.id)return s;
         throw new Error("fixture missing from real native snapshot");
      }
      private function mirror():void {
         var r:Object=mod.game.applyUnitsSync([snapshot()]);
         proxy=null;for each(var u:Object in mod.game.loc.units)if(u is MirrorHitUnit && MirrorHitUnit(u).body===body)proxy=u as MirrorHitUnit;
         check(r.matched==1 && proxy!=null,"production mirror pairs the existing native body");
         check(proxy!=null && GameBridge.probe(proxy,"vis")===body.vis && GameBridge.probe(proxy,"hpbar")===body.hpbar
            && GameBridge.probe(proxy,"npc")===false && GameBridge.probe(proxy,"id")===body.id,
            "receiver keeps real identity and SATS display references");
         partialFrames=0;borrowed=[];state("mirror");
      }
      private function drive(e:Event):void {
         if(phase=="done" || phase=="boot" || phase=="drain")return;
         var g:Object=mod.game.gg;g.disabled=true;g.invulner=true;g.dx=g.dy=0;g.setPos(baseX,baseY);g.setVisPos();
         if(body!=null){body.disabled=true;body.hp=body.maxhp-1;body.setVisPos();}
         mod.stage.invalidate();
      }
      private function capture(e:Event):void {
         if(body==null || phase=="done")return;
         frames++;
         if(phase!="native" && phase!="mirror")return;
         var v:DisplayObject=body.vis as DisplayObject,h:DisplayObject=body.hpbar as DisplayObject;
         if(frames==20 || frames==80) {
            var actualWeapon:Object=body.currentWeapon;
            var apiCarrier:Object=mod.main.getChildByName("RVExplorationAPI");
            var api:Object=apiCarrier==null?null:GameBridge.probe(apiCarrier,"api");
            Log.d("MASK RESTORE OBSERVE "+JSON.stringify({phase:phase,frame:frames,fraction:body.fraction,npc:body.npc,invis:body.invis,
               x:body.X,y:body.Y,black:mod.game.world.black,base:mod.game.loc.base,rv:api==null?null:api.active(mod.game.loc),
               visMask:v==null?false:v.mask!=null,barMask:h==null?false:h.mask!=null,weapon:getQualifiedClassName(actualWeapon),
               weaponOwner:GameBridge.probe(actualWeapon,"owner")===body,weaponChain:GameBridge.probe(actualWeapon,"in_chain"),
               weaponMask:GameBridge.probe(GameBridge.probe(actualWeapon,"vis"),"mask")!=null}));
         }
         if(v==null || h==null || !(v.mask is Shape) || !(h.mask is Shape))return;
         var w:Object=body.currentWeapon,wm:DisplayObject=GameBridge.probe(GameBridge.probe(w,"vis"),"mask") as DisplayObject;
         var weaponCase:Boolean=round==1 || (round==3 && replaced);
         if(weaponCase && (wm==null || wm.parent==null || GameBridge.probe(w,"owner")!==body))return;
         if(weaponCase)nativeWeaponMask=wm;
         partialFrames++;
         if(phase=="native"){originals=[v.mask,h.mask];nativeWeaponMask=v.mask;
            if(round==0 && template==null)template=maskLayout(v.mask as Shape);}
         else {
            borrowed=[v.mask,h.mask];
            for(var i:int=0;i<2;i++)if(retiredMasks[i]==null && (originals.length!=2 || borrowed[i]!==originals[i]))
               retiredMasks[i]=borrowed[i];
         }
         if(round==4 && phase=="mirror" && partialFrames==1)leave();
      }
      private function replaceVisuals():void {
         var oldV:Object=body.vis,oldH:Object=body.hpbar;
         body.remVisual();body.initBlit();body.hpbar=null;
         body.disabled=false;body.addVisual();body.disabled=true;
         check(body.vis!==oldV && body.hpbar!==oldH,"native addVisual builds both replacement fields");
         // A genuine sight movement makes RV redraw its own masks too.
         baseX+=2;replaced=true;borrowed=[];partialFrames=0;state("mirror");
      }
      private function leave():void {
         var v:DisplayObject=body.vis as DisplayObject,h:DisplayObject=body.hpbar as DisplayObject;
         // A directly observed native mask is updated by its true renderer;
         // the proxy's bitmap can differ and is not the native oracle.
         var sources:Array=round==1 || round>=4?borrowed:originals;
         var expected:Array=[signature(sources[0] as Shape),signature(sources[1] as Shape)];
         var pictures:Array=[fieldPicture(v),fieldPicture(h)];
         var sceneBefore:Array=[scene(v,sources[0] as Shape,pictures[0]),scene(h,sources[1] as Shape,pictures[1])];
         var positions:Array=[JSON.stringify(sources[0].transform.matrix),JSON.stringify(sources[1].transform.matrix)];
         check(partialFrames>=(round==4?1:4) && (round>=4 || (nativeWeaponMask!=null && borrowed[0]!==nativeWeaponMask)),
            "actual partial RV masks distinguish native and receiver objects");
         if(round==0)check(originals.length==2 && originals[0]===nativeWeaponMask,"native mask identities were observed before alias creation");
         mod.session.leave();
         if(round==1 || round==3)check(body.currentWeapon.vis.mask===nativeWeaponMask,
            "restoration preserves the real native weapon mask reference");
         check(mod.session.mode=="offline" && mod.game.loc.units.indexOf(body)>=0 && body.in_chain
            && v===body.vis && h===body.hpbar && v.stage!=null && h.stage!=null,"leave retains the native body and both live fields");
         check(proxy.body==null && GameBridge.probe(proxy,"vis")==null && GameBridge.probe(proxy,"hpbar")==null
            && mod.game.loc.units.indexOf(proxy)<0,"receiver retires without deleting its native body");
         for(var i:int=0;i<2;i++) {
            var field:String=i==0?"vis":"hpbar",view:DisplayObject=i==0?v:h;
            check(view.mask!=null && view.mask!==retiredMasks[i] && decoys.indexOf(view.mask)<0,
               field+" restores a live clip without borrowing retired or unrelated masks");
            check(view.mask is Shape && signature(view.mask as Shape)===expected[i],field+" preserves the actual alpha clipping bitmap");
            check(view.mask!=null && JSON.stringify(view.mask.transform.matrix)===positions[i]
               && view.mask.stage===view.stage,field+" preserves the mask transform and stage coordinates");
            check(view.mask is Shape && view.mask.parent===view.parent
               && scene(view,view.mask as Shape,pictures[i])===sceneBefore[i],field+" restores identical clipped field pixels at its real parent coordinates");
            Log.d("MASK RESTORE CLIP "+JSON.stringify({field:field,expected:expected[i],actual:signature(view.mask as Shape)}));
            if(round==0)check(view.mask===originals[i],field+" restores the proven native mask identity");
         }
         for each(var pic:Object in pictures)BitmapData(pic.bitmap).dispose();
         picture("leave");
         // Negative control removes only driver-owned decoys, never RV shapes.
         for each(var d:Shape in decoys)if(d.parent!=null)d.parent.removeChild(d);
         if(round==5 || round==6) {
            cleanupMasks=[v.mask,h.mask];
            check(cleanupMasks[0]!=null && cleanupMasks[1]!=null && cleanupMasks[0].name=="RConnectRestoredMask"
               && cleanupMasks[1].name=="RConnectRestoredMask","unknown native ownership uses independent transitional masks");
            if(round==5){mod.game.roomHold=true;mod.game.world.black=false;state("inactive");}
            else {body.remVisual();body.initBlit();body.hpbar=null;body.disabled=false;body.addVisual();body.disabled=true;state("replacement");}
            return;
         }
         state("after");
      }
      private function render(e:Event):void {
         if(phase=="after" && body!=null && body.vis!=null && body.hpbar!=null
            && body.vis.stage!=null && body.hpbar.stage!=null && body.hpbar.mask!=null
            && (body.vis.mask!=null || ((round==1 || round==3) && body.currentWeapon.vis.mask!=null)))visibleFields++;
      }
      private function after():void {
         var removed:int=0;for each(var old:DisplayObject in retiredMasks)if(old!=null && old.parent==null)removed++;
         check(retiredMasks.length==2 && removed==2,"actual RV sweep removes both retired receiver masks");
         check(visibleFields>0 && body.hpbar.mask!=null,"native health clipping continues through the retirement sweep");
         if(round==1 || round==3)check(body.currentWeapon.vis.mask===nativeWeaponMask && body.vis.mask!==retiredMasks[0],
            "RV retains its real weapon mask after reclaiming native display state");
         else if(originals.length==2)check(body.vis.mask===originals[0] && body.vis.mask!==retiredMasks[0],"RV reclaims its exact native body mask");
         else check(body.vis.mask!=null && body.vis.mask!==retiredMasks[0],"RV reclaims a live native body mask after the early leave window");
         check(body.hpbar.mask!==retiredMasks[1] && body.hpbar.mask.stage!=null,"native health bar retains a live mask after RV refresh");
         var orphan:int=0;
         for each(var index:int in [2,3]) {
            var layer:DisplayObjectContainer=mod.game.world.grafon.visObjs[index] as DisplayObjectContainer;
            for(var i:int=0;i<layer.numChildren;i++) {
               var item:DisplayObject=layer.getChildAt(i);
               if(item.name=="RConnectRestoredMask" && item!==body.vis.mask && item!==body.hpbar.mask && item.visible)orphan++;
            }
         }
         check(orphan==0,"temporary owned masks leave no visible orphan after RV reclaims clipping");
         picture("sweep");
         Log.d("MASK RESTORE SUMMARY "+JSON.stringify({caseId:round,partial:partialFrames,liveFields:2,
            retiredRemoved:removed,renderedClipped:visibleFields,decoys:decoys.length,ownedOrphans:orphan}));
         endCase();
      }
      private function endCase():void {
         mod.game.loc.remObj(body.currentWeapon);mod.game.loc.remObj(body);var n:int=mod.game.loc.units.indexOf(body);if(n>=0)mod.game.loc.units.splice(n,1);body=null;
         if(++round>=7)finish();else create();
      }
      private function maskGraphics(s:Shape):Object {var g:Object=s.graphics;return g["readGraphicsData"](false);}
      private function fieldPicture(view:DisplayObject):Object {
         var r:Rectangle=view.getBounds(view),b:BitmapData=new BitmapData(Math.ceil(r.width),Math.ceil(r.height),true,0);
         b.draw(view,new Matrix(1,0,0,1,-r.x,-r.y));return {bitmap:b,bounds:r};
      }
      private function scene(view:DisplayObject,mask:Shape,pic:Object):String {
         // Detached display objects model the real parent coordinates. Never
         // assign the live mask: that would steal ownership and contaminate the
         // production restore state while a nested render callback is possible.
         var tree:Sprite=new Sprite(),image:Sprite=new Sprite(),imageBits:Bitmap=new Bitmap(pic.bitmap),r:Rectangle=pic.bounds;
         imageBits.x=r.x;imageBits.y=r.y;image.addChild(imageBits);image.transform.matrix=view.transform.matrix.clone();
         var clip:Shape=new Shape();clip.graphics.copyFrom(mask.graphics);clip.transform.matrix=mask.transform.matrix.clone();
         image.cacheAsBitmap=clip.cacheAsBitmap=true;tree.addChild(image);tree.addChild(clip);image.mask=clip;
         var area:Rectangle=image.getBounds(tree);area.inflate(2,2);
         var b:BitmapData=new BitmapData(Math.ceil(area.width),Math.ceil(area.height),true,0),value:String="";
         try {
            b.draw(tree,new Matrix(1,0,0,1,-area.x,-area.y));
            var hash:uint=2166136261;for each(var pixel:uint in b.getVector(b.rect))hash=uint((hash^pixel)*65599);
            value=JSON.stringify([area.x,area.y,b.width,b.height,hash]);
         } finally {b.dispose();image.mask=null;}
         return value;
      }
      private function signature(s:Shape):String {
         if(s==null)return "";var result:String="",b:BitmapData=null;
         try {
            var r:Rectangle=s.getBounds(s),w:int=Math.ceil(r.width),h:int=Math.ceil(r.height);
            if(w<1 || h<1 || w*h>1000000)return "";
            var paint:Shape=new Shape();paint.graphics.copyFrom(s.graphics);
            b=new BitmapData(w,h,true,0);b.draw(paint,new Matrix(1,0,0,1,-r.x,-r.y));
            var hash:uint=2166136261;for each(var pixel:uint in b.getVector(b.rect))hash=uint((hash^pixel)*65599);
            result=JSON.stringify([r.x,r.y,w,h,hash]);
         } catch(e:Error){}finally {if(b!=null)b.dispose();}return result;
      }
      private function maskLayout(s:Shape):Object {
         for each(var p:Object in maskGraphics(s))if(p is GraphicsBitmapFill) {
            var f:GraphicsBitmapFill=p as GraphicsBitmapFill;
            return {width:f.bitmapData.width,height:f.bitmapData.height,matrix:f.matrix.clone(),
               repeat:f.repeat,smooth:f.smooth,bounds:s.getBounds(s),transform:s.transform.matrix.clone()};
         }return null;
      }
      private function makeDecoy(layout:Object):Shape {
         var b:BitmapData=new BitmapData(layout.width,layout.height,true,0x80FFFFFF);copies.push(b);
         var r:Rectangle=layout.bounds,out:Shape=new Shape();
         out.graphics.beginBitmapFill(b,layout.matrix.clone(),layout.repeat,layout.smooth);
         out.graphics.drawRect(r.x,r.y,r.width,r.height);out.graphics.endFill();
         out.transform.matrix=layout.transform.clone();out.cacheAsBitmap=true;return out;
      }
      private function picture(label:String):void {
         var b:BitmapData=new BitmapData(mod.stage.stageWidth,mod.stage.stageHeight,false,0),f:FileStream=new FileStream();
         try {b.draw(mod.main as DisplayObject);f.open(File.applicationStorageDirectory.resolvePath("presentation-mask-restore-"+round+"-"+label+".png"),FileMode.WRITE);f.writeBytes(b.encode(b.rect,new PNGEncoderOptions()));}
         finally {f.close();b.dispose();}
      }
      private function finish():void {
         if(phase=="done")return;phase="done";timer.stop();
         if(mod!=null){mod.stage.removeEventListener(Event.ENTER_FRAME,drive);mod.stage.removeEventListener(Event.ENTER_FRAME,capture);mod.stage.removeEventListener(Event.RENDER,render);}
         for each(var b:BitmapData in copies)b.dispose();copies=[];
         Log.d("COOP EFFECTS DONE");
      }
   }
}

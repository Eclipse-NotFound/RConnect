package {
   import flash.desktop.NativeApplication;
   import flash.display.BitmapData;
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.PNGEncoderOptions;
   import flash.events.Event;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.utils.ByteArray;
   import flash.utils.Dictionary;
   import flash.utils.getTimer;
   import rconnect.core.Log;

   /** Read-only final-RENDER observer. Never requests or releases a loading owner. */
   public final class NativeLoadingProbe {
      private var mod:RConnectMod,role:String,ids:Dictionary=new Dictionary(true),nextId:int=0;
      private var world:Object,nativeWait:DisplayObject,nativeParent:DisplayObjectContainer;
      private var rows:Array=[],boundaries:Array=[],faults:Array=[],checks:Array=[],last:Object;
      private var faultCount:int=0,dropped:int=0,renderCount:int=0,eligibleCount:int=0,waitCount:int=0;
      private var missingWait:int=0,layerLeak:int=0,copyCount:int=0,identityChanges:int=0,parentChanges:int=0;
      private var bridgeMissing:int=0,worldFaultFrames:int=0,terminalRequested:Boolean=false,written:Boolean=false;
      private var round:int=-1,target:String="",phase:String="boot",began:int,finishedAt:int=0;
      private var totalMs:int=0,maxMs:int=0,maxRenderGap:int=0;
      private var rounds:Object={};
      private var spans:Object={nativeWait:{start:-1,total:0,max:0},black:{start:-1,total:0,max:0},
         obscured:{start:-1,total:0,max:0},pending:{start:-1,total:0,max:0}};
      private static const LIMIT:int=20000;
      private static const OLD_NAMES:Array=["rconnect-room-entry","rconnect-room-entry-sats","rconnect-native-loading"];

      public function NativeLoadingProbe(m:RConnectMod) {
         mod=m;began=getTimer();
         role=NativeApplication.nativeApplication.applicationID.indexOf("-host-")>=0?"host":"join";
         // Later than RoomSync.present (-2000000000). Repeated render events
         // remain observations; they are not claimed as separate GPU frames.
         mod.stage.addEventListener(Event.RENDER,render,false,-2147483000);
      }
      private function fault(label:String,error:*):void {
         faultCount++;if(faults.length<16)faults.push({at:getTimer(),label:label,error:String(error)});
      }
      private function id(value:Object):int {
         if(value==null)return 0;if(ids[value]==null)ids[value]=++nextId;return int(ids[value]);
      }
      private function display(value:Object):Object {
         var d:DisplayObject=value as DisplayObject;
         if(d==null)return {id:0,parent:0,attached:false,visible:false,alpha:0,effective:false,index:-1};
         var a:Number=1,shown:Boolean=true,depth:int=0,p:DisplayObject=d;
         while(p!=null && depth<128){shown=shown&&p.visible;a*=p.alpha;p=p.parent;depth++;}
         if(p!=null)throw new Error("Display ancestor depth exceeded");
         return {id:id(d),parent:id(d.parent),name:d.name,attached:d.stage===mod.stage,
            visible:d.visible,alpha:d.alpha,effective:shown&&a>0&&d.stage===mod.stage,
            effectiveAlpha:a,index:d.parent==null?-1:d.parent.getChildIndex(d),x:d.x,y:d.y};
      }
      /** Exact old implementation attached only under these native containers.
       * A complete tree scan also runs after timing, before the terminal PNG. */
      private function knownCopies(w:Object):Array {
         var scopes:Array=[mod.stage,mod.main,w.visual==null?null:w.visual.parent,w.vsats],seen:Dictionary=new Dictionary(true),found:Array=[];
         for each(var scope:DisplayObjectContainer in scopes) {
            if(scope==null||seen[scope])continue;seen[scope]=true;
            for each(var name:String in OLD_NAMES) {
               var child:DisplayObject=scope.getChildByName(name);
               if(child!=null)found.push({id:id(child),name:name,parent:id(scope),effective:display(child).effective});
            }
         }
         return found;
      }
      private function blocked(w:Object):String {
         if(w.gg==null||w.loc==null||w.game==null||w.vwait==null||w.gg.pers==null)return "no-world";
         if(w.comLoad>=0||w.ng_wait>0||w.t_die>0||w.gg.pers.dead)return "native-load-or-death";
         if(w.allStat!=1)return "native-state";
         if(w.catPause||w.vscene.visible||w.clickReq!=0||w.vwait.story.visible)return "native-story";
         if(w.onConsol||w.verror.visible||(w.pip!=null&&w.pip.active)||(w.sats!=null&&w.sats.active)
            ||(w.stand!=null&&w.stand.active)||(w.gui!=null&&w.gui.guiPause))return "native-overlay";
         if(w.t_exit>20)return "native-fade";
         return "";
      }
      private function snapshot():Object {
         var w:Object=mod.game.world,r:Object=mod.session.rooms;
         if(w==null||w.vwait==null)throw new Error("Missing actual World/vwait");
         if(world==null){
            nativeWait=w.vwait as DisplayObject;
            if(nativeWait==null||nativeWait.parent==null)throw new Error("Native vwait is not attached to its original parent");
            world=w;nativeParent=nativeWait.parent;
         }
         var wait:Object=display(w.vwait),black:Object=display(w.vblack),visual:Object=display(w.visual),
            fon:Object=display(w.vfon),gui:Object=display(w.vgui),copies:Array=knownCopies(w);
         var reason:String=blocked(w),eligible:Boolean=r.entryPending===true&&reason=="";
         var supported:Boolean="rconnectLoadingUiFaults" in w;
         var same:Boolean=w===world&&w.vwait===nativeWait;
         var parentSame:Boolean=nativeWait!=null&&nativeWait.parent===nativeParent;
         if(!same)identityChanges++;if(!parentSame)parentChanges++;
         if(!supported)bridgeMissing++;
         var nativeFaults:int=supported?int(w.rconnectLoadingUiFaults):-1;
         if(nativeFaults>0)worldFaultFrames++;
         if(copies.length>0)copyCount+=copies.length;
         if(wait.effective)waitCount++;
         if(eligible) {
            eligibleCount++;
            if(!wait.effective)missingWait++;
            if(visual.visible||fon.visible||gui.visible)layerLeak++;
         }
         return {at:getTimer(),round:round,target:target,phase:phase,world:id(w),game:id(w.game),player:id(w.gg),
            entryPending:r.entryPending,busy:r.busy,ready:r.ready,term:r.term,epoch:r.epoch,
            exit:w.t_exit,loadScreen:w.loadScreen,clickReq:w.clickReq,allStat:w.allStat,onPause:w.onPause,
            wait:wait,vblack:black,visual:visual,vfon:fon,vgui:gui,eligible:eligible,blocked:reason,
            nativeWaitIdentity:same,nativeParentIdentity:parentSame,supported:supported,nativeFaults:nativeFaults,
            copies:copies,storyVisible:w.vwait.story.visible,
            progressVisible:w.vwait.progres.visible,progressText:String(w.vwait.progres.text)};
      }
      private function duration(name:String,active:Boolean,at:int):void {
         var s:Object=spans[name];
         if(last!=null && int(s.start)>=0)s.total+=at-int(last.at);
         if(active && int(s.start)<0)s.start=at;
         if(!active && int(s.start)>=0){s.max=Math.max(int(s.max),at-int(s.start));s.start=-1;}
      }
      private function render(e:Event):void {
         if(written)return;var started:int=getTimer();
         try {
            var row:Object=snapshot();renderCount++;
            var key:String=String(round),counts:Object=rounds[key];
            if(counts==null)rounds[key]=counts={renders:0,nativeWait:0,eligible:0,pending:0,black:0};
            counts.renders++;if(row.wait.effective)counts.nativeWait++;if(row.eligible)counts.eligible++;
            if(row.entryPending)counts.pending++;if(row.vblack.effective)counts.black++;
            if(last!=null)maxRenderGap=Math.max(maxRenderGap,int(row.at)-int(last.at));
            duration("nativeWait",row.wait.effective,row.at);
            duration("black",row.vblack.effective,row.at);
            duration("obscured",row.wait.effective||row.vblack.effective,row.at);
            duration("pending",row.entryPending,row.at);
            last=row;if(rows.length<LIMIT)rows.push(row);else dropped++;
         } catch(error:*) {fault("render",error);}
         var cost:int=getTimer()-started;totalMs+=cost;maxMs=Math.max(maxMs,cost);
         if(terminalRequested) {
            try {finishOutput();}
            catch(outputError:*) {
               fault("terminal-output",outputError);
               Log.d("NATIVE LOADING PROBE OUTPUT FAILED "+role+" "+String(outputError));
            }
         }
      }
      public function begin(index:int,land:String,time:int):void {
         try {round=index;target=land;phase="travel";boundaries.push({kind:"begin",round:index,target:land,at:time});}
         catch(error:*){fault("begin",error);}
      }
      public function completed(index:int,time:int):void {
         try {phase="settled";boundaries.push({kind:"result",round:index,at:time});}
         catch(error:*){fault("completed",error);}
      }
      public function finish():void {
         try {finishedAt=getTimer();phase="finished";terminalRequested=true;
            boundaries.push({kind:"finish-request",round:round,at:finishedAt});}
         catch(error:*){fault("finish-request",error);}
      }
      private function fullCopies():Object {
         var queue:Array=[mod.stage],found:Array=[],visited:int=0;
         while(queue.length>0 && visited<100000) {
            var d:DisplayObject=queue.pop() as DisplayObject;visited++;
            if(OLD_NAMES.indexOf(d.name)>=0)found.push({id:id(d),name:d.name,parent:id(d.parent)});
            var c:DisplayObjectContainer=d as DisplayObjectContainer;
            if(c!=null)for(var i:int=0;i<c.numChildren;i++)queue.push(c.getChildAt(i));
         }
         if(queue.length>0)throw new Error("Terminal tree scan exceeded bound");
         return {visited:visited,copies:found};
      }
      private function check(ok:Boolean,label:String):void {checks.push({passed:ok,label:label});}
      private function finishOutput():void {
         if(written)return;written=true;mod.stage.removeEventListener(Event.RENDER,render);
         var ending:int=getTimer(),tree:Object=null,png:Object=null;
         for(var key:String in spans)if(int(spans[key].start)>=0) {
            spans[key].max=Math.max(int(spans[key].max),ending-int(spans[key].start));spans[key].start=-1;
         }
         try {tree=fullCopies();}catch(scanError:*){fault("terminal-scan",scanError);}
         // The original final elapsed/result and DONE already exist. No image
         // capture or PNG encoding occurs inside any measured travel window.
         var bmp:BitmapData=null;
         try {
            var pngAt:int=getTimer();bmp=new BitmapData(mod.stage.stageWidth,mod.stage.stageHeight,false,0);
            bmp.draw(mod.stage);
            var encoded:ByteArray=bmp.encode(bmp.rect,new PNGEncoderOptions());
            var dest:File=File.applicationStorageDirectory.resolvePath("native-loading-terminal.png"),stream:FileStream=new FileStream();
            try {stream.open(dest,FileMode.WRITE);stream.writeBytes(encoded);}finally {stream.close();}
            png={name:dest.name,bytes:encoded.length,at:pngAt,finishedAt:finishedAt,afterMeasuredTravel:pngAt>=finishedAt,
               width:mod.stage.stageWidth,height:mod.stage.stageHeight,milliseconds:getTimer()-pngAt};
         }catch(pngError:*){fault("terminal-png",pngError);}
         finally {if(bmp!=null)bmp.dispose();}
         var begins:Array=[],ends:Array=[];
         for each(var b:Object in boundaries){if(b.kind=="begin")begins.push(b.round);if(b.kind=="result")ends.push(b.round);}
         check(JSON.stringify(begins)=="[0,1,2]"&&JSON.stringify(ends)=="[0,1,2]","all three original trips observed");
         check(rounds["0"]!=null&&rounds["1"]!=null&&rounds["2"]!=null
            &&rounds["0"].renders>0&&rounds["1"].renders>0&&rounds["2"].renders>0,"each original trip has actual final-RENDER observations");
         check(faultCount==0&&dropped==0,"no observation errors or discarded render rows");
         check(renderCount>0&&waitCount>0&&eligibleCount>0,"actual native wait and eligible pending observed");
         check(bridgeMissing==0&&worldFaultFrames==0,"actual World bridge present with zero native faults");
         check(identityChanges==0&&parentChanges==0,"same actual vwait and original parent throughout");
         check(copyCount==0&&tree!=null&&tree.copies.length==0,"no old custom cover or copied loading objects");
         check(missingWait==0&&layerLeak==0,"eligible local pending shows native wait and hides scene/background/HUD");
         check(last!=null&&int(last.at)>=finishedAt&&last.phase=="finished","terminal state came from final RENDER after finish");
         check(last!=null&&!last.entryPending&&!last.busy&&!last.wait.effective&&!last.vblack.effective
            &&last.visual.effective&&last.vfon.effective&&last.vgui.effective,"terminal native layers restored without loading/fade obstruction");
         check(png!=null&&png.afterMeasuredTravel&&png.bytes>0,"real terminal PNG captured after original timing");
         var passed:Boolean=true;for each(var c:Object in checks)if(!c.passed)passed=false;
         var result:Object={kind:"native-loading-observer-v1",role:role,
            appId:NativeApplication.nativeApplication.applicationID,passed:passed,complete:true,checks:checks,
            startedAt:began,finishedAt:finishedAt,terminalAt:ending,rows:rows,boundaries:boundaries,rounds:rounds,
            faultCount:faultCount,faults:faults,dropped:dropped,renderCount:renderCount,
            eligibleCount:eligibleCount,waitCount:waitCount,missingWait:missingWait,layerLeak:layerLeak,
            copyCount:copyCount,identityChanges:identityChanges,parentChanges:parentChanges,
            bridgeMissing:bridgeMissing,worldFaultFrames:worldFaultFrames,spans:spans,maxRenderGap:maxRenderGap,
            observationMs:totalMs,observationMaxMs:maxMs,terminalTree:tree,png:png,
            durationMeaning:"sample-held state intervals, not GPU completion or exact unsampled transition time",
            diagnosticOnly:true,performanceQualified:false,loadingViewCalled:false};
         var file:FileStream=new FileStream();
         try {file.open(File.applicationStorageDirectory.resolvePath("native-loading-observer.json"),FileMode.WRITE);
            file.writeUTFBytes(JSON.stringify(result));}
         finally {file.close();}
         Log.d("NATIVE LOADING PROBE RESULT "+JSON.stringify({role:role,passed:passed,renderCount:renderCount,
            eligibleCount:eligibleCount,faultCount:faultCount,dropped:dropped,checks:checks}));
         Log.d("NATIVE LOADING PROBE DONE "+role);
      }
   }
}

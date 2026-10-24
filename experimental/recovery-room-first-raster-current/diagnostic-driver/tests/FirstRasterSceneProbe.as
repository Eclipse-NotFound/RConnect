package {
   import flash.desktop.NativeApplication;
   import flash.events.Event;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.utils.getTimer;
   import rconnect.core.Log;

   /** External, first-map-only evidence. Native hooks are called exactly once;
    * the observer neither releases a ticket nor calls checkpoint/restore. */
   public final class FirstRasterSceneProbe {
      private var mod:Object,cls:Object,original:Function,wrapper:Function;
      private var ticket:Object,refs:Object,rows:Array=[],surfaces:Array=[];
      private var started:Boolean=false,completed:Boolean=false,restored:Boolean=false;
      private var host:Boolean=false,finalState:Object,authorization:Object,eventRef:Object,beforeRow:Object;
      private var faults:Array=[],faultCount:int=0,ignoredAuthorizations:int=0;
      private var additionalBridgeCalls:int=0,finished:Boolean=false;
      private const LIMIT:int=4;

      public function FirstRasterSceneProbe(value:Object) {
         mod=value;
         try {
            if(NativeApplication.nativeApplication.applicationID.indexOf("rconnect-coop-")<0)
               throw new Error("Not an isolated cooperation instance");
            cls=mod.game.main.loaderInfo.applicationDomain.getDefinition("fe.graph.Grafon");
            if(!("rconnectRasterBridge" in cls) || !(cls.rconnectRasterBridge is Function))
               throw new Error("Exact native raster callback unavailable");
            original=cls.rconnectRasterBridge;
            wrapper=function(w:Object,l:Object,g:Object):Object {
               // Do not catch or alter exceptions from the production hook.
               var result:Object=original(w,l,g);
               try {opened(w,l,g,result);}catch(error:*){fault("open",error);}
               return result;
            };
            cls.rconnectRasterBridge=wrapper;
            mod.stage.addEventListener(Event.RENDER,paint,false,1000000);
            mod.stage.addEventListener(Event.RENDER,activated,false,-2147483648);
         }catch(error:*){fault("install",error);}
      }
      private function fault(where:String,error:*):void {
         ++faultCount;
         if(faults.length<8)faults.push({where:where,message:String(error)});
      }
      private function opened(w:Object,l:Object,g:Object,result:Object):void {
         if(completed || finished)return;
         if(started) {
            if(l===refs.loc) {
               ++additionalBridgeCalls;
               if(result!==ticket || w!==refs.world || g!==refs.grafon)
                  throw new Error("Target redraw replaced the original native raster ticket");
            }
            return;
         }
         if(result==null || l==null || l.land==null || String(l.land.act.id)!="random_mane")return;
         if(mod.session.mode!="hosting" && mod.session.mode!="connected")throw new Error("No real paired session");
         host=mod.session.mode=="hosting";started=true;ticket=result;
         refs={world:w,game:w.game,player:w.gg,land:w.land,loc:l,grafon:g};
         rows.push(snapshot("ticket-open"));
      }
      private function identities():Object {
         var w:Object=mod.game.world,g:Object=refs.grafon;
         return {world:w===refs.world,game:w!=null && w.game===refs.game,
            player:w!=null && w.gg===refs.player,land:w!=null && w.land===refs.land,
            loc:w!=null && w.loc===refs.loc,grafon:w!=null && w.grafon===g,
            rendererLoc:g.loc===refs.loc};
      }
      private function snapshot(kind:String):Object {
         var at:int=getTimer(),w:Object=mod.game.world,g:Object=refs.grafon,r:Object=mod.session.rooms;
         var value:Object={kind:kind,at:at,wall:new Date().time,identity:identities(),
            exit:int(w.t_exit),waiting:ticket.waiting,unpainted:ticket.unpainted,
            rasterPending:g.rconnectRasterPending,earlyPending:Boolean(r.earlyTravelPending),
            ready:Boolean(r.ready),busy:Boolean(r.busy),roomKey:mod.game.roomKey(refs.loc),
            land:String(refs.land.act.id),seed:Number(refs.land.rconnectLayoutSeed),
            redraws:Number(g.sceneRedraws),passes:Number(g.sceneRegionPasses),
            resident:Number(g.sceneResident),evictions:Number(g.sceneEvictions)};
         for each(var name:String in ["redraws","passes","resident","evictions"])
            if(!isFinite(value[name]) || value[name]<0 || value[name]!=Math.floor(value[name]))
               throw new Error("Invalid native counter "+name);
         return value;
      }
      public function before(e:Object):void {
         if(!started || completed || finished || authorization!=null)return;
         try {
            var p:Object=e.data;
            if(p.type!="room" || p.op!=(host?"ready":"grant") || String(p.earlyId || "")=="")return;
            if(ticket.waiting!==true)return;
            if(eventRef!=null)throw new Error("Nested authorization dispatch cannot be bracketed");
            beforeRow=snapshot("authorization-before");eventRef=e;
         }catch(error:*){fault("before",error);}
      }
      public function after(e:Object):void {
         if(eventRef!==e)return;
         try {
            var p:Object=e.data;
            if(ticket.waiting===false) {
               authorization={op:String(p.op),earlyId:String(p.earlyId),epoch:int(p.epoch),barrier:int(p.barrier)};
               rows.push(beforeRow);rows.push(snapshot("authorization-after"));
            }else ++ignoredAuthorizations; // A rejected stale packet is not an authorization boundary.
         }catch(error:*){fault("after",error);}
         finally {eventRef=null;beforeRow=null;}
      }
      private function paint(e:Event):void {
         if(!started || completed || finished || authorization==null || rows.length!=3)return;
         try {
            if(ticket.waiting!==false || ticket.unpainted!==false)return;
            var row:Object=snapshot("first-raster-ready");
            row.viewReady=refs.grafon.sceneViewReady()===true;
            row.renderEvent=true;
            var all:Array=refs.grafon.sceneSurfaces();
            row.surfaceCount=all.length;row.surfaceSamples=[];
            // Keep at most four references, not bitmap pixels or a full surface history.
            for each(var item:Object in all) {
               if(surfaces.length==LIMIT)break;
               if(item==null || !(item.nativeBuffers is Array) || item.nativeBuffers.length!=4)
                  throw new Error("Native surface has no four-buffer identity");
               surfaces.push({entry:item,cx:item.cx,cy:item.cy,buffers:item.nativeBuffers.slice()});
               row.surfaceSamples.push({cx:item.cx,cy:item.cy,sample:surfaces.length});
            }
            rows.push(row);
         }catch(error:*){fault("paint",error);}
      }
      private function activated(e:Event):void {
         if(!started || completed || finished || rows.length!=4)return;
         try {
            var r:Object=mod.session.rooms;
            if(r.earlyTravelPending)return;
            var w:Object=mod.game.world,g:Object=refs.grafon;
            finalState={at:getTimer(),wall:new Date().time,identity:identities(),
               ready:Boolean(r.ready),busy:Boolean(r.busy),earlyPending:Boolean(r.earlyTravelPending),
               exit:int(w.t_exit),paused:Boolean(w.onPause),control:Boolean(w.gg.ggControl),noAct:Boolean(w.pip.noAct),
               rasterPending:g.rconnectRasterPending,viewReady:g.sceneViewReady()===true,
               redraws:Number(g.sceneRedraws),passes:Number(g.sceneRegionPasses),
               resident:Number(g.sceneResident),evictions:Number(g.sceneEvictions),surfaceSamples:[]};
            var all:Array=g.sceneSurfaces();
            for each(var sample:Object in surfaces) {
               var found:Object=null;
               for each(var item:Object in all)if(item.cx==sample.cx && item.cy==sample.cy){found=item;break;}
               var same:Boolean=found===sample.entry;
               if(same)for(var i:int=0;i<4;i++)if(found.nativeBuffers[i]!==sample.buffers[i])same=false;
               finalState.surfaceSamples.push({cx:sample.cx,cy:sample.cy,retained:same});
            }
            completed=true;dispose();
         }catch(error:*){fault("activation",error);}
      }
      private function identityOkay(value:Object,renderer:Boolean=true):Boolean {
         return value!=null && value.world && value.game && value.player && value.land && value.loc && value.grafon
            && (!renderer || value.rendererLoc);
      }
      private function dispose():void {
         try {
            mod.stage.removeEventListener(Event.RENDER,paint);
            mod.stage.removeEventListener(Event.RENDER,activated);
         }catch(error:*){fault("listeners-cleanup",error);}
         try {
            if(original!=null) {
               if(cls.rconnectRasterBridge===wrapper){cls.rconnectRasterBridge=original;restored=true;}
               else if(!restored)fault("cleanup","Native callback ownership changed");
            }
         }catch(error:*){fault("callback-cleanup",error);}
         ticket=refs=eventRef=beforeRow=null;surfaces=[];
      }
      public function finish():void {
         if(finished)return;finished=true;
         dispose();
         var checks:Array=[];
         checks.push({passed:faultCount==0,label:"observer has no exception or identity fault"});
         checks.push({passed:started && completed && restored && rows.length==4,label:"one real first-map ticket completed and callback ownership restored"});
         var valid:Boolean=rows.length==4 && finalState!=null && authorization!=null;
         if(valid) {
            var a:Object=rows[0],b:Object=rows[1],c:Object=rows[2],d:Object=rows[3];
            checks.push({passed:identityOkay(a.identity,false) && identityOkay(b.identity) && identityOkay(c.identity)
               && identityOkay(d.identity) && identityOkay(finalState.identity),label:"same native world, game, player, land, room and renderer"});
            checks.push({passed:a.at<=b.at && b.at<=c.at && c.at<=d.at && d.at<=finalState.at
               && a.seed==b.seed && b.seed==c.seed && c.seed==d.seed
               && a.roomKey==b.roomKey && b.roomKey==c.roomKey && c.roomKey==d.roomKey
               && authorization.epoch>0 && authorization.barrier>0,
               label:"ordered native boundaries belong to the same room and authorization"});
            checks.push({passed:a.waiting===true && a.unpainted===true && a.earlyPending
               && b.waiting===true && b.unpainted===true && b.rasterPending===true,
               label:"native ticket still holds terrain before real authorization"});
            checks.push({passed:b.redraws==a.redraws && b.passes==a.passes && b.resident==0,
               label:"no expensive raster pass completed or began before authorization"});
            checks.push({passed:c.redraws==a.redraws && c.passes==a.passes && c.resident==0
               && c.waiting===false && c.unpainted===true && c.rasterPending===true,
               label:"full authorization handler released waiting without drawing terrain"});
            checks.push({passed:d.redraws>c.redraws && d.passes>=c.passes && d.resident>0
               && d.waiting===false && d.unpainted===false && d.rasterPending===false && d.viewReady,
               label:"actual native raster work happens after authorization and reaches a ready view"});
            checks.push({passed:finalState.ready && !finalState.busy && !finalState.earlyPending && finalState.exit==0
               && !finalState.paused && finalState.control && !finalState.noAct && finalState.viewReady && !finalState.rasterPending,
               label:"real activation returns native input after painting"});
            var retained:Boolean=finalState.surfaceSamples.length>0 && finalState.surfaceSamples.length<=LIMIT;
            for each(var sample:Object in finalState.surfaceSamples)retained=retained && sample.retained;
            checks.push({passed:retained && finalState.evictions==d.evictions && finalState.redraws>=d.redraws
               && finalState.passes>=d.passes && finalState.resident>=d.resident,
               label:"sampled first-view surfaces survive until activation; later warmup may add work"});
         }
         var passed:Boolean=valid;
         for each(var check:Object in checks)passed=passed && check.passed;
         var result:Object={kind:"first-raster-current-four-node-v1",role:host?"host":"join",passed:passed,
            diagnosticOnly:true,performanceQualified:false,pixelEquality:false,wholeMapSinglePass:false,
            nodes:rows,authorization:authorization,activation:finalState,checks:checks,
            ignoredAuthorizations:ignoredAuthorizations,additionalBridgeCalls:additionalBridgeCalls,
            faultCount:faultCount,faults:faults,callbackRestored:restored,
            boundary:"native raster work and RENDER events, not GPU completion"};
         var stream:FileStream=new FileStream();
         try {
            stream.open(File.applicationStorageDirectory.resolvePath("first-raster-current.json"),FileMode.WRITE);
            stream.writeUTFBytes(JSON.stringify(result));
         }catch(error:*) {
            passed=false;result.passed=false;result.outputError=String(error);
            Log.d("COOP FAIL first-raster-current result write "+error);
         }
         finally {try{stream.close();}catch(ignored:*){}}
         Log.d("FIRST RASTER CURRENT RESULT "+JSON.stringify(result));
         Log.d("COOP "+(passed?"PASS ":"FAIL ")+"first-raster-current deferred native raster evidence");
      }
   }
}

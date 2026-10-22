package {
   import flash.utils.Dictionary;
   /** Fixed buckets retain every stable call, including positive-time rendering. */
   public final class PaintTimingBuffer {
      private static const LIMIT:int=32;
      private var cls:Object,own:Function,world:Object,game:Object,renderer:Object,room:Object;
      private var rows:Array=[],buckets:Array=[],bucketRooms:Array=[],locations:Dictionary;
      private var locationSerial:int=0,segment:int=-1;
      private var active:Boolean=false,attached:Boolean=false,available:Boolean=false;
      private var overflow:Boolean=false,faults:int=0,conflicts:int=0,nativeStart:uint=0;
      private var ownershipPreserved:Boolean=true;
      private var calls:int=0,positiveMsCalls:int=0,zeroMsCalls:int=0,incompleteCalls:int=0;
      private var inclusiveTotalMs:Number=0,maxMs:Number=0,lastFinished:Number=-1,lastWall:Number=-1;
      public var tailObserver:Function;
      public function ownsObserver():Boolean {
         return active && attached && cls!=null && cls.rconnectPaintTimingBridge===own;
      }
      public function PaintTimingBuffer(type:Object) {cls=type;own=receive;}
      private function bucket(category:String):Object {
         return {category:category,calls:0,positiveMsCalls:0,zeroMsCalls:0,totalMs:0,maxMs:0,
            firstStarted:null,lastFinished:null,firstStartedWall:null,lastFinishedWall:null,
            firstCall:null,lastCall:null,roomChanges:0,firstResident:null,lastResident:null,
            residentTransitions:0,preloadCalls:0,allCompleted:true,allIdentitiesMatch:true,
            allClocksValid:true,stableResidentOnly:true};
      }
      public function begin(w:Object):void {
         if(active){faults++;return;}
         segment++;active=true;world=w;game=w==null?null:w.game;renderer=w==null?null:w.grafon;room=null;
         rows=[];buckets=[bucket("target"),bucket("unbound"),bucket("other")];bucketRooms=[null,null,null];
         locations=new Dictionary();locationSerial=0;overflow=false;faults=conflicts=0;
         available=false;attached=false;ownershipPreserved=true;nativeStart=0;
         calls=positiveMsCalls=zeroMsCalls=incompleteCalls=0;inclusiveTotalMs=maxMs=0;lastFinished=lastWall=-1;
         try {
            available=cls!=null && ("rconnectPaintTimingBridge" in cls) && ("rconnectPaintTimingFaults" in cls);
            if(!available || w==null || game==null || renderer==null){faults++;return;}
            nativeStart=uint(cls.rconnectPaintTimingFaults);
            if(cls.rconnectPaintTimingBridge!=null){ownershipPreserved=false;faults++;return;}
            cls.rconnectPaintTimingBridge=own;attached=true;
         }catch(ignored:*){faults++;}
      }
      public function bind(w:Object,l:Object,g:Object):void {
         if(!active)return;
         try {
            if(w!==world || w.game!==game || g!==renderer || l==null){conflicts++;return;}
            if(room==null)room=l;else if(room!==l)conflicts++;
         }catch(ignored:*){faults++;}
      }
      private function detach():void {
         if(!attached)return;
         try {
            if(cls.rconnectPaintTimingBridge===own)cls.rconnectPaintTimingBridge=null;
            else ownershipPreserved=false;
         }catch(ignored:*){faults++;ownershipPreserved=false;}
         attached=false;
      }
      private function store(row:Object):void {
         if(rows.length>=LIMIT){overflow=true;detach();return;}
         row.segment=segment;row.sequence=rows.length+1;row.callIndex=calls;rows.push(row);
      }
      private function receive(g:Object,w:Object,gameValue:Object,l:Object,v:Object):void {
         if(!active)return;
         calls++;
         var category:String=room==null?"unbound":(l===room?"target":"other");
         try {
            if(v==null || v.phase!=="ensure-work" || !(v.started is Number) || !(v.finished is Number)
               || !(v.startedWall is Number) || !(v.finishedWall is Number)
               || (v.initial!==true && v.initial!==false) || (v.preload!==true && v.preload!==false))throw new Error("metadata");
            var started:Number=Number(v.started),finished:Number=Number(v.finished);
            var wallStart:Number=Number(v.startedWall),wallEnd:Number=Number(v.finishedWall);
            var duration:Number=finished-started;
            var clocks:Boolean=isFinite(started) && isFinite(finished) && isFinite(wallStart) && isFinite(wallEnd)
               && started==int(started) && finished==int(finished) && started>=0 && duration>=0
               && wallEnd>=wallStart && started>=lastFinished && wallStart>=lastWall;
            if(clocks) {
               inclusiveTotalMs+=duration;maxMs=Math.max(maxMs,duration);
               if(duration>0)positiveMsCalls++;else zeroMsCalls++;
               lastFinished=finished;lastWall=wallEnd;
            }else faults++;
            if(v.completed!==true)incompleteCalls++;
            var sameWorld:Boolean=w===world && v.sameWorld===true;
            var sameGame:Boolean=gameValue===game && v.sameGame===true;
            var sameRenderer:Boolean=g===renderer && v.worldRendererAtStart===true && v.worldRendererAtEnd===true;
            var sameLoc:Boolean=l!=null && v.sameLoc===true && v.worldLocAtStart===true && v.worldLocAtEnd===true;
            var residents:Boolean=(v.residentBefore is Number) && (v.residentAfter is Number)
               && isFinite(Number(v.residentBefore)) && isFinite(Number(v.residentAfter))
               && Number(v.residentBefore)==int(v.residentBefore) && Number(v.residentAfter)==int(v.residentAfter)
               && int(v.residentBefore)>=0 && int(v.residentAfter)>=0;
            var stable:Boolean=clocks && residents && v.initial===false && v.completed===true
               && sameWorld && sameGame && sameRenderer && sameLoc && int(v.residentBefore)==int(v.residentAfter);
            if(stable) {
               var index:int=category=="target"?0:(category=="unbound"?1:2);
               var b:Object=buckets[index];
               if(b.calls==0) {
                  b.firstStarted=started;b.firstStartedWall=wallStart;b.firstCall=calls;b.firstResident=int(v.residentBefore);
               }else {
                  if(bucketRooms[index]!==l)b.roomChanges++;
                  if(b.lastResident!=int(v.residentBefore))b.residentTransitions++;
               }
               bucketRooms[index]=l;b.calls++;b.totalMs+=duration;b.maxMs=Math.max(b.maxMs,duration);
               if(duration>0)b.positiveMsCalls++;else b.zeroMsCalls++;
               b.lastFinished=finished;b.lastFinishedWall=wallEnd;b.lastCall=calls;b.lastResident=int(v.residentAfter);
               if(v.preload===true)b.preloadCalls++;
               return;
            }
            var id:int=0;
            if(l!=null && rows.length<LIMIT) {
               if(locations[l]===undefined)locations[l]=++locationSerial;
               id=int(locations[l]);
            }
            store({phase:String(v.phase),category:category,location:id,important:true,clockValid:clocks,
               residentsValid:residents,sameWorld:sameWorld,sameGame:sameGame,sameRenderer:sameRenderer,sameLoc:sameLoc,
               sameRasterRoom:category=="target",worldRendererAtStart:v.worldRendererAtStart===true,
               worldRendererAtEnd:v.worldRendererAtEnd===true,worldLocAtStart:v.worldLocAtStart===true,
               worldLocAtEnd:v.worldLocAtEnd===true,preload:v.preload===true,initial:v.initial===true,
               started:started,finished:finished,startedWall:wallStart,finishedWall:wallEnd,
               residentBefore:Number(v.residentBefore),residentAfter:Number(v.residentAfter),completed:v.completed===true,
               left:Number(v.left),top:Number(v.top),width:Number(v.width),height:Number(v.height)});
            // The aggregate entry above remains the sole native observer. A stable
            // resident call cannot trigger the 0-to-positive tail window.
            if(attached && tailObserver!=null)tailObserver(g,w,gameValue,l,v);
         }catch(ignored:*) {
            faults++;
            store({phase:"observer-error",category:category,important:true,observerError:true,
               sameRasterRoom:category=="target",completed:false,clockValid:false});
            detach();
         }
      }
      public function finish(reason:String):Object {
         if(!active)return null;
         var nativeFaults:Number=0;
         try {if(available)nativeFaults=uint(cls.rconnectPaintTimingFaults)-nativeStart;}catch(ignored:*){faults++;}
         detach();active=false;
         var ok:Boolean=available && !overflow && faults==0 && conflicts==0 && nativeFaults==0 && ownershipPreserved;
         var targetRows:int=0;
         for each(var row:Object in rows) {
            ok=ok && row.phase=="ensure-work" && row.sameWorld && row.sameGame && row.sameRenderer && row.sameLoc
               && row.completed && row.clockValid && row.residentsValid;
            if(row.sameRasterRoom)targetRows++;
         }
         var targetCalls:int=targetRows+int(buckets[0].calls);
         if(room!=null)ok=ok && targetCalls>0;
         var result:Object={kind:"ensure-work-aggregate-v1",schema:1,diagnosticOnly:true,performanceQualified:false,passed:ok,
            segment:segment,reason:reason,available:available,limit:LIMIT,bucketLimit:3,overflow:overflow,faults:faults,
            bindingConflicts:conflicts,nativeFaults:nativeFaults,ownershipPreserved:ownershipPreserved,
            rasterRoomBound:room!=null,targetRows:targetRows,targetCalls:targetCalls,observedCalls:calls,
            positiveMsCalls:positiveMsCalls,zeroMsCalls:zeroMsCalls,incompleteCalls:incompleteCalls,
            inclusiveTotalMs:inclusiveTotalMs,maxMs:maxMs,observationComplete:!overflow && faults==0 && nativeFaults==0 && ownershipPreserved,
            scope:"after native waiting/full-preload early returns; initial/resident-change/failure/identity/clock rows; all stable calls in fixed room buckets",
            bucketMeaning:"stable resident can still perform drawing; buckets retain every call and its measured duration",
            rows:rows,buckets:buckets};
         world=game=renderer=room=null;locations=null;bucketRooms=[];rows=[];buckets=[];return result;
      }
   }
}

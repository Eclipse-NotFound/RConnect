package {
   import flash.utils.Dictionary;
   /** External observation only. No scene, ticket, actor or random-state writes. */
   public final class PaintTimingBuffer {
      private static const LIMIT:int=32;
      private var cls:Object,own:Function,world:Object,game:Object,renderer:Object,room:Object;
      private var rows:Array=[],locations:Dictionary,locationSerial:int=0,segment:int=-1;
      private var active:Boolean=false,attached:Boolean=false,available:Boolean=false;
      private var overflow:Boolean=false,faults:int=0,conflicts:int=0,nativeStart:uint=0;
      private var ownershipPreserved:Boolean=true;
      private var calls:int=0,zeroMsStableResidentSkipped:int=0,positiveMsCalls:int=0,incompleteCalls:int=0;
      private var inclusiveTotalMs:Number=0,maxMs:int=0;
      public function PaintTimingBuffer(type:Object) {cls=type;own=receive;}
      public function begin(w:Object):void {
         if(active){faults++;return;}
         segment++;active=true;world=w;game=w==null?null:w.game;renderer=w==null?null:w.grafon;room=null;
         rows=[];locations=new Dictionary();locationSerial=0;overflow=false;faults=conflicts=0;
         available=false;attached=false;ownershipPreserved=true;nativeStart=0;
         calls=zeroMsStableResidentSkipped=positiveMsCalls=incompleteCalls=maxMs=0;inclusiveTotalMs=0;
         try {
            available=cls!=null && ("rconnectPaintTimingBridge" in cls) && ("rconnectPaintTimingFaults" in cls);
            if(!available || w==null || game==null || renderer==null){faults++;return;}
            nativeStart=uint(cls.rconnectPaintTimingFaults);
            if(cls.rconnectPaintTimingBridge!=null){ownershipPreserved=false;faults++;return;}
            cls.rconnectPaintTimingBridge=own;attached=true;
         }catch(ignored:*){faults++;}
      }
      /** Called by the already-existing real sceneOpen bridge, including its null-ticket case. */
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
      private function receive(g:Object,w:Object,gameValue:Object,l:Object,v:Object):void {
         if(!active)return;
         try {
            calls++;
            if(v==null || v.phase!=="ensure-work" || !(v.started is Number) || !(v.finished is Number)
               || !(v.startedWall is Number) || !(v.finishedWall is Number))throw new Error("Invalid paint timing metadata");
            var duration:int=int(v.finished)-int(v.started);
            if(duration<0)throw new Error("Paint timer moved backwards");
            inclusiveTotalMs+=duration;maxMs=Math.max(maxMs,duration);
            if(duration>0)positiveMsCalls++;
            if(v.completed!==true)incompleteCalls++;
            var sameWorld:Boolean=w===world && v.sameWorld===true;
            var sameGame:Boolean=gameValue===game && v.sameGame===true;
            var sameRenderer:Boolean=g===renderer && v.worldRendererAtStart===true && v.worldRendererAtEnd===true;
            var sameLoc:Boolean=v.sameLoc===true && v.worldLocAtStart===true && v.worldLocAtEnd===true;
            // This is an explicit millisecond-resolution filter, not proof
            // that a zero-ms call did no pixel work. Every such call is counted.
            if(duration==0 && v.initial!==true && int(v.residentBefore)==int(v.residentAfter)
               && v.completed===true && sameWorld && sameGame && sameRenderer && sameLoc) {
               zeroMsStableResidentSkipped++;return;
            }
            if(rows.length>=LIMIT){overflow=true;detach();return;}
            var id:int=0;
            if(l!=null) {
               if(locations[l]===undefined)locations[l]=++locationSerial;
               id=int(locations[l]);
            }
            rows.push({segment:segment,sequence:rows.length+1,location:id,
               sameWorld:sameWorld,sameGame:sameGame,sameRenderer:sameRenderer,sameLoc:sameLoc,
               sameRasterRoom:room!=null && l===room,
               worldRendererAtStart:v.worldRendererAtStart===true,worldRendererAtEnd:v.worldRendererAtEnd===true,
               worldLocAtStart:v.worldLocAtStart===true,worldLocAtEnd:v.worldLocAtEnd===true,
               phase:String(v.phase),preload:v.preload===true,initial:v.initial===true,
               started:int(v.started),finished:int(v.finished),startedWall:Number(v.startedWall),finishedWall:Number(v.finishedWall),
               residentBefore:int(v.residentBefore),residentAfter:int(v.residentAfter),completed:v.completed===true,
               left:Number(v.left),top:Number(v.top),width:Number(v.width),height:Number(v.height)});
         }catch(ignored:*){faults++;detach();}
      }
      public function finish(reason:String):Object {
         if(!active)return null;
         var nativeFaults:Number=0;
         try {if(available)nativeFaults=uint(cls.rconnectPaintTimingFaults)-nativeStart;}catch(ignored:*){faults++;}
         detach();active=false;
         var ok:Boolean=available && !overflow && faults==0 && conflicts==0 && nativeFaults==0 && ownershipPreserved;
         var targetRows:int=0;
         for each(var row:Object in rows) {
            ok=ok && row.sameWorld && row.sameGame && row.sameRenderer && row.sameLoc && row.completed
               && row.finished>=row.started && isFinite(row.startedWall) && isFinite(row.finishedWall);
            if(row.sameRasterRoom)targetRows++;
         }
         if(room!=null)ok=ok && targetRows>0;
         var result:Object={kind:"ensure-work",diagnosticOnly:true,performanceQualified:false,passed:ok,
            segment:segment,reason:reason,available:available,limit:LIMIT,overflow:overflow,faults:faults,
            bindingConflicts:conflicts,nativeFaults:nativeFaults,ownershipPreserved:ownershipPreserved,
            rasterRoomBound:room!=null,targetRows:targetRows,observedCalls:calls,positiveMsCalls:positiveMsCalls,
            zeroMsStableResidentSkipped:zeroMsStableResidentSkipped,incompleteCalls:incompleteCalls,
            inclusiveTotalMs:inclusiveTotalMs,maxMs:maxMs,observationComplete:!overflow && faults==0 && nativeFaults==0 && ownershipPreserved,
            scope:"after native waiting/full-preload early returns; initial/resident-change/positive-ms/error/identity-change rows",
            zeroMsMeaning:"omitted zero-ms stable-resident calls are counted; not proof of zero pixel work",rows:rows};
         world=game=renderer=room=null;locations=null;rows=[];return result;
      }
   }
}

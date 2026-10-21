package {
   import flash.events.Event;
   import flash.utils.Dictionary;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   import rconnect.diagnostics.FlightDiagnostics;

   /** Bounded scalar collection during all eight ORIGINAL trials. Export only
    * at finish(), after the original native listeners/fixtures are removed.
    * This changes measurement overhead, therefore never qualifies performance. */
   public final class FlightDiagnosticRecorder {
      private static const WIDTH:int=24,MAX_ROWS:int=131072,MAX_TEXTS:int=256;
      private static const MAX_PAYLOADS:int=2048,MAX_PAYLOAD_CHARS:int=2097152;
      private var mod:RConnectMod,host:Boolean,started:Boolean=false,finished:Boolean=false;
      private var values:Vector.<Number>=new Vector.<Number>(MAX_ROWS*WIDTH,true);
      private var used:int=0,round:int=-1,frame:int=0,render:int=0,phase:int=0,dropped:int=0;
      private var textIds:Dictionary=new Dictionary(),texts:Array=[],textOverflow:int=0;
      private var payloadIds:Dictionary=new Dictionary(),payloads:Array=[],payloadChars:int=0,payloadOverflow:int=0;
      // Eight per-payload operation counters: hit, miss, remember, evict,
      // protected-unpack begin, reset (no payload), miss-unpack end, protected end.
      private var payloadCounts:Vector.<Number>=new Vector.<Number>(MAX_PAYLOADS*10,true);
      private var wallHit:int=0,wallMiss:int=0,wallRemember:int=0,wallEvict:int=0,wallProtect:int=0,wallReset:int=0;
      private var wallDecoded:int=0,wallProtectedDone:int=0,wallCost:int=0,wallMax:int=0,wallProtectedCost:int=0,wallProtectedMax:int=0;
      private var cacheEntries:int=0,cacheWords:int=0,cacheChars:int=0,lastWallFlush:int=0;
      private var timing:Object,previousTiming:Object,timingOwned:Boolean=false,timingBusy:Boolean=false;
      private var codecPack:int=0,codecUnpack:int=0,codecFirstMs:int=0,codecSecondMs:int=0;
      private var hookOccupied:Boolean=false;
      public function FlightDiagnosticRecorder(m:RConnectMod,h:Boolean){mod=m;host=h;}
      public function start():void {
         if(started)return;started=true;
         if(FlightDiagnostics.sink!=null){hookOccupied=true;return;}
         FlightDiagnostics.reset();FlightDiagnostics.sink=this;
         previousTiming=mod.game.presentationTiming;
         if(previousTiming==null){timing={viewMs:0,viewCalls:0,motionMs:0,motionCalls:0};mod.game.presentationTiming=timing;timingOwned=true;}
         else timingBusy=true;
         // Phase brackets are event-order measurements, not named-function CPU attribution.
         mod.stage.addEventListener(Event.ENTER_FRAME,enterFirst,false,2147483647);
         mod.stage.addEventListener(Event.ENTER_FRAME,afterStamp,false,89999);
         mod.stage.addEventListener(Event.ENTER_FRAME,afterNative,false,-1);
         mod.stage.addEventListener(Event.ENTER_FRAME,afterWeapon,false,-6001);
         mod.stage.addEventListener(Event.ENTER_FRAME,afterMirror,false,-10001);
         mod.stage.addEventListener(Event.RENDER,renderFirst,false,2147483647);
         mod.stage.addEventListener(Event.RENDER,afterView,false,-10001);
         mod.stage.addEventListener(Event.RENDER,renderLast,false,-2147483648);
         row(10,0,new Date().time);
      }
      public function caseStart(n:int):void {flushWall();round=n;row(10,1,n);flushWall();}
      public function mark(name:String):void {row(10,2,text(name));}
      private function enterFirst(e:Event):void{frame++;phase=1;boundary();}
      private function afterStamp(e:Event):void{phase=2;boundary();}
      private function afterNative(e:Event):void{phase=3;boundary();}
      private function afterWeapon(e:Event):void{phase=4;boundary();}
      private function afterMirror(e:Event):void{phase=5;boundary();}
      private function renderFirst(e:Event):void{render++;phase=6;boundary();}
      private function afterView(e:Event):void{phase=7;boundary();}
      private function renderLast(e:Event):void{phase=8;boundary();phase=9;}
      private function boundary():void {
         row(9,timing==null?NaN:Number(timing.viewMs),timing==null?NaN:Number(timing.viewCalls),
            timing==null?NaN:Number(timing.motionMs),timing==null?NaN:Number(timing.motionCalls));
         if(getTimer()-lastWallFlush>=250)flushWall();
      }
      private function text(s:String):int {
         var value:*=textIds[s];if(value!==undefined)return int(value);
         if(texts.length>=MAX_TEXTS){textOverflow++;return -1;}
         var n:int=texts.length;texts.push(s);textIds[s]=n;return n;
      }
      private function payload(s:String):int {
         if(s==null)return -1;
         var value:*=payloadIds[s];if(value!==undefined)return int(value);
         if(payloads.length>=MAX_PAYLOADS || payloadChars+s.length>MAX_PAYLOAD_CHARS){payloadOverflow++;return -1;}
         var n:int=payloads.length;payloads.push(s);payloadIds[s]=n;payloadChars+=s.length;return n;
      }
      // Fixed-width vectors avoid per-event object/array allocations. NaN is
      // exported as null, with absent/nonfinite semantics documented in schema.
      private function row(kind:int,a:Number=NaN,b:Number=NaN,c:Number=NaN,d:Number=NaN,e:Number=NaN,f:Number=NaN,
         g:Number=NaN,h:Number=NaN,i:Number=NaN,j:Number=NaN,k:Number=NaN,l:Number=NaN,m:Number=NaN,n:Number=NaN,
         o:Number=NaN,p:Number=NaN,q:Number=NaN,r:Number=NaN):void {
         if(used>=MAX_ROWS){dropped++;return;}
         var index:int=used++*WIDTH;
         values[index++]=kind;values[index++]=getTimer();values[index++]=frame;values[index++]=phase;values[index++]=round;values[index++]=render;
         values[index++]=a;values[index++]=b;values[index++]=c;values[index++]=d;values[index++]=e;values[index++]=f;
         values[index++]=g;values[index++]=h;values[index++]=i;values[index++]=j;values[index++]=k;values[index++]=l;
         values[index++]=m;values[index++]=n;values[index++]=o;values[index++]=p;values[index++]=q;values[index]=r;
      }
      public function motion(id:int,op:int,now:int,cursor:Number,offset:Number,stamp:Number,sampledAt:int,
         arrivedAt:int,count:int,delay:Number,interval:int,flags:int,wanted:Number,rate:Number,x:Number,y:Number,latest:Number):void {
         row(1,id,op,now,cursor,offset,stamp,sampledAt,arrivedAt,count,delay,interval,flags,wanted,rate,x,y,latest);
      }
      public function clock(id:int,motionId:int,op:int,now:int,offset:Number,delay:Number,clockAt:Number,detached:Number,cursor:Number,latest:Number,incomingOffset:Number):void {
         row(2,id,motionId,op,now,offset,delay,clockAt,detached,cursor,latest,incomingOffset);
      }
      public function projectileReceive(id:int,owner:int,motionId:int,player:Boolean,source:Number,seq:int,cls:String,
         weapon:String,count:int,first:Number,last:Number,end:Number):void {
         row(3,id,owner,motionId,player?1:0,source,seq,text(cls),text(weapon),count,first,last,end);
      }
      public function projectileTick(id:int,now:int,time:Number,reason:int,first:Number,last:Number,count:int,end:Number,
         x:Number,y:Number,f:int,hasVisual:int,motionId:int,cursor:Number):void {
         row(4,id,now,time,reason,first,last,count,end,x,y,f,hasVisual,motionId,cursor);
      }
      public function tick(now:int,count:int,pauseAt:int):void{row(5,now,count,pauseAt);}
      public function wall(owner:int,op:int,data:String,cost:int,entries:int,words:int,chars:int,detail:int):void {
         var id:int=payload(data),slot:int=id*10;
         cacheEntries=entries;cacheWords=words;cacheChars=chars;
         if(op==1)wallHit++;else if(op==2)wallMiss++;else if(op==3)wallRemember++;else if(op==4)wallEvict++;
         else if(op==5)wallProtect++;else if(op==7)wallReset++;
         else if(op==8){wallDecoded++;wallCost+=cost;wallMax=Math.max(wallMax,cost);}
         else if(op==9){wallProtectedDone++;wallProtectedCost+=cost;wallProtectedMax=Math.max(wallProtectedMax,cost);}
         if(id>=0){if(op>=1 && op<=9)payloadCounts[slot+op-1]++;payloadCounts[slot+9]+=cost;}
         // Decode durations/eviction reasons get bounded rows; hits only update counters.
         if(op==4 || op==8 || op==9)row(7,owner,op,id,data==null?0:data.length,cost,entries,words,chars,detail);
      }
      private function flushWall():void {
         lastWallFlush=getTimer();
         row(6,wallHit,wallMiss,wallRemember,wallEvict,wallProtect,wallReset,wallDecoded,wallProtectedDone,
            wallCost,wallMax,wallProtectedCost,wallProtectedMax,cacheEntries,cacheWords,cacheChars,payloads.length,payloadChars);
      }
      public function codec(op:int,start:int,first:int,middle:int,second:int,end:int,chars:int,bytes:int):void {
         if(op==1)codecPack++;else codecUnpack++;
         codecFirstMs+=middle-first;codecSecondMs+=end-second;
         row(8,op,start,first,middle,second,end,chars,bytes);
      }
      public function finish():void {
         if(finished)return;finished=true;
         if(FlightDiagnostics.sink===this)FlightDiagnostics.sink=null;
         if(started && !hookOccupied) {
            mod.stage.removeEventListener(Event.ENTER_FRAME,enterFirst);mod.stage.removeEventListener(Event.ENTER_FRAME,afterStamp);
            mod.stage.removeEventListener(Event.ENTER_FRAME,afterNative);mod.stage.removeEventListener(Event.ENTER_FRAME,afterWeapon);
            mod.stage.removeEventListener(Event.ENTER_FRAME,afterMirror);mod.stage.removeEventListener(Event.RENDER,renderFirst);
            mod.stage.removeEventListener(Event.RENDER,afterView);mod.stage.removeEventListener(Event.RENDER,renderLast);
         }
         if(timingOwned && mod.game.presentationTiming===timing)mod.game.presentationTiming=previousTiming;
         else if(timingOwned)timingBusy=true;
         flushWall();
         var complete:Boolean=started && !hookOccupied && !timingBusy && dropped==0 && textOverflow==0 && payloadOverflow==0 &&
            FlightDiagnostics.hookErrors==0 && !FlightDiagnostics.identityOverflow && wallMiss==wallDecoded && wallProtect==wallProtectedDone;
         var header:Object={schema:1,role:host?"host":"join",diagnosticOnly:true,performanceQualified:false,
            width:WIDTH,rows:used,capacity:MAX_ROWS,wallIntervalMs:250,texts:texts,payloads:payloads.length,payloadChars:payloadChars,
            dropped:dropped,textOverflow:textOverflow,payloadOverflow:payloadOverflow,hookErrors:FlightDiagnostics.hookErrors,
            identityOverflow:FlightDiagnostics.identityOverflow,timingBusy:timingBusy,hookOccupied:hookOccupied,
            wallMiss:wallMiss,wallDecoded:wallDecoded,wallProtect:wallProtect,wallProtectedDone:wallProtectedDone,
            codecPack:codecPack,codecUnpack:codecUnpack,codecFirstLogMs:codecFirstMs,codecSecondLogMs:codecSecondMs,complete:complete};
         // No synchronous diagnostic log IO has occurred before this point.
         Log.d("FLIGHT DIAG HEADER "+JSON.stringify(header));
         for(var start:int=0;start<used;start+=128) {
            var rows:Array=[];
            for(var at:int=start;at<Math.min(used,start+128);at++) {
               var one:Array=[];for(var col:int=0;col<WIDTH;col++)one.push(values[at*WIDTH+col]);rows.push(one);
            }
            Log.d("FLIGHT DIAG ROWS "+JSON.stringify({from:start,rows:rows}));
         }
         for(var id:int=0;id<payloads.length;id++) {
            var counts:Array=[];for(col=0;col<10;col++)counts.push(payloadCounts[id*10+col]);
            Log.d("FLIGHT DIAG PAYLOAD "+JSON.stringify({id:id,chars:String(payloads[id]).length,data:payloads[id],counts:counts}));
         }
         Log.d("FLIGHT DIAG DONE "+JSON.stringify({complete:complete,rows:used,payloads:payloads.length,round:round,
            diagnosticOnly:true,performanceQualified:false}));
      }
   }
}

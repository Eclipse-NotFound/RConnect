package {
   import flash.events.Event;
   import flash.system.System;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   import rconnect.diagnostics.FlightDiagnostics;

   /** Six MiB fixed numeric buffer; no payload/text table or runtime log writes.
    * Overflow is an incomplete diagnosis, never silent loss or overwritten rows. */
   public final class FlightDiagnosticRecorder {
      private static const WIDTH:int=24,MAX_ROWS:int=32768;
      private var values:Vector.<Number>=new Vector.<Number>(WIDTH*MAX_ROWS,true);
      private var mod:RConnectMod,host:Boolean,started:Boolean=false,finished:Boolean=false,occupied:Boolean=false;
      private var used:int=0,dropped:int=0,round:int=-1,frame:int=0,render:int=0,phase:int=0;
      private var frameCostMs:Number=0,frameCalls:int=0,frameMaxMs:int=0,lastMemory:int=-1000;
      private var exitFirst:int=-1,exitLast:int=-1,exitEarlyCount:int=0,exitLateCount:int=0,exitFirstPhase:int=0;
      private var priorActive:int=0,memoryErrors:int=0;
      public function FlightDiagnosticRecorder(m:RConnectMod,h:Boolean){mod=m;host=h;}
      public function start():void {
         if(started)return;started=true;
         if(FlightDiagnostics.sink!=null){occupied=true;return;}
         FlightDiagnostics.reset();FlightDiagnostics.sink=this;
         mod.stage.addEventListener(Event.ENTER_FRAME,enterFirst,false,2147483647);
         mod.stage.addEventListener(Event.ENTER_FRAME,enterLast,false,-2147483648);
         mod.stage.addEventListener(Event.EXIT_FRAME,exitEarly,false,2147483647);
         mod.stage.addEventListener(Event.EXIT_FRAME,exitLate,false,-2147483648);
         mod.stage.addEventListener(Event.RENDER,renderFirst,false,2147483647);
         mod.stage.addEventListener(Event.RENDER,renderLast,false,-2147483648);
         row(10,0,new Date().time);
      }
      public function caseStart(n:int):void {
         flushExit();round=n;FlightDiagnostics.caseStart();row(10,1,n);
      }
      public function mark(name:String):void {
         var code:int=0;
         switch(name) {
            case "prepare-complete":code=1;break;case "armed":code=2;break;
            case "first-active-enter":code=3;break;case "first-active-render":code=4;break;
            case "native-shot":code=5;break;case "first-visible-render":code=6;break;
            case "native-contact":code=7;break;case "first-contact-render":code=8;break;
            case "native-end":code=9;break;case "source-trace-send":code=10;break;
            case "first-production-flight-received":code=11;break;case "contact-received":code=12;break;
            case "trace-received":code=13;break;case "evaluate":code=14;break;
         }
         row(10,2,code);
      }
      private function measured(start:int):void {
         var elapsed:int=getTimer()-start;frameCalls++;frameCostMs+=elapsed;if(elapsed>frameMaxMs)frameMaxMs=elapsed;
      }
      private function enterFirst(e:Event):void {
         var start:int=getTimer();flushExit();frame++;phase=1;row(9,1);
         if(start-lastMemory>=1000) {
            lastMemory=start;
            try{row(8,System.totalMemoryNumber,System.freeMemory,System.privateMemory);}
            catch(error:*){memoryErrors++;}
         }
         measured(start);
      }
      private function enterLast(e:Event):void {var start:int=getTimer();phase=2;row(9,2);measured(start);}
      private function exitEarly(e:Event):void {
         var start:int=getTimer();if(exitFirst<0){exitFirst=start;exitFirstPhase=phase;}exitEarlyCount++;measured(start);
      }
      private function exitLate(e:Event):void {var start:int=getTimer();exitLast=start;exitLateCount++;measured(start);}
      private function flushExit():void {
         if(exitEarlyCount || exitLateCount)row(7,exitFirst,exitLast,exitEarlyCount,exitLateCount,exitFirstPhase,phase);
         exitFirst=exitLast=-1;exitEarlyCount=exitLateCount=0;
      }
      private function renderFirst(e:Event):void {var start:int=getTimer();render++;phase=3;row(9,3);measured(start);}
      private function renderLast(e:Event):void {var start:int=getTimer();phase=4;row(9,4);measured(start);phase=5;}
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
      public function clock(id:int,motionId:int,op:int,now:int,offset:Number,delay:Number,clockAt:Number,
         detached:Number,cursor:Number,latest:Number,incomingOffset:Number):void {
         row(2,id,motionId,op,now,offset,delay,clockAt,detached,cursor,latest,incomingOffset);
      }
      public function projectileReceive(id:int,owner:int,motionId:int,player:Boolean,source:Number,seq:int,
         count:int,first:Number,last:Number,end:Number):void {row(3,id,owner,motionId,player?1:0,source,seq,count,first,last,end);}
      public function projectileTick(id:int,now:int,time:Number,reason:int,first:Number,last:Number,count:int,end:Number,
         x:Number,y:Number,f:int,hasVisual:int,motionId:int,cursor:Number):void {row(4,id,now,time,reason,first,last,count,end,x,y,f,hasVisual,motionId,cursor);}
      public function tick(now:int,count:int,pauseAt:int):void {
         if(count>0 || priorActive>0)row(5,now,count,pauseAt);priorActive=count;
      }
      public function span(method:int,type:int,start:int,end:int):void {row(6,method,type,start,end,end-start);}
      public function finish():void {
         if(finished)return;finished=true;
         if(FlightDiagnostics.sink===this)FlightDiagnostics.sink=null;
         if(started && !occupied) {
            mod.stage.removeEventListener(Event.ENTER_FRAME,enterFirst);mod.stage.removeEventListener(Event.ENTER_FRAME,enterLast);
            mod.stage.removeEventListener(Event.EXIT_FRAME,exitEarly);mod.stage.removeEventListener(Event.EXIT_FRAME,exitLate);
            mod.stage.removeEventListener(Event.RENDER,renderFirst);mod.stage.removeEventListener(Event.RENDER,renderLast);
         }
         flushExit();
         var complete:Boolean=started && !occupied && dropped==0 && memoryErrors==0 &&
            FlightDiagnostics.hookErrors==0 && !FlightDiagnostics.identityOverflow;
         var header:Object={schema:8,role:host?"host":"join",diagnosticOnly:true,performanceQualified:false,
            width:WIDTH,rows:used,capacity:MAX_ROWS,numericBytes:WIDTH*MAX_ROWS*8,dropped:dropped,
            hookErrors:FlightDiagnostics.hookErrors,identityOverflow:FlightDiagnostics.identityOverflow,occupied:occupied,
            memoryErrors:memoryErrors,memoryIntervalMs:1000,payloads:0,codecDiagnostics:false,complete:complete,
            hookCalls:FlightDiagnostics.hookCalls,hookCostMs:FlightDiagnostics.hookCostMs,hookMaxMs:FlightDiagnostics.hookMaxMs,
            frameCalls:frameCalls,frameCostMs:frameCostMs,frameMaxMs:frameMaxMs};
         var exportAt:int=getTimer();
         Log.d("FLIGHT TIMING08 HEADER "+JSON.stringify(header));
         for(var start:int=0;start<used;start+=128) {
            var rows:Array=[];
            for(var at:int=start;at<Math.min(used,start+128);at++) {
               var one:Array=[];for(var col:int=0;col<WIDTH;col++)one.push(values[at*WIDTH+col]);rows.push(one);
            }
            Log.d("FLIGHT TIMING08 ROWS "+JSON.stringify({from:start,rows:rows}));
         }
         Log.d("FLIGHT TIMING08 DONE "+JSON.stringify({complete:complete,rows:used,round:round,exportMs:getTimer()-exportAt,
            diagnosticOnly:true,performanceQualified:false}));
      }
   }
}

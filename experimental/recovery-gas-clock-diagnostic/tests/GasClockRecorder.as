package {
   import flash.events.Event;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   import rconnect.diagnostics.FlightDiagnostics;

   /** timing08 fixed scalar buffer and deferred export, restricted to gas round 0. */
   public final class GasClockRecorder {
      private static const WIDTH:int=24,MAX_ROWS:int=32768;
      private var values:Vector.<Number>=new Vector.<Number>(WIDTH*MAX_ROWS,true);
      private var host:Boolean,stage:Object,started:Boolean=false,stopped:Boolean=false,exported:Boolean=false,occupied:Boolean=false;
      private var used:int=0,dropped:int=0,frame:int=0,render:int=0,phase:int=0,firstRoundComplete:Boolean=false;
      private var frameCalls:int=0,frameCostMs:Number=0,frameMaxMs:int=0;
      private var stoppedHeader:Object;
      public function GasClockRecorder(isHost:Boolean){host=isHost;}
      public function start():void {
         if(started)return;started=true;
         if(FlightDiagnostics.sink!=null){occupied=true;return;}
         FlightDiagnostics.reset();FlightDiagnostics.sink=this;row(10,0,new Date().time);
      }
      public function attach(s:Object):void {
         if(stage!=null || s==null || stopped || occupied)return;stage=s;
         stage.addEventListener(Event.ENTER_FRAME,enterFirst,false,2147483647);
         stage.addEventListener(Event.ENTER_FRAME,enterLast,false,-2147483648);
         stage.addEventListener(Event.RENDER,renderLast,false,-2147483648);
      }
      private function measured(start:int):void {
         var elapsed:int=getTimer()-start;frameCalls++;frameCostMs+=elapsed;if(elapsed>frameMaxMs)frameMaxMs=elapsed;
      }
      private function enterFirst(e:Event):void {var a:int=getTimer();frame++;phase=1;if(FlightDiagnostics.boundCount>0)row(9,1);measured(a);}
      private function enterLast(e:Event):void {var a:int=getTimer();phase=2;if(FlightDiagnostics.boundCount>0)row(9,2);measured(a);}
      private function renderLast(e:Event):void {var a:int=getTimer();render++;phase=3;if(FlightDiagnostics.boundCount>0)row(9,3);measured(a);}
      private function row(kind:int,a:Number=NaN,b:Number=NaN,c:Number=NaN,d:Number=NaN,e:Number=NaN,f:Number=NaN,
         g:Number=NaN,h:Number=NaN,i:Number=NaN,j:Number=NaN,k:Number=NaN,l:Number=NaN,m:Number=NaN,n:Number=NaN,
         o:Number=NaN,p:Number=NaN,q:Number=NaN,r:Number=NaN):void {
         if(stopped)return;if(used>=MAX_ROWS){dropped++;return;}
         var index:int=used++*WIDTH;
         values[index++]=kind;values[index++]=getTimer();values[index++]=frame;values[index++]=phase;values[index++]=render;values[index++]=0;
         values[index++]=a;values[index++]=b;values[index++]=c;values[index++]=d;values[index++]=e;values[index++]=f;
         values[index++]=g;values[index++]=h;values[index++]=i;values[index++]=j;values[index++]=k;values[index++]=l;
         values[index++]=m;values[index++]=n;values[index++]=o;values[index++]=p;values[index++]=q;values[index]=r;
      }
      public function bind(id:int,peer:int,world:int,loc:int,epoch:int,stamp:Number,now:int,presentation:int,
         hold:int,paused:int,fresh:int,cursor:Number,latest:Number):void {row(2,id,peer,world,loc,epoch,stamp,now,presentation,hold,paused,fresh,cursor,latest);}
      public function motion(id:int,op:int,now:int,cursor:Number,offset:Number,stamp:Number,sampledAt:int,
         arrivedAt:int,count:int,wanted:Number,rate:Number,debt:Number,calibrationRate:Number,calibrating:int,
         latest:Number,branch:int):void {row(1,id,op,now,cursor,offset,stamp,sampledAt,arrivedAt,count,wanted,rate,debt,calibrationRate,calibrating,latest,branch);}
      public function gas(id:int,op:int,eventId:int,now:int,time:Number,cursor:Number,latest:Number,first:Number,
         last:Number,end:Number,visual:int,onStage:int,updated:Number,shownStamp:Number):void {
         row(3,id,op,eventId,now,time,cursor,latest,first,last,end,visual,onStage,updated,shownStamp);}
      public function stop(completed:Boolean=false):void {
         if(stopped)return;firstRoundComplete=completed;row(10,1,completed?1:0);
         stopped=true;if(FlightDiagnostics.sink===this)FlightDiagnostics.sink=null;
         if(stage!=null) {
            stage.removeEventListener(Event.ENTER_FRAME,enterFirst);stage.removeEventListener(Event.ENTER_FRAME,enterLast);
            stage.removeEventListener(Event.RENDER,renderLast);
         }
         stoppedHeader={schema:13,role:host?"host":"join",diagnosticOnly:true,performanceQualified:false,
            width:WIDTH,capacity:MAX_ROWS,rows:used,numericBytes:WIDTH*MAX_ROWS*8,dropped:dropped,
            occupied:occupied,firstRoundComplete:firstRoundComplete,clocks:FlightDiagnostics.boundCount,
            hookErrors:FlightDiagnostics.hookErrors,identityOverflow:FlightDiagnostics.overflow,lateBindings:FlightDiagnostics.lateBindings,
            hookCalls:FlightDiagnostics.hookCalls,hookCostMs:FlightDiagnostics.hookCostMs,hookMaxMs:FlightDiagnostics.hookMaxMs,
            frameCalls:frameCalls,frameCostMs:frameCostMs,frameMaxMs:frameMaxMs,
            complete:started && !occupied && firstRoundComplete && dropped==0 && FlightDiagnostics.hookErrors==0
               && !FlightDiagnostics.overflow && FlightDiagnostics.lateBindings==0 && FlightDiagnostics.boundCount>0};
      }
      public function finish():void {
         if(exported)return;stop(false);exported=true;var begin:int=getTimer();
         Log.d("GAS CLOCK HEADER "+JSON.stringify(stoppedHeader));
         for(var start:int=0;start<used;start+=128) {
            var rows:Array=[];
            for(var at:int=start;at<Math.min(used,start+128);at++) {
               var one:Array=[];for(var col:int=0;col<WIDTH;col++)one.push(values[at*WIDTH+col]);rows.push(one);
            }
            Log.d("GAS CLOCK ROWS "+JSON.stringify({from:start,rows:rows}));
         }
         Log.d("GAS CLOCK DONE "+JSON.stringify({rows:used,complete:stoppedHeader.complete,exportMs:getTimer()-begin,
            diagnosticOnly:true,performanceQualified:false}));
      }
   }
}

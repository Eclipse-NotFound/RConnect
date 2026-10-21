package rconnect.diagnostics {
   import flash.display.DisplayObject;
   import flash.utils.Dictionary;
   import flash.utils.getTimer;
   import rconnect.game.RemoteMotion;

   /** Derived from timing08's nullable sink and measured fixed-scalar calls.
    * At most two actual actor clocks; no invocation advances a game clock. */
   public final class FlightDiagnostics {
      public static var sink:Object=null,hookErrors:int=0,hookCalls:int=0,hookCostMs:Number=0,hookMaxMs:int=0;
      public static var overflow:Boolean=false,lateBindings:int=0,boundCount:int=0;
      private static var clocks:Dictionary=new Dictionary(true),identities:Dictionary=new Dictionary(true);
      private static var nextIdentity:int=1,firstGas:Object,gasShown:Boolean=false,gasEnded:Boolean=false;
      public static function reset():void {
         clocks=new Dictionary(true);identities=new Dictionary(true);nextIdentity=1;firstGas=null;
         gasShown=gasEnded=overflow=false;hookErrors=hookCalls=hookMaxMs=lateBindings=boundCount=0;hookCostMs=0;
      }
      public static function watches(o:Object):Boolean{return clocks[o]!=null;}
      private static function identity(o:Object):int {
         if(o==null)return 0;var old:*=identities[o];if(old!==undefined)return int(old);
         if(nextIdentity>16){overflow=true;return 0;}identities[o]=nextIdentity;return nextIdentity++;
      }
      private static function cost(start:int):void {
         var elapsed:int=getTimer()-start;hookCalls++;hookCostMs+=elapsed;if(elapsed>hookMaxMs)hookMaxMs=elapsed;
      }
      public static function bind(m:RemoteMotion,w:Object,loc:Object,peer:int,epoch:int,stamp:Number,
         now:int,presentation:int,hold:Boolean,paused:Boolean):void {
         if(sink==null || m==null)return;var start:int=getTimer();
         try {
            var r:Object=clocks[m],fresh:Boolean=r==null;
            if(fresh) {
               if(boundCount>=2){overflow=true;return;}
               if(isFinite(m.sourceTime) || m.currentSample!=null)lateBindings++;
               r={id:++boundCount};clocks[m]=r;
            }
            if(fresh || r.w!==w || r.loc!==loc || r.epoch!=epoch || r.hold!==hold || r.paused!==paused) {
               sink.bind(r.id,peer,identity(w),identity(loc),epoch,stamp,now,presentation,hold?1:0,paused?1:0,
                  fresh?1:0,m.sourceTime,m.latestSampleTime);
               r.w=w;r.loc=loc;r.epoch=epoch;r.hold=hold;r.paused=paused;
            }
         } catch(error:*){hookErrors++;}finally{cost(start);}
      }
      public static function motion(m:RemoteMotion,op:int,now:int,cursor:Number,offset:Number,stamp:Number,
         sampledAt:int,arrivedAt:int,count:int,wanted:Number,rate:Number,debt:Number,calibrationRate:Number,
         calibrating:Boolean,latest:Number,branch:int):void {
         if(sink==null || clocks[m]==null)return;var start:int=getTimer();
         try{sink.motion(clocks[m].id,op,now,cursor,offset,stamp,sampledAt,arrivedAt,count,wanted,rate,debt,
            calibrationRate,calibrating?1:0,latest,branch);}catch(error:*){hookErrors++;}finally{cost(start);}
      }
      public static function gas(a:Object,op:int,now:int,time:Number):void {
         if(sink==null || a==null || clocks[a.motion]==null)return;
         if(a.s.cls!="visualGas" && a.s.cls!="visualPinkGas")return;
         if(firstGas==null && op==1)firstGas=a;if(a!==firstGas)return;
         if(op==2 && gasShown || op==3 && gasEnded)return;
         var start:int=getTimer();
         try {
            var frames:Array=a.s.frames as Array,v:DisplayObject=a.vis as DisplayObject;
            sink.gas(clocks[a.motion].id,op,int(a.id),now,time,a.motion.sourceTime,a.motion.latestSampleTime,
               frames.length?Number(frames[0].at):NaN,frames.length?Number(frames[frames.length-1].at):NaN,
               Number(a.s.end),v==null?0:1,v!=null && v.stage!=null?1:0,Number(a.updated),
               a.shown==null?NaN:Number(a.shown.at));
            if(op==2)gasShown=true;if(op==3)gasEnded=true;
         }catch(error:*){hookErrors++;}finally{cost(start);}
      }
   }
}

package rconnect.diagnostics {
   import flash.display.DisplayObject;
   import flash.display.MovieClip;
   import flash.utils.Dictionary;
   import flash.utils.getTimer;
   import rconnect.game.RemoteMotion;

   /** Isolated scalar-only observation. Return values never enter gameplay. */
   public final class FlightDiagnostics {
      public static var sink:Object=null,hookErrors:int=0,identityOverflow:Boolean=false;
      public static var hookCalls:int=0,hookCostMs:Number=0,hookMaxMs:int=0;
      private static var identities:Dictionary=new Dictionary(true),watched:Dictionary=new Dictionary(true);
      private static var nextId:int=1;
      public static function reset():void {
         identities=new Dictionary(true);watched=new Dictionary(true);nextId=1;
         hookErrors=hookCalls=hookMaxMs=0;hookCostMs=0;identityOverflow=false;
      }
      public static function caseStart():void {watched=new Dictionary(true);}
      public static function watches(o:Object):Boolean {return watched[o]===true;}
      private static function id(o:Object):int {
         if(o==null)return 0;var prior:*=identities[o];if(prior!==undefined)return int(prior);
         if(nextId>4096){identityOverflow=true;return 0;}identities[o]=nextId;return nextId++;
      }
      private static function cost(start:int):void {
         var elapsed:int=getTimer()-start;hookCalls++;hookCostMs+=elapsed;if(elapsed>hookMaxMs)hookMaxMs=elapsed;
      }
      public static function messageType(msg:Object):int {
         if(msg==null)return 0;
         var type:String="";
         try{type=String(msg.type);}catch(error:*){hookErrors++;return 0;}
         switch(type) {
            case "worldstate":return 1;case "playerstate":return 2;case "unitsync":return 3;
            case "worldsync":return 4;case "ping":return 5;case "pong":return 6;
            default:return 0;
         }
         return 0;
      }
      public static function span(method:int,type:int,start:int,end:int):void {
         if(sink==null)return;var at:int=getTimer();
         try{sink.span(method,type,start,end);}catch(error:*){hookErrors++;}finally{cost(at);}
      }
      public static function motion(o:Object,op:int,now:int,cursor:Number,offset:Number,stamp:Number,
         sampledAt:int,arrivedAt:int,count:int,delay:Number,interval:int,flags:int,wanted:Number,rate:Number,x:Number,y:Number,latest:Number):void {
         if(sink==null || watched[o]!==true)return;var at:int=getTimer();
         try{sink.motion(id(o),op,now,cursor,offset,stamp,sampledAt,arrivedAt,count,delay,interval,flags,wanted,rate,x,y,latest);}
         catch(error:*){hookErrors++;}finally{cost(at);}
      }
      public static function clock(state:Object,motion:RemoteMotion,op:int,now:int,offset:Number,delay:Number,
         clockAt:Number,detached:Number,incomingOffset:Number=NaN):void {
         if(sink==null)return;var at:int=getTimer();
         try {
            if(motion!=null)watched[motion]=true;
            sink.clock(id(state),id(motion),op,now,offset,delay,clockAt,detached,
               motion==null?NaN:motion.sourceTime,motion==null?NaN:motion.latestSampleTime,incomingOffset);
         }catch(error:*){hookErrors++;}finally{cost(at);}
      }
      public static function projectileReceive(state:Object,owner:Object,motion:RemoteMotion,player:Boolean,
         source:Number,seq:int,cls:String,weapon:String,list:Array,end:Number):void {
         if(sink==null)return;var at:int=getTimer();
         try {
            if(motion!=null)watched[motion]=true;
            sink.projectileReceive(id(state),id(owner),id(motion),player,source,seq,
               list==null?0:list.length,list==null||list.length==0?NaN:Number(list[0].at),
               list==null||list.length==0?NaN:Number(list[list.length-1].at),end);
         }catch(error:*){hookErrors++;}finally{cost(at);}
      }
      public static function projectileTick(state:Object,now:int,time:Number,reason:int,list:Array,end:Number):void {
         if(sink==null)return;var at:int=getTimer();
         try {
            var v:DisplayObject=state.vis as DisplayObject;
            sink.projectileTick(id(state),now,time,reason,list==null||list.length==0?NaN:Number(list[0].at),
               list==null||list.length==0?NaN:Number(list[list.length-1].at),list==null?0:list.length,end,
               v==null?NaN:v.x,v==null?NaN:v.y,v is MovieClip?MovieClip(v).currentFrame:1,
               v==null?0:1,id(state.motion),state.motion==null?NaN:state.motion.sourceTime);
         }catch(error:*){hookErrors++;}finally{cost(at);}
      }
      public static function tick(now:int,count:int,pauseAt:int):void {
         if(sink==null)return;var at:int=getTimer();
         try{sink.tick(now,count,pauseAt);}catch(error:*){hookErrors++;}finally{cost(at);}
      }
   }
}

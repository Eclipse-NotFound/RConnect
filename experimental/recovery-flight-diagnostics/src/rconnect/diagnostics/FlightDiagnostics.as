package rconnect.diagnostics {
   import flash.display.DisplayObject;
   import flash.display.MovieClip;
   import flash.utils.Dictionary;
   import rconnect.game.RemoteMotion;

   /** Isolated diagnostic overlay only. Null in normal construction.
    * Hooks receive scalars / immutable text; no callback return enters gameplay.
    * No sampling, seeking, display mutation, JSON or disk IO in this helper. */
   public final class FlightDiagnostics {
      public static var sink:Object=null;
      public static var hookErrors:int=0;
      public static var identityOverflow:Boolean=false;
      private static var identities:Dictionary=new Dictionary(true);
      private static var nextIdentity:int=1;
      public static function reset():void {
         identities=new Dictionary(true);nextIdentity=1;hookErrors=0;identityOverflow=false;
      }
      private static function id(o:Object):int {
         if(o==null)return 0;
         var existing:*=identities[o];if(existing!==undefined)return int(existing);
         if(nextIdentity>8192){identityOverflow=true;return 0;}
         identities[o]=nextIdentity;return nextIdentity++;
      }
      public static function motion(o:Object,op:int,now:int,cursor:Number,offset:Number,stamp:Number,
         sampledAt:int,arrivedAt:int,count:int,delay:Number,interval:int,flags:int,wanted:Number,rate:Number,x:Number,y:Number,latest:Number):void {
         if(sink==null)return;
         try{sink.motion(id(o),op,now,cursor,offset,stamp,sampledAt,arrivedAt,count,delay,interval,flags,wanted,rate,x,y,latest);}
         catch(error:*){hookErrors++;}
      }
      public static function clock(state:Object,motion:RemoteMotion,op:int,now:int,offset:Number,delay:Number,clockAt:Number,detached:Number,incomingOffset:Number=NaN):void {
         if(sink==null)return;
         try{sink.clock(id(state),id(motion),op,now,offset,delay,clockAt,detached,
            motion==null?NaN:motion.sourceTime,motion==null?NaN:motion.latestSampleTime,incomingOffset);}
         catch(error:*){hookErrors++;}
      }
      public static function projectileReceive(state:Object,owner:Object,motion:RemoteMotion,player:Boolean,
         source:Number,seq:int,cls:String,weapon:String,list:Array,end:Number):void {
         if(sink==null)return;
         try{sink.projectileReceive(id(state),id(owner),id(motion),player,source,seq,cls,weapon,
            list==null?0:list.length,list==null||list.length==0?NaN:Number(list[0].at),
            list==null||list.length==0?NaN:Number(list[list.length-1].at),end);}
         catch(error:*){hookErrors++;}
      }
      public static function projectileTick(state:Object,now:int,time:Number,reason:int,list:Array,end:Number):void {
         if(sink==null)return;
         try {
            var v:DisplayObject=state.vis as DisplayObject;
            sink.projectileTick(id(state),now,time,reason,list==null?NaN:list.length==0?NaN:Number(list[0].at),
               list==null||list.length==0?NaN:Number(list[list.length-1].at),list==null?0:list.length,end,
               v==null?NaN:v.x,v==null?NaN:v.y,v is MovieClip?MovieClip(v).currentFrame:1,
               v==null?0:1,id(state.motion),state.motion==null?NaN:state.motion.sourceTime);
         }catch(error:*){hookErrors++;}
      }
      public static function tick(now:int,count:int,pauseAt:int):void {
         if(sink==null)return;
         try{sink.tick(now,count,pauseAt);}catch(error:*){hookErrors++;}
      }
      public static function wall(owner:Object,op:int,data:String,cost:int,entries:int,words:int,chars:int,detail:int):void {
         if(sink==null)return;
         try{sink.wall(id(owner),op,data,cost,entries,words,chars,detail);}catch(error:*){hookErrors++;}
      }
      public static function codec(op:int,start:int,first:int,middle:int,second:int,end:int,chars:int,bytes:int):void {
         if(sink==null)return;
         try{sink.codec(op,start,first,middle,second,end,chars,bytes);}catch(error:*){hookErrors++;}
      }
   }
}

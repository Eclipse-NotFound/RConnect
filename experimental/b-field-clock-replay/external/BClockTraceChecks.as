package {
   import flash.display.Stage;
   /** Optional helper-only checks. No real Link/Replica/world is used, and no
    * stage event is dispatched. All temporary listeners stop synchronously.
    */
   public final class BClockTraceChecks {
      private static function frame(id:int):Object {
         return {tick:id,time:id*33,room:"room",pauseEpoch:0,paused:false,
            players:[{epoch:1,roomEpoch:2},{epoch:3,roomEpoch:4}],
            timeControl:{phase:"idle",cycle:1},scene:{terrainRevision:id},
            projectiles:[],projectileEvents:[]};
      }
      private static function fixture():Object {
         var m:Object={role:"join",sessionId:"clock-helper-check",welcomed:true,link:{},
            test:{messages:0,confirms:0,messageThis:true,confirmThis:true,argument:null},
            replica:{frames:0,lastFrame:null,clock:{position:0,delay:65,queued:0,underflows:0,fraction:0,current:null,next:null}}};
         m.replica.confirmed=function(f:Object):void {
            ++m.test.confirms;m.test.confirmThis=m.test.confirmThis && this===m.replica;
         };
         m.link.message=function(value:Object):void {
            ++m.test.messages;m.test.argument=value;m.test.messageThis=m.test.messageThis && this===m.link;
            if(value.failure!=null)throw value.failure;
            if(value.type!="frame")return;
            ++m.replica.frames;m.replica.lastFrame=value.full;
            var c:Object=m.replica.clock;c.current=value.full;c.position=value.full.time;
            c.queued=0;c.next=null;++c.underflows;
            m.replica.confirmed(value.full);
         };
         return m;
      }
      public static function run(stage:Stage,check:Function):void {
         var m:Object=fixture(),original:Function=m.link.message,confirmed:Function=m.replica.confirmed;
         var trace:BClockTrace=new BClockTrace(m,stage),packet:Object={type:"frame",session:m.sessionId,serial:1,base:0,full:frame(1)};
         try {
            trace.start("helper-check");m.link.message(packet);
            var chat:Object={type:"chat",text:"same argument"};m.link.message(chat);
            trace.stop("helper-check complete");
            var result:Object=trace.data(),arrival:Object=result.rows[0],completion:Object=result.rows[1];
            check(m.test.messages==2 && m.test.argument===chat && m.test.messageThis,
               "clock observer forwards each original message once with the original receiver");
            check(m.test.confirms==1 && m.test.confirmThis && m.replica.frames==1,
               "clock observer neither repeats apply nor suppresses the old confirmed callback");
            check(arrival.kind=="arrival" && arrival.accepted && arrival.acceptedCount==1 && arrival.queueAccounting &&
               arrival.frame.time==33 && completion.kind=="confirmed" && completion.arrivalSeq===arrival.seq &&
               arrival.forwardAt<=completion.at && completion.at<=arrival.returnAt,
               "clock observer records decoded frame and boundary confirmation within delivery bracket");
            packet.full.players[0].epoch=99;packet.full.time=777;
            check(arrival.frame.players[0].epoch==1 && arrival.frame.time==33 && completion.frame.time==33,
               "clock observer retains scalar metadata without mutable source references");
            check(m.link.message===original && m.replica.confirmed===confirmed && result.header.completeHistory &&
               result.footer.restoredMessage && result.footer.restoredConfirmed && result.footer.faults==0,
               "clock observer restores its own hooks and reports complete initial history");
         }finally {trace.stop("helper-check cleanup");}

         m=fixture();trace=new BClockTrace(m,stage);var failure:Error=new Error("Original receive failed"),caught:*=null;
         try {
            trace.start("helper-error-check");
            try{m.link.message({type:"frame",serial:1,base:0,session:m.sessionId,failure:failure});}
            catch(error:*){caught=error;}
            trace.stop("helper-error complete");result=trace.data();
            check(caught===failure && m.test.messages==1 && result.rows[0].complete && !result.rows[0].accepted,
               "clock observer preserves the original receive exception without a retry");
         }finally {trace.stop("helper-error cleanup");}

         m=fixture();trace=new BClockTrace(m,stage,20);
         try {
            trace.start("helper-cap-check");
            for(var i:int=0;i<40;i++)m.link.message({type:"frame",serial:i+1,base:i,session:m.sessionId,full:frame(i)});
            trace.stop("helper-cap complete");result=trace.data();
            check(result.footer.lines<=20 && result.footer.truncated && !trace.running && m.test.messages==40 && m.test.confirms==40,
               "clock observer stops collecting at the row limit while every original callback still runs");
         }finally {trace.stop("helper-cap cleanup");}

         m=fixture();trace=new BClockTrace(m,stage);var replacement:Function=function(value:Object):void {};
         try {
            trace.start("helper-owner-check");m.link.message=replacement;m.replica.confirmed=replacement;
            trace.stop("new owner installed");result=trace.data();
            check(m.link.message===replacement && m.replica.confirmed===replacement &&
               !result.footer.restoredMessage && !result.footer.restoredConfirmed,
               "clock observer never overwrites a later callback owner during cleanup");
         }finally {trace.stop("helper-owner cleanup");}
      }
   }
}

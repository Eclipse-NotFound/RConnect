package {
   import flash.events.ProgressEvent;
   import flash.net.Socket;
   import flash.utils.Dictionary;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;

   /** External dispatch brackets only. Never reads bytes, sends, or changes a packet. */
   public class SocketBatchProbe {
      private static const HIGH:int=1000000,LOW:int=-1000000;
      private static const KEEP:int=16,ROWS:int=64,CELLS:int=1200,UNITS:int=512,PLAYERS:int=16;
      private var context:Function,role:String,links:Dictionary=new Dictionary(),sockets:Dictionary=new Dictionary();
      private var watched:Array=[],phases:Object={},longest:Array=[];
      private var serial:int=0,open:int=0,requested:Boolean=false,finished:Boolean=false;
      private var orphanMessages:int=0,missingEnd:int=0,nestedData:int=0,nestedMessage:int=0;
      private var faults:int=0,attachFailures:int=0,metadataTruncated:int=0,rowsDropped:int=0;

      public function SocketBatchProbe(role:String,context:Function) {this.role=role;this.context=context;}
      public function watch(link:TcpLink):void {
         if(link==null || finished || requested || links[link]!=null)return;
         var socket:Socket=Object(link).socket as Socket;
         if(socket==null){attachFailures++;return;}
         var state:Object={link:link,socket:socket,index:watched.length,attachedAt:getTimer(),batch:null,message:null};
         if(watched.length>=4){attachFailures++;return;}
         links[link]=state;sockets[socket]=state;watched.push(state);
         socket.addEventListener(ProgressEvent.SOCKET_DATA,dataBegin,false,HIGH);
         socket.addEventListener(ProgressEvent.SOCKET_DATA,dataEnd,false,LOW);
         link.addEventListener(TcpLink.MESSAGE,messageBegin,false,HIGH);
         link.addEventListener(TcpLink.MESSAGE,messageEnd,false,LOW);
      }
      private function where():Object {
         var c:Object=context();
         return {phase:String(c.phase),density:int(c.density),frame:int(c.frame)};
      }
      private function bucket(c:Object):String {return c.phase=="load" && c.density>=0 && c.density<=6?"load"+c.density:"outside";}
      private function typeOf(p:Object):String {
         if(p==null)return "other";
         var t:String=String(p.type);
         switch(t) {
            case "unitsync":case "worldstate":case "playerstate":case "terrain":case "terrain-ack":
            case "damage":case "playerdmg":case "objs":case "loot":case "loot-ack":case "exploration":
            case "room":case "combat-network-test":case "hello":case "welcome":case "chat":case "goodbye":
            case "projectile-grip":case "security-terminals":case "peer-grip":case "unit-grip":case "player-mines":
            case "coop-pause":case "friendly-fire":return t;
         }return "other";
      }
      private function count(map:Object,key:String,n:Number=1):void {map[key]=Number(map[key]||0)+n;}
      private function hist(map:Object,n:Number):void {
         var k:String=n<=0?"0":n<=1?"1":n<=2?"2":n<=5?"5":n<=10?"10":n<=20?"20":n<=50?"50":n<=100?"100":n<=200?"200":n<=500?"500":">500";
         count(map,k);
      }
      private function stats(c:Object):Object {
         var k:String=bucket(c),s:Object=phases[k];
         if(s==null)phases[k]=s={batches:0,messages:0,full:0,fast:0,dispatchMs:0,batchMs:0,maxMs:0,
            preObserveMs:0,postObserveMs:0,metadataMs:0,phaseCrossings:0,types:{},batchMsHistogram:{},
            messageCountHistogram:{},fullPerBatchHistogram:{},fastPerBatchHistogram:{},
            fullStats:volume(),fastStats:volume()};
         return s;
      }
      private function volume():Object {return {packets:0,units:0,wallCells:0,wallChars:0,stampCount:0,
         tickMin:null,tickMax:null,sampleMin:null,sampleMax:null,lastTick:null,lastSample:null,
         tickStepHistogram:{},sampleStepHistogram:{},tickReversed:0,sampleReversed:0};}
      private function range(r:Object,key:String,value:*):void {
         if(value==null || !isFinite(Number(value)))return;
         var n:Number=Number(value);
         if(r[key+"Min"]==null || n<r[key+"Min"])r[key+"Min"]=n;
         if(r[key+"Max"]==null || n>r[key+"Max"])r[key+"Max"]=n;
      }
      private function stamp(r:Object,value:*):void {
         if(value==null || !isFinite(Number(value)))return;
         range(r,"sample",value);r.stampCount++;
      }
      private function metadata(p:Object,t:String):Object {
         var r:Object={type:t,kind:t=="unitsync"?"full":t=="worldstate"?"fast":"other",tick:null,
            units:0,wallCells:0,wallChars:0,stampCount:0,sampleMin:null,sampleMax:null,truncated:false};
         if(p==null)return r;
         if(p.tick!=null && isFinite(Number(p.tick)))r.tick=Number(p.tick);
         stamp(r,p.sampleTime);
         // Exact existing packet fields. Source times are NOT wire-send timestamps.
         var a:Array=t=="unitsync"?p.units as Array:t=="worldstate"?p.enemyMotion as Array:null;
         var i:int,n:int;
         if(a!=null) {
            r.units=a.length;n=Math.min(a.length,UNITS);if(n<a.length)r.truncated=true;
            for(i=0;i<n;i++)if(a[i]!=null)stamp(r,a[i].sampleTime);
         }
         if(p.snap!=null)stamp(r,p.snap.sampleTime);
         a=p.players as Array;
         if(a!=null) {
            n=Math.min(a.length,PLAYERS);if(n<a.length)r.truncated=true;
            for(i=0;i<n;i++)if(a[i]!=null && a[i].snap!=null)stamp(r,a[i].snap.sampleTime);
         }
         a=p.wallPaint as Array;
         if(a!=null) {
            r.wallCells=a.length;n=Math.min(a.length,CELLS);if(n<a.length)r.truncated=true;
            for(i=0;i<n;i++)if(a[i]!=null && a[i].d is String)r.wallChars+=(a[i].d as String).length;
         }
         if(r.truncated)metadataTruncated++;
         return r;
      }
      private function accumulate(v:Object,r:Object):void {
         v.packets++;v.units+=r.units;v.wallCells+=r.wallCells;v.wallChars+=r.wallChars;v.stampCount+=r.stampCount;
         range(v,"tick",r.tick);range(v,"sample",r.sampleMin);range(v,"sample",r.sampleMax);
         if(r.tick!=null) {
            if(v.lastTick!=null){var dt:Number=r.tick-v.lastTick;if(dt<0)v.tickReversed++;else hist(v.tickStepHistogram,dt);}
            v.lastTick=r.tick;
         }
         if(r.sampleMax!=null) {
            if(v.lastSample!=null){var ds:Number=r.sampleMax-v.lastSample;if(ds<0)v.sampleReversed++;else hist(v.sampleStepHistogram,ds);}
            v.lastSample=r.sampleMax;
         }
      }
      private function dataBegin(e:ProgressEvent):void {
         if(finished)return;
         var started:int=getTimer();
         try {
            var s:Object=sockets[e.currentTarget];if(s==null){faults++;return;}
            if(s.batch!=null){nestedData++;missingEnd++;s.batch=null;s.message=null;open--;}
            var c:Object=where(),b:Object={id:++serial,link:s.index,start:started,beginReturnedAt:0,stop:null,
               startContext:c,endContext:null,bytesAvailable:s.socket.bytesAvailable,messages:0,full:0,fast:0,
               types:{},rows:[],rowsDropped:0,dispatchMs:0,metadataMs:0,preObserveMs:0,postObserveMs:0,
               fullStats:volume(),fastStats:volume()};
            s.batch=b;open++;b.beginReturnedAt=getTimer();b.preObserveMs=b.beginReturnedAt-started;
         }catch(error:*){faults++;}
      }
      private function messageBegin(e:NetMessageEvent):void {
         if(finished)return;
         var at:int=getTimer();
         try {
            var s:Object=links[e.currentTarget];if(s==null || s.batch==null){orphanMessages++;return;}
            if(s.message!=null){nestedMessage++;s.message=null;}
            var b:Object=s.batch,r:Object=metadata(e.data,typeOf(e.data));
            r.at=at;r.dispatchStart=getTimer();r.stop=null;r.metadataMs=r.dispatchStart-at;
            b.messages++;count(b.types,r.type);
            if(r.kind=="full"){b.full++;accumulate(b.fullStats,r);}
            if(r.kind=="fast"){b.fast++;accumulate(b.fastStats,r);}
            var aggregate:Object=stats(b.startContext);
            if(r.kind=="full")accumulate(aggregate.fullStats,r);
            if(r.kind=="fast")accumulate(aggregate.fastStats,r);
            if(b.rows.length<ROWS)b.rows.push(r);else {b.rowsDropped++;rowsDropped++;}
            // Mark immediately before returning to native dispatch; no packet is retained.
            r.dispatchStart=getTimer();r.metadataMs=r.dispatchStart-at;b.metadataMs+=r.metadataMs;s.message=r;
         }catch(error:*){faults++;}
      }
      private function messageEnd(e:NetMessageEvent):void {
         var stop:int=getTimer();if(finished)return;
         try {
            var s:Object=links[e.currentTarget];if(s==null || s.batch==null || s.message==null)return;
            var r:Object=s.message;r.stop=stop;r.dispatchMs=stop-r.dispatchStart;
            s.batch.dispatchMs+=r.dispatchMs;s.message=null;s.batch.postObserveMs+=getTimer()-stop;
         }catch(error:*){faults++;}
      }
      private function dataEnd(e:ProgressEvent):void {
         var stop:int=getTimer();if(finished)return;
         try {
            var s:Object=sockets[e.currentTarget];if(s==null || s.batch==null){missingEnd++;return;}
            var b:Object=s.batch;b.stop=stop;b.duration=stop-b.start;b.endContext=where();
            if(s.message!=null){missingEnd++;s.message=null;}
            s.batch=null;open--;
            var a:Object=stats(b.startContext);a.batches++;a.messages+=b.messages;a.full+=b.full;a.fast+=b.fast;
            a.dispatchMs+=b.dispatchMs;a.batchMs+=b.duration;a.maxMs=Math.max(a.maxMs,b.duration);
            a.preObserveMs+=b.preObserveMs;a.metadataMs+=b.metadataMs;
            if(bucket(b.startContext)!=bucket(b.endContext))a.phaseCrossings++;
            for(var k:String in b.types)count(a.types,k,b.types[k]);
            hist(a.batchMsHistogram,b.duration);hist(a.messageCountHistogram,b.messages);
            hist(a.fullPerBatchHistogram,b.full);hist(a.fastPerBatchHistogram,b.fast);
            if(bucket(b.startContext)!="outside") {
               longest.push(b);longest.sortOn("duration",Array.NUMERIC|Array.DESCENDING);if(longest.length>KEEP)longest.pop();
            }
            b.postObserveMs+=getTimer()-stop;a.postObserveMs+=b.postObserveMs;
         }catch(error:*){faults++;}
         if(requested && open==0)emit();
      }
      public function finish():void {
         if(finished)return;requested=true;
         // finish() can run inside Session/test MESSAGE listeners. Let DATA-low close first.
         if(open==0)emit();
      }
      private function emit():void {
         if(finished)return;finished=true;
         var attachment:Array=[];
         for each(var s:Object in watched) {
            attachment.push({link:s.index,attachedAt:s.attachedAt,socketUnchanged:Object(s.link).socket===s.socket});
            s.socket.removeEventListener(ProgressEvent.SOCKET_DATA,dataBegin);
            s.socket.removeEventListener(ProgressEvent.SOCKET_DATA,dataEnd);
            s.link.removeEventListener(TcpLink.MESSAGE,messageBegin);
            s.link.removeEventListener(TcpLink.MESSAGE,messageEnd);
         }
         Log.d("SOCKET BATCH PROFILE "+JSON.stringify({role:role,diagnosticOnly:true,performanceQualified:false,
            wireSendTimeAvailable:false,sourceTimeMeaning:"existing sampleTime and tick; no remote clock alignment",
            bracket:"Socket DATA high to low; MESSAGE high to low encloses synchronous listeners, not proof of accepted state",
            phases:phases,longest:longest,attachments:attachment,batches:serial,open:open,
            orphanMessages:orphanMessages,missingEnd:missingEnd,nestedData:nestedData,nestedMessage:nestedMessage,
            faults:faults,attachFailures:attachFailures,metadataTruncated:metadataTruncated,rowsDropped:rowsDropped}));
      }
   }
}

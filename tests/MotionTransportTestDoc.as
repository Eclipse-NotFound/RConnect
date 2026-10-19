package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.utils.ByteArray;
   import flash.utils.getTimer;
   import flash.utils.setTimeout;
   import rconnect.net.HostServer;
   import rconnect.net.BeforeHostServer;
   import rconnect.net.TcpLink;
   import rconnect.net.BinaryMessageCodec;
   import rconnect.net.Protocol;

   /** Exact old/new broadcast classes, without loading the game or saves.
    * Synthetic stress payload: timing is not an in-game FPS measurement. */
   public class MotionTransportTestDoc extends Sprite {
      private var checks:Array=[],failures:int=0,metrics:Array=[];
      public function MotionTransportTestDoc() {setTimeout(run,100);}
      private function check(ok:Boolean,name:String):void {
         checks.push({pass:ok,name:name});if(!ok)failures++;
      }
      private function same(a:*,b:*):Boolean {
         if(a===b)return true;
         if(a==null || b==null || typeof a!=typeof b || (a is Array)!=(b is Array))return false;
         if(typeof a!="object")return false;
         if(a is Array && a.length!=b.length)return false;
         var key:String,n:int=0,m:int=0;
         for(key in a){n++;if(!b.hasOwnProperty(key)||!same(a[key],b[key]))return false;}
         for(key in b)m++;return n==m;
      }
      private function visibleTo(packet:Object,id:int):Object {
         // Session.handleMessage forwards these fields; applyWorldState skips
         // the local id before reading snap. Everything else stays observable.
         var result:Object={},players:Array=[];
         for(var key:String in packet)result[key]=packet[key];
         for each(var p:Object in packet.players)if(int(p.id)!=id)players.push(p);
         result.players=players;return result;
      }
      private function packet(shots:int):Object {
         var players:Array=[];
         for(var id:int=0;id<3;id++) {
            var events:Array=[];
            for(var shot:int=0;shot<shots;shot++) {
               var frames:Array=[];
               for(var f:int=0;f<24;f++)frames.push({at:1000+f*33,x:shot*13+f*8.25,y:50+id,
                  rot:f*.3,sx:1,sy:1,a:.75,f:1,ls:1,lf:1});
               events.push({seq:shot+1,at:1000,flight:{cls:"visbul",frames:frames,end:0}});
            }
            players.push({id:id,name:"玩家"+id,extension:{kept:true},snap:{x:id*100,y:200,
               sampleTime:1800,weapons:[{id:"lmg",stream:1,slot:0,events:events}],hp:99.5}});
         }
         return {type:Protocol.MSG_WORLDSTATE,proto:1,tick:37,roomKey:"0,4",roomEpoch:3,
            players:players,enemyMotion:[{k:"U1",x:3.75,y:20}],lootMotion:[{k:"L1",x:1.5,y:2}],
            wallPaint:[{k:"1,1",value:123}],extra:{a:[1,2,3]}};
      }
      private function run():void {
         var old:BeforeHostServer=new BeforeHostServer(),next:HostServer=new HostServer();
         try {
            var a:CaptureLink=new CaptureLink(1),b:CaptureLink=new CaptureLink(2),unknown:CaptureLink=new CaptureLink(-1);
            next.clients=[a,b,unknown];
            check(next.hasObserverOtherThan(a),"another authenticated guest gets immediate relay");
            b.isOpen=false;check(!next.hasObserverOtherThan(a),"closed and unassigned observers do not request relay");
            b.isOpen=true;next.clients=[a];
            check(!next.hasObserverOtherThan(a),"one guest does not trigger a redundant world capture on upload");
            next.clients=[a,b,unknown];
            var input:Object=packet(2),original:String=JSON.stringify(input);
            next.broadcast(input);
            check(JSON.stringify(input)==original,"broadcast leaves the source tree unchanged");
            check(a.last.players[1].snap==null && b.last.players[2].snap==null,"each recipient omits only its own snapshot");
            check(same(visibleTo(input,1),visibleTo(a.last,1)),"peer 1 receives all consumed fields unchanged");
            check(same(visibleTo(input,2),visibleTo(b.last,2)),"peer 2 receives all consumed fields unchanged");
            check(same(input,unknown.last),"unassigned connection retains the complete message");
            check(a.last.players.length==3 && a.last.players[1].name==input.players[1].name
               && same(a.last.players[1].extension,input.players[1].extension),"roster and unknown entry metadata survive");
            check(a.last.players[0].snap===input.players[0].snap && a.last.enemyMotion===input.enemyMotion,
               "projection copies envelopes only");
            for each(var receiver:CaptureLink in [a,b]) {
               var binary:Object=BinaryMessageCodec.unpack(BinaryMessageCodec.pack(receiver.last));
               var json:Object=Protocol.decode(Protocol.encode(receiver.last));
               check(same(binary,json),"binary and JSON fallback agree for peer "+receiver.id);
               check(same(visibleTo(Protocol.decode(Protocol.encode(input)),receiver.id),visibleTo(binary,receiver.id)),
                  "decoded observation matches old full broadcast for peer "+receiver.id);
            }
            var oldCount:int=a.count;next.broadcast(input,a);
            check(a.count==oldCount && b.count==2,"broadcast exclusion is unchanged");
            b.isOpen=false;next.broadcast(input);check(b.count==2,"closed connections receive nothing");b.isOpen=true;
            for each(var kind:String in [Protocol.MSG_UNITSYNC,Protocol.MSG_CHAT,Protocol.MSG_PLAYERDMG,"custom"]){
               var other:Object={type:kind,players:input.players,damage:12};next.broadcast(other);
               check(a.last===other && b.last===other,"non-worldstate untouched: "+kind);
            }
            var empty:Object={type:Protocol.MSG_WORLDSTATE,players:[{id:0,snap:{x:1}},{id:1,snap:null}]};
            next.broadcast(empty);check(a.last===empty,"no-copy fast path when local snapshot is absent");
            for(var iteration:int=0;iteration<80;iteration++) {
               input=packet(iteration%3);input.roomEpoch=iteration;input.players[1].snap.hp=iteration*.1;
               original=JSON.stringify(input);next.broadcast(input);
               check(JSON.stringify(input)==original && same(visibleTo(input,1),visibleTo(a.last,1)),
                  "changing source, epoch and history remain intact round "+iteration);
            }
            // Alternating paired runs measure the existing codec and allocation
            // saved on the identical tree, outside gameplay and without sockets.
            input=packet(18);input.players.pop();old.clients=[a];next.clients=[a];a.encode=true;
            for(iteration=0;iteration<4;iteration++) {
               var row:Object={round:iteration,synthetic:true};
               for each(var variant:String in (iteration%2==0?["old","candidate"]:["candidate","old"])) {
                  var start:int=getTimer();
                  for(var j:int=0;j<12;j++){if(variant=="old")old.broadcast(input);else next.broadcast(input);}
                  row[variant]={ms:getTimer()-start,bytes:a.bytes};
               }
               metrics.push(row);
            }
            check(metrics[0].candidate.bytes<metrics[0].old.bytes,"wire payload shrinks without changing observed fields");
         } catch(error:Error){check(false,"uncaught "+error.getStackTrace());}
         finally {old.clients=[];next.clients=[];old.close();next.close();}
         var fs:FileStream=new FileStream();fs.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         fs.writeUTFBytes(JSON.stringify({pass:checks.length-failures,fail:failures,checks:checks,metrics:metrics,gameplayQualified:false}));fs.close();
         NativeApplication.nativeApplication.exit(failures?1:0);
      }
   }
}
import rconnect.net.TcpLink;
import rconnect.net.BinaryMessageCodec;
import flash.utils.ByteArray;
class CaptureLink extends TcpLink {
   public var last:Object,count:int=0,encode:Boolean=false,bytes:int=0;
   public function CaptureLink(identity:int){id=identity;isOpen=true;}
   override public function send(msg:Object):void {
      last=msg;count++;
      if(encode){var data:ByteArray=BinaryMessageCodec.pack(msg);bytes=data.length;
         if(BinaryMessageCodec.unpack(data)==null)throw new Error("invalid encoded packet");}
   }
}

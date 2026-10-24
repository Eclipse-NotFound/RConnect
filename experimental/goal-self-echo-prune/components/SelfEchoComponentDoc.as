package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.utils.setTimeout;
   import echo.ControlSessionSlice;
   import echo.CandidateSessionSlice;
   import rconnect.net.HostServer;
   import rconnect.net.TcpLink;
   import rconnect.net.BinaryMessageCodec;
   import rconnect.net.Protocol;

   /** Exact broadcast/consume method slices with real transport classes.
    * CaptureLink replaces the socket only. The game/room boundaries record
    * calls and return fixed data; this does not execute gameplay or timers. */
   public class SelfEchoComponentDoc extends Sprite {
      private static const EXPECTED_CHECKS:int=100;
      private var checks:Array=[],failures:int=0;
      public function SelfEchoComponentDoc() {setTimeout(run,100);}
      private function check(ok:Boolean,label:String):void {
         checks.push({passed:ok,label:label});if(!ok)failures++;
      }
      private function same(a:*,b:*):Boolean {
         if(a===b)return true;
         if(a==null||b==null||typeof a!=typeof b||(a is Array)!=(b is Array))return false;
         if(typeof a!="object")return false;
         if(a is Array&&a.length!=b.length)return false;
         var key:String,n:int=0,m:int=0;
         for(key in a){n++;if(!b.hasOwnProperty(key)||!same(a[key],b[key]))return false;}
         for(key in b)m++;return n==m;
      }
      private function snapshot(id:int):Object {
         return {x:100+id,y:200,hp:99.5,sost:1,sampleTime:1234,worldInfo:{roomKey:"room-"+id},
            heldMotion:{kind:"box",k:"B1",q:true,x:300,y:200},
            weapons:[{id:"lmg",events:[{seq:7,flight:{frames:[{at:1234,x:8.25,y:9}],end:0}}]}],
            port:{serial:2},peerGrip:{enabled:true},ap:{armor:"pip"}};
      }
      private function fixture(candidate:Boolean,mode:String):Object {
         var s:Object=candidate?new CandidateSessionSlice():new ControlSessionSlice();
         var link:EchoCaptureLink=new EchoCaptureLink(mode=="unassigned"?-1:mode=="zero-id"?0:mode=="rejoin"?2:1);
         var hostSnap:Object=snapshot(0),guestSnap:Object=snapshot(link.id);
         if(mode=="death")guestSnap.sost=4;
         if(mode=="split-room")guestSnap.worldInfo.roomKey="different-room";
         var calls:Array=[],observed:Array=[],updates:Array=[],removed:Array=[];
         var game:Object={readSnapshot:function():Object {calls.push("self");return hostSnap;},
            isTransitioning:function():Boolean {calls.push("transition");return false;},
            readEnemyMotion:function():Array {calls.push("enemies");return [{k:"U1",x:31,y:32}];},
            readLootSync:function(active:Boolean):Array {calls.push("loot:"+active);return [{k:"L1",x:41,y:42}];},
            readWallPaintUpdates:function():Array {calls.push("wall");return [{k:"0,0",v:5}];},
            wallPaintUpdatesSent:function(value:Array):void {calls.push({sent:value});},
            updateRemote:function(id:int,snap:Object,name:String):void {updates.push({id:id,snap:snap,name:name});},
            removeRemote:function(id:int):void {removed.push(id);}};
         s.mod={game:game};
         s.rooms={canSyncWorld:true,authority:true,
            stamp:function(packet:Object):Object {packet.roomKey="settled";packet.roomEpoch=3;packet.roomTerm=4;return packet;},
            observeTeammate:function(info:Object):void {observed.push(info);}};
         var server:HostServer=new HostServer();server.bound=true;server.clients=[link];s.server=server;
         s.peers=[{id:link.id,name:"guest",link:link,snap:guestSnap}];
         if(mode=="no-peer")s.peers=[];
         if(mode=="no-client")server.clients=[];
         if(mode=="multi-client")server.clients.push(new EchoCaptureLink(2));
         if(mode=="multi-peer")s.peers.push({id:2,name:"second",link:new EchoCaptureLink(2),snap:snapshot(2)});
         if(mode=="foreign-link")s.peers[0].link=new EchoCaptureLink(link.id);
         if(mode=="id-mismatch")s.peers[0].id=7;
         if(mode=="closed")link.isOpen=false;
         if(mode=="null-snap")s.peers[0].snap=null;
         if(mode=="unbound")server.bound=false;
         if(mode=="no-server")s.server=null;
         return {s:s,server:server,link:link,calls:calls,observed:observed,updates:updates,removed:removed,
            hostSnap:hostSnap,guestSnap:guestSnap,originalGuest:JSON.stringify(guestSnap),
            initialPeerSnap:s.peers.length==0?null:s.peers[0].snap};
      }
      private function dispose(f:Object):void {
         // No listening socket was created; detach captures before close().
         f.server.clients=[];f.server.close();
      }
      private function runCase(mode:String,prune:Boolean):void {
         var a:Object=fixture(false,mode),b:Object=fixture(true,mode);
         try {
            a.s.broadcastWorldState();b.s.broadcastWorldState();
            check(same(a.calls,b.calls),mode+": identical capture/ack calls");
            check(a.link.count==b.link.count,mode+": identical send count");
            check(JSON.stringify(b.guestSnap)==b.originalGuest &&
               (b.s.peers.length==0||b.s.peers[0].snap===b.initialPeerSnap),
               mode+": stored peer snapshot unchanged");
            if(a.link.count==0) {
               check(b.link.last==null,mode+": no new transmission");return;
            }
            var expected:Object=Protocol.decode(Protocol.encode(a.link.last));
            if(prune)expected.players[1].snap=null;
            check(same(expected,b.link.json)&&same(b.link.json,b.link.binary),
               mode+": decoded envelope differs only by permitted own snap");
            check(b.link.last.players.length==a.link.last.players.length &&
               b.link.last.players[0].snap===b.hostSnap,
               mode+": roster and host snapshot retained");
            if(prune&&b.initialPeerSnap!=null)
               check(b.link.binaryBytes<a.link.binaryBytes,mode+": encoded payload is smaller");
            for(var i:int=0;i<a.server.clients.length;i++) {
               var old:EchoCaptureLink=a.server.clients[i],next:EchoCaptureLink=b.server.clients[i];
               if(!prune)check(same(old.json,next.json),mode+": fallback recipient "+i+" unchanged");
            }
            a.s.myId=b.s.myId=b.link.id;
            a.s.remotes=[{id:0,snap:{}},{id:99,snap:{}}];
            b.s.remotes=[{id:0,snap:{}},{id:99,snap:{}}];
            a.s.applyWorldState(a.link.binary.players);b.s.applyWorldState(b.link.binary.players);
            check(same(a.observed,b.observed)&&same(a.updates,b.updates)&&same(a.removed,b.removed)&&
               same(a.s.remotes,b.s.remotes),mode+": real consumer and stale-member cleanup equivalent");
         } finally {dispose(a);dispose(b);}
      }
      private function run():void {
         try {
            for each(var mode:String in ["single","death","split-room","rejoin","null-snap"])
               runCase(mode,true);
            for each(mode in ["unassigned","zero-id","no-peer","no-client","multi-client","multi-peer",
               "foreign-link","id-mismatch","closed","unbound","no-server"])
               runCase(mode,false);
         } catch(error:Error) {check(false,"uncaught "+error.getStackTrace());}
         if(checks.length!=EXPECTED_CHECKS)check(false,"unexpected check count "+checks.length);
         var fs:FileStream=new FileStream();
         fs.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         fs.writeUTFBytes(JSON.stringify({passed:failures==0,failed:failures,assertions:checks,expectedChecks:EXPECTED_CHECKS,
            methodComponentsOnly:true,realSockets:false,gameplayQualified:false,performanceQualified:false}));
         fs.close();NativeApplication.nativeApplication.exit(failures?1:0);
      }
   }
}

import rconnect.net.TcpLink;
import rconnect.net.BinaryMessageCodec;
import rconnect.net.Protocol;
import flash.utils.ByteArray;
class EchoCaptureLink extends TcpLink {
   public var count:int=0,last:Object,json:Object,binary:Object,binaryBytes:int=0;
   public function EchoCaptureLink(identity:int) {id=identity;isOpen=true;}
   override public function send(message:Object):void {
      count++;last=message;
      json=Protocol.decode(Protocol.encode(message));
      var data:ByteArray=BinaryMessageCodec.pack(message);binaryBytes=data.length;
      binary=BinaryMessageCodec.unpack(data);
   }
}

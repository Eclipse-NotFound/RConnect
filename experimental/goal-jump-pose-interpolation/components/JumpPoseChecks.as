package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import rconnect.game.NativeJumpPose;
   import rconnect.game.RemoteMotion;
   import rconnect.game.ControlRemoteMotion;
   import rconnect.net.Protocol;
   import rconnect.net.BinaryMessageCodec;

   public class JumpPoseChecks extends Sprite {
      private var checks:Array=[];
      private var failures:int=0;
      public function JumpPoseChecks() {
         try {eligibility();segments();bounds();clock();teleport();wire();}
         catch(error:Error){check(false,"uncaught "+error.getStackTrace());}
         var stream:FileStream=new FileStream();
         stream.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         stream.writeUTFBytes(JSON.stringify({assertions:checks,failed:failures,passed:failures==0,gameLoaded:false}));
         stream.close();NativeApplication.nativeApplication.exit(failures?1:0);
      }
      private function check(ok:Boolean,label:String):void {
         checks.push({passed:ok,label:label});if(!ok)failures++;
      }
      private function fixture():Object {
         var loc:Object={},w:Object={allStat:1,onPause:false,t_exit:0};
         var u:Object={loc:loc,sost:1,hp:100,stay:false,aJump:1,animOff:false,t_work:0,
            isFly:false,isLaz:0,isPlav:false,levit:0,t_port:0,animState:"jump",dy:-12,jumpNumb:1,
            vis:{osn:{currentLabel:"jump",currentFrame:7,body:{isPlaying:false,totalFrames:32,currentFrame:4}}}};
         return {u:u,loc:loc,w:w};
      }
      private function eligibility():void {
         var f:Object=fixture();
         check(NativeJumpPose.eligible(f.u,f.loc,f.w),"real normal jump formula qualifies");
         var mutations:Array=[["stay",true],["aJump",0],["animOff",true],["t_work",1],
            ["isFly",true],["isLaz",1],["isPlav",true],["levit",1],["levit",2],
            ["t_port",1],["animState","pinok"],["sost",3],["hp",0],["dy",NaN]];
         for each(var m:Array in mutations) {
            f=fixture();f.u[m[0]]=m[1];
            check(!NativeJumpPose.eligible(f.u,f.loc,f.w),"reject native "+m[0]+"="+m[1]);
         }
         f=fixture();delete f.u.isFly;
         check(!NativeJumpPose.eligible(f.u,f.loc,f.w),"missing native field is not false");
         f=fixture();f.u.vis.osn.body.currentFrame=5;
         check(!NativeJumpPose.eligible(f.u,f.loc,f.w),"post-animation frame must match actual dy");
         f=fixture();f.u.vis.osn.body.isPlaying=true;
         check(!NativeJumpPose.eligible(f.u,f.loc,f.w),"native play timelines remain unchanged");
         f=fixture();f.u.vis.osn.currentLabel="levit";
         check(!NativeJumpPose.eligible(f.u,f.loc,f.w),"native selected clip must be jump");
         f=fixture();f.w.onPause=true;
         check(!NativeJumpPose.eligible(f.u,f.loc,f.w),"paused source does not arm");
         f=fixture();f.w.t_exit=1;
         check(!NativeJumpPose.eligible(f.u,f.loc,f.w),"travel source does not arm");
         f=fixture();delete f.u.jumpNumb;
         check(!NativeJumpPose.eligible(f.u,f.loc,f.w),"missing native double-jump discriminator does not arm");
      }
      private function segments():void {
         var f:Object=fixture(),p:NativeJumpPose=new NativeJumpPose();
         var a:int=p.observe(f.u,f.loc,f.w);
         check(a>0 && p.observe(f.u,f.loc,f.w)==a,"same native frame or repeated capture retains segment");
         f.u.stay=true;var absent:int=p.observe(f.u,f.loc,f.w);f.u.stay=false;
         var b:int=p.observe(f.u,f.loc,f.w);
         check(absent==0 && b!=a,"landing between two packets breaks the segment");
         a=b;f.loc={};f.u.loc=f.loc;b=p.observe(f.u,f.loc,f.w);
         check(b!=a,"same keys with a replacement room break segment");
         a=b;var replacement:Object=fixture();replacement.u.loc=f.loc;
         f.u=replacement.u;b=p.observe(f.u,f.loc,f.w);
         check(b!=a,"replacement local body breaks segment");
         a=b;f.w={allStat:1,onPause:false,t_exit:0};b=p.observe(f.u,f.loc,f.w);
         check(b!=a,"replacement world breaks segment");
         a=b;f.u.vis.osn.body={isPlaying:false,totalFrames:32,currentFrame:4};b=p.observe(f.u,f.loc,f.w);
         check(b!=a,"replacement visual child breaks segment");
         a=b;p.observe(null,f.loc,f.w);b=p.observe(f.u,f.loc,f.w);
         check(b!=a,"room hold or offline observation breaks segment");
         a=b;f.u.dy=3;f.u.vis.osn.body.currentFrame=19;
         check(p.observe(f.u,f.loc,f.w)==a,"ordinary apex keeps the native jump segment");
         f.u.jumpNumb=3;f.u.dy=-12;f.u.vis.osn.body.currentFrame=4;
         b=p.observe(f.u,f.loc,f.w);
         check(b!=a && b>0,"native airborne double-jump breaks segment even with the same eligible pose");
      }
      private function pose(at:Number,dy:Number,run:int=1):Object {
         return {x:at*.1,y:100+at*.1,sampleTime:at,dy:dy,dx:3,stay:0,sost:1,hp:100,
            pose:"jump",poseFrame:7,bodyFrame:NativeJumpPose.frame(dy),bodyPlaying:false,nativeJumpRun:run,
            roomKey:"rbl//0,0,0",roomEpoch:1,landId:"rbl",locId:"loc0_0"};
      }
      private function bounds():void {
         var a:Object=pose(0,-12),b:Object=pose(50,-8);
         check(NativeJumpPose.between(a,b,.5)==6,"midpoint dy -10 maps to native body frame6, endpoints4/8");
         check(NativeJumpPose.between(pose(0,-40),pose(50,-20),.5)==1,"lower native clamp permits repeated frame1");
         check(NativeJumpPose.between(pose(0,20),pose(50,40),.5)==32,"upper native clamp permits repeated frame32");
         check(NativeJumpPose.between(pose(0,-12.1),pose(50,-11.9),.5)==4,"native round permits unchanged interior frame");
         var mutations:Array=[["nativeJumpRun",0],["nativeJumpRun",2],["pose","levit"],["bodyPlaying",true],
            ["stay",1],["sost",3],["hp",0],["dy",NaN],["bodyFrame",20],["poseFrame",8],
            ["roomKey","other"],["roomEpoch",2],["landId","other"],["locId","other"],["sampleTime",0]];
         for each(var m:Array in mutations) {
            b=pose(50,-8);b[m[0]]=m[1];
            check(isNaN(NativeJumpPose.between(a,b,.5)),"fallback for endpoint "+m[0]+"="+m[1]);
         }
         b=pose(50,-8);delete b.nativeJumpRun;
         check(isNaN(NativeJumpPose.between(a,b,.5)),"legacy packet without eligibility falls back");
      }
      private function clock():void {
         var m:RemoteMotion=new RemoteMotion(),old:ControlRemoteMotion=new ControlRemoteMotion();
         m.push(pose(0,-12),1000);old.push(pose(0,-12),1000);
         m.push(pose(50,-8),1050);old.push(pose(50,-8),1050);
         var s:Object=m.sample(1125),o:Object=old.sample(1125);
         check(m.sourceTime==25 && s.bodyFrame==6 && o.bodyFrame==4,"same original cursor reveals held-body gap without clock changes");
         check(s.x==o.x && s.y==o.y && s.dy==o.dy && s.dx==o.dx && m.sourceTime==old.sourceTime,
            "position, physics velocities and source clock remain original78C");
         m.sample(1125);check(m.currentSample.bodyFrame==6 && m.sourceTime==25,"same sample(now) does not accumulate pose");
         m.push(pose(50,-8),1050);m.sample(1125);
         check(m.currentSample.bodyFrame==6 && m.sourceTime==25,"duplicate packet does not restart or accumulate");
         m.push(pose(50,-8,0),1050);m.sample(1125);
         check(m.currentSample.bodyFrame==4,"lost endpoint eligibility restores original selected frame, no stale midpoint");
         m.push(pose(50,-8),1050);m.sample(1125);
         check(m.currentSample.bodyFrame==6,"qualification restored recomputes from original endpoints");
         m.push(pose(-50,-16),1070);m.sample(1125);
         check(m.currentSample.bodyFrame==6 && m.sourceTime==25,"old packet preserves current pose and clock");
         s=m.settle(1130);check(s.bodyFrame==8 && m.sourceTime==50,"pause settles to exact last received native frame");
         m.sample(1300);check(m.currentSample.bodyFrame==8 && m.sourceTime==50,"no packets means no extrapolated body playback");
         m=new RemoteMotion();m.push(pose(0,-12,1),1000);m.push(pose(50,-8,2),1050);
         check(m.sample(1125).bodyFrame==4,"different jump segments cannot interpolate");
         m=new RemoteMotion();m.push({x:0,y:0,sampleTime:0},1000);m.push({x:10,y:10,sampleTime:50},1050);
         check(!("bodyFrame" in m.sample(1125)),"ordinary movement without body metadata gains no body field");
      }
      private function teleport():void {
         var a:Object=pose(0,-12),b:Object=pose(50,-8),m:RemoteMotion=new RemoteMotion();
         b.x=205;b.port={events:[{seq:1,at:25,fromX:2.5,fromY:102.5,toX:200,toY:100,
            postX:200,postY:100,scX:20,scY:40,roomKey:b.roomKey,roomEpoch:b.roomEpoch}]};
         m.push(a,1000);m.push(b,1050);
         check(m.sample(1112).bodyFrame==4,"real split method keeps departure pose before teleport");
         check(m.sample(1137).bodyFrame==8,"real split method selects arrival pose after teleport, never intermediate");
      }
      private function roundtrip(msg:Object,binary:Boolean):Object {
         return binary?BinaryMessageCodec.unpack(BinaryMessageCodec.pack(msg)):Protocol.decode(Protocol.encode(msg));
      }
      private function wire():void {
         // Exact production codecs at both hops. Session's direct snap relay
         // anchors are separately pinned by prepare_sources.py; no mock codec.
         for(var format:int=0;format<2;format++) {
            var binary:Boolean=format==1,label:String=binary?"AMF3":"JSON";
            var received:Object=roundtrip(Protocol.make(Protocol.MSG_PLAYERSTATE,{id:1,seq:1,name:"fixture",snap:pose(0,-12,7)}),binary);
            check(received!=null && received.snap.nativeJumpRun===7 && received.snap.bodyPlaying===false,
               label+" PLAYERSTATE preserves segment and stopped-body fields");
            var relayed:Object=roundtrip(Protocol.make(Protocol.MSG_WORLDSTATE,{tick:2,players:[{id:1,name:"fixture",snap:received.snap}]}),binary);
            var remote:Object=relayed.players[0].snap;
            check(remote.nativeJumpRun===7 && remote.bodyFrame==4 && remote.dy==-12,
               label+" WORLDSTATE retains the host's complete peer snapshot");
            var next:Object=roundtrip(Protocol.make(Protocol.MSG_PLAYERSTATE,{id:1,seq:2,snap:pose(50,-8,7)}),binary);
            next=roundtrip(Protocol.make(Protocol.MSG_WORLDSTATE,{tick:3,players:[{id:1,snap:next.snap}]}),binary);
            var m:RemoteMotion=new RemoteMotion();m.push(remote,1000);m.push(next.players[0].snap,1050);
            check(m.sample(1125).bodyFrame==6 && m.sourceTime==25,label+" real decoded endpoints reach the unchanged playback cursor");
            var legacy:Object=pose(50,-8,7);delete legacy.nativeJumpRun;
            legacy=roundtrip(Protocol.make(Protocol.MSG_PLAYERSTATE,{id:1,seq:3,snap:legacy}),binary);
            legacy=roundtrip(Protocol.make(Protocol.MSG_WORLDSTATE,{tick:4,players:[{id:1,snap:legacy.snap}]}),binary);
            m.push(legacy.players[0].snap,1050);
            check(m.sample(1125).bodyFrame==4,label+" old peer missing the marker restores the selected original frame");
         }
      }
   }
}

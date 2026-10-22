package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import rconnect.core.*;
   import rconnect.game.GameBridge;
   import rconnect.net.TcpLink;
   import pausecheck.*;

   /** Full production CoopPause + exact production Session methods in shells. */
   public class PauseFlushChecks extends Sprite {
      private var assertions:Array=[],failed:int=0,sessions:Array=[];
      public function PauseFlushChecks() {addEventListener(Event.ENTER_FRAME,run);}
      private function check(ok:Boolean,label:String):void {
         assertions.push({passed:ok,label:label});if(!ok)failed++;
      }
      private function make(host:Boolean=true,control:Boolean=false):Session {
         var s:Session=new Session();s.mode=host?Session.HOSTING:Session.CONNECTED;
         s.myId=host?0:1;s.server=new FakeServer();s.link=new TcpLink();
         s.peers=host?[{id:1,name:"Join",link:s.link,snap:{x:9,sampleTime:77}}]:[];
         s.mod={stage:new Sprite(),game:new GameBridge(),config:new FakeConfig()};
         s.pause=control?new ControlCoopPause(s):new CoopPause(s);sessions.push(s);
         frame(s);
         if(!host)s.link.receive({type:"coop-pause",op:"state",seq:0,epoch:7,menus:true,sats:true,reasons:[]});
         clear(s);return s;
      }
      private function clear(s:Session):void {
         s.server.calls=0;s.server.sent=[];s.link.sent=[];Probe.events=[];Log.rows=[];
         var g:GameBridge=s.mod.game;g.captures=g.enemies=g.loot=g.walls=g.commits=0;
      }
      private function frame(s:Session):void{s.mod.stage.dispatchEvent(new Event(Event.ENTER_FRAME));}
      private function sats(s:Session,on:Boolean):void{s.mod.game.world.sats.active=on;frame(s);}
      private function report(s:Session,seq:int,mask:int,epoch:int=7):void {
         s.link.receive({type:"coop-pause",op:"report",seq:seq,mask:mask,epoch:epoch});
      }
      private function state(s:Session,seq:int,mask:int):void {
         s.link.receive({type:"coop-pause",op:"state",seq:seq,epoch:7,menus:true,sats:true,
            reasons:mask?[{id:0,name:"Host",mask:mask}]:[]});
      }
      private function run(e:Event):void {
         removeEventListener(Event.ENTER_FRAME,run);
         try {localHost();remoteRequest();joining();guards();exceptionCases();messageEquivalence();}
         catch(error:Error){check(false,"uncaught "+error.getStackTrace());}
         for each(var s:Session in sessions)s.pause.reset();
         var f:File=File.applicationStorageDirectory.resolvePath("result.json"),stream:FileStream=new FileStream();
         stream.open(f,FileMode.WRITE);stream.writeUTFBytes(JSON.stringify({passed:failed==0,failed:failed,
            assertions:assertions,game_loaded:false,performance_qualified:false}));stream.close();
         NativeApplication.nativeApplication.exit(failed?1:0);
      }
      private function localHost():void {
         var s:Session=make(),g:GameBridge=s.mod.game;sats(s,true);
         check(s.pause.paused&&g.coopPaused,"01 host enters both pause states");
         check(g.captures==1&&g.enemies==1&&g.loot==1&&g.walls==1,"02 complete capture exactly once");
         check(s.server.calls==1&&s.server.sent.length==1,"03 one worldstate sent at edge");
         check(Probe.events.indexOf("pause-on")<Probe.events.indexOf("capture"),"04 native presentation pause precedes capture");
         var p:Object=s.server.sent[0];
         check(p.enemyMotion[0].sampleTime==12345&&p.enemyMotion[0].x==305,"05 exact source stamp and current endpoint retained");
         check(p.roomKey=="room-a"&&p.roomEpoch==7&&p.roomTerm==3,"06 current room epoch and term stamped");
         check(p.players.length==2&&p.players[1].snap.sampleTime==77,"07 full existing player payload retained");
         check(g.commits==1&&Probe.events.indexOf("wall-commit")>Probe.events.indexOf("world-send"),"08 wall revision committed only after broadcast");
         check(s.link.sent.length>0&&s.link.sent[s.link.sent.length-1].op=="state"
            &&Probe.events.indexOf("pause-state")<Probe.events.indexOf("capture"),
            "09 ordinary pause state precedes stopped-world capture");
         frame(s);s.mod.game.world.gui.guiPause=true;frame(s);
         check(s.server.calls==1,"10 repeated frame and additional reason do not flush again");
         s.mod.game.world.gui.guiPause=false;sats(s,false);
         check(!s.pause.paused&&s.server.calls==1,"11 resume does not flush");
         sats(s,true);check(s.server.calls==2,"12 new pause edge flushes again");
         s.pause.reset();
      }
      private function remoteRequest():void {
         var s:Session=make();report(s,1,2);
         check(s.pause.paused&&s.mod.game.coopPaused,"13 valid peer report pauses host");
         check(s.server.calls==1&&s.mod.game.enemies==1,"14 peer-origin edge captures and sends once");
         report(s,1,2);check(s.server.calls==1,"15 duplicate sequence does not flush");
         report(s,2,1);check(s.pause.paused&&s.server.calls==1,"16 changed nonzero reason is not a new edge");
         report(s,3,0,6);check(s.pause.paused&&s.server.calls==1,"17 old epoch cannot resume or flush");
         report(s,3,0);check(!s.pause.paused&&s.server.calls==1,"18 valid clear resumes without flush");
         report(s,4,2);check(s.pause.paused&&s.server.calls==2,"19 subsequent remote pause flushes once");
         report(s,-1,0);check(s.pause.paused&&s.server.calls==2,"20 invalid sequence has no side effect");
         s.pause.reset();
      }
      private function joining():void {
         var s:Session=make(false);sats(s,true);
         check(s.pause.paused&&s.server.calls==0,"21 joining local pause never broadcasts worldstate");
         check(s.link.sent.length>0&&s.link.sent[s.link.sent.length-1].op=="report","22 joining pause still reports to host");
         state(s,1,2);check(s.pause.paused&&s.server.calls==0,"23 host state preserves joining pause without flush");
         state(s,1,0);check(s.pause.paused&&s.server.calls==0,"24 duplicate state ignored");
         state(s,2,0);check(s.pause.paused,"25 local reason remains when remote reason clears");
         sats(s,false);check(!s.pause.paused&&s.server.calls==0,"26 joining release preserves ordinary handshake");
         s.pause.reset();
      }
      private function guards():void {
         var names:Array=["offline","join","server-null","unbound","no-clients","not-ready","busy","wrong-room","not-authority","transition","not-game-paused"];
         for(var i:int=0;i<names.length;i++) {
            var s:Session=make();sats(s,true);clear(s);var server:FakeServer=s.server;
            if(i==0)s.mode=Session.OFFLINE;else if(i==1)s.mode=Session.CONNECTED;
            else if(i==2)s.server=null;else if(i==3)s.server.bound=false;
            else if(i==4)s.server.clients=[];else if(i==5)s.rooms.ready=false;
            else if(i==6)s.rooms.busy=true;else if(i==7)s.rooms.current=false;
            else if(i==8)s.rooms.authority=false;else if(i==9)s.mod.game.transitioning=true;
            else s.mod.game.coopPaused=false;
            s.flushPausedWorldState();
            check(server.calls==0&&s.mod.game.captures==0&&s.mod.game.enemies==0,
               (27+i)+" guard "+names[i]+" prevents even capture");
            s.pause.reset();
         }
      }
      private function exceptionCases():void {
         var s:Session=make(),g:GameBridge=s.mod.game;s.server.throwOnce=true;sats(s,true);
         check(s.pause.paused&&g.coopPaused&&s.link.sent.length>0,"38 failed broadcast cannot prevent pause state transmission");
         check(s.server.calls==1&&g.commits==0&&Log.rows.length>0,"39 failure attempts once and does not acknowledge unsent wall revision");
         frame(s);check(s.server.calls==1,"40 exception does not retry each frame");
         sats(s,false);sats(s,true);check(s.server.calls==2&&g.commits==1,"41 next real edge can send after a failed edge");
         s.pause.reset();
         s=make();g=s.mod.game;
         var fixed:Session=s;s.server.hook=function():void{fixed.pause.setPolicy(true,true);};sats(s,true);
         check(s.server.calls==1&&g.captures==1,"42 synchronous refresh sees the already-set pause edge");
         check(g.commits==1&&s.server.sent.length==1,"43 repeated refresh cannot duplicate capture or wall commit");
         s.server.hook=null;s.rooms.epoch=8;s.rooms.term=4;frame(s);
         check(s.server.calls==1,"44 epoch refresh with same local pause is not another edge");
         sats(s,false);sats(s,true);
         check(s.server.sent[1].roomEpoch==8&&s.server.sent[1].roomTerm==4,"45 next valid edge uses new room authority identity");
         check(s.server.sent[0].tick==17&&s.server.sent[1].tick==17&&s.server.sent[1].enemyMotion[0].sampleTime==12345,
            "46 flush does not advance timer tick or fabricate a source frame");
         s.pause.reset();
         s=make();g=s.mod.game;fixed=s;
         s.server.hook=function():void{fixed.peers=[];fixed.server.clients=[];fixed.link.isOpen=false;};
         sats(s,true);frame(s);
         check(s.server.calls==1&&g.commits==0,"47 removed last recipient does not retry or commit wall delivery");
         check(!s.pause.paused&&!g.coopPaused,"48 ordinary refresh releases pause after disconnection");
         s.pause.reset();
      }
      private function localMessages(control:Boolean):Array {
         var s:Session=make(true,control),g:GameBridge=s.mod.game;
         g.world.sats.active=true;s.pause.setPolicy(true,true);
         s.pause.setPolicy(true,true);
         g.world.gui.guiPause=true;s.pause.setPolicy(true,true);
         g.world.sats.active=false;g.world.gui.guiPause=false;s.pause.setPolicy(true,true);
         s.rooms.epoch=8;s.pause.setPolicy(true,true);
         var a:Array=s.link.sent.concat();s.pause.reset();return a;
      }
      private function remoteMessages(control:Boolean):Array {
         var s:Session=make(true,control);
         report(s,1,2);report(s,1,2);report(s,2,1);report(s,3,0,6);report(s,3,0);report(s,4,2);
         var a:Array=s.link.sent.concat();s.pause.reset();return a;
      }
      private function messageEquivalence():void {
         check(JSON.stringify(localMessages(true))==JSON.stringify(localMessages(false)),
            "49 exact old/new local pause-state payload and sequence equivalence");
         check(JSON.stringify(remoteMessages(true))==JSON.stringify(remoteMessages(false)),
            "50 exact old/new peer-report pause-state payload and sequence equivalence");
      }
   }
}

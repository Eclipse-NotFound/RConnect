package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.TimerEvent;
   import flash.utils.Timer;
   import flash.utils.Dictionary;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   import rconnect.core.TravelGuard;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;
   public class FollowNetworkTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var mod:RConnectMod,host:Boolean,t:Timer=new Timer(150),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=0,a:Object,b:Object,xpStart:Number,checkpoint:Object;
      private var peerReady:Boolean=false,lastReady:int=-600;
      public function FollowNetworkTestDoc(){var app:String=NativeApplication.nativeApplication.applicationID;if(app.indexOf("rconnect-coop-")<0)return;
         host=app.indexOf("-host-")>=0;t.addEventListener(TimerEvent.TIMER,tick);t.start();}
      private function check(b:Boolean,s:String):void{Log.d("COOP "+(b?"PASS ":"FAIL ")+"follow-network "+s);}
      private function setPhase(s:String):void{phase=s;at=getTimer();Log.d("FOLLOW TCP "+(host?"host ":"join ")+s);}
      private function send(s:String,p:Object=null):void{p=p||{};p.type="follow-test";p.phase=s;if(host)mod.session.server.broadcast(p);else mod.session.link.send(p);}
      private function watch(l:TcpLink):void{if(l!=null&&!links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);}}
      private function info(o:Object):Object{return {landX:o.landX,landY:o.landY,landZ:o.landZ,landProb:o.landProb,key:mod.game.roomKey(o)};}
      private function go(o:Object):void{TravelGuard.follow(mod.game,o);}
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;if(p.type!="follow-test")return;
         try {
            if(p.phase=="done"){finish();return;}
            if(host) {
               if(p.phase=="ready")peerReady=true;
               else if(p.phase=="aligned"){send("split");setPhase("split");}
               else if(p.phase=="split-ready") {
                  check(mod.game.roomKey()==a.key,"follow disabled leaves host in original room");
                  send("reward");var c:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.loc.Bonus") as Class;
                  var o:Object=new c(mod.game.loc,"xp",mod.game.gg.X+300,mod.game.gg.Y,null,null);mod.game.loc.bonuses.push(o);mod.game.loc.addObj(o);
                  mod.game.loc.unXp=10;mod.game.loc.maxXp=mod.game.loc.kolXp=1;mod.session.progress.prepare();
                  o=mod.game.loc.bonuses[mod.game.loc.bonuses.length-1];o.take();setPhase("reward");
               } else if(p.phase=="rewarded"){go(b);send("arm-join");setPhase("merge-b");}
               else if(p.phase=="armed-join"){go(a);send("follow-join");setPhase("follow-join");}
               else if(p.phase=="followed-join") {mod.config.setValue("followTeammate","1");send("lead-join");setPhase("follow-host");}
               else if(p.phase=="join-b")setPhase("follow-host");
               else if(p.phase=="both-on"){go(a);send("both-follow");setPhase("both-follow");}
               else if(p.phase=="both-followed"){check(mod.game.roomKey()==a.key,"both follow toggles do not swap players back");send("done");finish();}
            } else {
               if(p.phase=="align"){a=p.a;b=p.b;go(a);setPhase("align");}
               else if(p.phase=="split"){go(b);setPhase("split");}
               else if(p.phase=="reward"){xpStart=mod.game.world.pers.xpCur;setPhase("reward");}
               else if(p.phase=="arm-join"){mod.config.setValue("followTeammate","1");setPhase("arm-join");}
               else if(p.phase=="follow-join")setPhase("follow-join");
               else if(p.phase=="lead-join"){mod.config.setValue("followTeammate","0");go(b);send("join-b");setPhase("lead-join");}
               else if(p.phase=="enable-both"){mod.config.setValue("followTeammate","1");send("both-on");setPhase("wait");}
               else if(p.phase=="both-follow")setPhase("both-follow");
            }
         }catch(err:Error){check(false,err.getStackTrace());send("done");finish();}
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null || mod.session==null)return;
         // Listen before room readiness; a peer may finish loading first.
         if(host){for each(var l:TcpLink in mod.session.server.clients)watch(l);}else watch(mod.session.link);
         if(mod.game.gg==null || !mod.session.rooms.ready || mod.session.rooms.busy || mod.game.isTransitioning())return;
         if(t.currentCount<30 || mod.game.readWorldInfo().curLandId!="random_mane")return;
         try {
            mod.game.gg.invulner=true;mod.game.gg.disabled=true;mod.game.gg.dx=mod.game.gg.dy=0;
            if(phase=="boot"){check(mod.config.getValue("followTeammate")=="0","follow is opt-in by default");mod.config.setValue("followTeammate","0");setPhase("wait");}
            // Retry only the fixture handshake until align acknowledges it.
            // Repeated ready messages never reset a running scenario.
            if(!host && phase=="wait" && a==null && getTimer()-lastReady>=600){send("ready");lastReady=getTimer();}
            if(host && phase=="wait" && peerReady && a==null)setPhase("select");
            if(host && phase=="select") {
               var rooms:Array=[];for each(var col:Array in mod.game.world.land.locs)if(col!=null)for each(var row:Array in col)if(row!=null)for each(var r:Object in row)if(r!=null&&!TravelGuard.restricted(r))rooms.push(r);
               check(rooms.length>=2,"two ordinary rooms available");a=info(rooms[0]);b=info(rooms[1]);go(a);send("align",{a:a,b:b});setPhase("align");
            }
            if(!host && phase=="align" && mod.game.roomKey()==a.key && getTimer()-at>1000){send("aligned");setPhase("wait");}
            if(!host && phase=="split" && mod.game.roomKey()==b.key && getTimer()-at>1500){check(mod.session.rooms.authority,"follow disabled permits independent room simulation");send("split-ready");setPhase("wait");}
            if(!host && phase=="reward" && getTimer()-at>1200){check(mod.game.world.pers.xpCur-xpStart==10,"XP reward arrives while teammate is in another room");send("rewarded");setPhase("wait");}
            if(!host && phase=="arm-join" && getTimer()-at>1800){send("armed-join");setPhase("wait");}
            if(!host && phase=="follow-join" && mod.game.roomKey()==a.key && getTimer()-at>1600){check(true,"join automatically follows host into ordinary room");send("followed-join");setPhase("wait");}
            if(host && phase=="follow-host" && mod.game.roomKey()==b.key && getTimer()-at>1600){check(true,"host automatically follows joining teammate");send("enable-both");setPhase("wait");}
            if(!host && phase=="both-follow" && mod.game.roomKey()==a.key && getTimer()-at>2500){check(true,"both enabled settle together without oscillating");send("both-followed");setPhase("wait");}
            if(phase!="done"&&getTimer()-at>30000){check(false,"timeout "+phase+" at "+mod.game.roomKey());send("done");finish();}
         }catch(err:Error){check(false,err.getStackTrace());send("done");finish();}
      }
      private function finish():void{if(phase=="done")return;setPhase("done");t.stop();Log.d("COOP EFFECTS DONE follow-network "+(host?"host":"join"));}
   }
}

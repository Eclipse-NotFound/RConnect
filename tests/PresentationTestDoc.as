package {
   import flash.desktop.NativeApplication;
   import flash.display.BitmapData;
   import flash.display.DisplayObject;
   import flash.display.PNGEncoderOptions;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.geom.Matrix;
   import flash.geom.Rectangle;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   import rconnect.game.ExplorationSync;
   import rconnect.game.GameBridge;
   import rconnect.game.RemoteMotion;
   import rconnect.net.NetMessageEvent;
   import rconnect.net.TcpLink;

   /** Test-only entry. A dark room with real RV, real TCP units and final scene pixels. */
   public class PresentationTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var clock:Timer=new Timer(250);
      private var host:Boolean;
      private var prepared:Boolean=false;
      private var tested:Boolean=false;
      private var seeded:Boolean=false;
      private var aligned:Boolean=false;
      private var bridge:GameBridge;
      private var started:int;
      private var monitored:TcpLink;
      private var received:Object={};
      private var lastUnits:Object;
      public function PresentationTestDoc() {
         var id:String=NativeApplication.nativeApplication.applicationID;
         if(id.indexOf("pfe-rconnect-coop-")!=0 && id.indexOf("pfe-modsettings-rconnect-coop-")!=0) return;
         host=id.indexOf("-coop-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            Log.d("COOP FAIL presentation uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();
         });
         clock.addEventListener(TimerEvent.TIMER,tick);clock.start();
      }
      private function check(ok:Boolean,label:String):void { Log.d("COOP "+(ok?"PASS ":"FAIL ")+"presentation "+label); }
      private function tick(e:TimerEvent):void {
         var m:RConnectMod=RConnectMod.instance;
         if(m!=null && m.session!=null && m.session.link!=null && monitored!==m.session.link) {
            monitored=m.session.link;
            monitored.addEventListener(TcpLink.MESSAGE,function(event:NetMessageEvent):void {
               var packet:Object=event.data;
               received[packet.type]=int(received[packet.type])+1;
               if(packet.type=="unitsync") lastUnits={world:packet.worldInfo,count:packet.units.length};
            },false,20000);
         }
         if(m==null || m.game==null || m.game.gg==null || m.game.loc==null || clock.currentCount<60) return;
         try {
            var b:GameBridge=m.game;
            if(!host && !tested && clock.currentCount%40==0)
               Log.d("PRESENT sample incoming="+JSON.stringify(received)+" units="+JSON.stringify(lastUnits)+" local="+JSON.stringify(b.readWorldInfo()));
            if(b.isTransitioning()) return;
            var required:String=String(m.config.getValue("autoTravelLand"));
            // Joiners follow the real host through the normal mission transition.
            if(required=="random_mane" || !host) {
               if(b.world.game.curLandId!="random_mane" || b.world.land.act.id!="random_mane") return;
            }
            if(!prepared) {
               prepared=true;started=getTimer();
               // The old begin-room test bypassed RV. Explicitly enter its actual fog path.
               b.loc.base=false;b.loc.black=true;b.world.black=true;
               b.gg.disabled=true;b.gg.dx=b.gg.dy=0;
               if(host) {
                  var ids:Array=["merc2","merc5","alicorn3"];
                  for(var i:int=0;i<ids.length;i++) {
                     var cls:Class=m.main.loaderInfo.applicationDomain.getDefinition(i<2?"fe.unit.UnitMerc":"fe.unit.UnitAlicorn") as Class;
                     var map:XML=<unit/>;map.@tr=i==0?2:(i==1?5:3);
                     var u:Object=new cls(i==2?"3":ids[i],100,map,null);
                     u.id="presentation_"+ids[i];
                     u.putLoc(b.loc,b.gg.X+100+i*85,b.gg.Y);
                     b.loc.addObj(u);b.loc.units.push(u);u.disabled=true;u.stay=true;u.animate();
                  }
               }
               Log.d("PRESENT sample fixture role="+(host?"host":"join")+" room="+b.loc.id+" player="+b.gg.X+","+b.gg.Y);
            }
            if(getTimer()-started<6000 || tested) return;
            var enemies:Array=[];
            for each(u in b.loc.units) if(String(u.id).indexOf("presentation_")==0) enemies.push(u);
            if(enemies.length<3) {
               if(getTimer()-started<60000) return;
               check(false,"three native enemy types available after TCP replication; got "+enemies.length);
               tested=true;finish();return;
            }
            if(!host && enemies.length==3 && !aligned) {
               aligned=true;
               b.gg.setPos(enemies[0].X-100,enemies[0].Y);b.gg.setVisPos();started=getTimer();return;
            }
            if(!host && enemies.length==3 && !seeded) {
               seeded=true;
               // A native unit may already have phased/faded locally before the
               // host claims it. Freezing AI must not freeze that local disguise.
               for each(u in enemies) {u.invis=true;u.isVis=false;u.vis.alpha=0;}
               started=getTimer()-4500;return;
            }
            tested=true;
            var carrier:Object=m.main.getChildByName("RVExplorationAPI");
            check(carrier!=null && carrier.api.active(b.loc)===true,"real RV dark-room path active");
            check(enemies.length==3,"three native enemy types available after TCP replication");
            for each(u in enemies) {
               var changed:int=scenePixels(b,u);
               Log.d("PRESENT sample enemy="+u.id+" alpha="+u.vis.alpha+" invis="+u.invis+" isVis="+u.isVis+" visible="+u.vis.visible+" parent="+(u.vis.parent!=null)+" mask="+u.vis.mask+" isolated="+EnemyRegression.pixels(u.vis)+" composite="+changed);
               if(!host) check(changed>30,"enemy contributes final scene pixels: "+u.id);
            }
            var watched:int=0, missing:int=0,closed:Boolean=false;
            var watchStart:int=getTimer();
            var watch:Function=function(frame:Event):void {
               if(host) return;
               if(scenePixels(b,enemies[watched%enemies.length],false)<30) missing++;
               watched++;
               if(watched>=15) closeWatch(null);
            };
            m.stage.addEventListener(Event.RENDER,watch,false,-30000);
            var invalidator:Function=function(frame:Event):void {m.stage.invalidate();};
            m.stage.addEventListener(Event.ENTER_FRAME,invalidator);
            var window:Timer=new Timer(host?100:12000,1);
            var closeWatch:Function=function(done:TimerEvent):void {
               if(closed) return;closed=true;window.stop();
               m.stage.removeEventListener(Event.RENDER,watch);m.stage.removeEventListener(Event.ENTER_FRAME,invalidator);
               if(!host) {Log.d("PRESENT sample final-render frames="+watched+" missing="+missing+" elapsedMs="+(getTimer()-watchStart));check(watched>=15 && missing==0,"enemies remain visible at consecutive final render boundaries");}
               var next:Timer=new Timer(100,1);next.addEventListener(TimerEvent.TIMER,function(e:TimerEvent):void {peerFrames(m);});next.start();
            };
            window.addEventListener(TimerEvent.TIMER,closeWatch);window.start();
         } catch(err:Error) { tested=true;clock.stop();Log.d("COOP FAIL presentation "+err.getStackTrace()); }
      }
      private function scenePixels(b:GameBridge,u:Object,save:Boolean=true):int {
         var root:DisplayObject=b.main as DisplayObject;
         var rect:Rectangle=u.vis.getBounds(root);rect.inflate(4,4);
         rect=rect.intersection(new Rectangle(0,0,root.stage.stageWidth,root.stage.stageHeight));
         if(rect.width<1 || rect.height<1 || rect.width>1000 || rect.height>1000) return 0;
         var a:BitmapData=new BitmapData(Math.ceil(rect.width),Math.ceil(rect.height),false,0);
         var z:BitmapData=a.clone();
         var matrix:Matrix=new Matrix(1,0,0,1,-rect.x,-rect.y);
         a.draw(root,matrix);
         var visible:Boolean=u.vis.visible;
         u.vis.visible=false;z.draw(root,matrix);u.vis.visible=visible;
         var av:Vector.<uint>=a.getVector(a.rect), zv:Vector.<uint>=z.getVector(z.rect), n:int=0;
         for(var i:int=0;i<av.length;i++) if(av[i]!=zv[i]) n++;
         if(save) {
            var out:FileStream=new FileStream();
            out.open(File.applicationStorageDirectory.resolvePath("presentation-"+u.id+".png"),FileMode.WRITE);
            out.writeBytes(a.encode(a.rect,new PNGEncoderOptions()));out.close();
         }
         a.dispose();z.dispose();return n;
      }
      private function peerFrames(m:RConnectMod):void {
         var motion:RemoteMotion=new RemoteMotion();
         motion.push({x:100,y:100,aimX:150,aimY:100},0);
         motion.push({x:160,y:100,aimX:210,aimY:100},200);
         var midpoint:Object=motion.sample(300);
         check(midpoint.x==130 && midpoint.aimX==180,"position and aim share continuous presentation time");
         check(motion.sample(2000).x==160,"delayed connection holds last known endpoint");
         motion.push({x:1000,y:500,aimX:1100,aimY:500},2100);
         check(motion.sample(2100).x==1000,"teleport snaps without sweeping across the room");
         bridge=new GameBridge({stage:m.stage,loaderInfo:m.main.loaderInfo});
         bridge.world=m.game.world;bridge.loc=m.game.loc;bridge.gg=m.game.gg;bridge.ghostCombat=false;
         var snap:Object=bridge.readSnapshot();
         for each(var label:Object in bridge.gg.vis.osn.currentLabels) if(label.name=="run") snap.poseFrame=label.frame;
         snap.pose="run";snap.bodyFrame=1;snap.bodyPlaying=true;snap.x+=40;snap.dx=0;snap.dy=0;
         bridge.updateRemote(993,snap,"FrameProbe");
         var g:Object=bridge.getRemoteGhost(993);
         var warm:Timer=new Timer(200,1);
         warm.addEventListener(TimerEvent.TIMER,function(ev:TimerEvent):void {
            var first:Number=g.X;snap.x+=60;bridge.updateRemote(993,snap,"FrameProbe");
            check(Math.abs(g.X-first)<1,"remote position does not jump to new packet endpoint");
            var positions:Object={}, frames:Object={}, count:int=0;
            var onFrame:Function=function(frame:Event):void {
               positions[String(g.X)]=true;frames[String(g.vis.osn.body.currentFrame)]=true;count++;
            };
            m.stage.addEventListener(Event.ENTER_FRAME,onFrame,false,-20000);
            var window:Timer=new Timer(240,1);
            window.addEventListener(TimerEvent.TIMER,function(done:TimerEvent):void {
               m.stage.removeEventListener(Event.ENTER_FRAME,onFrame);
               var pc:int=0,fc:int=0;for(var k:String in positions) pc++;for(k in frames) fc++;
               Log.d("PRESENT sample between-packets frames="+count+" positions="+pc+" bodyFrames="+fc+" totalFrames="+g.vis.osn.body.totalFrames);
               check(count>=3 && pc>=3,"remote moves on frames between network packets");
               check(fc>=3,"remote animation advances between network packets");
               snap.bodyPlaying=false;snap.bodyFrame=3;bridge.updateRemote(993,snap,"FrameProbe");
               var stopped:Timer=new Timer(200,1);
               stopped.addEventListener(TimerEvent.TIMER,function(stop:TimerEvent):void {
                  Log.d("PRESENT sample stopped frame="+g.vis.osn.body.currentFrame+" playing="+g.vis.osn.body.isPlaying);
                  check(g.vis.osn.body.currentFrame==3 && !g.vis.osn.body.isPlaying,"authoritative stopped animation stays stopped");
                  bridge.endSession();cadence(m);
               });stopped.start();
            });window.start();
         });warm.start();
      }
      private function cadence(m:RConnectMod):void {
         var carrier:Object=m.main.getChildByName("RVExplorationAPI");
         if(carrier==null) {check(false,"RV fixture available for exploration cadence");finish();return;}
         var api:Object=carrier.api, original:Function=api.capture;
         var rows:Array=ExplorationSync.nativeRows(m.game.loc);
         rows[0]=new Array(int(m.game.loc.spaceX)*17+1).join("0");
         var sequence:int=0;
         // Deterministic newly explored cells. The real packet/throttle/validation path runs unchanged.
         api.capture=function(loc:Object):Array {
            var data:Array=rows.concat();
            var index:int=(sequence++%Math.min(200,data[0].length/17))*17;
            data[0]=data[0].substr(0,index)+"fffffffffffffffff"+data[0].substr(index+17);
            return data;
         };
         var millis:int=0;
         var sync:ExplorationSync=new ExplorationSync(m,function():int{return millis;}), sent:int=0, costs:int=0;
         var wireBytes:int=0,fullBytes:int=0,first:int=getTimer(),previous:int=-1,gaps:Array=[];
         sync.resetLink();
         try { for(millis=0;millis<1000;millis+=50) {
            var at:int=getTimer();var packet:Object=sync.packet();costs+=getTimer()-at;
            if(packet!=null) {
               sent++;wireBytes+=JSON.stringify(packet).length;
               if(previous>=0) gaps.push(millis-previous);previous=millis;
               if(packet.rows!=null) fullBytes=JSON.stringify(packet).length;
            }
         }} finally {api.capture=original;}
         Log.d("PRESENT sample exploration packets="+sent+" logicalMs=1000 elapsedMs="+(getTimer()-first)+" gaps="+gaps.join(",")+" totalCaptureMs="+costs+" bytes="+wireBytes+" fullEquivalent="+(fullBytes*sent));
         check(sent==10,"continuous exploration published ten times per logical second");
         check(wireBytes<fullBytes*sent*0.5,"row deltas halve traffic during continuous changes");
         finish();
      }
      private function finish():void {clock.stop();Log.d("COOP PRESENTATION DONE "+(host?"host":"join"));}
   }
}

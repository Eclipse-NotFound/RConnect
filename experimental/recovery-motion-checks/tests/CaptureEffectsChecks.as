package {
   import flash.desktop.NativeApplication;
   import flash.display.*;
   import flash.events.Event;
   import flash.filesystem.*;
   import flash.utils.getTimer;
   import flash.utils.ByteArray;
   import flash.utils.setTimeout;
   import fe.unit.Unit;
   import fe.weapon.Bullet;
   import rconnect.game.*;
   import rconnect.net.BinaryMessageCodec;

   /** Real collection/serialization/receiver classes, with native simulation,
    * artwork and adjacent effect collectors explicitly replaced by fixtures. */
   public class CaptureEffectsChecks extends Sprite {
      private var rows:Array=[],failed:int=0,label:String="";
      public function CaptureEffectsChecks() {addEventListener(Event.ADDED_TO_STAGE,start);}
      private function check(ok:Boolean,text:String):void {
         rows.push({passed:ok,label:label+": "+text});if(!ok)failed++;
         trace((ok?"PASS ":"FAIL ")+label+": "+text);
      }
      private function start(e:Event):void {
         removeEventListener(Event.ADDED_TO_STAGE,start);
         for each(var test:Function in [mixed,incremental,beamShape,sameStamp,emptyAndEnd,switched,dead,deadClock,ordinaryEnd,slowOrdinary,impact,lateImpact,gap]) {
            try {test();}catch(error:Error){check(false,"uncaught "+error.getStackTrace());}
         }
         try {retention();}catch(error:Error){check(false,"retention setup "+error.getStackTrace());finish();}
      }
      private function finish():void {
         var out:FileStream=new FileStream();out.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         out.writeUTFBytes(JSON.stringify({passed:failed==0,failed:failed,assertions:rows,
            realCapture:true,realCodec:true,realReceiver:true,nativeGame:false,tcpSocket:false}));out.close();
         NativeApplication.nativeApplication.exit(failed?1:0);
      }
      private function scene():Object {
         var s:Object={p:new UnitPresentation(),v:new ProjectileVisuals(),clock:new CaptureClock(),layer:new Sprite()};
         addChild(s.layer);s.loc={units:[],firstObj:null,getAbsTile:function(x:Number,y:Number):Object{return {phis:0};}};
         var u:Unit=new Unit();u.loc=s.loc;u.X=0;u.Y=0;u.fraction=0;u.sost=1;u.childObjs=[];u.currentWeapon=null;
         s.u=u;s.loc.units=[u];
         s.main={loaderInfo:{applicationDomain:{getDefinition:function(n:String):Object {
            return n=="fe.World"?{w:{grafon:{visObjs:[null,null,s.layer]}}}:Sprite;
         }}}};
         return s;
      }
      private function gun(s:Object,id:String="test"):Object {
         var w:Object={id:id,variant:0,owner:s.u,loc:s.loc,kol_shoot:0,b:null,hold:100,rashod:1,
            X:0,Y:0,rot:0,t_prep:0,t_reload:0,rapid:2,fixtureImpacts:[]};
         s.u.currentWeapon=w;s.u.childObjs=[w];return w;
      }
      private function shot(s:Object,w:Object,recorded:Boolean,attached:Boolean=true,visual:Boolean=true):Bullet {
         var b:Bullet=new Bullet();b.weap=w;b.loc=s.loc;b.nobj=s.loc.firstObj;s.loc.firstObj=b;
         b.in_chain=true;b.babah=false;b.isExpl=false;b.explRadius=0;b.flame=0;b.spring=recorded?2:1;
         b.begx=0;b.begy=0;b.X=0;b.Y=0;b.dx=10;b.dy=0;b.ddy=0;b.rot=0;b.vel=10;
         if(visual) {b.vis=new Sprite();if(attached)addChild(b.vis);}
         w.b=b;w.kol_shoot++;w.hold--;return b;
      }
      private function wire(guns:Array):Array {
         if(guns==null)return null;
         var bytes:ByteArray=BinaryMessageCodec.pack({type:"worldstate",enemyMotion:[{effects:guns}]});
         check(bytes!=null,"actual binary codec accepts collection output");
         var packet:Object=BinaryMessageCodec.unpack(bytes);
         check(packet!=null,"actual binary codec decodes collection output");
         return packet==null?null:packet.enemyMotion[0].effects as Array;
      }
      private function receive(s:Object,guns:Array):void {s.v.receive(s.u,wire(guns),s.main,false,s.clock);}
      private function first(guns:Array):Object {return guns!=null&&guns.length&&guns[0].events.length?guns[0].events[0]:null;}
      private function cleanup(s:Object):void {s.v.reset();s.p.reset();while(numChildren)removeChildAt(0);}

      private function mixed():void {
         label="ordinary and recorded sequence";var s:Object=scene(),w:Object=gun(s);
         shot(s,w,false);s.p.observe(s.loc,1000);shot(s,w,true);s.p.observe(s.loc,1050);
         var rows:Array=s.p.captureEffects(s.u),events:Array=rows[0].events;
         check(events.length==2&&events[0].seq==1&&events[1].seq==2,"ordinary event is not skipped before a higher recorded sequence");
         check(events[0].flight!=null&&events[1].flight.frames is Array,"ordinary event remains present when another native-frame event follows it");
         receive(s,rows);check(s.v.count==2,"both event identities reach the real receiver");
         check(s.p.captureEffects(s.u)==null,"unchanged observations are not emitted every fast tick");cleanup(s);
      }
      private function incremental():void {
         // Ordinary moving bullets interpolate their confirmed positions.
         // spring=2 is a beam shape and intentionally does not use this rule.
         label="incremental plus full repair";var s:Object=scene(),w:Object=gun(s),b:Bullet=shot(s,w,false);
         s.p.observe(s.loc,1000);var early:Array=s.p.captureEffects(s.u);receive(s,early);
         b.vis.x=100;s.p.observe(s.loc,1050);var later:Array=s.p.captureEffects(s.u);receive(s,later);
         s.clock.time=1025;s.v.tick(s.loc,getTimer());check(s.layer.numChildren==1&&s.layer.getChildAt(0).x==50,"confirmed brackets survive real capture and codec");
         receive(s,s.p.capture(s.u));receive(s,later);s.v.tick(s.loc,getTimer());
         check(s.v.count==1&&s.layer.numChildren==1&&s.layer.getChildAt(0).x==50,"ordered full repair and duplicate delta neither respawn nor rewind");
         s.v.setPaused(true);var x:Number=s.layer.getChildAt(0).x;b.vis.x=200;s.p.observe(s.loc,1100);receive(s,s.p.captureEffects(s.u));
         s.v.tick(s.loc,getTimer()+100);check(s.layer.getChildAt(0).x==x,"paused playback remains fixed while its source cursor is held");
         s.v.setPaused(false);s.clock.time=1075;s.v.tick(s.loc,getTimer()+150);
         check(s.layer.getChildAt(0).x==150,"resume consumes confirmed samples using the same cursor");cleanup(s);
      }
      private function beamShape():void {
         label="authored beam shape remains discrete";var s:Object=scene(),w:Object=gun(s),b:Bullet=shot(s,w,true);
         b.vis.x=10;s.p.observe(s.loc,1000);receive(s,s.p.captureEffects(s.u));
         b.vis.x=110;s.p.observe(s.loc,1050);receive(s,s.p.captureEffects(s.u));
         s.clock.time=1025;s.v.tick(s.loc,getTimer());
         check(s.layer.numChildren==1&&s.layer.getChildAt(0).x==10,
            "spring=2 uses the actual current beam shape instead of blending its origin");
         s.clock.time=1050;s.v.tick(s.loc,getTimer());
         check(s.layer.numChildren==1&&s.layer.getChildAt(0).x==110,
            "beam switches to the next actual shape at its source stamp");cleanup(s);
      }
      private function sameStamp():void {
         label="final render correction at the same stamp";var s:Object=scene(),w:Object=gun(s),b:Bullet=shot(s,w,true);
         b.vis.x=10;s.p.observe(s.loc,1000);receive(s,s.p.captureEffects(s.u));
         b.vis.x=20;b.vis.scaleX=-1;b.vis.alpha=.5;s.p.observeFinal(s.loc,1000);var patch:Array=s.p.captureEffects(s.u),event:Object=first(patch);
         var point:Object=event!=null&&event.flight.frames.length?event.flight.frames[event.flight.frames.length-1]:null;
         check(point!=null&&point.x==20&&point.sx==-1&&point.a==.5,
            "corrected final sample is sent before the cumulative repair");
         if(patch!=null)receive(s,patch);s.clock.time=1000;s.v.tick(s.loc,getTimer());
         check(s.layer.numChildren==1&&s.layer.getChildAt(0).x==20,"receiver displays the corrected native point");
         s.p.observeFinal(s.loc,1000);
         check(s.p.captureEffects(s.u)==null,"unchanged final observation at the same stamp does not create duplicate traffic");
         // Resolve the newer helper dynamically so the baseline still compiles
         // and reports a missing helper as a failed assertion, not a build error.
         var streamClass:Object=ProjectileFrameStream,compare:Function;
         try {compare=streamClass["samePoint"] as Function;}catch(unavailable:Error){}
         check(compare!=null && !compare({at:1000,f:1,lf:2},{at:1000,f:2,lf:2}) &&
            !compare({at:1000,f:2,lf:2},{at:1000,f:2,lf:3}),
            "real comparison distinguishes body and nested clip frame fields (synthetic point fixture)");cleanup(s);
      }
      private function emptyAndEnd():void {
         label="empty initial frame set and ending";var s:Object=scene(),w:Object=gun(s),b:Bullet=shot(s,w,true,false);
         s.p.observe(s.loc,1000);var initial:Array=s.p.captureEffects(s.u);check(first(initial).flight.frames.length==0,"detached native visual has no invented frames");
         receive(s,initial);s.clock.time=1000;s.v.tick(s.loc,getTimer());check(s.v.count==1&&s.layer.numChildren==0,"empty first packet retains identity without drawing");
         addChild(b.vis);b.vis.x=30;s.p.observe(s.loc,1050);receive(s,s.p.captureEffects(s.u));
         s.clock.time=1050;s.v.tick(s.loc,getTimer());check(s.layer.numChildren==1&&s.layer.getChildAt(0).x==30,"first actual display point creates the visual");
         removeChild(b.vis);b.in_chain=false;s.p.observe(s.loc,1100);var ending:Array=s.p.captureEffects(s.u);receive(s,ending);
         check(first(ending)!=null&&first(ending).flight.end==1100,"ending is sent even when it carries no new display frames");
         s.clock.time=1099;s.v.tick(s.loc,getTimer());check(s.layer.numChildren==1,"early arrival of ending does not end source lifetime early");
         s.clock.time=1100;s.v.tick(s.loc,getTimer());check(s.v.count==0&&s.layer.numChildren==0,"actual source ending retires exactly once");cleanup(s);
      }
      private function switched():void {
         label="switching away from a live projectile";var s:Object=scene(),w:Object=gun(s,"old"),b:Bullet=shot(s,w,true);
         s.p.observe(s.loc,1000);var old:Array=s.p.captureEffects(s.u),stream:int=old[0].stream;receive(s,old);
         gun(s,"new");b.vis.x=50;s.p.observe(s.loc,1050);s.p.beginCaptureBatch();
         var later:Array;try{later=s.p.captureEffects(s.u);}finally{s.p.endCaptureBatch();}
         check(later!=null&&later[0].id=="old"&&later[0].stream==stream,"historical weapon retains the original stream after switching");
         receive(s,later);s.clock.time=1050;s.v.tick(s.loc,getTimer());check(s.v.count==1,"switch does not duplicate the old projectile");cleanup(s);
      }
      private function dead():void {
         label="collector after source death";var s:Object=scene(),w:Object=gun(s),b:Bullet=shot(s,w,true);
         s.p.observe(s.loc,1000);receive(s,s.p.captureEffects(s.u));s.u.sost=3;b.vis.x=80;
         s.p.observe(s.loc,1050);var tail:Array=s.p.captureEffects(s.u);
         check(first(tail)!=null,"collector itself keeps a dead shooter's existing native flight");
         // GameBridge currently excludes dead sources from fast enemyMotion.
         // This component does not bypass that fact or claim end-to-end death coverage.
         receive(s,tail);s.clock.time=1050;s.v.tick(s.loc,getTimer());check(s.layer.getChildAt(0).x==80,"receiver retains the existing dead owner's flight");cleanup(s);
      }
      private function ordinaryEnd():void {
         label="ordinary projectile true endpoint";var s:Object=scene(),w:Object=gun(s),b:Bullet=shot(s,w,false);
         s.p.observe(s.loc,1000);receive(s,s.p.captureEffects(s.u));
         b.X=15;b.vis.x=15;b.babah=true;s.p.observe(s.loc,1050);var stopped:Array=s.p.captureEffects(s.u),event:Object=first(stopped);
         check(event!=null&&event.flight.stopAt==1050,"fast stream reports ordinary native hit/removal time");
         // The 200 ms repair must also update the existing ordinary event.
         receive(s,s.p.capture(s.u));s.clock.time=1025;s.v.tick(s.loc,getTimer()+25);
         check(s.layer.numChildren==1&&s.layer.getChildAt(0).x<15,"early terminal packet does not teleport to impact before source time");
         s.clock.time=1050;s.v.tick(s.loc,getTimer()+100);
         check(s.layer.numChildren==1&&s.layer.getChildAt(0).x==15,"known native endpoint overrides extrapolation through a hit enemy");
         b.in_chain=false;s.p.observe(s.loc,1100);receive(s,s.p.capture(s.u));s.clock.time=1100;s.v.tick(s.loc,getTimer()+150);
         check(s.v.count==0,"cumulative repair retires an existing ordinary event at native end");cleanup(s);
      }
      private function slowOrdinary():void {
         label="ordinary native steps at low FPS with a late endpoint";
         var s:Object=scene(),w:Object=gun(s),b:Bullet=shot(s,w,false);
         // Native Bullet.dx is per simulation step, not per wall-clock 1/30s.
         // Ten-pixel steps 100 ms apart must not become 30 pixels remotely.
         b.dx=10;b.X=b.vis.x=0;s.p.observe(s.loc,1000);receive(s,s.p.captureEffects(s.u));
         s.clock.time=1050;s.v.tick(s.loc,getTimer()+50);
         check(s.layer.numChildren==1&&s.layer.getChildAt(0).x==0,
            "without a confirmed next native sample ordinary flight does not extrapolate");
         b.X=b.vis.x=10;s.p.observe(s.loc,1100);receive(s,s.p.captureEffects(s.u));
         s.clock.time=1050;s.v.tick(s.loc,getTimer()+60);var firstX:Number=s.layer.getChildAt(0).x;
         check(firstX>=0&&firstX<=10&&Math.abs(firstX-5)<.001,
            "ten-pixel native step remains ten pixels despite a 100 ms source frame");
         b.X=b.vis.x=20;s.p.observe(s.loc,1200);receive(s,s.p.captureEffects(s.u));
         s.clock.time=1150;s.v.tick(s.loc,getTimer()+70);var secondX:Number=s.layer.getChildAt(0).x;
         check(secondX>=firstX&&secondX<=20&&Math.abs(secondX-15)<.001,
            "ordinary flight stays inside confirmed low-FPS segment");
         b.X=b.vis.x=30;b.babah=true;s.p.observe(s.loc,1300);var terminal:Array=s.p.captureEffects(s.u);
         // Delay only this terminal packet while other source samples move the
         // shared actor clock. The receiver must hold its known 20-pixel tip.
         s.clock.time=1250;s.v.tick(s.loc,getTimer()+80);var beforeEnd:Number=s.layer.getChildAt(0).x;
         check(beforeEnd>=secondX&&beforeEnd==20,"late endpoint cannot cause unconfirmed flight past the last received point");
         receive(s,terminal);s.v.tick(s.loc,getTimer()+90);var afterEnd:Number=s.layer.getChildAt(0).x;
         check(afterEnd>=beforeEnd&&afterEnd<=30&&Math.abs(afterEnd-25)<.001,
            "late true endpoint extends the confirmed segment without rescaling past flight backwards");
         s.clock.time=1300;s.v.tick(s.loc,getTimer()+100);
         check(s.layer.getChildAt(0).x==30,"ordinary terminal pose matches the actual native display point");
         b.in_chain=false;s.p.observe(s.loc,1350);receive(s,s.p.captureEffects(s.u));
         s.clock.time=1350;s.v.tick(s.loc,getTimer()+150);check(s.v.count==0,"late-endpoint case still ends at the native removal time");cleanup(s);
      }
      private function deadClock():void {
         label="death releases the removed unit motion clock";var s:Object=scene(),w:Object=gun(s),b:Bullet=shot(s,w,true);
         s.p.observe(s.loc,1000);receive(s,s.p.captureEffects(s.u));
         s.clock.time=1000;s.v.tick(s.loc,getTimer());s.u.sost=3;b.vis.x=80;
         s.p.observe(s.loc,1050);s.v.receive(s.u,wire(s.p.capture(s.u)),s.main,false,null);
         s.v.tick(s.loc,getTimer()+300);
         check(s.layer.numChildren==1&&s.layer.getChildAt(0).x==80,
            "existing projectile releases deleted actor clock when full state supplies null motion");
         b.in_chain=false;s.p.observe(s.loc,1100);s.v.receive(s.u,wire(s.p.capture(s.u)),s.main,false,null);
         s.v.tick(s.loc,getTimer()+300);
         check(s.v.count==0,"dead shooter's actual projectile ending is not held until stale timeout");cleanup(s);
      }
      private function impact():void {
         label="confirmed impact packet contract";var s:Object=scene(),w:Object=gun(s),b:Bullet=shot(s,w,true);
         s.p.observe(s.loc,1000);s.p.captureEffects(s.u);
         // The fixture collector is a deliberate boundary. This is a confirmed
         // event transport test, not evidence of real Bullet.popadalo matching.
         w.fixtureImpacts=[{id:7,cls:"fixture-impact",frames:[{at:1050,x:12,y:18}],end:0}];
         var full:Array=s.p.capture(s.u),fast:Array=s.p.captureEffects(s.u);
         check(full[0].impacts.length==1,"full capture includes the adjacent collector's confirmed event");
         check(fast!=null&&fast.length>0&&fast[0].impacts is Array&&fast[0].impacts.length==1,
            "confirmed impact can travel without another projectile sample or shot sequence");cleanup(s);
      }
      private function gap():void {
         label="a lower serial becomes drawable later";var s:Object=scene(),w:Object=gun(s),firstBullet:Bullet=shot(s,w,false,true,false);
         s.p.observe(s.loc,1000);shot(s,w,true);s.p.observe(s.loc,1050);receive(s,s.p.captureEffects(s.u));
         firstBullet.vis=new Sprite();addChild(firstBullet.vis);s.p.observe(s.loc,1100);
         var late:Array=s.p.captureEffects(s.u);check(first(late)!=null&&first(late).seq==1,"real collector retries a prior event whose visual was absent");
         receive(s,late);check(s.v.count==2,"receiver does not confuse an unseen lower serial with a duplicate");cleanup(s);
      }
      private function lateImpact():void {
         label="confirmed lower-serial impact with no visual";var s:Object=scene(),w:Object=gun(s),b:Bullet=shot(s,w,false,true,false);
         s.p.observe(s.loc,1000);shot(s,w,true);s.p.observe(s.loc,1050);receive(s,s.p.captureEffects(s.u));
         b.fixtureImpact={groups:[{kind:"fixture",count:1}],x:10,y:20};b.babah=true;b.in_chain=false;
         s.p.observe(s.loc,1100);var packet:Array=s.p.captureEffects(s.u),event:Object=first(packet);
         check(event!=null&&event.seq==1&&event.flight==null&&event.impact!=null,"confirmed hit is transmitted without requiring a surviving clip");
         var before:int=BallisticImpactVisuals.played.length;receive(s,packet);receive(s,packet);
         s.clock.time=1099;s.v.tick(s.loc,getTimer());check(BallisticImpactVisuals.played.length==before,"confirmed hit waits for the source event time");
         s.clock.time=1100;s.v.tick(s.loc,getTimer());check(BallisticImpactVisuals.played.length==before+1,"lower-serial impact survives flight high-water filtering and plays once");cleanup(s);
      }
      private function retentionScene(sendEnd:Boolean,connected:Boolean=true):Object {
         var s:Object=scene(),live:Object=gun(s,"live"),b:Bullet=shot(s,live,false);
         s.p.retainUnsent=connected;
         s.p.observe(s.loc,Math.max(1,getTimer()));
         var ending:Object=gun(s,"retire"),gone:Bullet=shot(s,ending,false);
         s.p.observe(s.loc,Math.max(1,getTimer()));
         gone.in_chain=false;removeChild(gone.vis);
         s.p.observe(s.loc,Math.max(1,getTimer()));
         if(sendEnd)s.p.capture(s.u);
         return s;
      }
      private function eventFor(guns:Array,id:String):Object {
         for each(var g:Object in guns)if(g.id==id && g.events.length>0)return g.events[0];
         return null;
      }
      /** Use real getTimer passage: no replacement production clock or private
       * hostShots mutation. This adds ~15 seconds idle wait to the component. */
      private function retention():void {
         label="native event retention";
         var unsent:Object=retentionScene(false),sent:Object=retentionScene(true),grace:Object=retentionScene(false),offline:Object=retentionScene(false,false);
         setTimeout(function():void {
            label="native event retention";
            try {
               sent.p.observe(sent.loc,getTimer());
               check(eventFor(sent.p.capture(sent.u),"retire")==null,
                  "terminal event is retired 800 ms after its end was transmitted");
               grace.p.observe(grace.loc,getTimer());
               check(eventFor(grace.p.capture(grace.u),"retire")!=null,
                  "connected untransmitted terminal event survives the 700 ms boundary");
               offline.p.observe(offline.loc,getTimer());
               check(eventFor(offline.p.capture(offline.u),"retire")==null,
                  "with no peer an untransmitted terminal event retires after 700 ms");
            }catch(error:Error){check(false,"retention 800 ms "+error.getStackTrace());}
         },800);
         setTimeout(function():void {
            label="native event retention";
            try {
               unsent.p.observe(unsent.loc,getTimer());var packet:Array=unsent.p.capture(unsent.u);
               check(eventFor(packet,"retire")==null,
                  "connected terminal event never transmitted retires after 15 seconds");
               var live:Object=eventFor(packet,"live");
               check(live!=null&&live.flight!=null&&live.flight.end==0,
                  "native projectile still alive after 15 seconds is retained regardless of birth time");
               offline.p.observe(offline.loc,getTimer());live=eventFor(offline.p.capture(offline.u),"live");
               check(live!=null&&live.flight!=null&&live.flight.end==0,
                  "offline live native projectile is also retained beyond the terminal cleanup window");
            }catch(error:Error){check(false,"retention 15 seconds "+error.getStackTrace());}
            cleanup(unsent);cleanup(sent);cleanup(grace);cleanup(offline);finish();
         },15200);
      }
   }
}
import rconnect.game.RemoteMotion;
class CaptureClock extends RemoteMotion {
   public var time:Number=1000;
   override public function get sourceTime():Number {return time;}
}

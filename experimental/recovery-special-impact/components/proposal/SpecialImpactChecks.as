package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.utils.ByteArray;
   import flash.utils.getTimer;
   import fe.unit.Unit;
   import fe.weapon.Bullet;
   import rconnect.game.*;
   import rconnect.net.BinaryMessageCodec;

   /** Shared unchanged by old/new runs. Real capture, recipe, queue, codec and
    * receiver; native simulation, resources and adjacent collectors are mocks. */
   public class SpecialImpactChecks extends Sprite {
      private var rows:Array=[],failed:int=0,label:String="";
      public function SpecialImpactChecks() {addEventListener(Event.ADDED_TO_STAGE,start);}
      private function check(ok:Boolean,text:String):void {
         rows.push({passed:ok,label:label+": "+text});if(!ok)failed++;
         trace((ok?"PASS ":"FAIL ")+label+": "+text);
      }
      private function start(e:Event):void {
         removeEventListener(Event.ADDED_TO_STAGE,start);
         for each(var test:Function in [dummyFast,repairOnly,visibleDedup,lateLowerSerial,independentKinds,
               lateVisual,switchedAndDead,unconfirmed,pauseAndRoom,invalidAndLegacy,queueBounds]) {
            try {test();}catch(error:Error){check(false,"uncaught "+error.getStackTrace());}
         }
         var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         f.writeUTFBytes(JSON.stringify({passed:failed==0,failed:failed,assertions:rows,
            realCapture:true,realCodec:true,realReceiver:true,realExplosionRecipe:true,
            nativeGame:false,tcpSocket:false,groundAndAdjacentCollectorsAreMocks:true}));f.close();
         NativeApplication.nativeApplication.exit(failed?1:0);
      }
      private function scene():Object {
         BallisticImpactVisuals.reset();
         var s:Object={p:new UnitPresentation(),v:new ProjectileVisuals(),clock:new SpecialClock(),layer:new Sprite(),emits:[],sounds:[]};
         addChild(s.layer);s.loc={units:[],firstObj:null,getAbsTile:function(x:Number,y:Number):Object{return {phis:0};}};
         var u:Unit=new Unit();u.loc=s.loc;u.X=0;u.Y=0;u.fraction=0;u.sost=1;u.childObjs=[];u.currentWeapon=null;
         s.u=u;s.loc.units=[u];
         s.main={loaderInfo:{applicationDomain:{getDefinition:function(n:String):Object {
            if(n=="fe.World")return {w:{grafon:{visObjs:[null,null,s.layer]}}};
            if(n=="fe.graph.Emitter")return {emit:function(name:String,loc:Object,x:Number,y:Number,opts:Object=null):void {
               s.emits.push({name:name,loc:loc,x:x,y:y,opts:opts});
            }};
            if(n=="fe.Snd")return {ps:function(name:String,x:Number,y:Number):void {s.sounds.push({name:name,x:x,y:y});}};
            return Sprite;
         }}}};return s;
      }
      private function gun(s:Object,id:String="mswglau"):Object {
         var w:Object={id:id,variant:0,owner:s.u,loc:s.loc,kol_shoot:0,b:null,hold:100,rashod:1,
            X:0,Y:0,rot:0,t_prep:0,t_reload:0,rapid:2,fixtureImpacts:[],visexpl:""};
         s.u.currentWeapon=w;s.u.childObjs=[w];return w;
      }
      private function bullet(s:Object,w:Object,visual:Boolean,bindGun:Boolean=true):Bullet {
         var b:Bullet=new Bullet();b.weap=w;b.owner=s.u;b.loc=s.loc;b.nobj=s.loc.firstObj;s.loc.firstObj=b;
         b.in_chain=true;b.babah=false;b.isExpl=false;b.explRadius=0;b.flame=0;b.spring=1;
         b.begx=0;b.begy=0;b.X=72;b.Y=94;b.dx=10;b.dy=0;b.ddy=0;b.rot=0;b.vel=10;b.inWater=0;
         b.tipDamage=4;b.liv=100;b.vis=null;
         if(visual){b.vis=new Sprite();addChild(b.vis);}
         if(bindGun){w.b=b;w.kol_shoot++;w.hold--;}
         return b;
      }
      private function dummy(s:Object,w:Object):Bullet {
         var b:Bullet=bullet(s,w,false,false);b.isExpl=true;b.explRadius=120;b.liv=1;return b;
      }
      private function wire(guns:Array):Array {
         if(guns==null)return null;
         var bytes:ByteArray=BinaryMessageCodec.pack({type:"worldstate",enemyMotion:[{effects:guns}]});
         check(bytes!=null,"real binary codec accepts collection output");
         var p:Object=BinaryMessageCodec.unpack(bytes);check(p!=null,"real binary codec decodes collection output");
         return p==null?null:p.enemyMotion[0].effects as Array;
      }
      private function receive(s:Object,guns:Array,motion:RemoteMotion=null):void {
         s.v.receive(s.u,wire(guns),s.main,false,motion==null?s.clock:motion);
      }
      private function event(guns:Array,seq:int=-1):Object {
         for each(var g:Object in guns)for each(var e:Object in g.events)if(seq<0 || int(e.seq)==seq)return e;
         return null;
      }
      private function count(s:Object,name:String="expl"):int {
         var n:int=0;for each(var e:Object in s.emits)if(e.name==name)n++;return n;
      }
      private function tick(s:Object,time:Number):void {s.clock.time=time;s.v.tick(s.loc,getTimer());}
      private function clean(s:Object):void {s.v.reset();s.p.reset();while(numChildren)removeChildAt(0);}

      private function dummyFast():void {
         label="MSW-shaped no-clip detonation";var s:Object=scene(),w:Object=gun(s);
         var primary:Bullet=bullet(s,w,true);s.p.observe(s.loc,1000);s.p.captureEffects(s.u);
         var d:Bullet=dummy(s,w);s.p.observe(s.loc,1050);var fast:Array=s.p.captureEffects(s.u),e:Object=event(fast,2);
         check(w.b===primary && d!==primary && d.vis==null,"fixture is an independent real-class chain object, not Weapon.b");
         check(e!=null && e.flight==null && e.explosion!=null,"actual isExpl event survives absent display and empty frames");
         check(e!=null && e.explosion!=null && e.explosion.at==1050 && e.explosion.x==72 && e.explosion.y==94,
            "event retains the observed source time and location");
         receive(s,fast);tick(s,1049);check(count(s)==0,"early packet waits for the source display cursor");
         tick(s,1050);check(count(s)==1 && count(s,"flare")==1 && count(s,"iskr")==1 && s.sounds.length==1,
            "one confirmed ordinary explosion plays the original three emitter recipes and sound");
         check(s.v.count==1 && s.layer.numChildren==1,"only the original visible flight exists; no cosmetic projectile is invented for dummy");
         receive(s,fast);receive(s,s.p.capture(s.u));tick(s,1100);check(count(s)==1,"duplicate fast and cumulative repair do not replay detonation");
         check(s.p.captureEffects(s.u)==null,"unchanged no-clip detonation is not emitted on every fast tick");clean(s);
      }
      private function repairOnly():void {
         label="missed delta and disposed dummy";var s:Object=scene(),w:Object=gun(s),b:Bullet=dummy(s,w);
         s.p.observe(s.loc,1000);s.p.captureEffects(s.u); // Deliberately drop the fast packet.
         b.in_chain=false;s.loc.firstObj=null;s.p.observe(s.loc,1050);
         var full:Array=s.p.capture(s.u),e:Object=event(full);
         check(e!=null && e.flight==null && e.explosion!=null,"full repair retains an already-removed independent detonation");
         receive(s,full);tick(s,1100);check(count(s)==1,"full repair alone delivers the missed confirmed explosion");
         receive(s,full);tick(s,1150);check(count(s)==1,"repeated full repair remains idempotent");clean(s);
      }
      private function visibleDedup():void {
         label="visible projectile terminal compatibility";var s:Object=scene(),w:Object=gun(s),b:Bullet=bullet(s,w,true);
         s.p.observe(s.loc,1000);receive(s,s.p.captureEffects(s.u));
         b.isExpl=true;b.explRadius=120;b.in_chain=false;s.p.observe(s.loc,1050);
         var full:Array=s.p.capture(s.u),e:Object=event(full);check(e!=null && e.flight.explosion!=null,"existing flight explosion field remains on the wire");
         receive(s,full);receive(s,s.p.captureEffects(s.u));tick(s,1050);
         check(count(s)==1 && s.v.count==0,"terminal frame and independent queue share one explosion identity");
         receive(s,full);tick(s,1100);check(count(s)==1,"already-retired flight does not replay old explosion");clean(s);
      }
      private function lateLowerSerial():void {
         label="lower serial confirms later";var s:Object=scene(),w:Object=gun(s),b:Bullet=bullet(s,w,false,false);
         s.p.observe(s.loc,1000);bullet(s,w,true);s.p.observe(s.loc,1050);receive(s,s.p.captureEffects(s.u));
         b.isExpl=true;s.p.observe(s.loc,1100);var fast:Array=s.p.captureEffects(s.u),e:Object=event(fast,1);
         check(e!=null && e.explosion!=null,"lower unseen serial is retried when it really detonates");
         receive(s,fast);tick(s,1100);check(count(s)==1,"flight high-water state cannot discard a late confirmed explosion");clean(s);
      }
      private function independentKinds():void {
         label="impact and explosion share a shot";var s:Object=scene(),w:Object=gun(s),b:Bullet=dummy(s,w);
         b.babah=true;b.fixtureImpact={groups:[{kind:"fixture",count:1}],x:72,y:94};
         s.p.observe(s.loc,1000);var fast:Array=s.p.captureEffects(s.u);receive(s,fast);receive(s,s.p.capture(s.u));tick(s,1000);
         check(BallisticImpactVisuals.played.length==1,"confirmed ballistic fixture survives alongside same-sequence explosion");
         check(count(s)==1,"same-sequence ballistic event does not suppress explosion identity");
         receive(s,fast);tick(s,1050);check(count(s)==1 && BallisticImpactVisuals.played.length==1,"both kinds deduplicate independently");clean(s);
      }
      private function lateVisual():void {
         label="late visual after standalone explosion";var s:Object=scene(),w:Object=gun(s),b:Bullet=dummy(s,w);
         s.p.observe(s.loc,1000);receive(s,s.p.captureEffects(s.u));tick(s,1000);var firstCount:int=count(s);
         b.vis=new Sprite();addChild(b.vis);s.p.observe(s.loc,1050);receive(s,s.p.capture(s.u));tick(s,1050);
         check(firstCount==1,"no-clip event played before a display was attached");
         check(count(s)==1,"a later drawable record cannot play the same explosion a second time");clean(s);
      }
      private function switchedAndDead():void {
         label="old weapon and dead owner collection";var s:Object=scene(),w:Object=gun(s),b:Bullet=bullet(s,w,true);
         s.p.observe(s.loc,1000);s.p.captureEffects(s.u);gun(s,"lmg");s.u.sost=3;dummy(s,w);
         s.p.observe(s.loc,1050);var packet:Array=s.p.capture(s.u),found:Boolean=false;
         for each(var g:Object in packet)if(g.id=="mswglau")for each(var e:Object in g.events)
            if(e.flight==null && e.explosion!=null)found=g.effectsOnly===true;
         check(found,"full collector finds dummy on retained old weapon after owner death");
         receive(s,packet);tick(s,1050);check(count(s)==1,"receiver can play the retained weapon's explosion");
         // This does not claim that GameBridge sends fast enemyMotion for dead owners.
         clean(s);
      }
      private function unconfirmed():void {
         label="no inferred explosion";var s:Object=scene(),w:Object=gun(s),b:Bullet=bullet(s,w,false,false);
         b.babah=true;b.in_chain=false;b.explRadius=999;b.isExpl=false;
         s.p.observe(s.loc,1000);receive(s,s.p.capture(s.u));receive(s,s.p.captureEffects(s.u));tick(s,2000);
         check(count(s)==0 && s.sounds.length==0,"babah, removal and radius do not fabricate isExpl");
         b.isExpl=true;s.p.observe(s.loc,1050);receive(s,s.p.captureEffects(s.u));tick(s,1050);
         check(count(s)==1,"later actual native detonation remains eligible");clean(s);
      }
      private function pauseAndRoom():void {
         label="pause and room lifetime";var s:Object=scene(),w:Object=gun(s);dummy(s,w);s.p.observe(s.loc,1050);
         var packet:Array=s.p.captureEffects(s.u);receive(s,packet);s.v.setPaused(true);tick(s,1049);
         check(count(s)==0,"paused source cursor before event leaves detonation pending");
         s.v.setPaused(false);tick(s,1050);check(count(s)==1,"resume reaches pending source detonation once");
         s.v.reset();receive(s,packet);s.v.tick({},getTimer());tick(s,1050);
         check(count(s)==1,"leaving the location discards pending event without playing it later");
         s.v.reset();receive(s,packet);tick(s,1050);check(count(s)==2,"reset clears per-room receipt identities");clean(s);
      }
      private function envelope(seq:int,explosion:Object):Array {
         return [{id:"mswglau",variant:0,stream:1,sampleTime:1000,events:[{seq:seq,at:1000,flight:null,explosion:explosion}]}];
      }
      private function invalidAndLegacy():void {
         label="receiver validation and old field";var s:Object=scene();gun(s);
         // No codec here: invalid values are a receiver-boundary test, not wire syntax.
         s.v.receive(s.u,envelope(1,{at:NaN,x:72,y:94,type:4}),s.main,false,s.clock);
         s.v.receive(s.u,envelope(2,{at:1000,x:NaN,y:94,type:4}),s.main,false,s.clock);tick(s,1000);
         check(count(s)==0,"nonfinite timestamp or position never emits");
         receive(s,envelope(1,{at:1000,x:72,y:94,type:4}));receive(s,envelope(2,{at:1000,x:72,y:94,type:4}));tick(s,1000);
         check(count(s)==2,"invalid first payload does not poison later valid same-sequence identity");
         var old:Array=envelope(3,null);old[0].events[0].flight={cls:"missing-native-artwork",frames:[],end:1000,
            explosion:{at:1000,x:72,y:94,type:4}};
         receive(s,old);tick(s,1000);check(count(s)==3,"legacy flight.explosion plays even with zero frames");
         s.v.reset();receive(s,envelope(4,{at:1,x:72,y:94,type:4}));tick(s,15002);
         check(count(s)==3,"event beyond existing 15 second stale horizon is not replayed");clean(s);
      }
      private function queueBounds():void {
         label="bounded pending detonation queue";var s:Object=scene();gun(s);
         // This is the queue boundary test; codec coverage is exercised above.
         for(var i:int=1;i<=513;i++)s.v.receive(s.u,envelope(i,{at:1000,x:i,y:94,type:4}),s.main,false,s.clock);
         tick(s,1000);check(count(s)==512,"existing 512 pending-event cap also bounds independent explosions");
         var earliest:Number=Number.POSITIVE_INFINITY;for each(var e:Object in s.emits)if(e.name=="expl")earliest=Math.min(earliest,e.x);
         check(earliest==2,"overflow drops the oldest pending event without unbounded growth");clean(s);
      }
   }
}
import rconnect.game.RemoteMotion;
class SpecialClock extends RemoteMotion {
   public var time:Number=1000;
   override public function get sourceTime():Number {return time;}
}

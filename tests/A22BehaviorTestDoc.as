package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.display.MovieClip;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import fe.unit.Unit;
   import fe.unit.EnemyGrabProbe;
   import fe.unit.RConnectAnimationAccess;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;
   import rconnect.game.MirrorHitUnit;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;

   /** Exact production-byte probe. Real native control/throw/terrain collision;
    * the probe never injects a throw packet, impulse, damage or timer value. */
   public class A22BehaviorTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var mod:RConnectMod,host:Boolean,timer:Timer=new Timer(100),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=getTimer(),readyAt:int=0;
      private var bx:Number,by:Number,target:Object,raw:Object,round:int=0,acted:Boolean=false;
      private var peerReady:Boolean=false,localReady:Boolean=false;
      private var peerWings:Boolean=false,localWings:Boolean=false,peerDone:Boolean=false,localDone:Boolean=false;
      private var wings:Object={},bloat:Array=[],wire:Array=[],frames:Array=[];
      private var hpBefore:Number,releaseCount:int=0,observedThrow:int=0;
      private var beforeRelease:Object,lastRelease:Object;
      private var frameSerial:int=0,sampledSerial:int=-1;
      private const CASES:Array=["host-body","join-body","join-receiver","host-ai-horizontal","join-ai-horizontal"];
      public function A22BehaviorTestDoc() {
         var app:String=NativeApplication.nativeApplication.applicationID;
         if(app.indexOf("rconnect-coop-")<0)return;
         host=app.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();finish();
         });
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,s:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"a22-behavior "+s+" phase="+phase+" case="+CASES[round]);}
      private function change(s:String):void {phase=s;at=getTimer();}
      private function send(op:String,p:Object=null):void {
         p=p||{};p.type="a22-behavior-test";p.op=op;
         if(host)mod.session.server.broadcast(p);else mod.session.link.send(p);
      }
      private function watch(l:TcpLink):void {
         if(l==null||links[l])return;links[l]=true;
         l.addEventListener(TcpLink.MESSAGE,wireBefore,false,100);
         l.addEventListener(TcpLink.MESSAGE,receive);
         l.addEventListener(TcpLink.MESSAGE,wireAfter,false,-100);
      }
      private function wireBefore(e:NetMessageEvent):void {
         if(!host||target==null||e.data.type!="unit-grip"||e.data.op!="release")return;
         beforeRelease={x:target.dx,y:target.dy,t:target.t_throw};
      }
      private function wireAfter(e:NetMessageEvent):void {
         if(!host||beforeRelease==null||e.data.type!="unit-grip"||e.data.op!="release")return;
         lastRelease=JSON.parse(JSON.stringify(e.data));releaseCount++;
         wire.push({before:beforeRelease,after:{x:target.dx,y:target.dy,t:target.t_throw},message:lastRelease});
         beforeRelease=null;
      }
      private function find(id:String):Object {
         for each(var u:Object in mod.game.loc.units)if(!(u is MirrorHitUnit)&&u.id==id)return u;
         return null;
      }
      private function arena():Object {
         var l:Object=mod.game.loc;
         for(var y:int=240;y<Number(l.limY)-40;y+=40)for(var x:int=80;x<Number(l.limX)-320;x+=40) {
            var clear:Boolean=true;
            for(var xx:int=0;xx<=280&&clear;xx+=20) {
               if(l.getAbsTile(x+xx,y+1).phis!=1){clear=false;break;}
               for(var yy:int=20;yy<=200;yy+=20)if(l.getAbsTile(x+xx,y-yy).phis!=0){clear=false;break;}
            }
            if(clear)return {x:x,y:y};
         }
         throw new Error("No native floor for downward throw");
      }
      private function prepare():void {
         var a:Object=arena();bx=a.x;by=a.y;
         var c:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit.UnitBloat") as Class;
         for each(var variant:int in [1,8])for each(var restored:Boolean in [false,true]) {
            var u:Object=new c(String(variant),10,<unit/>,null);
            u.id="m52_bloat_"+variant+"_"+restored;u.putLoc(mod.game.loc,bx+160,by-160);
            mod.game.loc.addObj(u);mod.game.loc.units.push(u);u.disabled=true;u.xp=0;u.doop=true;bloat.push(u);
            var pose:Object=RConnectAnimationAccess.capture(u as Unit);
            Log.d("A22 FRESH CLIP "+JSON.stringify({id:u.id,frame:u.vis.osn.currentFrame,play:u.vis.osn.isPlaying,pose:pose}));
            // The same capture/receive calls used by an immediate room checkpoint.
            if(restored)RConnectAnimationAccess.receive(u as Unit,pose,String(u.animState));
         }
         c=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit.UnitRaider") as Class;
         target=new c("1",10,<unit weap="lmg"/>,null);target.id="m52_throw";
         target.putLoc(mod.game.loc,bx+100,by);mod.game.loc.addObj(target);mod.game.loc.units.push(target);
         target.controlOn=false;target.xp=0;target.doop=true;target.invulner=false;target.walk=0;
         // Keep the same living native body for all three throws. The ordinary
         // 50 HP fixture dies on the first 73-point impact and cannot be reused.
         target.hp=target.maxhp=1000;
         Log.d("A22 THROW NATIVE "+JSON.stringify({mass:target.massa,damWall:target.damWall,speed:target.damWallSpeed,hp:target.hp}));
         attach();change("wings");send("setup",{x:bx,y:by});
      }
      private function attach():void {
         mod.stage.addEventListener(Event.ENTER_FRAME,drive,false,100005);
         mod.stage.addEventListener(Event.ENTER_FRAME,afterControl,false,-7999);
         mod.stage.addEventListener(Event.RENDER,sample,false,-30000);
      }
      private function owner():Boolean {return round==0 || round==3?host:!host;}
      private function start(n:int):void {
         round=n;acted=false;raw=null;wire=[];frames=[];lastRelease=null;releaseCount=observedThrow=0;
         peerReady=localReady=peerDone=localDone=false;
         if(mod.game.gg.teleObj!=null)mod.game.gg.dropTeleObj();
         if(host) {
            target.setPos(bx+100,by);target.dx=target.dy=0;target.t_throw=0;target.levit_r=0;
            target.levitPoss=true;target.hp=target.maxhp;target.stun=0;target.levit=0;
            target.controlOn=round>=3;
         }
         change("settle");
      }
      private function grab():void {
         raw=target;
         if((round==2 || round==4)&&!host)for each(var u:Object in mod.game.loc.units)
            if(u is MirrorHitUnit&&MirrorHitUnit(u).body===target){raw=u;break;}
         if((round==2 || round==4)&&!host)check(raw is MirrorHitUnit,"use the actual cursor/collision receiver");
         raw.onCursor=1;mod.game.loc.celObj=raw;mod.game.loc.celDist=0;
         EnemyGrabProbe.grab(mod.game.gg);
         check(mod.game.gg.teleObj===raw,"native grab accepts selected object");
      }
      private function hold():void {if(owner())grab();change("hold");}
      private function advance():void {
         if(!host||!localDone||!peerDone)return;
         if(round+1<CASES.length){start(round+1);send("round",{round:round});}
         else {send("done");finish();}
      }
      private function drive(e:Event):void {
         frameSerial++;
         if(phase=="done"||phase=="boot"||mod.game.gg==null)return;
         var g:Object=mod.game.gg,b:Object=mod.game;
         b.forceCloseOverlays();g.invulner=true;g.dx=g.dy=0;g.isTake=0;g.work="";
         g.setPos(bx+(host?0:40),by-(round>=3?55:170));g.setVisPos();g.disabled=false;g.ctr.clearAll();
         b.loc.base=false;b.loc.portOn=true;
         g.pers.maxTeleMassa=1000;g.pers.teleDist=1000000;g.pers.telemaster=1;
         g.pers.unitLevitMult=100;g.pers.teleMult=1;g.pers.allDManaMult=1;g.pers.teleMana=0;g.pers.telePorog=0;
         g.pers.throwForce=35;g.pers.throwDmagic=2;g.pers.throwDmanaMult=0;g.pers.spellsPoss=1;
         g.maxmana=10000;if(phase=="settle")g.mana=10000;
         // Keep the held body above a real floor and below the caster. Native
         // throw aims away from the caster, then real gravity/run hits the floor.
         g.celX=b.world.celX=bx+(round>=3?160:120);g.celY=b.world.celY=by-(round>=3?100:65);b.loc.celDist=0;
         if(phase=="hold"&&owner()&&!acted&&getTimer()-at>1500) {
            acted=true;hpBefore=target.hp;g.ctr.keyAction=true;
            Log.d("A22 INPUT THROW "+JSON.stringify({raw:raw is MirrorHitUnit?"receiver":"body",hp:hpBefore,
               x:raw.X,y:raw.Y,dx:raw.dx,dy:raw.dy,t:raw.t_throw,mana:g.mana}));
         }
         mod.stage.invalidate();
      }
      private function afterControl(e:Event):void {
         if(phase!="hold"||target==null)return;
         if(target.t_throw>0)observedThrow++;
         if((acted&&owner() || host&&releaseCount>0)&&frames.length<30)frames.push({at:getTimer(),bodyT:target.t_throw,
            x:target.X,y:target.Y,bodyDX:target.dx,bodyDY:target.dy,hp:target.hp,levit:target.levit,
            rawT:raw==null?null:raw.t_throw,rawDX:raw==null?null:raw.dx,rawDY:raw==null?null:raw.dy,
            held:mod.game.gg.teleObj!=null});
      }
      private function sample(e:Event):void {
         if(phase!="wings"||sampledSerial==frameSerial)return;sampledSerial=frameSerial;
         for each(var variant:int in [1,8])for each(var restored:Boolean in [false,true]) {
            var id:String="m52_bloat_"+variant+"_"+restored,u:Object=find(id);
            if(u==null||u.vis==null||!(u.vis.osn is MovieClip))continue;
            var row:Object=wings[id];if(row==null)row=wings[id]={samples:0,changes:0,frames:{},last:-1};
            var f:int=u.vis.osn.currentFrame;row.samples++;if(f!=row.last)row.changes++;row.frames[f]=true;row.last=f;
         }
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;if(p.type!="a22-behavior-test")return;
         try {
            if(p.op=="done"){finish();return;}
            if(host&&phase=="boot"&&p.op=="ready")prepare();
            else if(!host&&p.op=="setup"){bx=p.x;by=p.y;attach();change("wings");}
            else if(host&&p.op=="wings-done")peerWings=true;
            else if(!host&&p.op=="round")start(int(p.round));
            else if(host&&p.op=="settled")peerReady=true;
            else if(!host&&p.op=="hold")hold();
            else if(host&&p.op=="round-done") {peerDone=true;advance();}
         }catch(error:Error){check(false,error.getStackTrace());send("done");finish();}
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null||mod.session==null||mod.game==null)return;
         if(phase=="boot"&&mod.game.gg!=null)mod.game.gg.invulner=true;
         if(host)for each(var peer:Object in mod.session.peers)watch(peer.link);else watch(mod.session.link);
         try {
            if(phase=="done")return;
            if(getTimer()-at>90000){check(false,"timeout");send("done");finish();return;}
            if(!mod.session.rooms.ready||mod.session.rooms.busy||mod.game.isTransitioning()||mod.game.gg==null)return;
            if(String(mod.game.readWorldInfo().curLandId)!="rbl")return;
            if(phase=="boot"&&!host&&getTimer()-readyAt>500){readyAt=getTimer();send("ready");}
            if(phase=="wings"&&getTimer()-at>4500) {
               Log.d("A22 WINGS "+JSON.stringify(wings));
               for each(var variant:int in [1,8])for each(var restored:Boolean in [false,true]) {
                  var id:String="m52_bloat_"+variant+"_"+restored,row:Object=wings[id];
                  check(row!=null&&row.samples>15&&row.changes>row.samples*.6,"flight keeps advancing "+id+" "+JSON.stringify(row));
               }
               target=find("m52_throw");check(target!=null,"native throw target exists");
               localWings=true;change("wings-done");if(!host)send("wings-done");
            }
            if(host&&phase=="wings-done"&&localWings&&peerWings){start(0);send("round",{round:0});}
            if(phase=="settle"&&getTimer()-at>1200&&!localReady) {
               target=find("m52_throw");localReady=target!=null;
               if(localReady){hpBefore=target.hp;check(target.damWall>0&&target.hp>0&&target.sost<3&&target.in_chain,
                  "native target is alive/in chain and can take wall damage");if(!host)send("settled");}
            }
            if(host&&phase=="settle"&&localReady&&peerReady){hold();send("hold");}
            if(phase=="hold"&&getTimer()-at>4500) {
               Log.d("A22 THROW FRAMES "+JSON.stringify(frames));Log.d("A22 THROW WIRE "+JSON.stringify(wire));
               if(owner())check(acted&&mod.game.gg.teleObj==null,"native action key actually releases the hold");
               if(round<3)check(target.hp<hpBefore,"native floor collision deals damage before="+hpBefore+" after="+target.hp);
               // A real collision may consume t_throw in the same frame. Check
               // the received native state before that collision, not only the
               // post-frame timer which legitimately becomes zero.
               if(host&&!owner())check(releaseCount==1&&lastRelease!=null&&lastRelease.kick!=null&&wire[0].after.t==45,
                  "exactly one throw reaches authority releases="+releaseCount+" armedFrames="+observedThrow);
               localDone=true;change("round-done");if(!host)send("round-done");else advance();
            }
         }catch(error:Error){check(false,error.getStackTrace());send("done");finish();}
      }
      private function finish():void {
         if(phase=="done")return;phase="done";timer.stop();
         if(mod!=null){mod.stage.removeEventListener(Event.ENTER_FRAME,drive);mod.stage.removeEventListener(Event.ENTER_FRAME,afterControl);mod.stage.removeEventListener(Event.RENDER,sample);}
         Log.d("COOP EFFECTS DONE a22-behavior "+(host?"host":"join"));
      }
   }
}

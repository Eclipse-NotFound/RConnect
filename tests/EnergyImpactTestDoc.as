package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.MovieClip;
   import flash.display.BitmapData;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.events.MouseEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.geom.Matrix;
   import flash.geom.Rectangle;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import flash.utils.getQualifiedClassName;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;
   import rconnect.game.MirrorHitUnit;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;

   /** Native Weapon.attack/step -> Bullet -> Part, with final rendered pixels
    * observed on both ends of real Session/TCP. No energy helper is imported:
    * the same driver also runs against the installed build as a negative control.
    */
   public class EnergyImpactTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private static const CASES:Array=[
         {id:"nova",actor:"host",target:"wall"},{id:"nova",actor:"join",target:"wall"},
         {id:"plam",actor:"host",target:"wall"},{id:"plam",actor:"join",target:"wall"},
         {id:"blaster",actor:"host",target:"unit"},{id:"blaster",actor:"join",target:"unit"},
         {id:"prism",actor:"host",target:"wall"},{id:"prism",actor:"join",target:"wall"},
         {id:"alilight",actor:"enemy",target:"wall"},
         {id:"plamg",actor:"host",target:"expiry"},{id:"plamg",actor:"join",target:"expiry"}];
      private static const CLIPS:Object={flPlasma:true,flPlasma2:true,flLaser:true,flLaser2:true,
         flSpark:true,flSparkl:true,flDray:true,visualTeleFlare:true,visualIceFlare:true};
      private var mod:RConnectMod,host:Boolean,timer:Timer=new Timer(100),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=getTimer(),readyAt:int=0,round:int=0;
      private var baseX:Number,baseY:Number,wallX:int,gun:Object,actor:Object,target:Object;
      private var oldGun:Object,oldChildren:Object,enemyActor:Object,shot:Boolean=false,localSource:Boolean=false;
      private var nativeObjects:Dictionary=new Dictionary(true),copies:Dictionary=new Dictionary(true),shots:Dictionary=new Dictionary(true);
      private var source:Array=[],remote:Array=[],sourcePixels:int=0,remotePixels:int=0,nativeShots:int=0;
      private var localResult:Object,peerResult:Object,compared:Boolean=false,peerDone:Boolean=false;
      private var localPrepared:Boolean=false,peerPrepared:Boolean=false,targetHp:Number=0,frames:int=0;

      public function EnergyImpactTestDoc() {
         var id:String=NativeApplication.nativeApplication.applicationID;
         if(id.indexOf("rconnect-coop-")<0)return;host=id.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();send("done");finish();
         });
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,label:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"energy-impact "+label+" case="+round);}
      private function send(stage:String,data:Object=null):void {
         data=data||{};data.type="energy-impact-test";data.stage=stage;data.round=round;
         if(host)mod.session.server.broadcast(data);else if(mod.session.link!=null)mod.session.link.send(data);
      }
      private function watch(link:TcpLink):void {if(link!=null && !links[link]) {links[link]=true;link.addEventListener(TcpLink.MESSAGE,receive);}}
      private function setup(x:Number,y:Number):void {
         baseX=x;baseY=y;wallX=int((baseX+280)/40);
         var g:Object=mod.game.gg;oldGun=g.currentWeapon;oldChildren=g.childObjs;
         mod.game.loc.black=false;mod.game.world.black=false;mod.game.loc.tileSpawn=0;
         mod.stage.addEventListener(Event.ENTER_FRAME,before,false,100000);
         mod.stage.addEventListener(Event.ENTER_FRAME,after,false,-6000);
         mod.stage.addEventListener(Event.RENDER,render,false,-30000);
      }
      private function prepare(n:int):void {
         round=n;phase="prepare";at=getTimer();shot=false;compared=peerDone=localPrepared=peerPrepared=false;
         source=[];remote=[];nativeObjects=new Dictionary(true);copies=new Dictionary(true);shots=new Dictionary(true);
         sourcePixels=remotePixels=nativeShots=frames=0;localResult=peerResult=null;
         cleanupGun();
         localSource=CASES[n].actor==(host?"host":"join") || (host && CASES[n].actor=="enemy");
         target=null;
         var loc:Object=mod.game.loc;
         if(host) {
            var layout:Array=[];
            for(var x:int=Math.max(1,int(baseX/40)-2);x<=Math.min(loc.spaceX-2,wallX+2);x++)
               for(var y:int=Math.max(1,int(baseY/40)-6);y<=Math.min(loc.spaceY-2,int(baseY/40));y++) {
                  var wall:Boolean=x==wallX && CASES[n].target!="expiry";
                  layout.push({x:x,y:y,p:wall?1:0,f:wall?"A":"",h:300,o:wall?1:0});
               }
            mod.game.applyTilePatch(layout);
            // Damage is disabled for fixture terrain, while the real material
            // still goes through native collision and Bullet.popadalo.
            for(y=Math.max(1,int(baseY/40)-6);y<=Math.min(loc.spaceY-2,int(baseY/40));y++) {
               loc.space[wallX][y].mat=2;loc.space[wallX][y].indestruct=true;loc.space[wallX][y].water=0;
            }
            if(CASES[n].target=="unit")target=spawn("UnitZombie","1",<unit tr="1" dig="0"/>,baseX+180);
            if(CASES[n].actor=="enemy")enemyActor=spawn("UnitAlicorn","1",<unit tr="1"/>,baseX);
            mod.game.readUnitsSnapshot();mod.game.readTilePatch();
            send("case",{layout:layout});
         }
         if(localSource) {
            actor=CASES[n].actor=="enemy"?enemyActor:mod.game.gg;
            var factory:Object=mod.main.loaderInfo.applicationDomain.getDefinition("fe.weapon.Weapon");
            gun=factory.create(actor,String(CASES[n].id),0);
            if(actor===mod.game.gg)gun.setPers(actor,actor.pers);
            actor.currentWeapon=gun;actor.childObjs=[gun];gun.addVisual();
            gun.hold=10000;gun.t_reload=0;gun.precision=0;gun.deviation=0;gun.recoil=0;gun.recoilUp=0;
            gun.lvl=0;gun.perslvl=0;
            gun.skillConf=1;gun.damage=10;gun.destroy=0;gun.damageExpl=0;gun.critCh=0;gun.dopCh=0;
            check(gun.vis!=null && gun.vis.stage!=null,"real "+CASES[n].id+" weapon staged with "+gun.kol+" native projectiles");
         }
      }
      private function spawn(name:String,id:String,xml:XML,x:Number):Object {
         var cls:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit."+name) as Class;
         var u:Object=new cls(id,100,xml,null);u.putLoc(mod.game.loc,x,baseY);mod.game.loc.units.push(u);
         // Keep a real stationary native Unit in the collision list without
         // running its AI; this is a fixture target, not a second implementation.
         u.addVisual();u.setVisPos();u.hp=u.maxhp=54321+round;u.skin=0;u.armor=0;u.dexter=0;u.dodge=0;
         u.invulner=false;u.disabled=false;u.trigDis=false;u.doop=true;u.lootIsDrop=true;u.xp=0;
         u.scX=40;u.scY=80;u.setPos(x,baseY);u.animate();return u;
      }
      private function findTarget():Object {
         for each(var u:Object in mod.game.loc.units)
            if(!(u is MirrorHitUnit) && getQualifiedClassName(u)=="fe.unit::UnitZombie" && Number(u.maxhp)==54321+round)return u;
         return null;
      }
      private function begin():void {phase="run";at=getTimer();targetHp=target==null?0:Number(target.hp);}
      private function before(e:Event):void {
         if(phase=="done" || phase=="boot")return;
         var g:Object=mod.game.gg,w:Object=mod.game.world;
         g.setPos(baseX,baseY);g.dx=g.dy=0;g.disabled=true;g.invulner=true;g.storona=1;
         mod.game.forceCloseOverlays();w.testDam=true;
         for each(var u:Object in mod.game.loc.units) {
            if(u===g || u===target || u===enemyActor || u is MirrorHitUnit || String(u.id).indexOf("rconnect_ghost")==0)continue;
            u.disabled=true;
            // A disabled mirror body can still have a live collision receiver.
            // Move unrelated source enemies behind the muzzle; the setup wait
            // lets their authoritative positions arrive before the test shot.
            if(host) {u.setPos(baseX-60,baseY);u.dx=u.dy=0;u.setVisPos();}
         }
         if(target!=null && host) {target.disabled=false;target.dx=target.dy=0;target.setPos(baseX+180,baseY);target.setVisPos();}
         if(gun==null)return;
         actor.celX=baseX+500;actor.celY=baseY-40;
         if(actor===g) {
            w.celX=actor.celX;w.celY=actor.celY;
            w.cam.celX=int(w.celX*w.cam.scaleV+w.cam.vx);w.cam.celY=int(w.celY*w.cam.scaleV+w.cam.vy);
         } else {actor.storona=1;actor.setWeaponPos(gun.tip);}
         // alilight has native preparation time. Keep requesting the attack
         // until native Weapon.step actually creates a projectile.
         if(phase=="run" && !shot && getTimer()-at>1000) {gun.hold=10000;gun.t_reload=0;gun.attack();}
      }
      private function after(e:Event):void {
         if(phase=="done" || phase=="boot")return;
         if(gun!=null) {
            gun.step();
            for(var b:Object=mod.game.loc.firstObj;b!=null;b=b.nobj) {
               if(GameBridge.probe(b,"weap")!==gun || GameBridge.probe(b,"begx")==null || shots[b])continue;
               shots[b]=true;nativeShots++;b.miss=0;b.critCh=0;b.critInvis=0;b.desintegr=0;b.probiv=0;b.precision=0;
               if(CASES[round].target=="expiry")b.liv=1;
            }
            if(nativeShots>0)shot=true;
         }
         mod.stage.invalidate();
      }
      private function point(v:DisplayObject):Object {
         return {x:v.x,y:v.y,r:v.rotation,sx:v.scaleX,sy:v.scaleY,a:v.alpha,f:v is MovieClip?MovieClip(v).currentFrame:1};
      }
      private function record(map:Dictionary,list:Array,key:Object,v:DisplayObject):void {
         var s:Object=map[key];
         if(s==null) {s=map[key]={cls:getQualifiedClassName(v),first:getTimer()-at,last:0,frames:[]};list.push(s);}
         s.last=getTimer()-at;s.frames.push(point(v));
      }
      private function pixels(v:DisplayObject):int {
         if(v==null || !v.visible || v.stage==null || v.alpha<=0)return 0;
         var root:DisplayObject=mod.main as DisplayObject;
         var r:Rectangle=v.getBounds(root).intersection(new Rectangle(0,0,mod.stage.stageWidth,mod.stage.stageHeight));
         if(r.width<1 || r.height<1 || r.width*r.height>150000)return 0;
         var a:BitmapData=new BitmapData(Math.ceil(r.width),Math.ceil(r.height),false,0),b:BitmapData=a.clone();
         var m:Matrix=new Matrix(1,0,0,1,-r.x,-r.y);a.draw(root,m);v.visible=false;b.draw(root,m);v.visible=true;
         var av:Vector.<uint>=a.getVector(a.rect),bv:Vector.<uint>=b.getVector(b.rect),count:int=0;
         for(var i:int=0;i<av.length;i++)if(av[i]!=bv[i])count++;
         a.dispose();b.dispose();return count;
      }
      private function render(e:Event):void {
         if(phase!="run")return;frames++;
         var nativeVis:Dictionary=new Dictionary(true);
         for(var o:Object=mod.game.loc.firstObj;o!=null;o=o.nobj) {
            if(getQualifiedClassName(o)!="fe.graph::Part")continue;
            var v:DisplayObject=o.vis as DisplayObject;
            if(v==null || CLIPS[getQualifiedClassName(v)]!==true)continue;
            nativeVis[v]=true;
            if(v.visible && v.stage!=null) {record(nativeObjects,source,o,v);if(pixels(v)>0)sourcePixels++;}
         }
         for(var layerIndex:int=0;layerIndex<5;layerIndex++) {
            var layer:DisplayObjectContainer=mod.game.world.grafon.visObjs[layerIndex] as DisplayObjectContainer;
            if(layer==null)continue;
            for(var i:int=0;i<layer.numChildren;i++) {
               v=layer.getChildAt(i);
               if(nativeVis[v] || !v.visible || v.stage==null || CLIPS[getQualifiedClassName(v)]!==true)continue;
               record(copies,remote,v,v);if(pixels(v)>0)remotePixels++;
            }
         }
      }
      private function collect():void {
         phase="sampled";
         localResult={source:source,remote:remote,sourcePixels:sourcePixels,remotePixels:remotePixels,
            shots:nativeShots,frames:frames,kol:gun==null?0:int(gun.kol),loss:target==null?0:targetHp-Number(target.hp)};
         send("result",{result:localResult});compare();
      }
      private function distance(a:Object,b:Object):Number {
         return Math.max(Math.abs(a.x-b.x),Math.abs(a.y-b.y),Math.abs(a.r-b.r),
            Math.abs(a.sx-b.sx)*100,Math.abs(a.sy-b.sy)*100,Math.abs(a.f-b.f)*100,Math.abs(a.a-b.a)*100);
      }
      private function compare():void {
         if(compared || localResult==null || peerResult==null)return;compared=true;
         var nativeResult:Object=localSource?localResult:peerResult;
         var copyResult:Object=localSource?peerResult:localResult;
         var expected:Array=nativeResult.source as Array,actual:Array=copyResult.remote as Array;
         check(nativeResult.shots==nativeResult.kol && nativeResult.shots>0,"native attack creates all projectiles count="+nativeResult.shots+" expected="+nativeResult.kol);
         check(copyResult.source.length==0,"receiver never creates a native energy Part");
         if(CASES[round].target=="expiry") {
            check(expected.length==0 && actual.length==0,"unhit native expiry produces no invented flash");
         } else {
            check(expected.length==nativeResult.shots && nativeResult.sourcePixels>0,"real native impacts render pixels count="+expected.length+" pixels="+nativeResult.sourcePixels);
            var intended:Boolean=expected.length>0;
            for each(var hit:Object in expected) {
               var hitX:Number=Number(hit.frames[0].x);
               if(CASES[round].target=="wall")intended=intended && hitX>=wallX*40 && hitX<=(wallX+1)*40;
               else intended=intended && hitX>=baseX+160 && hitX<=baseX+200;
            }
            check(intended,"native effects originate at the intended "+CASES[round].target+" collision");
            check(actual.length==expected.length && actual.length>0,"every impact appears exactly once across TCP actual="+actual.length+" expected="+expected.length);
            check(copyResult.remotePixels>0,"remote impact contributes actual final game pixels="+copyResult.remotePixels);
            var wrong:int=0,progressed:int=0,maxError:Number=0;
            for each(var a:Object in actual) {
               var changed:Boolean=false,first:int=int(a.frames[0].f);
               for each(var pa:Object in a.frames) {
                  if(int(pa.f)!=first)changed=true;
                  var best:Number=1e9;
                  for each(var b:Object in expected)if(a.cls==b.cls)for each(var pb:Object in b.frames)best=Math.min(best,distance(pa,pb));
                  maxError=Math.max(maxError,best);if(best>.05)wrong++;
               }
               if(changed)progressed++;
               check(a.last<2600,"effect expires without a frozen clip last="+a.last);
            }
            check(actual.length>0 && wrong==0,"native impact position/scale/frame retained wrong="+wrong+" maxError="+maxError);
            var nativeProgress:int=0;
            for each(b in expected) {first=int(b.frames[0].f);for each(pb in b.frames)if(int(pb.f)!=first) {nativeProgress++;break;}}
            check(progressed>=nativeProgress,"short impact animation advances source="+nativeProgress+" remote="+progressed);
            if(CASES[round].target=="unit") {
               check(nativeResult.loss>0,"real source projectile damages the fixture enemy loss="+nativeResult.loss);
               check(Math.abs(localResult.loss-peerResult.loss)<.01,"display replay adds no second damage local="+localResult.loss+" peer="+peerResult.loss);
            }
         }
         Log.d("ENERGY IMPACT METRIC "+JSON.stringify({role:host?"host":"join",round:round,scenario:CASES[round],local:localResult,peer:peerResult}));
         send("compared");advance();
      }
      private function advance():void {
         if(!host || !compared || !peerDone)return;
         if(round+1<CASES.length)prepare(round+1);else {send("done");finish();}
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;if(p.type!="energy-impact-test")return;
         try {
            if(p.stage=="ready" && host && phase=="boot") {
               setup(Math.max(120,Math.min(mod.game.gg.X,mod.game.loc.spaceX*40-600)),mod.game.gg.Y);
               send("setup",{x:baseX,y:baseY});prepare(0);
            } else if(p.stage=="setup" && !host && phase=="boot")setup(p.x,p.y);
            else if(p.stage=="case" && !host) {
               prepare(int(p.round));mod.game.applyTilePatch(p.layout as Array);
               for(var y:int=Math.max(1,int(baseY/40)-6);y<=Math.min(mod.game.loc.spaceY-2,int(baseY/40));y++) {
                  mod.game.loc.space[wallX][y].mat=2;mod.game.loc.space[wallX][y].indestruct=true;mod.game.loc.space[wallX][y].water=0;
               }
            } else if(p.stage=="prepared" && host && int(p.round)==round)peerPrepared=true;
            else if(p.stage=="go" && !host && int(p.round)==round)begin();
            else if(p.stage=="result" && int(p.round)==round) {peerResult=p.result;compare();}
            else if(p.stage=="compared" && host && int(p.round)==round) {peerDone=true;advance();}
            else if(p.stage=="done")finish();
         } catch(error:Error) {check(false,error.getStackTrace());send("done");finish();}
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null || mod.game==null || mod.game.gg==null || mod.session==null)return;
         if(host)for each(var p:Object in mod.session.peers)watch(p.link as TcpLink);else watch(mod.session.link);
         if(mod.game.world.clickReq==1) {mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN,true));mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP,true));}
         if(phase!="done" && getTimer()-at>60000) {check(false,"timeout "+phase);send("done");finish();return;}
         if(!mod.session.rooms.ready || mod.session.rooms.busy || mod.game.isTransitioning())return;
         if(phase=="boot" && !host && timer.currentCount>160 && getTimer()-readyAt>500) {readyAt=getTimer();send("ready");}
         if(phase=="prepare") {
            if(CASES[round].target=="unit" && target==null)target=findTarget();
            if(!localPrepared && getTimer()-at>700 && (CASES[round].target!="unit" || target!=null)) {
               localPrepared=true;if(!host)send("prepared");
            }
            if(host && localPrepared && peerPrepared) {begin();send("go");}
         }
         if(phase=="run" && getTimer()-at>3600)collect();
      }
      private function cleanupGun():void {
         if(gun!=null) {gun.remVisual();gun=null;}
         if(mod!=null && oldGun!=null) {mod.game.gg.currentWeapon=oldGun;mod.game.gg.childObjs=oldChildren;}
         if(host && target!=null) {mod.game.loc.remObj(target);target.remVisual();var i:int=mod.game.loc.units.indexOf(target);if(i>=0)mod.game.loc.units.splice(i,1);}
         if(host && enemyActor!=null) {mod.game.loc.remObj(enemyActor);enemyActor.remVisual();i=mod.game.loc.units.indexOf(enemyActor);if(i>=0)mod.game.loc.units.splice(i,1);enemyActor=null;}
      }
      private function finish():void {
         if(phase=="done")return;phase="done";timer.stop();
         if(mod!=null) {mod.stage.removeEventListener(Event.ENTER_FRAME,before);mod.stage.removeEventListener(Event.ENTER_FRAME,after);mod.stage.removeEventListener(Event.RENDER,render);cleanupGun();}
         Log.d("COOP EFFECTS DONE energy-impact "+(host?"host":"join"));
      }
   }
}

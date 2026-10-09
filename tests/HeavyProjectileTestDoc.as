package {
   import flash.desktop.NativeApplication;
   import flash.display.BitmapData;
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.MouseEvent;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.geom.Matrix;
   import flash.geom.Rectangle;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getQualifiedClassName;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   import rconnect.net.NetMessageEvent;
   import rconnect.net.TcpLink;

   /** Real Weapon.attack/step -> native Bullet.step -> Session/TCP -> staged
    * projectile display. The reference is the source's actual rendered path,
    * never an integration formula or the production flight.frames payload.
    * The driver changes neither projectile velocity nor collision/lifetime.
    * One shooter per case prevents native and mirrored visuals being confused. */
   public class HeavyProjectileTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private static const CASES:Array=[
         {id:"mlau",host:true,left:false,short:false},
         {id:"mlau",host:false,left:true,short:false},
         {id:"bel",host:true,left:true,short:false},
         {id:"bel",host:false,left:false,short:false},
         {id:"glau",host:true,left:false,short:false},
         {id:"glau",host:false,left:true,short:false},
         {id:"mlau",host:true,left:false,short:true},
         {id:"bel",host:false,left:true,short:true}
      ];
      private var mod:RConnectMod,host:Boolean,timer:Timer=new Timer(100),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=getTimer(),readyAt:int=0,round:int=-1;
      private var gun:Object,oldGun:Object,oldChildren:Object,source:Boolean=false,issued:Boolean=false;
      private var baseX:Number,baseY:Number,angle:Number,wallX:int=-1,frameAt:int=0;
      private var points:Array=[],nativePoints:Array=[],nativeInfo:Object,nativeEnd:int=0;
      private var sentTrace:Boolean=false,traceArrived:int=0,clockOffset:Number=Number.POSITIVE_INFINITY;
      private var samples:int=0,pixels:int=0,peak:int=0,lastVisible:int=0;
      private var seenBullet:Object,sourceShots:int=0,lastSync:int=0;

      public function HeavyProjectileTestDoc() {
         var app:String=NativeApplication.nativeApplication.applicationID;
         if(app.indexOf("rconnect-coop-")<0)return;host=app.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));
            e.preventDefault();send("done");finish();
         });
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,s:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"heavy-projectile "+s+" case="+round);}
      private function send(s:String,p:Object=null):void {
         if(mod==null)return;p=p||{};p.type="heavy-projectile-test";p.stage=s;p.round=round;
         if(host)mod.session.server.broadcast(p);else if(mod.session.link!=null)mod.session.link.send(p);
      }
      private function watch(l:TcpLink):void {if(l!=null && !links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);}}
      private function active():Boolean {return phase=="armed" || phase=="flight" || phase=="drain";}
      private function setup():void {
         var g:Object=mod.game.gg;oldGun=g.currentWeapon;oldChildren=g.childObjs;
         mod.stage.addEventListener(Event.ENTER_FRAME,before,false,100000);
         mod.stage.addEventListener(Event.ENTER_FRAME,after,false,-6000);
         mod.stage.addEventListener(Event.RENDER,render,false,-30000);
      }
      private function prepare(n:int):void {
         round=n;phase="prepared";at=getTimer();source=host==Boolean(CASES[n].host);
         issued=sentTrace=false;seenBullet=null;sourceShots=nativeEnd=traceArrived=0;
         points=[];nativePoints=[];nativeInfo=null;samples=pixels=peak=lastVisible=0;
         clockOffset=Number.POSITIVE_INFINITY;lastSync=0;
         var b:Object=mod.game,g:Object=b.gg,loc:Object=b.loc;
         if(gun!=null){gun.remVisual();gun=null;}
         g.currentWeapon=oldGun;g.childObjs=oldChildren;
         b.forceCloseOverlays();loc.base=false;loc.black=false;b.world.black=false;
         // The room is fixture-owned and isolated. Clear the flight corridor,
         // keep a real solid floor/boundary, and optionally build a close wall.
         var floor:int=Math.max(8,Math.min(loc.spaceY-2,14));baseY=floor*40;
         baseX=CASES[n].left?loc.spaceX*40-180:180;
         angle=CASES[n].left?-Math.PI+Math.PI/9:-Math.PI/9;
         wallX=CASES[n].short?int((baseX+(CASES[n].left?-150:150))/40):-1;
         for(var x:int=1;x<loc.spaceX-1;x++)for(var y:int=1;y<loc.spaceY-1;y++) {
            var tile:Object=loc.space[x][y];tile.phis=(y>=floor || x==wallX)?1:0;
            tile.opac=tile.phis;tile.front="";tile.water=0;
            tile.phX1=x*40;tile.phX2=(x+1)*40;tile.phY1=y*40;tile.phY2=(y+1)*40;
         }
         for each(var u:Object in loc.units){u.disabled=true;u.noAgro=true;u.trigDis=true;}
         g.invulner=true;g.disabled=true;g.dx=g.dy=0;g.setPos(baseX,baseY);g.setVisPos();
         b.world.redrawLoc();
         if(source) {
            var c:Object=mod.main.loaderInfo.applicationDomain.getDefinition("fe.weapon.Weapon");
            gun=c.create(g,CASES[n].id,0);gun.setPers(g,g.pers);gun.addVisual();
            g.currentWeapon=gun;g.childObjs=[gun];gun.hold=1;gun.lvl=0;gun.perslvl=0;
            check(gun.id==CASES[n].id && gun.vis!=null && gun.vis.stage!=null,"real native weapon is staged id="+gun.id);
         }
         Log.d("HEAVY PREPARE "+JSON.stringify({round:n,role:host?"host":"join",source:source,weapon:CASES[n].id,x:baseX,y:baseY,wall:wallX}));
      }
      private function before(e:Event):void {
         frameAt=getTimer();if(mod==null || round<0 || phase=="done")return;
         var b:Object=mod.game,g:Object=b.gg;b.forceCloseOverlays();
         for each(var u:Object in b.loc.units){u.disabled=true;u.noAgro=true;u.trigDis=true;}
         g.disabled=true;g.invulner=true;g.dx=g.dy=0;g.setPos(baseX,baseY);g.setVisPos();
         g.storona=CASES[round].left?-1:1;
         b.world.ctr.keyAttack=false;
         g.celX=b.world.celX=baseX+Math.cos(angle)*500;
         g.celY=b.world.celY=baseY-g.scY*.7+Math.sin(angle)*500;
         var cam:Object=b.world.cam;cam.celX=int(g.celX*cam.scaleV+cam.vx);cam.celY=int(g.celY*cam.scaleV+cam.vy);
         if(source && active() && gun!=null) {
            g.setWeaponPos(gun.tip);
            gun.findCel=false;gun.forceRot=angle;
            if(!issued && getTimer()-at>=800)gun.attack();
         }
         mod.stage.invalidate();
      }
      private function after(e:Event):void {
         if(!source || !active() || gun==null)return;
         // Disabled player: drive its actual weapon once, then let Location's
         // native object chain advance every projectile on subsequent frames.
         gun.step();
         if(gun.b!=null && gun.b!==seenBullet) {
            seenBullet=gun.b;sourceShots++;issued=true;phase="flight";
            nativeInfo={weapon:gun.id,cls:getQualifiedClassName(gun.b.vis),bullet:getQualifiedClassName(gun.b),
               begx:gun.b.begx,begy:gun.b.begy,dx:gun.b.dx,dy:gun.b.dy,ddx:gun.b.ddx,ddy:gun.b.ddy,
               grav:gun.grav,accel:gun.accel,rot:gun.b.rot,at:frameAt,short:CASES[round].short};
            Log.d("HEAVY NATIVE SHOT "+JSON.stringify(nativeInfo));
         }
      }
      private function displayPoint(v:DisplayObject):Object {return {at:frameAt,x:v.x,y:v.y,rot:v.rotation,sx:v.scaleX,sy:v.scaleY};}
      private function artPixels(v:DisplayObject):int {
         var r:Rectangle=v.getBounds(v);if(r.width<1 || r.height<1 || r.width*r.height>65536)return 0;
         var data:BitmapData=new BitmapData(Math.ceil(r.width),Math.ceil(r.height),true,0);
         data.draw(v,new Matrix(1,0,0,1,-r.x,-r.y));var count:int=0;
         for each(var c:uint in data.getVector(data.rect))if((c>>>24)>20)count++;
         data.dispose();return count;
      }
      private function render(e:Event):void {
         if(!active())return;
         if(source) {
            if(!issued)return;
            var v:DisplayObject=gun.b.vis as DisplayObject;
            if(v!=null && v.visible && v.stage!=null)points.push(displayPoint(v));
            if(!gun.b.in_chain && nativeEnd==0){nativeEnd=frameAt;phase="drain";}
         } else {
            var layer:DisplayObjectContainer=mod.game.world.grafon.visObjs[2];
            var expected:String=CASES[round].id=="mlau"?"visbulrocket":CASES[round].id=="bel"?"visbulbaleegg":"visbulgren40";
            var count:int=0;
            for(var i:int=0;i<layer.numChildren;i++) {
               v=layer.getChildAt(i);
               if(getQualifiedClassName(v)!=expected || !v.visible || v.alpha<=0 || v.stage==null)continue;
               count++;samples++;lastVisible=frameAt;points.push(displayPoint(v));
               if(pixels==0)pixels=artPixels(v);
            }
            peak=Math.max(peak,count);
         }
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;
         if(p.type!="heavy-projectile-test")return;
         try {
            if(p.stage=="ready" && host && phase=="boot"){setup();prepare(0);send("prepare");}
            else if(p.stage=="prepare" && !host) {
               if(phase=="boot")setup();prepare(int(p.round));send("prepared");
            }
            else if(p.stage=="prepared" && host && int(p.round)==round){phase="armed";at=getTimer();send("start");}
            else if(p.stage=="start" && !host && int(p.round)==round){phase="armed";at=getTimer();}
            else if(p.stage=="clock" && !source && int(p.round)==round)clockOffset=Math.min(clockOffset,getTimer()-Number(p.at));
            else if(p.stage=="trace" && !source && int(p.round)==round) {
               clockOffset=Math.min(clockOffset,getTimer()-Number(p.at));
               nativePoints=p.points;nativeInfo=p.info;nativeEnd=int(p.end);traceArrived=getTimer();phase="drain";
            }
            else if(p.stage=="result" && source && int(p.round)==round) {
               if(host)advance();else {phase="wait";send("advance");}
            }
            else if(p.stage=="advance" && host && !source && int(p.round)==round)advance();
            else if(p.stage=="done")finish();
         } catch(err:Error){check(false,err.getStackTrace());send("done");finish();}
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null || mod.game==null || mod.game.gg==null)return;
         if(host)for each(var l:TcpLink in mod.session.server.clients)watch(l);else watch(mod.session.link);
         mod.game.gg.invulner=true;
         if(mod.game.world.clickReq==1){mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN,true));mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP,true));}
         if(!mod.session.rooms.ready || mod.session.rooms.busy || mod.game.isTransitioning())return;
         try {
            if(phase=="boot" && !host && timer.currentCount>160 && getTimer()-readyAt>500){readyAt=getTimer();send("ready");}
            if(source && active() && getTimer()-lastSync>=100){lastSync=getTimer();send("clock",{at:getTimer()});}
            if(source && nativeEnd>0 && !sentTrace && getTimer()-nativeEnd>=400) {
               sentTrace=true;
               check(sourceShots==1,"exactly one native projectile fired count="+sourceShots);
               check(points.length>=(CASES[round].short?1:8),"native trajectory captured frames="+points.length);
               check(nativeInfo!=null && (Math.abs(nativeInfo.ddx)+Math.abs(nativeInfo.ddy)>0),"native acceleration/gravity remains active "+JSON.stringify(nativeInfo));
               if(CASES[round].id=="glau")check(nativeInfo.grav>0,"gravity control uses unmodified native grenade launcher");
               Log.d("HEAVY SOURCE TRACE "+JSON.stringify({round:round,info:nativeInfo,end:nativeEnd,points:points}));
               send("trace",{at:getTimer(),end:nativeEnd,info:nativeInfo,points:points});
            }
            if(!source && traceArrived>0 && phase=="drain" && getTimer()-traceArrived>=1100) {
               evaluate();phase="wait";send("result");
            }
            if(phase!="boot" && phase!="done" && getTimer()-at>16000){check(false,"timeout "+phase);send("done");finish();}
            if(phase=="boot" && getTimer()-at>90000){check(false,"boot timeout");send("done");finish();}
         } catch(err:Error){check(false,err.getStackTrace());send("done");finish();}
      }
      private static function angleDelta(a:Number,b:Number):Number {var d:Number=b-a;while(d>180)d-=360;while(d< -180)d+=360;return d;}
      private function nearest(p:Object):Object {
         var best:Object={distance:Number.POSITIVE_INFINITY,rotation:0};
         for(var i:int=0;i<nativePoints.length;i++) {
            var a:Object=nativePoints[i],b:Object=nativePoints[Math.min(i+1,nativePoints.length-1)];
            var dx:Number=b.x-a.x,dy:Number=b.y-a.y,len:Number=dx*dx+dy*dy;
            var t:Number=len>0?Math.max(0,Math.min(1,((p.x-a.x)*dx+(p.y-a.y)*dy)/len)):0;
            var ex:Number=p.x-a.x-dx*t,ey:Number=p.y-a.y-dy*t,d:Number=Math.sqrt(ex*ex+ey*ey);
            if(d<best.distance)best={distance:d,rotation:Number(a.rot)+angleDelta(a.rot,b.rot)*t};
         }
         return best;
      }
      private function evaluate():void {
         var maxDistance:Number=0,maxAngle:Number=0,reverse:int=0;
         for(var i:int=0;i<points.length;i++) {
            var p:Object=points[i],n:Object=nearest(p);
            maxDistance=Math.max(maxDistance,n.distance);maxAngle=Math.max(maxAngle,Math.abs(angleDelta(n.rotation,p.rot)));
            if(i>0 && (p.x-points[i-1].x)*(CASES[round].left?-1:1)< -1)reverse++;
         }
         var nativeDuration:Number=nativePoints.length?nativeEnd-Number(nativePoints[0].at):0;
         var remoteDuration:Number=points.length?Number(points[points.length-1].at)-Number(points[0].at):0;
         check(samples>=(CASES[round].short?1:6) && pixels>0,"staged remote projectile contains native artwork samples="+samples+" pixels="+pixels);
         check(points.length>0 && maxDistance<=3,"remote follows actual source path maxDistance="+maxDistance.toFixed(3));
         check(points.length>0 && maxAngle<=3,"remote heading follows source trajectory maxAngle="+maxAngle.toFixed(3));
         check(reverse==0 && peak<=1,"one projectile moves in native direction reverse="+reverse+" peak="+peak);
         check(nativeDuration>0 && remoteDuration<=nativeDuration*1.35+120 && remoteDuration>=Math.max(0,nativeDuration*.65-80),
            "visible flight duration follows native source="+nativeDuration+" remote="+remoteDuration);
         check(lastVisible>0 && getTimer()-lastVisible>=400,"native end removes remote visual lastVisibleAge="+(getTimer()-lastVisible));
         Log.d("HEAVY REMOTE TRACE "+JSON.stringify({round:round,info:nativeInfo,clockOffset:clockOffset,sourceEnd:nativeEnd,
            sourceDuration:nativeDuration,remoteDuration:remoteDuration,maxDistance:maxDistance,maxAngle:maxAngle,reverse:reverse,peak:peak,points:points}));
      }
      private function advance():void {if(round+1<CASES.length){prepare(round+1);send("prepare");}else{send("done");finish();}}
      private function finish():void {
         if(phase=="done")return;phase="done";timer.stop();
         if(mod!=null){mod.stage.removeEventListener(Event.ENTER_FRAME,before);mod.stage.removeEventListener(Event.ENTER_FRAME,after);mod.stage.removeEventListener(Event.RENDER,render);
            if(gun!=null)gun.remVisual();if(oldGun!=null){mod.game.gg.currentWeapon=oldGun;mod.game.gg.childObjs=oldChildren;}}
         Log.d("COOP EFFECTS DONE heavy-projectile "+(host?"host":"join"));
      }
   }
}

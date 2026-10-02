package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.display.BitmapData;
   import flash.display.DisplayObject;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.geom.Matrix;
   import flash.geom.Rectangle;
   import flash.utils.Timer;
   import flash.utils.Dictionary;
   import flash.utils.getTimer;
   import fe.unit.Unit;
   import fe.unit.PresentationProbe;
   import rconnect.core.Log;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;

   /** Real TCP in both directions; sample at final rendering, including active RV. */
   public class SmoothNetworkTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var timer:Timer=new Timer(100),mod:RConnectMod,host:Boolean,links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=0,baseX:Number,baseY:Number,units:Array=[];
      private var trace:Array=[],previous:int=0,px:Number=0,ex:Number=0,localDone:Boolean=false,peerDone:Boolean=false;
      private var faded:Array=[false,false],seen:int=0,packets:int=0;
      private var frameSerial:int=0,sampledSerial:int=-1;
      private var frameTime:int=0,sources:Array=[];
      public function SmoothNetworkTestDoc() {
         var id:String=NativeApplication.nativeApplication.applicationID;
         if(id.indexOf("pfe-rconnect-coop-")!=0 && id.indexOf("pfe-modsettings-rconnect-coop-")!=0)return;
         host=id.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void{
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();finish();
         });
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,s:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"smooth-network "+s);}
      private function watch(l:TcpLink):void {if(l!=null && !links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);}}
      private function send(s:String,p:Object=null):void {p=p||{};p.type="smooth-network-test";p.stage=s;if(host)mod.session.server.broadcast(p);else mod.session.link.send(p);}
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;
         if(p.type=="playerstate" || p.type=="worldstate")packets++;
         if(phase=="moving"){
            var incoming:Object=host?p.snap:null;
            if(!host && p.players is Array)for each(var player:Object in p.players)if(player.id==0)incoming=player.snap;
            if(incoming!=null)sources.push({t:incoming.sampleTime,x:incoming.x,frame:incoming.bodyFrame,playing:incoming.bodyPlaying});
         }
         if(p.type!="smooth-network-test")return;
         if(p.stage=="ready" && host){baseX=mod.game.gg.X;baseY=mod.game.gg.Y;begin();send("begin",{x:baseX,y:baseY});}
         else if(p.stage=="begin" && !host){baseX=p.x;baseY=p.y;begin();}
         else if(p.stage=="sampled"){peerDone=true;if(localDone){send("done");finish();}}
         else if(p.stage=="done")finish();
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null || mod.session==null)return;
         // Protect the fixture during initial travel, before the pair is ready.
         // A dead source legitimately sends the stopped death pose (frame 40).
         if(mod.game!=null && mod.game.gg!=null){mod.game.gg.invulner=true;mod.game.gg.hp=mod.game.gg.maxhp;}
         if(host)for each(var p:Object in mod.session.peers)watch(p.link as TcpLink);else watch(mod.session.link);
         if(phase=="boot" && mod.game!=null && mod.game.gg!=null && mod.session.rooms.ready
            && !mod.session.rooms.busy && !mod.game.isTransitioning()) {
            if(!host){send("ready");phase="wait";at=getTimer();}
         }
         if(phase!="done" && at>0 && getTimer()-at>40000){check(false,"scenario timed out "+phase);finish();}
      }
      private function spawn(name:String,id:String,xml:XML,offset:Number):Object {
         var c:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit."+name) as Class;
         var u:Object=new c(id,100,xml,null);u.id="smooth_"+name;
         u.putLoc(mod.game.loc,baseX+offset,baseY);mod.game.loc.addObj(u);mod.game.loc.units.push(u);
         u.disabled=true;u.doop=true;u.xp=0;units.push(u);return u;
      }
      private function begin():void {
         phase="moving";at=getTimer();
         var b:Object=mod.game;b.gg.disabled=true;b.gg.invulner=true;b.world.pers.infravis=0;
         b.gg.anim();b.gg.work="";b.gg.animState="";b.gg.isSit=false;b.gg.storona=1;
         b.loc.base=false;b.loc.black=true;b.world.black=true;
         if(host){spawn("UnitMerc","1",<unit tr="1"/>,150);spawn("UnitZebra","1",<unit tr="1"/>,80);spawn("UnitAlicorn","3",<unit tr="3"/>,250);}
         mod.stage.addEventListener(Event.ENTER_FRAME,drive,false,-5000);
         mod.stage.addEventListener(Event.ENTER_FRAME,beginFrame,false,100001);
         mod.stage.addEventListener(Event.RENDER,sample,false,-30000);
      }
      private function beginFrame(e:Event):void {frameTime=getTimer();}
      private function drive(e:Event):void {
         if(phase!="moving")return;
         frameSerial++;
         var elapsed:int=frameTime-at,b:Object=mod.game,g:Object=b.gg;
         b.forceCloseOverlays();g.anim();g.work="";
         if(g.vis.osn.currentFrameLabel=="die")g.animState="";
         g.disabled=true;g.setPos(baseX+(host?0:60)+elapsed*.03,baseY);g.setVisPos();
         g.stay=true;g.dx=5;g.dy=0;g.animate();
         if(host){
            var merc:Object=units[0];merc.disabled=true;merc.setPos(baseX+150+elapsed*.03,baseY);merc.setVisPos();merc.stay=true;merc.dx=3;merc.dy=0;merc.animate();
            for(var i:int=1;i<units.length;i++)PresentationProbe.fade(units[i] as Unit);
         }
         mod.stage.invalidate();
      }
      private function find(id:String):Object {for each(var u:Object in mod.game.loc.units)if(u.id=="smooth_"+id)return u;return null;}
      private function pixels(u:Object):int {
         var root:DisplayObject=mod.main as DisplayObject,rect:Rectangle=u.vis.getBounds(root);rect.inflate(2,2);
         rect=rect.intersection(new Rectangle(0,0,root.stage.stageWidth,root.stage.stageHeight));
         if(rect.width<1 || rect.height<1 || rect.width>1000 || rect.height>1000)return 0;
         var a:BitmapData=new BitmapData(Math.ceil(rect.width),Math.ceil(rect.height),false,0),z:BitmapData=a.clone();
         var matrix:Matrix=new Matrix(1,0,0,1,-rect.x,-rect.y),visible:Boolean=u.vis.visible;
         a.draw(root,matrix);u.vis.visible=false;z.draw(root,matrix);u.vis.visible=visible;
         var av:Vector.<uint>=a.getVector(a.rect),zv:Vector.<uint>=z.getVector(z.rect),n:int=0;
         for(var i:int=0;i<av.length;i++)if(av[i]!=zv[i])n++;
         a.dispose();z.dispose();return n;
      }
      private function sample(e:Event):void {
         if(phase!="moving" || sampledSerial==frameSerial)return;
         sampledSerial=frameSerial;
         try {
            var now:int=getTimer(),elapsed:int=now-at,remote:Object=mod.game.getRemoteGhost(host?1:0);
            var merc:Object=find("UnitMerc");
            if(remote!=null && merc!=null && elapsed>2000){
               if(previous>0)trace.push({dt:frameTime-previous,peer:(remote.X-px)/(frameTime-previous),enemy:(merc.X-ex)/(frameTime-previous),
                  body:remote.vis.osn.body.currentFrame,source:mod.game.gg.vis.osn.body.currentFrame,enemyFrame:PresentationProbe.frame(merc as Unit)});
               previous=frameTime;px=remote.X;ex=merc.X;
               if(seen<2 && elapsed>4000+seen*1000){
                  var f:Object=find(seen==0?"UnitZebra":"UnitAlicorn");
                  faded[seen]=f!=null && f.vis.alpha>0 && f.vis.alpha<.5 && f.invis && !f.isVis && pixels(f)>10;
                  seen++;
               }
            }
            if(elapsed>=10000){
               Log.d("SMOOTH TCP TRACE "+(host?"host":"join")+" "+JSON.stringify(trace));
               Log.d("SMOOTH TCP SOURCE "+(host?"host":"join")+" "+JSON.stringify(sources));
               check(trace.length>=35 && packets>=25,"real peer stream and final frames available frames="+trace.length+" packets="+packets);
               for each(var field:String in (host?["peer"]:["peer","enemy"])){
                  var errors:Array=[],stalls:int=0,repeated:int=0,last:int=-1,distinct:Object={};
                  for each(var row:Object in trace){errors.push(Math.abs(Number(row[field])-.03));if(row[field]<.001)stalls++;
                     var frame:int=int(row[field=="peer"?"body":"enemyFrame"]);if(frame==last)repeated++;last=frame;distinct[frame]=true;}
                  errors.sort(Array.NUMERIC);var n:int=0;for(var key:String in distinct)n++;
                  var p95:Number=errors.length?errors[int(errors.length*.95)]:999;
                  check(stalls<=trace.length*.08 && p95<.02,field+" continuous movement stalls="+stalls+" p95Error="+p95.toFixed(4));
                  check(n>=3 && repeated<trace.length*.4,field+" native animation cadence distinct="+n+" repeated="+repeated+"/"+trace.length);
               }
               if(!host){check(faded[0],"zebra faint pixels survive actual final scene");check(faded[1],"alicorn faint pixels survive actual final scene");}
               else Log.d("SMOOTH native source occlusion zebra="+faded[0]+" alicorn="+faded[1]);
               localDone=true;phase="sampled";send("sampled");if(peerDone){send("done");finish();}
            }
         } catch(error:Error){check(false,"sample "+error.getStackTrace());send("done");finish();}
      }
      private function finish():void {
         if(phase=="done")return;phase="done";timer.stop();
         if(mod!=null){mod.stage.removeEventListener(Event.ENTER_FRAME,beginFrame);mod.stage.removeEventListener(Event.ENTER_FRAME,drive);mod.stage.removeEventListener(Event.RENDER,sample);}
         Log.d("COOP EFFECTS DONE smooth-network "+(host?"host":"join"));
      }
   }
}

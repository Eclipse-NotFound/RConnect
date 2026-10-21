package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.display.DisplayObject;
   import flash.display.BitmapData;
   import flash.display.PNGEncoderOptions;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.filters.GlowFilter;
   import flash.geom.ColorTransform;
   import flash.geom.Matrix;
   import flash.geom.Rectangle;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import fe.unit.EnemyGrabProbe;
   import rconnect.core.Config;
   import rconnect.core.Log;
   import rconnect.core.TravelGuard;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;

   /** Both player-owned bodies, real native grab/action/physics and TCP. */
   public class PeerGripTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var mod:RConnectMod,host:Boolean,timer:Timer=new Timer(50),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=getTimer(),round:int=0,ready:Boolean=false,localDone:Boolean=false,peerDone:Boolean=false;
      private var baseX:Number,baseY:Number,target:Object,startY:Number,minY:Number,initialMana:Number;
      private var held:int=0,samples:int=0,acted:Boolean=false,escapeAt:int=0,pauseAt:int=0,pausePos:Number=NaN;
      private var lifted:Boolean=false,peerLifted:Boolean=false,actionAt:int=0,peerPauseAt:int=0,peerPauseY:Number=NaN,pauseChecks:int=0;
      private var thrown:int=0;
      private var heldManaMin:Number=NaN;
      private var nativeAura:Object,auraSamples:int=0,auraWrong:int=0;
      private var rasterSamples:int=0,rasterWrong:int=0,rasterChecked:Boolean=false;
      private var releasedRGB:String;
      private var baselineReady:Boolean=false,peerBaselineReady:Boolean=false,baselineVisual:DisplayObject,baselineState:Object;
      private var bodyIds:Dictionary=new Dictionary(true),nextBodyId:int=1,heldColorsLogged:Boolean=false;
      private var peerBaseline:Object,wireSeen:Object={},wireCount:int=0,liftStatusAt:int=0,liftStatusCount:int=0;
      private var origin:Object,away:Object,heldVisual:DisplayObject;
      private var pictures:Array=[],pictured:Object={};
      private var firstHoldSeen:Boolean=false,firstHoldAbility:Boolean=false;
      private static const CASES:Array=["denied","no-struggle","struggle","revoke","throw","pause","reset","room"];
      public function PeerGripTestDoc() {
         var app:String=NativeApplication.nativeApplication.applicationID;if(app.indexOf("rconnect-coop-")<0)return;
         host=app.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();send("done");finish();
         });timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function caster():Boolean {return round<CASES.length?host:!host;}
      private function kind():String {return CASES[round%CASES.length];}
      private function check(v:Boolean,s:String):void {Log.d("COOP "+(v?"PASS ":"FAIL ")+"peer-grip "+s+" round="+round+" kind="+kind());}
      private function change(s:String):void {phase=s;at=getTimer();Log.d("PEER GRIP PHASE "+(host?"host ":"join ")+s+" round="+round);}
      private function send(op:String,p:Object=null):void {p=p||{};p.type="peer-grip-test";p.op=op;p.round=round;if(host&&mod.session.server!=null)mod.session.server.broadcast(p);else if(!host&&mod.session.link!=null)mod.session.link.send(p);}
      private function watch(l:TcpLink):void {if(l!=null&&!links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);}}
      private function stable():Boolean {return mod.session.rooms.ready&&!mod.session.rooms.busy&&!mod.game.isTransitioning();}
      private function ghost():Object {return mod.game.getRemoteGhost(host?1:0);}
      private function roomInfo(l:Object):Object {return {landX:l.landX,landY:l.landY,landZ:l.landZ,landProb:l.landProb,key:mod.game.roomKey(l)};}
      private function otherRoom():Object {
         for each(var column:Object in mod.game.world.land.locs)for each(var row:Object in column)
            for each(var room:Object in row)if(room!=null && room!==mod.game.loc && !TravelGuard.restricted(room)
               && String(room.landProb)=="")return roomInfo(room);
         return null;
      }
      private function arena():void {
         var l:Object=mod.game.loc;
         for(var y:int=240;y<l.limY-40;y+=40)for(var x:int=80;x<l.limX-300;x+=40) {
            var clear:Boolean=true;for(var ix:int=0;ix<=280&&clear;ix+=20) {
               if(l.getAbsTile(x+ix,y+1).phis!=1){clear=false;break;}
               for(var iy:int=20;iy<=200;iy+=20)if(l.getAbsTile(x+ix,y-iy).phis!=0){clear=false;break;}
            }if(clear){baseX=x;baseY=y;return;}
         }throw new Error("no native floored peer grip corridor");
      }
      private function install():void {
         check(mod.game.readWorldInfo().layoutSeed==PeerAuraFixture.SEED,"same native corridor layout in both exact-byte runs");
         check(mod.config.getValue("allowPeerGrip")=="0"&&mod.config.getValue("peerGripStruggle")=="1","safe personal defaults");
         mod.config.setValue("followTeammate","0");mod.game.forceCloseOverlays();
         var l:Object=mod.game.loc;
         check(l.gg===mod.game.gg && !mod.game.gg.in_chain,"native local player lives outside the ordinary object chain");
         PeerAuraFixture.prepareCaster(mod.game.gg);
         check(true,"persistent native skills and perks survive repeated setParameters");
         for each(var o:Object in l.objs.concat())if(o.X2>baseX-20&&o.X1<baseX+300&&o.Y2>baseY-210&&o.Y1<baseY+20) {
            l.remObj(o);l.objs.splice(l.objs.indexOf(o),1);if(l.celObj===o)l.celObj=null;
         }
         mod.stage.addEventListener(Event.ENTER_FRAME,before,false,99000);
         mod.stage.addEventListener(Event.ENTER_FRAME,after,false,-9500);
         mod.stage.addEventListener(Event.RENDER,renderAura,false,-30000);
      }
      private function start(n:int):void {
         round=n;mod.peerGrip.reset();mod.game.forceCloseOverlays();
         var g:Object=mod.game.gg;
         g.t_throw=0;mod.game.world.ctr.keyAction=false;thrown=0;
         // Preserve the established mana reserve, but derive every grab/throw
         // capability from the persistent native inputs installed above.
         g.mana=g.maxmana=10000;
         mod.peerGrip.setPreferences(!caster()&&kind()!="denied",kind()=="struggle");
         var saved:Config=new Config();check(saved.getValue("allowPeerGrip")==mod.config.getValue("allowPeerGrip")
            &&saved.getValue("peerGripStruggle")==mod.config.getValue("peerGripStruggle"),"personal choices persist in own storage");
         if(host)mod.session.pause.setPolicy(kind()=="pause",false);
         held=samples=0;acted=false;escapeAt=pauseAt=0;pausePos=NaN;localDone=peerDone=false;
         nativeAura=null;auraSamples=auraWrong=0;rasterSamples=rasterWrong=0;rasterChecked=false;releasedRGB=null;heldVisual=null;
         baselineReady=peerBaselineReady=heldColorsLogged=false;baselineVisual=null;baselineState=peerBaseline=null;
         wireSeen={};wireCount=liftStatusAt=liftStatusCount=0;
         firstHoldSeen=firstHoldAbility=false;
         lifted=peerLifted=false;actionAt=peerPauseAt=pauseChecks=0;peerPauseY=NaN;
         startY=minY=baseY;change("settle");
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;
         // Observe real protocol evidence without intercepting/changing it.
         // Local Q success is not proof that the other owner accepted the hold.
         if(p.type=="peer-grip"){recordWire(p);return;}
         if(p.type!="peer-grip-test")return;
         try {
            if(p.op!="ready" && p.op!="setup" && p.op!="installed" && p.op!="round" && p.op!="done"
               && int(p.round)!=round) {Log.d("PEER GRIP TEST STALE "+JSON.stringify({round:round,messageRound:p.round,op:p.op}));return;}
            if(host&&p.op=="ready")ready=true;
            else if(!host&&p.op=="setup"){baseX=p.x;baseY=p.y;origin=p.origin;away=p.away;install();send("installed");change("waiting");}
            else if(host&&p.op=="installed"){start(0);send("round",{round:0});}
            else if(!host&&p.op=="round")start(p.round);
            else if(p.op=="baseline-ready" && phase=="settle") {peerBaselineReady=true;peerBaseline=p.state;}
            else if(!host&&p.op=="baseline-go" && phase=="settle")beginGrab();
            else if(p.op=="lifted" && phase=="holding") {
               check(int(p.held)>=3 && Number(p.rise)>20,"peer lift acknowledgement contains native held samples and rise");
               if(int(p.held)>=3 && Number(p.rise)>20){peerLifted=true;if(host&&lifted)beginAction();}
            }
            else if(!host&&p.op=="action" && phase=="holding" && actionAt==0) {
               check(lifted&&peerLifted,"both native bodies verified lifted before action");
               if(!lifted || !peerLifted)throw new Error("Action arrived before the two-sided lift barrier");
               actionAt=getTimer();Log.d("PEER GRIP ACTION START "+JSON.stringify({round:round,role:"join",at:actionAt,wall:new Date().time}));
            }
            else if(p.op=="paused-body"){peerPauseAt=getTimer();peerPauseY=p.y;}
            else if(p.op=="native-aura" && int(p.round)==round)nativeAura=p.value;
            else if(p.op=="sampled" && (phase=="holding" || phase=="sampled")){peerDone=true;if(host&&localDone)releaseRound();}
            else if(!host&&p.op=="release" && phase=="sampled")releaseRound();
            else if(p.op=="released" && (phase=="released" || phase=="release-sampled")){peerDone=true;if(host&&localDone)advance();}
            else if(p.op=="done"){if(host)send("done");finish();}
         }catch(err:Error){check(false,err.getStackTrace());send("done");finish();}
      }
      private function before(e:Event):void {
         if(phase=="done")return;var g:Object=mod.game.gg,w:Object=mod.game.world;
         if(g==null || w==null || mod.game.loc==null)return;
         if(kind()=="room" && acted && !stable())return;
         g.invulner=true;g.transp=true;g.disabled=false;g.isTake=0;w.ctr.active=true;
         // No derived Pers assignments here: native/mod stat rebuilds must
         // preserve the real skill/perk fixture without winning a frame race.
         g.maxmana=10000;if(phase=="settle")g.mana=10000;
         mod.game.loc.base=false;mod.game.loc.portOn=true;
         if(phase=="settle"||caster()){g.dx=g.dy=0;g.setPos(baseX+(caster()?0:100),baseY);g.setVisPos();}
         if(caster()) {
            var aimX:Number=phase=="settle"?baseX+100:baseX+150,aimY:Number=phase=="settle"?baseY-25:baseY-170;
            g.celX=w.celX=aimX;g.celY=w.celY=aimY;
            w.cam.celX=int(aimX*w.cam.scaleV+w.cam.vx);w.cam.celY=int(aimY*w.cam.scaleV+w.cam.vy);
         }
         if(!caster()&&phase=="holding"&&(kind()=="no-struggle"||kind()=="struggle")&&actionAt>0&&getTimer()-actionAt>1100)w.ctr.keyLeft=true;
         mod.stage.invalidate();
      }
      private function after(e:Event):void {
         if(phase!="holding")return;target=caster()?ghost():mod.game.gg;if(target==null)return;
         minY=Math.min(minY,target.Y);samples++;
         if(caster()?mod.game.gg.teleObj===target:target.levit==2)held++;
         if(caster() && mod.game.gg.teleObj===target)heldManaMin=Math.min(heldManaMin,Number(mod.game.gg.mana));
         if(!caster()&&target.t_throw>0)thrown++;
         if(kind()=="pause"&&mod.session.pause.paused) {
            if(isNaN(pausePos)){pausePos=target.Y;if(!caster())send("paused-body",{y:target.Y});}
            Log.d("PEER GRIP PAUSE "+JSON.stringify({round:round,caster:caster(),y:target.Y,ownY:mod.game.gg.Y,endpoint:peerPauseY,elapsed:getTimer()-peerPauseAt}));
            if(!caster()) {pauseChecks++;if(Math.abs(target.Y-pausePos)>1)check(false,"shared pause freezes actual owned player");}
            else if(peerPauseAt>0&&getTimer()-peerPauseAt>500) {pauseChecks++;if(Math.abs(target.Y-peerPauseY)>1)check(false,"remote hold settles at actual paused owner endpoint");}
         }
      }
      private function style(v:DisplayObject):Object {
         var glows:Array=[];
         if(v==null)return null;
         for each(var f:Object in v.filters)if(f is GlowFilter)
            glows.push([f.color,f.alpha,f.blurX,f.blurY,f.strength,f.quality,f.inner,f.knockout]);
         var c:ColorTransform=v.transform.colorTransform;
         return {glow:glows,rgb:[c.redMultiplier,c.greenMultiplier,c.blueMultiplier,c.redOffset,c.greenOffset,c.blueOffset],
            alpha:[c.alphaMultiplier,c.alphaOffset]};
      }
      private function optional(o:Object,key:String):* {
         if(o==null)return null;try{return key in o?o[key]:null;}catch(e:*){return null;}
      }
      private function transformChannels(c:Object):Array {
         if(!(c is ColorTransform))return null;
         return [c.redMultiplier,c.greenMultiplier,c.blueMultiplier,c.alphaMultiplier,
            c.redOffset,c.greenOffset,c.blueOffset,c.alphaOffset];
      }
      private function bodyState(u:Object):Object {
         if(u==null)return null;
         var v:DisplayObject=optional(u,"vis") as DisplayObject;
         if(v!=null && bodyIds[v]==null)bodyIds[v]=nextBodyId++;
         var effects:Array=[],sourceEffects:Object=optional(u,"effects") || [];
         for each(var effect:Object in sourceEffects)effects.push({id:optional(effect,"id"),
            kol:optional(effect,"kol"),t:optional(effect,"t"),power:optional(effect,"power")});
         return {visId:v==null?0:bodyIds[v],sameAsBaseline:v===baselineVisual,style:style(v),
            nativeTransform:transformChannels(optional(u,"cTransform")),roomTransform:transformChannels(optional(optional(u,"loc"),"cTransform")),
            room:optional(u,"loc")===mod.game.loc?mod.game.roomKey():"other",effects:effects,
            levit:optional(u,"levit"),x:optional(u,"X"),y:optional(u,"Y"),
            isLocal:u===mod.game.gg,heldByPeer:u===mod.game.gg&&mod.peerGrip.heldByTeammate,
            heldByLocal:mod.game.gg.teleObj===u,stageAttached:v!=null&&v.stage===mod.stage};
      }
      private function recordColors(label:String):Object {
         var state:Object={round:round,role:host?"host":"join",caster:caster(),label:label,at:getTimer(),wall:new Date().time,
            local:bodyState(mod.game.gg),observed:bodyState(caster()?ghost():mod.game.gg),
            baseline:baselineState==null?null:baselineState.local,peerBaseline:peerBaseline==null?null:peerBaseline.local};
         Log.d("PEER GRIP COLOR STATE "+JSON.stringify(state));return state;
      }
      private function captureBaseline():void {
         var g:Object=mod.game.gg,plain:Boolean=g.teleObj==null && g.levit!=2 && !mod.peerGrip.heldByTeammate;
         check(plain,"final-render pre-grab baseline is captured before either native hold starts");
         if(!plain){recordColors("invalid-pre-grab-baseline");send("done");finish();return;}
         baselineVisual=g.vis as DisplayObject;
         if(baselineVisual==null){check(false,"local baseline body exists");send("done");finish();return;}
         releasedRGB=JSON.stringify(style(baselineVisual).rgb);
         baselineState=recordColors("before-final-render");baselineReady=true;
         send("baseline-ready",{state:baselineState});
      }
      private function beginGrab():void {
         var g:Object=mod.game.gg,barrier:Boolean=baselineReady && peerBaselineReady && baselineState!=null && peerBaseline!=null;
         check(barrier,"both final-render baselines acknowledged before native Q");
         check(g.vis===baselineVisual,"local body identity is unchanged at native Q boundary");
         if(!barrier || g.vis!==baselineVisual)throw new Error("Native Q baseline barrier incomplete");
         recordColors("before-native-Q");
         target=ghost();check(target.levitPoss==(caster()&&kind()!="denied"),"remote grab permission follows teammate choice");
         if(caster()) {
            // Observe only. A failed first Q is a fixture failure, not a reason
            // to reapply derived stats, wait another frame or retry the action.
            var dx:Number=g.X-target.X,dy:Number=g.Y-target.Y;
            var capable:Boolean=PeerAuraFixture.canLift(g,Number(target.massa),dx*dx+dy*dy)
               && g.mana>=200 && g.pers.telePorog<target.massa && g.pers.teleMult>0;
            check(capable,"native Q ability fixture is ready at the action boundary");
            Log.d("PEER GRIP CASTER AT Q "+JSON.stringify({round:round,state:PeerAuraFixture.casterState(g),targetMass:target.massa}));
            if(!capable)throw new Error("Persistent native caster ability invalid at first Q");
            target.onCursor=1;mod.game.loc.celObj=target;mod.game.loc.celDist=0;
            Log.d("PEER GRIP NATIVE INPUT "+JSON.stringify({round:round,mana:g.mana,maxmana:g.maxmana,mass:target.massa,
               maxMass:g.pers.maxTeleMassa,poss:target.levitPoss,cursor:target.onCursor,range:g.pers.teleDist,
               line:mod.game.loc.isLine(g.X,g.Y-g.scY*.75,target.X,target.Y-target.scY/2),master:g.pers.telemaster,port:mod.game.loc.portOn,
               target:g.teleObj==null?null:String(g.teleObj.id)}));
            EnemyGrabProbe.grab(g);check((g.teleObj===target)==(kind()!="denied"),"native grab respects target permission");initialMana=g.mana;heldManaMin=initialMana;
            if(g.teleObj===target){nativeAura=style(target.vis as DisplayObject);send("native-aura",{round:round,value:nativeAura});
               check(nativeAura.glow.length>0,"native grab creates source glow before synchronization");}
         }
         change("holding");
      }
      private function recordWire(p:Object):void {
         if(round<0 || phase=="done" || wireCount>=16)return;
         if(p.op=="hold" && !firstHoldSeen) {
            firstHoldSeen=true;
            var g:Object=mod.game.gg,source:Object=ghost(),input:Object=p.input;
            var dx:Number=source==null?NaN:g.X-source.X,dy:Number=source==null?NaN:g.Y-source.Y;
            firstHoldAbility=input!=null && isFinite(Number(input.mass)) && Number(input.mass)>=Number(g.massa)
               && Number(input.master)==1 && Number(input.startMana)>=200 && Number(input.mana)>0
               && isFinite(Number(input.range)) && Number(input.range)>=dx*dx+dy*dy;
            Log.d("PEER GRIP FIRST HOLD ABILITY "+JSON.stringify({round:round,role:host?"host":"join",
               token:p.token,valid:firstHoldAbility,input:input,targetMass:g.massa,distanceSquared:dx*dx+dy*dy}));
            check(firstHoldAbility,"first received native hold retains sufficient mass range mana and mastery");
            if(!firstHoldAbility){send("done");finish();return;}
         }
         var key:String=String(p.op)+"/"+String(p.token)+"/"+String(p.accept)+"/"+String(p.reason);
         if(wireSeen[key])return;wireSeen[key]=true;wireCount++;
         Log.d("PEER GRIP WIRE RECEIVED "+JSON.stringify({round:round,phase:phase,role:host?"host":"join",at:getTimer(),wall:new Date().time,
            op:p.op,token:p.token,accept:p.accept,reason:p.reason,input:p.input,aura:p.aura,kick:p.kick,
            actualLocal:bodyState(mod.game.gg),casterOwnsNativeTarget:mod.game.gg.teleObj===ghost()}));
      }
      private function liftStatus():void {
         if(actionAt>0 || getTimer()-liftStatusAt<1000 || liftStatusCount>=8)return;
         liftStatusAt=getTimer();liftStatusCount++;
         Log.d("PEER GRIP LIFT WAIT "+JSON.stringify({round:round,role:host?"host":"join",caster:caster(),at:getTimer(),wall:new Date().time,
            held:held,samples:samples,rise:baseY-minY,lifted:lifted,peerLifted:peerLifted,actionAt:actionAt,
            local:bodyState(mod.game.gg),remote:bodyState(ghost()),mana:mod.game.gg.mana,massLimit:mod.game.gg.pers.maxTeleMassa}));
      }
      private function renderAura(e:Event):void {
         // Capture BOTH baselines at final RENDER, then acknowledge them over
         // TCP. Neither side can execute Q while the other still samples its
         // supposedly pre-grab colour in an independent Timer callback.
         if(phase=="settle" && !baselineReady && getTimer()-at>1600 && stable() && ghost()!=null
            && mod.game.gg.ggControl && mod.game.gg.sost==1 && mod.game.gg.work!="res")captureBaseline();
         if(phase!="holding" || nativeAura==null || getTimer()-at<600)return;
         var u:Object=caster()?ghost():mod.game.gg;
         if(u==null || !(caster()?mod.game.gg.teleObj===u:mod.peerGrip.heldByTeammate))return;
         if(heldVisual==null)heldVisual=u.vis as DisplayObject;
         if(!heldColorsLogged){heldColorsLogged=true;recordColors("held-final-render");}
         auraSamples++;
         if(kind()=="no-struggle" && getTimer()-at>1000)capturePicture("held");
         if(JSON.stringify(style(u.vis as DisplayObject))!=JSON.stringify(nativeAura)) {
            if(auraWrong==0)Log.d("PEER GRIP AURA MISMATCH "+JSON.stringify({round:round,caster:caster(),
               expected:nativeAura,actual:style(u.vis as DisplayObject),chain:u.in_chain,player:u.player,
               sameRoom:u.loc===mod.game.loc,localIdentity:mod.game.loc.gg===u}));
            auraWrong++;
         }
         // A filter on an invisible or masked body is not a rendered aura.
         // Inspect actual final stage pixels once per held round. This is a
         // functional visual probe; its raster work is excluded from timing claims.
         if(!rasterChecked && getTimer()-at>800) {
            rasterChecked=true;
            if(auraPixels(u.vis as DisplayObject))rasterSamples++;else rasterWrong++;
         }
      }
      private function auraPixels(v:DisplayObject):Boolean {
         if(v==null || v.stage!==mod.stage)return false;
         var bounds:Rectangle=v.getBounds(mod.stage);bounds.inflate(16,16);
         bounds=bounds.intersection(new Rectangle(0,0,mod.stage.stageWidth,mod.stage.stageHeight));
         bounds.x=Math.floor(bounds.x);bounds.y=Math.floor(bounds.y);
         bounds.width=Math.ceil(bounds.width);bounds.height=Math.ceil(bounds.height);
         if(bounds.width<3 || bounds.height<3)return false;
         var withGlow:BitmapData=new BitmapData(bounds.width,bounds.height,false,0);
         var withoutGlow:BitmapData=new BitmapData(bounds.width,bounds.height,false,0);
         var matrix:Matrix=new Matrix(1,0,0,1,-bounds.x,-bounds.y),saved:Array=v.filters,plain:Array=[];
         for each(var filter:Object in saved)if(!(filter is GlowFilter))plain.push(filter);
         try {
            withGlow.draw(mod.stage,matrix,null,null,withGlow.rect);
            v.filters=plain;
            withoutGlow.draw(mod.stage,matrix,null,null,withoutGlow.rect);
         } finally {v.filters=saved;}
         var a:Vector.<uint>=withGlow.getVector(withGlow.rect),b:Vector.<uint>=withoutGlow.getVector(withoutGlow.rect);
         var changed:int=0;for(var i:int=0;i<a.length;i++)if(a[i]!=b[i])changed++;
         Log.d("PEER GRIP RASTER "+JSON.stringify({round:round,caster:caster(),changed:changed,
            width:bounds.width,height:bounds.height,x:bounds.x,y:bounds.y,stageAttached:v.stage===mod.stage}));
         if(kind()=="no-struggle") {
            pictures.push({name:"presentation-peer-aura-"+round+"-raster-with.png",bitmap:withGlow});
            pictures.push({name:"presentation-peer-aura-"+round+"-raster-without.png",bitmap:withoutGlow});
         } else {withGlow.dispose();withoutGlow.dispose();}
         return changed>4;
      }
      private function capturePicture(label:String):void {
         var name:String="presentation-peer-aura-"+round+"-"+label+".png";
         if(pictured[name])return;
         pictured[name]=true;
         var bitmap:BitmapData=new BitmapData(mod.stage.stageWidth,mod.stage.stageHeight,false,0);
         bitmap.draw(mod.stage);
         pictures.push({name:name,bitmap:bitmap});
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null||mod.session==null)return;
         try {PeerAuraFixture.prepare(mod,host);}catch(setupError:Error){check(false,setupError.getStackTrace());finish();return;}
         if(mod.game.gg==null||mod.game.loc==null)return;
         if(host&&mod.session.server!=null)for each(var l:TcpLink in mod.session.server.clients)watch(l);else if(!host)watch(mod.session.link);
         try {
            if(phase=="done")return;if(getTimer()-at>(phase=="boot"?180000:90000)){check(false,"timeout "+phase);send("done");finish();return;}
            if(phase=="boot"&&stable()&&mod.game.readWorldInfo().curLandId=="random_mane") {
               if(host&&ready){arena();origin=roomInfo(mod.game.loc);away=otherRoom();
                  check(away!=null,"real ordinary room available for held-player travel cleanup");
                  if(away==null){send("done");finish();return;}
                  install();send("setup",{x:baseX,y:baseY,origin:origin,away:away});change("setup");}else if(!host)send("ready");
            }
            var g:Object=mod.game.gg,elapsed:int=getTimer()-at;
            if(phase=="settle" && host && baselineReady && peerBaselineReady && stable() && ghost()!=null) {
               // Same TCP order: the receiver sees go before a later hold
               // packet. Its pre-grab baseline was already acknowledged.
               send("baseline-go");beginGrab();
            } else if(phase=="holding") {
               if(kind()!="denied"&&!lifted&&held>=3&&minY<baseY-20) {
                  lifted=true;send("lifted",{held:held,rise:baseY-minY,at:getTimer(),wall:new Date().time});if(host&&peerLifted)beginAction();
               }
               if(kind()!="denied" && actionAt==0)liftStatus();
               var actionElapsed:int=actionAt>0?getTimer()-actionAt:0;
               if(!acted&&actionElapsed>1100) {
                  acted=true;
                  if(!caster()&&kind()=="revoke")mod.peerGrip.setPreferences(false,false);
                  if(!caster()&&kind()=="reset")mod.peerGrip.reset();
                  if(!caster()&&kind()=="room")TravelGuard.follow(mod.game,away);
                  if(caster()&&kind()=="throw")mod.game.world.ctr.keyAction=true;
                  if(caster()&&kind()=="pause")mod.game.world.pip.onoff(5);
               }
               if(kind()=="pause"&&caster()&&actionElapsed>3100)mod.game.world.pip.onoff(-1);
               if(kind()=="denied"?elapsed>3200:actionElapsed>4300) {
                  if(kind()=="room" && (!stable() || (!caster() && mod.game.roomKey()!=away.key)))return;
                  if(kind()=="denied")check(held==0&&minY>=baseY-1,"disabled target is never moved or held");
                  else {check(held>=3,"real player actually held");check(minY<baseY-20,"native player actually lifted rise="+(baseY-minY));
                     if(!caster())check(firstHoldSeen&&firstHoldAbility,"first native hold capability was verified without retry");
                     check(auraSamples>0 && auraWrong==0,"caster glow/color survives final rendering on grabbed body samples="+auraSamples+" wrong="+auraWrong);
                     check(rasterSamples>0 && rasterWrong==0,"native aura contributes visible final stage pixels samples="+rasterSamples+" wrong="+rasterWrong);}
                  if(kind()=="struggle"||kind()=="revoke"||kind()=="throw"||kind()=="reset"||kind()=="room")check(caster()?g.teleObj==null:g.levit!=2,"escape/revocation/throw/reset/room travel releases both ends");
                  if(kind()=="room")check(heldVisual!=null && style(heldVisual).glow.length==0,"native room travel cleans the previously held visual, including detached bodies");
                  if(kind()=="throw"&&!caster())check(thrown>0,"native E throw reaches actual grabbed player");
                  if(kind()=="no-struggle")check(caster()?g.teleObj===ghost():g.levit==2,"WASD with struggle disabled keeps hold");
                  if(kind()=="pause")check(pauseChecks>0&&!isNaN(pausePos)&&!mod.session.pause.paused&&(caster()?g.teleObj===ghost():g.levit==2),"hold survives verified shared pause and resumes");
                  // Revocation/struggle releases about three seconds before
                  // this summary. Native regeneration may refill that debit;
                  // observe the charge while the actual target is still held.
                  if(caster()&&kind()!="denied")check(heldManaMin<initialMana,"native caster mana charged during actual hold");
                  Log.d("PEER GRIP SAMPLE "+JSON.stringify({round:round,caster:caster(),held:held,samples:samples,rise:baseY-minY,
                     initialMana:initialMana,heldManaMin:heldManaMin,finalMana:g.mana}));
                  localDone=true;send("sampled");change("sampled");if(host&&peerDone)releaseRound();
               }
            } else if(phase=="released"&&elapsed>1200) {
               if(kind()=="room" && (!stable() || mod.game.roomKey()!=origin.key || ghost()==null))return;
               recordColors("released-before-strict-check");
               check(g.teleObj==null&&g.levit!=2,"native release leaves no player grip");
               check(style(g.vis as DisplayObject).glow.length==0,"released local body retains no peer grip glow");
               check(JSON.stringify(style(g.vis as DisplayObject).rgb)==releasedRGB,"released local body restores pre-grab native RGB channels");
               var remote:Object=ghost();
               check(remote!=null && style(remote.vis as DisplayObject).glow.length==0,"released remote body retains no peer grip glow");
               if(kind()=="no-struggle")capturePicture("released");
               mod.game.world.ctr.keyLeft=false;localDone=true;send("released");change("release-sampled");if(host&&peerDone)advance();
            }
         }catch(err:Error){check(false,err.getStackTrace());send("done");finish();}
      }
      private function beginAction():void {
         if(!host || phase!="holding" || actionAt>0)return;
         check(lifted&&peerLifted,"both native bodies verified lifted before action");
         if(!lifted || !peerLifted)throw new Error("Native lift barrier incomplete");
         actionAt=getTimer();send("action");
         Log.d("PEER GRIP ACTION START "+JSON.stringify({round:round,role:"host",at:actionAt,wall:new Date().time}));
      }
      private function releaseRound():void {if(host)send("release");if(mod.game.gg.teleObj!=null)mod.game.gg.dropTeleObj();mod.game.world.ctr.keyLeft=false;
         if(kind()=="room" && !caster())TravelGuard.follow(mod.game,origin);
         localDone=peerDone=false;change("released");}
      private function advance():void {if(round<CASES.length*2-1){start(round+1);send("round",{round:round});}else{send("done");finish();}}
      private function finish():void {
         if(phase=="done")return;change("done");timer.stop();
         if(mod!=null){mod.stage.removeEventListener(Event.ENTER_FRAME,before);mod.stage.removeEventListener(Event.ENTER_FRAME,after);mod.stage.removeEventListener(Event.RENDER,renderAura);mod.peerGrip.reset();}
         // Encode only after gameplay assertions; PNG compression must not
         // stall the native hold, escape, or throw under observation.
         for each(var picture:Object in pictures) {
            var fs:FileStream=new FileStream(),bitmap:BitmapData=picture.bitmap;
            fs.open(File.applicationStorageDirectory.resolvePath(picture.name),FileMode.WRITE);
            fs.writeBytes(bitmap.encode(bitmap.rect,new PNGEncoderOptions()));fs.close();bitmap.dispose();
         }
         pictures=[];Log.d("COOP EFFECTS DONE peer-grip");
      }
   }
}

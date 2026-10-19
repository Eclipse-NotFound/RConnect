package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.MouseEvent;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import fe.unit.RConnectPortAccess;
   import rconnect.core.Log;
   import rconnect.core.Config;
   import rconnect.core.PortSight;
   import rconnect.net.NetMessageEvent;
   import rconnect.net.TcpLink;

   /** Real Q hold/release in both directions. No test calls a teleport/cast,
    * sends a production sight answer, or injects a successful spell event. */
   public class PeerPortTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private static const CASES:Array=[
         {id:"off-own",on:false,own:true,peer:true,ok:true},
         {id:"off-peer",on:false,own:false,peer:true,ok:false},
         {id:"on-peer",on:true,own:false,peer:true,ok:true},
         {id:"on-own",on:true,own:true,peer:false,ok:true},
         {id:"neither",on:true,own:false,peer:false,ok:false},
         {id:"history",on:true,own:false,peer:false,ok:false},
         {id:"blocked",on:true,own:false,peer:true,ok:false},
         {id:"mana",on:true,own:false,peer:true,ok:false},
         {id:"short",on:true,own:false,peer:true,ok:false},
         {id:"cooldown",on:true,own:false,peer:true,ok:false},
         {id:"no-skill",on:true,own:false,peer:true,ok:false},
         {id:"lost-sight",on:true,own:false,peer:true,ok:false},
         {id:"policy-revoked",on:true,own:false,peer:true,ok:false}];
      private var mod:RConnectMod,host:Boolean,timer:Timer=new Timer(100),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=getTimer(),readyAt:int=0,round:int=0,spec:Object;
      private var source:Boolean=false,fromX:Number,toX:Number=800,baseY:Number=319;
      // The spell snaps to (800,319). Aim inside the target tile, rather than
      // exactly on an edge where camera pixel rounding changes the tile.
      private var aimX:Number=790,aimY:Number=270;
      private var released:Boolean=false,fired:Boolean=false,frames:int=0,charge:int=0,fireAt:int=0;
      private var prepared:Boolean=false,peerPrepared:Boolean=false,reported:Boolean=false,peerReported:Boolean=false;
      private var saved:Boolean=false,hidden:Boolean=false,hiddenAt:int=0;
      private var manaBefore:Number,manaAfter:Number,postX:Number,preview:int=0;
      private var old:Object={},tiles:Array=[],units:Dictionary=new Dictionary(true);
      private var query:int=0,answer:int=0,accepted:int=0,sightAtRelease:Number=-1;
      public function PeerPortTestDoc() {
         var app:String=NativeApplication.nativeApplication.applicationID;
         if(app.indexOf("rconnect-coop-")<0)return;host=app.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();send("done");finish();
         });timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,s:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"peer-port "+s+" round="+round);}
      private function change(s:String):void {phase=s;at=getTimer();}
      private function send(s:String,p:Object=null):void {
         p=p||{};p.type="peer-port-test";p.stage=s;p.round=round;
         if(host)mod.session.server.broadcast(p);else if(mod.session.link!=null)mod.session.link.send(p);
      }
      private function watch(l:TcpLink):void {if(l!=null && !links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);}}
      private function stable():Boolean {return mod.session.rooms.ready && !mod.session.rooms.busy && !mod.game.isTransitioning();}
      private function setup():void {
         var g:Object=mod.game.gg,w:Object=mod.game.world,loc:Object=mod.game.loc;
         if(loc.limX<1000 || loc.limY<360)throw new Error("room too small");
         old.g={disabled:g.disabled,transp:g.transp,invulner:g.invulner,ggControl:g.ggControl,mana:g.mana,maxmana:g.maxmana};
         old.loc={base:loc.base,portOn:loc.portOn,retDark:loc.retDark,lDist1:loc.lDist1,lDist2:loc.lDist2};
         old.alicorn=w.alicorn;old.policy=mod.peerVisionTeleport.enabled;old.pers={};
         for each(var key:String in ["portPoss","spellsPoss","portTime","portMana","portMagic","portDown","spellDown","allDManaMult"])old.pers[key]=g.pers[key];
         for(var x:int=1;x<=23;x++)for(var y:int=3;y<=8;y++) {
            var tile:Object=loc.space[x][y],fields:Object={};
            for each(key in ["phis","opac","front","water","visi","t_visi","indestruct","phX1","phX2","phY1","phY2","zForm","diagon","stair","shelf"])fields[key]=tile[key];
            tiles.push({tile:tile,fields:fields,x:x,y:y});
         }
         mod.config.setValue("followTeammate","0");
         if(host)mod.session.pause.setPolicy(false,false);
         check(!mod.peerVisionTeleport.enabled,"new config defaults off");
         check(host==mod.peerVisionTeleport.canChangePolicy,"host owns policy; join is read-only");
         if(!host)check(!mod.peerVisionTeleport.setEnabled(true),"join cannot change host policy");
         sightChecks();saved=true;
         mod.stage.addEventListener(Event.ENTER_FRAME,before,false,100000);
         mod.stage.addEventListener(Event.ENTER_FRAME,after,false,-12000);
      }
      private function sightChecks():void {
         var tile:Object={X:8,Y:6,visi:1},g:Object={X:200,Y1:220,stayY:40,storona:1};
         var opacity:Number=0,water:Number=0;
         var loc:Object={lDist1:300,lDist2:1000,opacWater:.3,
            getAbsTile:function(x:Number,y:Number):Object{return {opac:opacity,water:water};}};
         check(PortSight.visible(loc,g,tile),"current clear point accepted");
         opacity=1;check(!PortSight.visible(loc,g,tile),"explored tile behind opaque wall rejected");
         opacity=0;water=1;check(!PortSight.visible(loc,g,tile),"native water opacity retained");
         water=0;tile.X=40;check(!PortSight.visible(loc,g,tile),"fully explored but distant tile rejected");
         tile.X=8;tile.visi=.79;check(!PortSight.visible(loc,g,tile),"below native sight threshold rejected");
      }
      private function prepare(n:int):void {
         round=n;spec=CASES[int(n/2)];source=host==(n%2==0);fromX=spec.own?640:160;
         released=fired=prepared=peerPrepared=reported=peerReported=hidden=false;
         frames=charge=fireAt=hiddenAt=preview=query=answer=accepted=0;postX=NaN;sightAtRelease=-1;
         var g:Object=mod.game.gg,w:Object=mod.game.world,loc:Object=mod.game.loc;
         mod.game.forceCloseOverlays();loc.base=false;loc.portOn=true;loc.retDark=false;
         loc.lDist1=300;loc.lDist2=1000;w.alicorn=false;
         for each(var r:Object in tiles) {
            var solid:Boolean=r.y==8 || spec.id=="blocked" && r.x==20 && r.y==6;
            r.tile.phis=solid?1:0;r.tile.opac=solid?1:0;r.tile.water=0;r.tile.front="";
            r.tile.indestruct=true;r.tile.zForm=r.tile.diagon=r.tile.stair=0;r.tile.shelf=false;
            r.tile.phX1=r.x*40;r.tile.phX2=(r.x+1)*40;r.tile.phY1=r.y*40;r.tile.phY2=(r.y+1)*40;
         }
         w.redrawLoc();g.pers.portPoss=spec.id=="no-skill"?0:1;g.pers.spellsPoss=1;g.pers.portTime=25;
         g.pers.portMana=25;g.pers.portMagic=950;g.pers.portDown=300;g.pers.spellDown=1;g.pers.allDManaMult=1;
         g.maxmana=10000;g.mana=spec.id=="mana"?0:10000;manaBefore=g.mana;
         g.t_culd=spec.id=="cooldown"?10000:0;g.t_port=0;g.ggControl=true;g.isTake=0;
         if(g.teleObj!=null)g.dropTeleObj();
         g.ctr.clearAll();g.setPos(source?fromX:spec.peer?720:80,baseY);g.setVisPos();g.dx=g.dy=0;
         if(host && mod.peerVisionTeleport.enabled!=spec.on) {
            mod.hud.openPage("peer");
            var button:Object=mod.hud.getChildByName("rconnect-peer-port");
            check(button!=null && button.visible && button.mouseEnabled,"host Q switch reachable in peer tab");
            if(button!=null)button.dispatchEvent(new MouseEvent(MouseEvent.CLICK,true));
            check(mod.peerVisionTeleport.enabled==spec.on,"HUD click changes Q policy");
            check((new Config()).getValue("peerVisionTeleport")== (spec.on?"1":"0"),"Q policy persists in isolated profile");
            mod.hud.collapse(true);
         }
         change("prepare");Log.d("PEER PORT CASE "+JSON.stringify({round:n,role:host?"host":"join",source:source,spec:spec}));
      }
      private function before(e:Event):void {
         if(!saved || phase=="done")return;
         var g:Object=mod.game.gg,w:Object=mod.game.world,c:Object=w.ctr;
         g.invulner=true;g.transp=true;g.disabled=false;g.ggControl=true;g.isTake=0;g.dx=g.dy=0;
         for each(var u:Object in mod.game.loc.units)if(u!==g) {
            if(units[u]==null)units[u]={disabled:u.disabled,trigDis:u.trigDis};
            u.disabled=true;u.trigDis=true;
         }
         c.clearAll();c.keyPip=c.keyCrack=c.keyFly=c.keyTest1=c.keyTest2=false;
         c.active=true;c.keyLeft=c.keyRight=c.keyBeUp=c.keySit=c.keyJump=c.keyRun=false;
         c.keyAction=c.keyAttack=c.keyPunch=c.keyGrenad=c.keyMagic=c.keyDef=c.keyReload=c.keyTele=c.keySats=false;
         g.celX=w.celX=aimX;g.celY=w.celY=aimY;
         w.cam.celX=int(w.celX*w.cam.scaleV+w.cam.vx);w.cam.celY=int(w.celY*w.cam.scaleV+w.cam.vy);
         var lit:Boolean=source?spec.own:spec.peer&&!hidden;
         for each(var r:Object in tiles)r.tile.visi=r.tile.t_visi=lit||spec.id=="history"&&!source?1:0;
         if(phase=="prepare" || phase=="wait" || !source) {
            g.setPos(source?fromX:spec.peer&&!hidden?720:80,baseY);g.setVisPos();
         }
         if(phase=="run" && source && !fired) {
            c.keyTele=!released;if(spec.id=="mana")g.mana=0;
         }
         mod.stage.invalidate();
      }
      private function after(e:Event):void {
         if(!saved || phase!="run" || !source || fired)return;
         var g:Object=mod.game.gg,w:Object=mod.game.world,tile:Object=mod.game.loc.getAbsTile(aimX,aimY);
         frames++;charge=Math.max(charge,int(g.t_port));
         if(frames==25 || released)Log.d("PEER PORT STATE "+JSON.stringify({round:round,frame:frames,
            controllable:RConnectPortAccess.controllable(g),hp:g.hp,sost:g.sost,disabled:g.disabled,
            trigDis:g.trigDis,emerg:g.t_emerg,work:g.work,autoAttack:g.autoAttack,rat:g.rat,
            control:g.ggControl,ctrActive:w.ctr.active,charge:g.t_port,cooldown:g.t_culd,
            on:mod.peerVisionTeleport.enabled,room:mod.game.roomKey(),epoch:mod.session.rooms.epoch,
            term:mod.session.rooms.term,roomReady:mod.session.rooms.ready,roomBusy:mod.session.rooms.busy,
            hold:mod.game.roomHold,paused:mod.game.coopPaused,transition:mod.game.isTransitioning(),
            dead:mod.game.isPlayerDead(),localActive:mod.game.loc.active,playerLoc:g.loc===mod.game.loc,
            worldLoc:w.loc===mod.game.loc,worldPlayer:w.gg===g,celX:w.celX,celY:w.celY,
            tileX:tile.X,tileY:tile.Y,actualTileX:mod.game.loc.getAbsTile(w.celX,w.celY).X,
            actualTileY:mod.game.loc.getAbsTile(w.celX,w.celY).Y,pip:w.pip.active}));
         if(g.t_port>=25 && mod.game.world.gui.vis.portCel.visible && mod.game.world.gui.vis.portCel.currentFrame==2)preview++;
         if(released && g.t_port==0) {
            fired=true;fireAt=getTimer();postX=g.X;manaAfter=g.mana;sightAtRelease=tile.visi;
            check(Math.abs(postX-(spec.ok?toX:fromX))<=1,"native Q result "+spec.id+" x="+postX);
            if(spec.ok) {
               check(charge>=25,"real native charge completed");
               check(manaBefore-manaAfter>900 && manaBefore-manaAfter<1000,"exactly one native mana payment "+(manaBefore-manaAfter));
               check(g.t_culd>0,"native cooldown applied");
               check(Math.abs(g.vis.x-g.X)<=1,"local body lands in the same render frame");
            } else if(spec.id!="mana")check(manaBefore-manaAfter<1,"rejected Q did not spend spell mana");
            if(spec.id=="blocked")check(mod.game.loc.collisionUnit(toX,baseY,g.stayX,g.stayY),"destination really intersects native solid geometry");
            if(spec.id=="on-peer") {
               check(answer>0 && accepted>0,"real TCP fresh sight replies received");
               check(preview>0,"native ready marker uses teammate permission");
               check(sightAtRelease<.8,"lent tile visibility restored after native call");
            }
            if(spec.id=="history")check(accepted==0,"historical native visible flag does not grant current sight");
            Log.d("PEER PORT RESULT "+JSON.stringify({round:round,postX:postX,charge:charge,frames:frames,
               manaBefore:manaBefore,manaAfter:manaAfter,preview:preview,query:query,answer:answer,accepted:accepted,sight:sightAtRelease}));
         } else if((spec.id=="lost-sight" || spec.id=="policy-revoked") && charge>=18 && !hidden) {
            hidden=true;hiddenAt=getTimer();send("hide");
            if(host && spec.id=="policy-revoked")mod.peerVisionTeleport.setEnabled(false);
         } else if(spec.id=="short"?charge>=2:
            (spec.id=="no-skill" || spec.id=="cooldown"?frames>=35:
             hidden?charge>=30 && getTimer()-hiddenAt>800:charge>=30))released=true;
      }
      private function report():void {
         if(reported)return;reported=true;
         if(!source) {
            var ghost:Object=mod.game.getRemoteGhost(host?1:0);
            check(ghost!=null && Math.abs(ghost.X-(spec.ok?toX:fromX))<2,"peer observed authoritative spell position "+spec.id);
         }
         check(mod.peerVisionTeleport.enabled==(spec.id=="policy-revoked"?false:spec.on),"both roles retain host policy");
         send("report");change("reported");advance();
      }
      private function advance():void {
         if(!host || !reported || !peerReported)return;
         if(round+1<CASES.length*2){prepare(round+1);send("round");}else{send("done");finish();}
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;if(p.type=="peer-vision-port") {
            if(p.op=="query")query++;
            if(p.op=="answer"){answer++;if(p.seen===true)accepted++;}
            return;
         }
         if(p.type!="peer-port-test")return;
         try {
            if(host && p.stage=="ready" && phase=="boot"){setup();send("setup");prepare(0);}
            else if(!host && p.stage=="setup" && phase=="boot"){setup();prepare(0);}
            else if(!host && p.stage=="round")prepare(int(p.round));
            else if(p.stage=="prepared" && int(p.round)==round)peerPrepared=true;
            else if(!host && p.stage=="run" && int(p.round)==round)change("run");
            else if(p.stage=="hide" && int(p.round)==round) {
               hidden=true;hiddenAt=getTimer();if(host && spec.id=="policy-revoked")mod.peerVisionTeleport.setEnabled(false);
            } else if(p.stage=="report" && int(p.round)==round){peerReported=true;advance();}
            else if(p.stage=="done")finish();
         }catch(err:Error){check(false,err.getStackTrace());send("done");finish();}
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null || mod.game==null || mod.game.gg==null)return;
         if(host)for each(var peer:Object in mod.session.peers)watch(peer.link);else watch(mod.session.link);
         var w:Object=mod.game.world;
         if(w.clickReq==1){mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN,true));mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP,true));}
         if(phase=="done")return;
         if(getTimer()-at>(phase=="boot"?90000:25000)){check(false,"timeout "+phase);send("done");finish();return;}
         if(!stable())return;
         try {
            if(phase=="boot" && !host && timer.currentCount>100 && getTimer()-readyAt>500){readyAt=getTimer();send("ready");}
            if(phase=="prepare" && getTimer()-at>900 && mod.peerVisionTeleport.enabled==spec.on) {
               prepared=true;send("prepared");change("wait");
            }
            if(host && phase=="wait" && prepared && peerPrepared){send("run");change("run");}
            if(phase=="run" && (source?fired && getTimer()-fireAt>1000:peerReported))report();
         }catch(err:Error){check(false,err.getStackTrace());send("done");finish();}
      }
      private function finish():void {
         if(phase=="done")return;phase="done";timer.stop();
         if(saved)try {
            mod.stage.removeEventListener(Event.ENTER_FRAME,before);mod.stage.removeEventListener(Event.ENTER_FRAME,after);
            mod.game.world.ctr.clearAll();
            for(var k:String in old.g)mod.game.gg[k]=old.g[k];
            for(k in old.loc)mod.game.loc[k]=old.loc[k];for(k in old.pers)mod.game.gg.pers[k]=old.pers[k];
            mod.game.world.alicorn=old.alicorn;
            for each(var r:Object in tiles)for(k in r.fields)r.tile[k]=r.fields[k];
            for(var u:Object in units)for(k in units[u])u[k]=units[u][k];
            if(host)mod.peerVisionTeleport.setEnabled(old.policy);
         }catch(e:*){check(false,"cleanup "+e);}
         Log.d("COOP EFFECTS DONE peer-port "+(host?"host":"join"));
      }
   }
}

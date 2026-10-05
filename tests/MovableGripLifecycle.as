package {
   import flash.events.Event;
   import flash.events.KeyboardEvent;
   import flash.events.TimerEvent;
   import flash.filters.GlowFilter;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   import rconnect.core.TravelGuard;
   import rconnect.game.GameBridge;
   import rconnect.net.NetMessageEvent;
   import rconnect.net.TcpLink;

   /** Synthetic one-shot TCP leases test cleanup, not native grab eligibility.
    * Native Q, menu pause, room travel and Session.leave exercise real callers.
    * Uses the saved characters and unchanged supported floor of the motion test. */
   public class MovableGripLifecycle {
      private static const CASES:Array=["expiry","pause-expiry","local-takeover","room-handoff","offline"];
      private var mod:RConnectMod,host:Boolean,done:Function,x:Number,y:Number;
      private var a:Object,b:Object,loot:Object,ak:String,bk:String,lk:String;
      private var home:Object,other:Object,homeRoom:Object;
      private var links:Dictionary=new Dictionary(),timer:Timer=new Timer(100);
      private var phase:String="boot",at:int=getTimer(),round:int=0,readyAt:int=0;
      private var sent:Boolean=false,acted:Boolean=false,checked:Boolean=false,closed:Boolean=false;
      private var pauseChecked:Boolean=false,resumeChecked:Boolean=false,travelled:Boolean=false;
      private var localDone:Boolean=false,peerDone:Boolean=false,lastLease:int=0;
      private var key:int=0,keyUntil:int=0,offlineAt:int=0;
      private var previousLocal:Boolean=false;
      private var heldStyle:String;
      private var beforeNative:Object;

      public function MovableGripLifecycle(m:RConnectMod,h:Boolean,px:Number,py:Number,callback:Function) {
         mod=m;host=h;x=px;y=py;done=callback;homeRoom=mod.game.loc;home=info(homeRoom);
         mod.stage.addEventListener(Event.ENTER_FRAME,before,false,100001);
         mod.stage.addEventListener(Event.ENTER_FRAME,after,false,-7000);
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
         if(host) {
            var c:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.loc.Box") as Class;
            b=new c(mod.game.loc,"case",x+250,y-20,<obj/>,null);
            mod.game.loc.addObj(b);mod.game.loc.objs.push(b);
            for each(var col:Object in mod.game.world.land.locs)for each(var row:Object in col)for each(var room:Object in row)
               if(room!=null && mod.game.roomKey(room)!=home.key && !TravelGuard.restricted(room) && other==null)other=info(room);
            check(other!=null,"ordinary second room exists");
         }
      }
      private function check(ok:Boolean,label:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"movable-lifecycle "+label+" case="+CASES[round]);}
      private function info(room:Object):Object {return {landX:room.landX,landY:room.landY,landZ:room.landZ,landProb:room.landProb,key:mod.game.roomKey(room)};}
      private function stable():Boolean {return mod.session.rooms.ready && !mod.session.rooms.busy && !mod.game.isTransitioning();}
      private function watch(link:TcpLink):void {if(link!=null && !links[link]){links[link]=true;link.addEventListener(TcpLink.MESSAGE,receive);}}
      private function send(s:String,p:Object=null):void {
         p=p||{};p.type="movable-lifecycle-test";p.stage=s;
         if(host){if(mod.session.server!=null)mod.session.server.broadcast(p);}
         else if(mod.session.link!=null && mod.session.link.isOpen)mod.session.link.send(p);
      }
      private function findFixtures():Boolean {
         a=b=loot=null;
         for each(var o:Object in mod.game.loc.objs)if(o.id=="case") {
            if(Math.abs(Number(o.begX)-x-130)<2)a=o;
            if(Math.abs(Number(o.begX)-x-250)<2)b=o;
         }
         for(o=mod.game.loc.firstObj;o!=null;o=o.nobj)
            if(GameBridge.probe(GameBridge.probe(o,"item"),"id")=="kofe" && GameBridge.probe(GameBridge.probe(o,"item"),"kol")==27)loot=o;
         if(host) {
            for each(var s:Object in mod.game.readObjsSnapshot())if(s.id=="case") {
               if(Math.abs(Number(s.bx)-x-130)<2 || (a!=null && Math.abs(Number(s.x)-Number(a.X))<.01))ak=String(s.k);
               if(Math.abs(Number(s.bx)-x-250)<2 || (b!=null && Math.abs(Number(s.x)-Number(b.X))<.01))bk=String(s.k);
            }
            for each(s in mod.game.readLootSync())if(s.item!=null && s.item.id=="kofe" && s.item.kol==27)lk=String(s.k);
         }
         return a!=null && b!=null && loot!=null && (!host || (ak!="" && bk!="" && lk!=""));
      }
      private function resetTarget(o:Object,px:Number,py:Number):void {
         o.levit=0;o.fracLevit=0;o.dx=o.dy=0;o.stay=false;o.X=px;o.Y=py;
         o.X1=px-o.scX/2;o.X2=px+o.scX/2;o.Y1=py-o.scY;o.Y2=py;
         var f:Function=GameBridge.probe(o,"runVis") as Function;if(f!=null)f();
      }
      private function start(n:int):void {
         releaseKey();round=n;phase="running";at=getTimer();
         sent=acted=checked=closed=pauseChecked=resumeChecked=travelled=localDone=peerDone=false;lastLease=0;
         heldStyle=null;
         if(mod.game.gg.teleObj!=null)mod.game.gg.dropTeleObj();
         if(host) {
            resetTarget(a,x+130,y-20);resetTarget(b,x+250,y-20);resetTarget(loot,x+180,y-20);
            mod.session.pause.setPolicy(round==1,false);
         }
         Log.d("MOVABLE LIFECYCLE START "+JSON.stringify({role:host?"host":"join",round:round,ak:ak,bk:bk,lk:lk,room:mod.game.roomKey()}));
      }
      private function lease():void {
         // No teleObj pointer is assigned. The receiver must independently
         // expire this lease if no source heartbeat arrives.
         var target:Object=round==4?b:a,k:String=round==4?bk:ak;
         mod.session.link.send(mod.session.rooms.stamp({type:"objs",moved:[{k:k,id:"case",x:Number(target.begX),y:y-120,
            q:true,f:100,dx:0,dy:0,sampleTime:getTimer()}],ist:[],scene:[]}));
         mod.session.link.send(mod.session.rooms.stamp({type:"loot",picked:[],moved:[{k:lk,x:x+180,y:y-120,
            q:true,dx:0,dy:0,sampleTime:getTimer()}]}));
         Log.d("MOVABLE LIFECYCLE SYNTHETIC LEASE "+JSON.stringify({round:round,k:k,t:getTimer()}));
      }
      private function press(code:int):void {releaseKey();key=code;keyUntil=getTimer()+130;mod.stage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_DOWN,true,false,0,code));}
      private function releaseKey():void {if(key>0)mod.stage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_UP,true,false,0,key));key=0;}
      private function before(e:Event):void {
         if(phase=="done" || mod.game.gg==null)return;
         var g:Object=mod.game.gg,w:Object=mod.game.world;g.disabled=false;g.invulner=true;g.hp=g.maxhp;
         g.transp=true; // Same native bullet isolation as the motion fixture.
         w.ctr.active=true;g.dx=g.dy=0;g.isTake=0;
         if(mod.game.roomKey()!=home.key)return;
         g.setPos(x+(host?0:50),y);g.setVisPos();g.storona=1;
         var target:Object=round==3 && !host?b:a;
         if(target==null)return;
         var cx:Number=Number(target.X),cy:Number=Number(target.Y)-Number(target.scY)/2;
         if(g.teleObj===target)cy=y-120;
         w.celX=g.celX=cx;w.celY=g.celY=cy;
         w.cam.celX=int(cx*w.cam.scaleV+w.cam.vx);w.cam.celY=int(cy*w.cam.scaleV+w.cam.vy);
         if(g.teleObj==null)mod.game.loc.celObj=null;
         if(host && round==4)beforeNative=nativeState();
         mod.stage.invalidate();
      }
      private function floor(o:Object):Boolean {
         var t:Object=homeRoom.getAbsTile(Number(o.X),y+1);
         return o.levit==0 && o.stay===true && Math.abs(Number(o.dy))<.001 && t.phis==1
            && Math.abs(Number(t.phY1)-y)<.001 && Math.abs(Number(o.Y)-y)<=(o===loot?1.01:.01);
      }
      private function style(o:Object):String {
         if(o==null || o.vis==null)return "missing";
         var glows:Array=[];
         for each(var f:Object in o.vis.filters)if(f is GlowFilter)
            glows.push([f.color,f.alpha,f.blurX,f.blurY,f.strength,f.quality,f.inner,f.knockout]);
         var c:Object=o.vis.transform.colorTransform;
         return JSON.stringify({glow:glows,ct:[c.redMultiplier,c.greenMultiplier,c.blueMultiplier,c.alphaMultiplier,
            c.redOffset,c.greenOffset,c.blueOffset,c.alphaOffset]});
      }
      private function sampleDone():void {
         Log.d("MOVABLE LIFECYCLE RESULT "+JSON.stringify({role:host?"host":"join",round:round,
            a:{levit:a.levit,stay:a.stay,y:a.Y,dy:a.dy,local:mod.game.gg.teleObj===a},
            b:{levit:b.levit,stay:b.stay,y:b.Y,dy:b.dy,local:mod.game.gg.teleObj===b},
            loot:{levit:loot.levit,stay:loot.stay,y:loot.Y,dy:loot.dy},room:mod.game.roomKey()}));
         localDone=true;phase="sampled";send("sampled",{round:round});if(host && peerDone)advance();
      }
      private function after(e:Event):void {
         if(phase=="done")return;
         var now:int=getTimer(),age:int=now-at,g:Object=mod.game.gg;
         if(key>0 && now>keyUntil)releaseKey();
         if(host && round==4 && previousLocal && g.teleObj!==a)state("first-local-clear");
         previousLocal=g.teleObj===a;
         try {
            if(phase=="running") {
               if(!host && age>600 && (!sent || (round==4 && now-lastLease>300))) {lease();sent=true;lastLease=now;}
               if(host && !checked && age>1100) {
                  checked=true;var remote:Object=round==4?b:a;
                  check(remote.levit==1 && g.teleObj!==remote,"TCP lease sets remote box flag without local caster");
                  check(loot.stay===true && loot.Y<y-80,"remote loot lease suspends native gravity");
               }
               if(round==1) {
                  if(!host && !acted && age>1000){acted=true;mod.game.world.pip.onoff(5);}
                  if(!pauseChecked && age>4000) {
                     pauseChecked=true;check(mod.session.pause.paused,"real shared menu pauses longer than the 1500ms lease");
                     check(a.levit==1 && a.Y<y-80,"remote box lease survives shared pause");
                     check(loot.stay===true && loot.Y<y-80,"remote loot lease survives shared pause");
                  }
                  if(!host && !closed && age>4500){closed=true;mod.game.world.pip.onoff(-1);}
                  if(!resumeChecked && age>4900) {
                     resumeChecked=true;check(!mod.session.pause.paused,"shared menu pause resumes");
                     check(a.levit==1 && a.Y<y-80,"remaining box lease survives resume");
                  }
               }
               if((round==2 || round==4) && host && !acted && age>1200){acted=true;press(81);}
               if((round==2 || round==4) && host && acted && heldStyle==null && g.teleObj===a) {
                  heldStyle=style(a);check(JSON.parse(heldStyle).glow.length>0,"actual native local Q has a visible glow");
                  Log.d("MOVABLE LIFECYCLE NATIVE STYLE "+JSON.stringify({round:round,t:now,style:heldStyle}));
               }
               if(round==2 && !pauseChecked && age>4300) {
                  pauseChecked=true;if(host)check(g.teleObj===a && a.levit==1,"real local Q takeover survives remote lease expiry");
                  if(host)check(heldStyle!=null && style(a)==heldStyle,"local Q takeover retains native glow and CT after lease expiry");
               }
               if(round==2 && host && !closed && age>4700){closed=true;if(g.teleObj===a)press(81);}
               if(round==3 && !host && !acted && age>1200){acted=true;press(81);}
               if(round==3 && !host && !travelled && age>1800) {
                  travelled=true;check(g.teleObj===b,"real Q holds second box before native room travel");
                  TravelGuard.follow(mod.game,other);phase="away";at=now;send("away");
               }
               if(round==4 && host && age>2000) {
                  check(g.teleObj===a && a.levit==1,"actual local hold exists immediately before offline cleanup");
                  check(b.levit==1,"remote second box is held immediately before offline cleanup");
                  send("offline");checked=false;phase="offline-wait";at=now;
               }
               var end:int=round==0?6000:round==1?8500:round==2?8000:0;
               if(end>0 && age>end) {
                  check(a.levit==0,"remote box lease/release clears physics flag");
                  check(a.Y>y-50 && floor(a),"box returns to supported native floor");
                  check(loot.Y>y-50 && floor(loot),"loot returns to supported native floor");
                  check(g.teleObj==null,"caster pointer is clear after release");sampleDone();
               }
            } else if(phase=="away" && stable() && age>2000) {
               check(mod.game.roomKey()==other.key,"join enters ordinary second room");
               check(g.teleObj==null && b.levit==0,"native room handoff releases local box pointer and flag");
               check(a.levit==0,"native room handoff releases remote box flag");
               TravelGuard.follow(mod.game,home);phase="returning";at=now;
            } else if(phase=="returning" && stable() && age>2000 && findFixtures()) {
               check(mod.game.roomKey()==home.key,"join returns after handoff");send("returned");phase="landed";at=now;
            } else if(phase=="landed" && age>4000) {
               check(a.levit==0 && b.levit==0 && g.teleObj==null,"room re-entry retains no orphaned box hold");
               check(floor(a) && floor(b) && floor(loot),"room checkpoint restores supported resting objects");sampleDone();
            } else if(phase=="offline-wait" && age>(host?800:100)) {
               state("before-leave");mod.session.leave();state("after-leave");offlineAt=now;phase="offline";at=now;
               if(host)check(g.teleObj===a && a.levit==1,"synchronous offline cleanup preserves the native local hold");
               if(host)check(heldStyle!=null && style(a)==heldStyle,"synchronous offline cleanup preserves native local glow and CT");
            } else if(phase=="offline" && age>3000 && !checked) {
               checked=true;check(mod.session.mode=="offline","real Session.leave completes");
               check(b.levit==0 && floor(b),"offline cleanup clears remote box and resumes native gravity");
               check(loot.levit==0 && floor(loot),"offline cleanup resumes remote loot gravity");
               if(host) {check(g.teleObj===a && a.levit==1,"offline cleanup preserves actual local Q hold");
                  check(heldStyle!=null && style(a)==heldStyle,"offline local hold retains native glow and CT for three seconds");
                  if(g.teleObj===a)press(81);}
               else check(g.teleObj==null && a.levit==0,"offline receiver has no orphaned native hold");
            } else if(phase=="offline" && age>7000) {
               check(g.teleObj==null && a.levit==0 && floor(a),"local release after offline reaches native floor");
               if(host){phase="native-knockback";at=now;acted=false;checked=false;resetTarget(a,x+130,y-20);}
               else finish();
            } else if(phase=="native-knockback") {
               if(!acted && age>500){acted=true;press(81);}
               if(acted && !checked && age>1000) {
                  checked=true;check(g.teleObj===a && a.levit==1,"real Q acquires the box for the native knockdown control");
                  state("before-native-knockdown");
                  // Deliberately call the original damage path. Test immunity
                  // protects HP, but must not suppress native knockdown release.
                  g.damage(Number(g.maxhp)*.45/Math.max(.01,Number(g.knocked)),0);
                  state("after-native-knockdown");
                  check(Number(g.pinok)>60,"native damage crosses the original knockdown threshold");
                  check(g.teleObj==null && a.levit==0,"native knockdown still releases the actual Q hold while offline");
                  var released:Object=JSON.parse(style(a));
                  check(released.glow.length==0 && released.ct.toString()==[1,1,1,1,0,0,0,0].toString(),"native knockdown clears local glow and CT");
               }
               if(age>5000){check(g.teleObj==null && floor(a),"native knockdown release returns to the supported floor");finish();}
            }
            mod.stage.invalidate();
         } catch(error:Error){check(false,error.getStackTrace());send("done");finish();}
      }
      private function nativeState():Object {
         var g:Object=mod.game.gg,c:Object=mod.game.world.ctr;
         return {role:host?"host":"join",phase:phase,t:getTimer(),
            pointer:GameBridge.probe(g.teleObj,"id"),levit:a.levit,eligible:a.levitPoss,mana:g.mana,
            key:c.keyTele,keyAction:c.keyAction,keyMagic:c.keyMagic,keyAttack:c.keyAttack,
            keyDef:c.keyDef,keyJump:c.keyJump,active:c.active,
            pinok:g.pinok,ggControl:g.ggControl,spellsPoss:g.pers.spellsPoss,
            hp:g.hp,maxhp:g.maxhp,disabled:g.disabled,invulner:g.invulner,transp:g.transp,
            pause:mod.game.world.onPause,allStat:mod.game.world.allStat,
            weapon:GameBridge.probe(g.currentWeapon,"id"),rat:g.rat,
            celDist:mod.game.loc.celDist,work:g.work,sost:g.sost,
            room:mod.game.roomKey(),x:g.X,y:g.Y,ax:a.X,ay:a.Y,chain:a.in_chain,loc:a.loc===mod.game.loc,
            teleDist:g.pers.teleDist,style:style(a)};
      }
      private function state(note:String):void {
         var sample:Object=nativeState();sample.note=note;
         if(note=="first-local-clear")sample.beforeNative=beforeNative;
         Log.d("MOVABLE LIFECYCLE STATE "+JSON.stringify(sample));
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;if(p.type!="movable-lifecycle-test")return;
         try {
            if(!host && p.stage=="setup") {ak=p.ak;bk=p.bk;lk=p.lk;other=p.other;phase="find";at=getTimer();}
            else if(host && p.stage=="prepared" && phase=="boot"){start(0);send("round",{round:0});}
            else if(!host && p.stage=="round")start(int(p.round));
            else if(p.stage=="sampled" && int(p.round)==round){peerDone=true;if(host && localDone)advance();}
            else if(host && p.stage=="away"){phase="wait-return";at=getTimer();}
            else if(host && p.stage=="returned"){phase="landed";at=getTimer();}
            else if(!host && p.stage=="offline"){checked=false;phase="offline-wait";at=getTimer();}
            else if(p.stage=="done")finish();
         } catch(error:Error){check(false,error.getStackTrace());send("done");finish();}
      }
      private function advance():void {start(round+1);send("round",{round:round});}
      private function tick(e:TimerEvent):void {
         if(host)for each(var peer:Object in mod.session.peers)watch(peer.link as TcpLink);else watch(mod.session.link);
         if(getTimer()-at>(phase=="away" || phase=="wait-return" || phase=="returning"?50000:22000)) {check(false,"timeout "+phase);send("done");finish();return;}
         if(host && phase=="boot" && findFixtures() && getTimer()-readyAt>500) {
            readyAt=getTimer();send("setup",{ak:ak,bk:bk,lk:lk,other:other});
         }
         if(!host && phase=="find" && findFixtures()){phase="prepared";send("prepared");}
      }
      private function finish():void {
         if(phase=="done")return;phase="done";releaseKey();timer.stop();
         mod.stage.removeEventListener(Event.ENTER_FRAME,before);mod.stage.removeEventListener(Event.ENTER_FRAME,after);
         for(var link:Object in links)TcpLink(link).removeEventListener(TcpLink.MESSAGE,receive);
         done();
      }
   }
}

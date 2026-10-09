package
{
   import flash.desktop.NativeApplication;
   import flash.display.BitmapData;
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.events.MouseEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.geom.Matrix;
   import flash.geom.Point;
   import flash.geom.Rectangle;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   import rconnect.core.TravelGuard;
   import rconnect.game.GameBridge;
   import rconnect.net.NetMessageEvent;
   import rconnect.net.RoomCodec;
   import rconnect.net.TcpLink;

   /** Runs unchanged against installed 21 for a real negative control. Only
    * native Weapon.attack/step and Bullet collision create the reference mark.
    * Expected pixels are frozen on the first native impact RENDER, before a
    * delayed host correction can become the supposed native reference.
    * No WallImpactVisuals import or direct receive/apply helper is used.
    */
   public class WallImpactTestDoc extends Sprite
   {
      public static const MOD_CLASS:Class=RConnectMod;
      private static const CASES:Array=[
         {weapon:"lmg",actor:"host",mat:3,locked:true,hole:true},
         {weapon:"lmg",actor:"join",mat:3,locked:true,hole:true},
         {weapon:"plam",actor:"host",mat:2,locked:false,hole:true},
         {weapon:"plam",actor:"join",mat:2,locked:false,hole:true},
         {weapon:"prism",actor:"host",mat:2,locked:true,hole:false},
         {weapon:"prism",actor:"join",mat:2,locked:true,hole:false},
         {weapon:"lmg",actor:"both",mat:3,locked:true,hole:true}];
      private var mod:RConnectMod,host:Boolean,timer:Timer=new Timer(100),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=getTimer(),readyAt:int=0,round:int=0;
      private var baseX:Number,baseY:Number,wallX:int,wallTop:int,wallBottom:int,area:Rectangle;
      private var gun:Object,oldGun:Object,oldChildren:Object,sourceSide:Boolean=false,shot:Boolean=false;
      private var nativeBullets:Dictionary=new Dictionary(true),nativeCount:int=0,contact:Boolean=false;
      private var baseline:BitmapData,reference:Array=[],expected:Array=[],nativeResult:Object;
      private var nativeBefore:BitmapData,nativeChanges:Object={},nativeFinished:Boolean=false;
      private var prepared:Boolean=false,peerPrepared:Boolean=false,haveExpected:Boolean=false;
      private var expectedAt:int=0,collected:Boolean=false,peerDone:Boolean=false,compared:Boolean=false;
      private var localResult:Object,peerResult:Object,sceneFrames:int=0,sourceVisible:int=0;
      private var duplicates:Array=[],duplicateAt:int=0,duplicateBaseline:Array,duplicateHp:Array;
      private var origin:Object,away:Object,awaySeen:Boolean=false,returnSeen:Boolean=false;
      private var revisitExpected:Array,revisitHp:Array,revisitArea:Rectangle;
      private var oldDestroy:Boolean;

      public function WallImpactTestDoc()
      {
         var app:String=NativeApplication.nativeApplication.applicationID;
         if(app.indexOf("rconnect-coop-")<0)return;host=app.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            check(false,"uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));
            e.preventDefault();send("done");finish();
         });
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function check(ok:Boolean,label:String):void
      {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"wall-impact "+label+" case="+round);}
      private function send(stage:String,data:Object=null):void
      {
         data=data || {};data.type="wall-impact-test";data.stage=stage;data.round=round;
         if(host)mod.session.server.broadcast(data);else if(mod.session.link!=null)mod.session.link.send(data);
      }
      private function watch(l:TcpLink):void
      {if(l!=null && !links[l]) {links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);}}
      private function stable():Boolean
      {return mod.session.rooms.ready && !mod.session.rooms.busy && !mod.game.isTransitioning();}
      private function setup(x:Number,y:Number):void
      {
         baseX=x;baseY=y;wallX=int((baseX+260)/40);
         wallBottom=Math.max(3,int((baseY-10)/40));wallTop=Math.max(1,wallBottom-8);
         var b:BitmapData=mod.game.world.grafon.frontBmp;
         area=new Rectangle(Math.max(0,wallX*40-100),Math.max(0,wallTop*40-20),240,(wallBottom-wallTop+1)*40+40).intersection(b.rect);
         oldGun=mod.game.gg.currentWeapon;oldChildren=mod.game.gg.childObjs;oldDestroy=mod.game.loc.destroyOn;
         mod.stage.addEventListener(Event.ENTER_FRAME,before,false,100000);
         mod.stage.addEventListener(Event.ENTER_FRAME,after,false,-6000);
         mod.stage.addEventListener(Event.RENDER,render,false,-35000);
      }
      private function layout():Array
      {
         var out:Array=[],loc:Object=mod.game.loc;
         for(var x:int=Math.max(1,int(baseX/40)-1);x<=Math.min(loc.spaceX-2,wallX+2);x++)
            for(var y:int=wallTop;y<=wallBottom;y++)
               out.push({x:x,y:y,p:x==wallX?1:0,f:x==wallX?"A":"",o:x==wallX?1:0,h:20000});
         return out;
      }
      private function prepare(n:int):void
      {
         cleanupGun();round=n;phase="prepare";at=getTimer();
         nativeBullets=new Dictionary(true);nativeCount=0;contact=shot=prepared=peerPrepared=false;
         reference=[];expected=[];nativeResult=peerNative=localResult=peerResult=null;
         nativeChanges={};nativeFinished=false;
         haveExpected=collected=peerDone=compared=false;expectedAt=0;sceneFrames=sourceVisible=0;duplicates=[];
         sourceSide=CASES[n].actor=="both" || CASES[n].actor==(host?"host":"join");
         if(host) {var tiles:Array=layout();mod.game.applyTilePatch(tiles);send("case",{layout:tiles});}
         configureWall();
      }
      private function configureWall():void
      {
         var loc:Object=mod.game.loc,c:Object=CASES[round];
         loc.base=false;loc.black=false;loc.destroyOn=true;loc.tileSpawn=0;mod.game.world.black=false;
         for(var y:int=wallTop;y<=wallBottom;y++)
         {
            var t:Object=loc.space[wallX][y];t.mat=int(c.mat);t.indestruct=Boolean(c.locked);t.thre=0;
            t.fake=false;t.door=null;t.trap=null;t.water=0;
         }
         if(sourceSide && gun==null)
         {
            var factory:Object=mod.main.loaderInfo.applicationDomain.getDefinition("fe.weapon.Weapon");
            gun=factory.create(mod.game.gg,String(c.weapon),0);gun.setPers(mod.game.gg,mod.game.gg.pers);
            gun.lvl=gun.perslvl=0;
            mod.game.gg.currentWeapon=gun;mod.game.gg.childObjs=[gun];gun.addVisual();
            gun.hold=10000;gun.t_reload=0;gun.precision=0;gun.deviation=0;gun.recoil=0;gun.recoilUp=0;
            // Retain native bullet type, decal, velocity and firing path. Small
            // fixture damage leaves the wall solid even for plasma's erase mark.
            gun.destroy=30;gun.damageExpl=0;gun.critCh=0;gun.dopCh=0;
            check(gun.vis!=null && gun.vis.stage!=null,"native weapon staged "+c.weapon+" decal="+gun.tipDecal);
         }
      }
      private function begin():void
      {
         if(baseline!=null)baseline.dispose();
         baseline=new BitmapData(int(area.width),int(area.height),true,0);
         baseline.copyPixels(mod.game.world.grafon.frontBmp,area,new Point());
         phase="run";at=getTimer();
      }
      private function before(e:Event):void
      {
         if(phase=="boot" || phase=="done" || phase.indexOf("travel")>=0 || phase=="revisit")return;
         var g:Object=mod.game.gg,w:Object=mod.game.world;
         if(phase=="run" && sourceSide && nativeResult==null) {
            if(nativeBefore!=null)nativeBefore.dispose();
            nativeBefore=new BitmapData(int(area.width),int(area.height),true,0);
            nativeBefore.copyPixels(w.grafon.frontBmp,area,new Point());
         }
         g.disabled=true;g.invulner=true;g.dx=g.dy=0;g.storona=1;g.setPos(baseX,baseY);
         g.setVisPos();g.setWeaponPos(gun==null?0:gun.tip);
         mod.game.forceCloseOverlays();w.testDam=true;
         for each(var u:Object in mod.game.loc.units)if(u!==g && String(u.id).indexOf("rconnect_ghost")!=0)u.disabled=true;
         var aimY:Number=wallTop*40+20+Math.min(round,wallBottom-wallTop)*40;
         if(CASES[round].actor=="both" && !host)aimY-=60;
         g.celX=wallX*40+80;g.celY=aimY;w.celX=g.celX;w.celY=g.celY;
         w.cam.celX=int(w.celX*w.cam.scaleV+w.cam.vx);w.cam.celY=int(w.celY*w.cam.scaleV+w.cam.vy);
         if(gun!=null){gun.findCel=false;gun.forceRot=Math.atan2(g.celY-g.weaponY,g.celX-g.weaponX);}
         if(phase=="run" && sourceSide && !shot && getTimer()-at>900)
         {gun.hold=10000;gun.t_reload=0;gun.attack();}
      }
      private function after(e:Event):void
      {
         if(phase=="boot" || phase=="done" || phase.indexOf("travel")>=0 || phase=="revisit")return;
         if(gun!=null)gun.step();
         // A hitscan can be removed from firstObj in its first native step.
         // Keep the actual Weapon.b witness as well as all linked pellets.
         if(gun!=null && gun.b!=null && !nativeBullets[gun.b]) {
            nativeBullets[gun.b]=true;nativeCount++;shot=true;
            Log.d("WALL NATIVE SHOT "+JSON.stringify({round:round,x:gun.b.begx,y:gun.b.begy,
               hit:gun.b.tilehit,ex:gun.b.X,ey:gun.b.Y,weapon:gun.id,rot:gun.b.rot}));
         }
         for(var o:Object=mod.game.loc.firstObj;o!=null;o=o.nobj)
         {
            if(gun==null || GameBridge.probe(o,"weap")!==gun || GameBridge.probe(o,"begx")===undefined)continue;
            if(!nativeBullets[o]) {nativeBullets[o]=true;nativeCount++;shot=true;o.miss=0;o.critCh=0;o.critInvis=0;o.probiv=0;o.desintegr=0;}
         }
         for(o in nativeBullets)if(GameBridge.probe(o,"tilehit")===true)contact=true;
         if(phase=="run" && sourceSide && nativeResult==null && nativeBefore!=null && contact) {
            // Observe only the synchronous native simulation interval. Network
            // replies between frames cannot become the native pixel oracle.
            // Keep every shot of the weapon's real burst, not just its first hit.
            var prior:Vector.<uint>=nativeBefore.getVector(nativeBefore.rect);
            var current:Vector.<uint>=mod.game.world.grafon.frontBmp.getVector(area);
            var original:Vector.<uint>=baseline.getVector(baseline.rect);
            for(var pi:int=0;pi<current.length;pi++)if(prior[pi]!=current[pi]) {
               if(current[pi]==original[pi])delete nativeChanges[String(pi)];
               else nativeChanges[String(pi)]=Number(current[pi]);
            }
            nativeFinished=shot && gun.t_attack<=0;
            for(o in nativeBullets)if(o.in_chain===true)nativeFinished=false;
         }
         mod.stage.invalidate();
      }
      private function sourcePatch():Array
      {
         var b:BitmapData=mod.game.world.grafon.frontBmp,old:Vector.<uint>=baseline.getVector(baseline.rect);
         var now:Vector.<uint>=b.getVector(area),out:Array=[];
         for(var i:int=0;i<now.length;i++)if(old[i]!=now[i])out.push(i,Number(now[i]));
         return out;
      }
      private function appearancePixels():int
      {
         var root:DisplayObject=mod.main as DisplayObject,layer:DisplayObjectContainer=mod.game.world.grafon.visFront;
         var p1:Point=root.globalToLocal(layer.localToGlobal(new Point(area.x,area.y)));
         var p2:Point=root.globalToLocal(layer.localToGlobal(new Point(area.right,area.bottom)));
         var r:Rectangle=new Rectangle(Math.min(p1.x,p2.x),Math.min(p1.y,p2.y),Math.abs(p2.x-p1.x),Math.abs(p2.y-p1.y));
         r=r.intersection(new Rectangle(0,0,mod.stage.stageWidth,mod.stage.stageHeight));
         r.x=Math.floor(r.x);r.y=Math.floor(r.y);r.width=Math.ceil(r.width);r.height=Math.ceil(r.height);
         if(r.isEmpty() || r.width*r.height>600000)return 0;
         var a:BitmapData=new BitmapData(int(r.width),int(r.height),false,0),b:BitmapData=a.clone();
         var front:BitmapData=mod.game.world.grafon.frontBmp;
         var saved:BitmapData=new BitmapData(int(area.width),int(area.height),true,0);
         saved.copyPixels(front,area,new Point());
         var matrix:Matrix=new Matrix(1,0,0,1,-r.x,-r.y);
         try {a.draw(root,matrix);front.copyPixels(baseline,baseline.rect,new Point(area.x,area.y));b.draw(root,matrix);}
         finally {front.copyPixels(saved,saved.rect,new Point(area.x,area.y));saved.dispose();}
         var av:Vector.<uint>=a.getVector(a.rect),bv:Vector.<uint>=b.getVector(b.rect),count:int=0;
         for(var i:int=0;i<av.length;i++)if(av[i]!=bv[i])count++;
         a.dispose();b.dispose();return count;
      }
      private function render(e:Event):void
      {
         if(phase!="run" && phase!="duplicate")return;sceneFrames++;
         if(phase=="run" && sourceSide && contact && nativeFinished && nativeResult==null)
         {
            var keys:Array=[];for(var key:String in nativeChanges)keys.push(int(key));keys.sort(Array.NUMERIC);
            reference=[];for each(var index:int in keys)reference.push(index,nativeChanges[String(index)]);
            if(!reference.length)return;
            var holes:int=0,old:Vector.<uint>=baseline.getVector(baseline.rect);
            for(var i:int=0;i<reference.length;i+=2)
               if((uint(reference[i+1])>>>24)<(old[int(reference[i])]>>>24))holes++;
            sourceVisible=appearancePixels();
            nativeResult={count:reference.length/2,holes:holes,visible:sourceVisible,bullets:nativeCount,
               decal:int(gun.tipDecal),hp:hp(),at:getTimer(),reference:RoomCodec.pack(reference)};
            check(nativeCount>0 && contact,"real native projectile reaches the wall");
            check(reference.length>=10,"native wall appearance changes pixels="+reference.length/2);
            check(!CASES[round].hole || holes>0,"native requested hole changes alpha pixels="+holes);
            check(sourceVisible>0,"native wall change contributes final game pixels="+sourceVisible);
            addExpected(reference);send("expected",{result:nativeResult});
         }
      }
      private function addExpected(words:Array):void
      {
         // Two simultaneous LMG impacts use separate heights; merge their
         // changed pixels rather than assuming one side's whole bitmap is final.
         var values:Object={};for(var i:int=0;i<expected.length;i+=2)values[String(expected[i])]=expected[i+1];
         for(i=0;i<words.length;i+=2)values[String(words[i])]=words[i+1];
         var keys:Array=[];for(var k:String in values)keys.push(int(k));keys.sort(Array.NUMERIC);
         expected=[];for each(var index:int in keys)expected.push(index,values[String(index)]);
         haveExpected=CASES[round].actor!="both" || (nativeResult!=null && peerNative!=null);
         expectedAt=getTimer();
      }
      private var peerNative:Object;
      private function hp():Array
      {var out:Array=[];for(var y:int=wallTop;y<=wallBottom;y++)out.push(Number(mod.game.loc.space[wallX][y].hp));return out;}
      private function same(a:Array,b:Array):Boolean {return JSON.stringify(a)==JSON.stringify(b);}
      private function examine():Object
      {
         var b:BitmapData=mod.game.world.grafon.frontBmp,now:Vector.<uint>=b.getVector(area);
         var wrong:int=0,mask:Object={},extra:int=0;
         for(var i:int=0;i<expected.length;i+=2)
         {mask[String(expected[i])]=true;if(now[int(expected[i])]!=uint(expected[i+1]))wrong++;}
         var changed:Array=sourcePatch();
         for(i=0;i<changed.length;i+=2)if(!mask[String(changed[i])])extra++;
         return {wrong:wrong,extra:extra,expected:expected.length/2,changed:changed.length/2,
            pixels:appearancePixels(),hp:hp(),solid:solidWall(),frames:sceneFrames,raw:ArrayFromVector(now)};
      }
      private function solidWall():Boolean
      {for(var y:int=wallTop;y<=wallBottom;y++)if(mod.game.loc.space[wallX][y].phis!=1)return false;return true;}
      private static function ArrayFromVector(v:Vector.<uint>):Array
      {var a:Array=[];for each(var n:uint in v)a.push(Number(n));return a;}
      private function collect():void
      {
         collected=true;localResult=examine();phase="sampled";
         send("result",{result:{wrong:localResult.wrong,extra:localResult.extra,expected:localResult.expected,
            changed:localResult.changed,pixels:localResult.pixels,hp:localResult.hp,solid:localResult.solid,frames:localResult.frames}});
         compare();
      }
      private function compare():void
      {
         if(compared || localResult==null || peerResult==null)return;compared=true;
         check(localResult.wrong==0,"all original native mark pixels arrive exactly wrong="+localResult.wrong+" expected="+localResult.expected);
         check(localResult.extra==0,"no extra random centre marks or impact echo pixels="+localResult.extra);
         check(localResult.pixels>0,"synchronized marks affect final rendered game pixels="+localResult.pixels);
         check(localResult.solid && peerResult.solid,"small visual holes never open tile collision");
         check(same(localResult.hp,peerResult.hp),"HP settles once and both sides agree local="+localResult.hp+" peer="+peerResult.hp);
         Log.d("WALL IMPACT METRIC "+JSON.stringify({role:host?"host":"join",round:round,scenario:CASES[round],
            local:{wrong:localResult.wrong,extra:localResult.extra,pixels:localResult.pixels,hp:localResult.hp,frames:localResult.frames},
            peer:{wrong:peerResult.wrong,extra:peerResult.extra,pixels:peerResult.pixels,hp:peerResult.hp,frames:peerResult.frames},native:nativeResult || peerNative}));
         send("compared");advance();
      }
      private function advance():void
      {
         if(!host || !compared || !peerDone)return;
         if(round+1<CASES.length)prepare(round+1);
         else {send("duplicate-start");startDuplicate();}
      }
      private function startDuplicate():void
      {
         phase="duplicate";at=duplicateAt=getTimer();duplicateBaseline=localResult.raw;duplicateHp=hp();
         // These were incoming packets. Ask their original sender to replay
         // them in the original direction, through the actual production parser.
         send("replay-production",{packets:duplicates});
      }
      private function inspectDuplicate():void
      {
         var now:Vector.<uint>=mod.game.world.grafon.frontBmp.getVector(area);
         check(same(ArrayFromVector(now),duplicateBaseline),"repeated actual sync packets cannot redraw or darken marks");
         check(same(hp(),duplicateHp),"repeated actual sync packets cause no second terrain damage");
         var total:int=duplicates.length;
         Log.d("WALL IMPACT DUPLICATE role="+(host?"host":"join")+" packets="+total);
         send("duplicate-result",{count:total});phase="duplicate-wait";at=getTimer();
      }
      private function roomInfo(room:Object):Object
      {return {key:mod.game.roomKey(room),landX:int(room.landX),landY:int(room.landY),landZ:int(room.landZ),landProb:String(room.landProb || "")};}
      private function startTravel():void
      {
         cleanupGun();origin=roomInfo(mod.game.loc);away=null;
         for each(var column:Array in mod.game.world.land.locs)if(column!=null)for each(var row:Array in column)if(row!=null)
            for each(var room:Object in row)if(away==null && room!=null && !TravelGuard.restricted(room) && mod.game.roomKey(room)!=origin.key)away=roomInfo(room);
         check(away!=null,"ordinary second room exists for a real revisit");
         if(away==null){send("done");finish();return;}
         revisitExpected=expected.concat();revisitHp=hp();revisitArea=area.clone();
         send("travel-away",{origin:origin,away:away});TravelGuard.follow(mod.game,away,false);phase="travel-away";at=getTimer();
      }
      private function inspectRevisit():void
      {
         var pixels:Vector.<uint>=mod.game.world.grafon.frontBmp.getVector(revisitArea),wrong:int=0;
         for(var i:int=0;i<revisitExpected.length;i+=2)if(pixels[int(revisitExpected[i])]!=uint(revisitExpected[i+1]))wrong++;
         check(wrong==0,"native room exit/re-entry retains marks and transparent notches wrong="+wrong);
         check(same(hp(),revisitHp) && solidWall(),"revisit retains physical state without a cosmetic extra hit");
         send("revisited");phase="revisit-wait";at=getTimer();
      }
      private function receive(e:NetMessageEvent):void
      {
         var p:Object=e.data;
         // Retain real production packets as immutable duplicate inputs. A
         // host receives client terrain, a join receives authoritative unitsync.
         if(phase=="run" && ((host && p.type=="terrain" && p.wall!=null) ||
            (!host && p.type=="unitsync" && p.wallPaint is Array)))
            if(duplicates.length<2)duplicates.push(JSON.parse(JSON.stringify(p)));
         if(p.type!="wall-impact-test")return;
         try
         {
            if(p.stage=="ready" && host && phase=="boot")
            {setup(Math.max(120,Math.min(mod.game.gg.X,mod.game.loc.spaceX*40-600)),mod.game.gg.Y);send("setup",{x:baseX,y:baseY});prepare(0);}
            else if(p.stage=="setup" && !host && phase=="boot")setup(p.x,p.y);
            else if(p.stage=="case" && !host)
            {peerNative=null;prepare(int(p.round));mod.game.applyTilePatch(p.layout as Array);configureWall();}
            else if(p.stage=="prepared" && host && int(p.round)==round)peerPrepared=true;
            else if(p.stage=="go" && !host && int(p.round)==round)begin();
            else if(p.stage=="expected" && int(p.round)==round)
            {peerNative=p.result;addExpected(RoomCodec.unpack(String(p.result.reference)) as Array);}
            else if(p.stage=="result" && int(p.round)==round){peerResult=p.result;compare();}
            else if(p.stage=="compared" && host && int(p.round)==round){peerDone=true;advance();}
            else if(p.stage=="duplicate-start" && !host)startDuplicate();
            else if(p.stage=="replay-production" && int(p.round)==round)
            {
               for each(var packet:Object in p.packets)
                  if((host && packet.type=="unitsync" && packet.wallPaint is Array) ||
                     (!host && packet.type=="terrain" && packet.wall!=null))
                     for(var repeat:int=0;repeat<3;repeat++)
                        if(host)mod.session.server.broadcast(packet);else mod.session.link.send(packet);
            }
            else if(p.stage=="duplicate-result" && host)
            {check(duplicates.length+int(p.count)>0,"at least one real wall payload exists for duplicate testing");startTravel();}
            else if(p.stage=="travel-away" && !host)
            {
               cleanupGun();origin=p.origin;away=p.away;revisitExpected=expected.concat();revisitHp=hp();revisitArea=area.clone();
               TravelGuard.follow(mod.game,away,true);phase="travel-away";at=getTimer();
            }
            else if(p.stage=="away-ready" && host)awaySeen=true;
            else if(p.stage=="travel-back" && !host){TravelGuard.follow(mod.game,origin,true);phase="travel-back";at=getTimer();}
            else if(p.stage=="returned" && host)returnSeen=true;
            else if(p.stage=="revisited" && host){send("done");finish();}
            else if(p.stage=="done")finish();
         }
         catch(err:Error){check(false,err.getStackTrace());send("done");finish();}
      }
      private function tick(e:TimerEvent):void
      {
         mod=RConnectMod.instance;if(mod==null || mod.game==null || mod.game.gg==null || mod.session==null)return;
         if(host)for each(var p:Object in mod.session.peers)watch(p.link as TcpLink);else watch(mod.session.link);
         if(mod.game.world.clickReq==1)
         {mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN,true));mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP,true));}
         try
         {
            if(phase=="done")return;
            if(getTimer()-at>60000){check(false,"timeout "+phase+" shot="+shot+" nativeCount="+nativeCount+" contact="+contact);send("done");finish();return;}
            if(!stable())return;
            if(phase=="boot" && !host && timer.currentCount>160 && getTimer()-readyAt>500){readyAt=getTimer();send("ready");}
            else if(phase=="prepare")
            {
               if(!prepared && getTimer()-at>800) {prepared=true;if(!host)send("prepared");}
               if(host && prepared && peerPrepared){begin();send("go");}
            }
            else if(phase=="run" && haveExpected && getTimer()-expectedAt>1800 && !collected)collect();
            else if(phase=="duplicate" && getTimer()-duplicateAt>1800)inspectDuplicate();
            else if(phase=="travel-away" && mod.game.roomKey()==away.key && getTimer()-at>1200)
            {
               if(!host){send("away-ready");phase="travel-away-wait";}
               else if(awaySeen){send("travel-back");TravelGuard.follow(mod.game,origin,false);phase="travel-back";at=getTimer();}
            }
            else if(phase=="travel-back" && mod.game.roomKey()==origin.key && getTimer()-at>1500)
            {
               if(!host){send("returned");phase="revisit";at=getTimer();}
               else if(returnSeen){phase="revisit";at=getTimer();}
            }
            else if(phase=="revisit" && getTimer()-at>1200)inspectRevisit();
         }
         catch(err:Error){check(false,err.getStackTrace());send("done");finish();}
      }
      private function cleanupGun():void
      {
         if(gun!=null){gun.remVisual();gun=null;}
         if(mod!=null && oldGun!=null){mod.game.gg.currentWeapon=oldGun;mod.game.gg.childObjs=oldChildren;}
      }
      private function finish():void
      {
         if(phase=="done")return;phase="done";timer.stop();
         if(mod!=null)
         {
            mod.stage.removeEventListener(Event.ENTER_FRAME,before);mod.stage.removeEventListener(Event.ENTER_FRAME,after);
            mod.stage.removeEventListener(Event.RENDER,render);cleanupGun();
            if(mod.game.loc!=null)mod.game.loc.destroyOn=oldDestroy;
         }
         if(baseline!=null){baseline.dispose();baseline=null;}
         if(nativeBefore!=null){nativeBefore.dispose();nativeBefore=null;}
         Log.d("COOP EFFECTS DONE wall-impact "+(host?"host":"join"));
      }
   }
}

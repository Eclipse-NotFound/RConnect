package {
   import flash.desktop.NativeApplication;
   import flash.display.BitmapData;
   import flash.display.DisplayObject;
   import flash.display.PNGEncoderOptions;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.events.UncaughtErrorEvent;
   import flash.geom.Matrix;
   import flash.geom.Rectangle;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getQualifiedClassName;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;
   import rconnect.net.NetMessageEvent;
   import rconnect.net.TcpLink;

   /** Isolated native actions across the real Session/TCP path. */
   public class EffectsTerrainTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var timer:Timer=new Timer(250);
      private var host:Boolean;
      private var mod:RConnectMod;
      private var links:Dictionary=new Dictionary();
      private var phase:String="boot";
      private var at:int=0;
      private var merc:Object, drone:Object, rotor:Object, tile:Object;
      private var wallX:int,wallY:int;
      private var shots:int=0,fireFrames:int=0,deathParts:int=0;
      private var partsBefore:int=0;
      private var deathWatching:Boolean=false;
      private var readiness:Boolean=false;
      private var afterWall:Boolean=false;
      private var renderWatch:Boolean=false,wallPixels:int=0,wallFrames:int=0;
      public function EffectsTerrainTestDoc() {
         var app:String=NativeApplication.nativeApplication.applicationID;
         if(app.indexOf("pfe-rconnect-coop-")!=0 && app.indexOf("pfe-modsettings-rconnect-coop-")!=0) return;
         host=app.indexOf("-host-")>=0;
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,function(e:UncaughtErrorEvent):void {
            Log.d("COOP FAIL effects uncaught "+(e.error is Error?Error(e.error).getStackTrace():e.error));e.preventDefault();
         });
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
         addEventListener(Event.ENTER_FRAME,frame);
      }
      private function check(ok:Boolean,label:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"effects "+label);}
      private function send(stage:String,fields:Object=null):void {
         var p:Object=fields || {};p.type="effects-test";p.stage=stage;
         if(host) mod.session.server.broadcast(p);else mod.session.link.send(p);
      }
      private function watch(link:TcpLink):void {
         if(link==null || links[link]) return;links[link]=true;
         link.addEventListener(TcpLink.MESSAGE,message);
      }
      private function setPhase(value:String):void {phase=value;at=getTimer();Log.d("EFFECTS phase "+(host?"host ":"join ")+value);}
      private function message(e:NetMessageEvent):void {
         var p:Object=e.data;if(p.type!="effects-test") return;
         if(host) {
            if(p.stage=="ready" && phase=="fixtures") {setPhase("fire");send("fire");}
            else if(p.stage=="fire-checked") {setPhase("death-wait");send("death-start");}
            else if(p.stage=="death-checked") {setPhase("wall-wait");send("wall",{x:wallX,y:wallY});prepareWall();}
            else if(p.stage=="wall-ready") {setPhase("wall-priming");}
            else if(p.stage=="wall-checked") {check(tile.phis==0 && tile.opac==0,"join destruction reaches host collision and light");setPhase("done");send("done");finish();}
         } else {
            if(p.stage=="fire") setPhase("fire");
            else if(p.stage=="check-fire") {
               check(fireFrames>0,"enemy gun shows native firing frames on join");
               check(merc.currentWeapon.kol_shoot==0 && merc.currentWeapon.b==null,"firing display creates no local weapon shots or bullets");
               send("fire-checked");setPhase("wait-death");
            }
            else if(p.stage=="death-start") {partsBefore=parts();deathWatching=true;setPhase("death");}
            else if(p.stage=="check-death") {
               check(drone!=null && drone.sost>=3,"native mechanical death reaches join state");
               check(deathParts>0,"mechanical death emits visible native fragments on join");
               check(drone!=null && (drone.vis==null || drone.vis.parent==null || !drone.vis.visible),"destroyed flying enemy leaves no intact hovering body");
               check(rotor!=null && rotor.sost==4 && (rotor.vis==null || rotor.vis.parent==null || !rotor.vis.visible),"native Vortex rotor death removes its intact body on join");
               var partCount:int=parts();mod.game.applyUnitsSync(mod.game.readUnitsSnapshot());
               check(parts()==partCount,"repeated dead snapshot does not replay explosion fragments");
               deathWatching=false;send("death-checked");setPhase("wait-wall");
            } else if(p.stage=="wall") {wallX=p.x;wallY=p.y;prepareWall();setPhase("wall-ready");send("wall-ready");}
            else if(p.stage=="break-wall") {breakWall();setPhase("wall");}
            else if(p.stage=="done") finish();
         }
      }
      private function create(name:String,id:String,tr:int,x:Number,y:Number):Object {
         var c:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit."+name) as Class;
         var map:XML=<unit/>;map.@tr=tr;
         var u:Object=new c(id,100,map,null);
         u.id="effects_"+id;u.putLoc(mod.game.loc,x,y);mod.game.loc.addObj(u);mod.game.loc.units.push(u);
         u.disabled=true;u.doop=true;u.lootIsDrop=true;u.xp=0;u.stay=true;u.animate();return u;
      }
      private function find(prefix:String):Object {
         for each(var u:Object in mod.game.loc.units) if(String(u.id)==prefix)return u;
         return null;
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;
         if(mod==null || mod.game.gg==null || mod.game.loc==null || mod.game.isTransitioning())return;
         if(!renderWatch) {renderWatch=true;mod.stage.addEventListener(Event.RENDER,rendered,false,-30000);}
         if(host) {for each(var link:TcpLink in mod.session.server.clients)watch(link);} else watch(mod.session.link);
         if(timer.currentCount<50)return;
         try {
            if(phase=="boot") {
               var b:GameBridge=mod.game;b.gg.disabled=true;b.gg.dx=b.gg.dy=0;
               b.loc.base=false;b.loc.black=true;b.world.black=true;
               wallX=Math.min(int(b.loc.spaceX)-4,int(b.gg.X/40)+3);wallY=int(b.gg.Y/40)-1;
               if(host) {
                  merc=create("UnitMerc","merc2",2,600,b.gg.Y);
                  drone=create("UnitDron","dron2",2,700,b.gg.Y-100);
                  rotor=create("UnitVortex","vortex",0,650,b.gg.Y-70);
                  Log.d("EFFECTS native weapon id="+merc.currentWeapon.id+" frames="+merc.currentWeapon.vis.totalFrames);
                  rectangleTiles();
                  TerrainRegression.run(check);
               }
               setPhase("fixtures");
            }
            if(!host && phase=="fixtures" && !readiness) {
               merc=find("effects_merc2");drone=find("effects_dron2");rotor=find("effects_vortex");
               if(merc!=null && drone!=null && rotor!=null) {readiness=true;send("ready");}
            }
            if(host && phase=="fire") {
               var w:Object=merc.currentWeapon;
               if(shots<6 && getTimer()-at>shots*500) {
                  merc.celX=merc.X+300;merc.celY=merc.Y-35;
                  w.t_attack=0;w.t_reload=0;w.hold=90;w.damage=w.damageExpl=w.destroy=0;
                  w.attack();w.step();shots++;
                  Log.d("EFFECTS fired shots="+w.kol_shoot+" frame="+w.vis.currentFrame+" label="+w.vis.currentLabel);
               }
               if(getTimer()-at>4200){check(w.kol_shoot>0,"host drives real native enemy weapon fire");send("check-fire");setPhase("fire-wait");}
            }
            if(host && phase=="death-wait" && getTimer()-at>1000) {
               var before:int=parts();drone.hp=0;drone.die();
               check(drone.sost==4 && parts()>before,"native flying machine death explodes and removes its body");setPhase("death");
               before=parts();rotor.hp=0;rotor.die();
               check(rotor.sost==4 && parts()>before,"native Vortex rotor death emits explosion fragments");
            }
            if(host && phase=="death" && getTimer()-at>1800){send("check-death");setPhase("death-check");}
            if(host && phase=="wall-priming" && getTimer()-at>1500) {
               check(tile.phis==1 && tile.hp==60,"host wall is intact before join fires");
               setPhase("wall");send("break-wall");
            }
            if(!host && phase=="wall" && getTimer()-at>6000 && !afterWall) {
               afterWall=true;
               check(tile.phis==0 && tile.opac==0,"join wall stays destroyed after newer host snapshots");
               var pixels:int=wallPixels;
               Log.d("EFFECTS wall final p="+tile.phis+" opacity="+tile.opac+" enemyPixels="+pixels);
               Log.d("EFFECTS enemy x="+merc.X+" y="+merc.Y+" gg="+mod.game.gg.X+","+mod.game.gg.Y+" bounds="+merc.vis.getBounds(mod.main)+" alpha="+merc.vis.alpha+" visible="+merc.vis.visible+" parent="+merc.vis.parent+" mask="+merc.vis.mask+" frames="+wallFrames);
               saveScene();
               check(pixels>30,"enemy behind destroyed wall contributes actual viewport pixels");
               send("wall-checked");setPhase("wait-done");
            }
            if(phase!="done" && getTimer()-at>45000){check(false,"scenario timeout at "+phase);finish();}
         }catch(err:Error){check(false,err.getStackTrace());finish();}
      }
      private function prepareWall():void {
         var clear:Boolean=true;
         for(var x:int=wallX-3;x<=wallX+3;x++) if(x!=wallX && mod.game.loc.space[x][wallY].phis>0)clear=false;
         check(clear,"wall fixture has an open corridor on both sides");
         tile=mod.game.loc.space[wallX][wallY];tile.mainFrame("A");
         tile.indestruct=false;tile.hp=60;tile.thre=0;tile.door=null;tile.trap=null;
         mod.game.loc.destroyOn=true;mod.game.loc.tileSpawn=0;
         mod.game.gg.setPos(wallX*40-120,(wallY+1)*40);mod.game.gg.setVisPos();
         if(host){merc.setPos(wallX*40+120,(wallY+1)*40);merc.setVisPos();}
         mod.game.world.redrawLoc();
      }
      private function breakWall():void {
         var c:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.weapon.Bullet") as Class;
         var bullet:Object=new c(mod.game.gg,wallX*40+20,wallY*40+20,null,false);
         bullet.damage=0;bullet.destroy=1000;bullet.dx=1;bullet.dy=0;bullet.precision=0;bullet.partEmit=false;
         bullet.run();
         check(tile.phis==0 && tile.opac==0,"native join bullet breaks destructible wall");
      }
      private function frame(e:Event):void {
         if(mod==null || mod.game==null || mod.game.loc==null)return;
         if(!host && merc!=null && phase=="fire") {
            var vis:Object=merc.currentWeapon.vis;
            if(vis!=null && vis.currentLabel=="shoot")fireFrames++;
         }
         if(deathWatching)deathParts=Math.max(deathParts,parts()-partsBefore);
      }
      private function rendered(e:Event):void {
         if(!host && phase=="wall" && tile!=null && tile.phis==0 && merc!=null) {wallPixels=Math.max(wallPixels,scenePixels(merc));wallFrames++;}
      }
      private function saveScene():void {
         var scene:BitmapData=new BitmapData(mod.stage.stageWidth,mod.stage.stageHeight,false,0);scene.draw(mod.main as DisplayObject);
         var file:FileStream=new FileStream();file.open(File.applicationStorageDirectory.resolvePath("presentation-effects-wall.png"),FileMode.WRITE);
         file.writeBytes(scene.encode(scene.rect,new PNGEncoderOptions()));file.close();scene.dispose();
      }
      private function parts():int {
         var n:int=0,o:Object=mod.game.loc.firstObj,guard:int=0;
         while(o!=null && guard++<5000){if(getQualifiedClassName(o).indexOf("Part")>=0)n++;o=o.nobj;}
         return n;
      }
      private function scenePixels(u:Object):int {
         if(u==null || u.vis==null)return 0;
         var root:DisplayObject=mod.main as DisplayObject,rect:Rectangle=u.vis.getBounds(root);rect.inflate(4,4);
         rect=rect.intersection(new Rectangle(0,0,mod.stage.stageWidth,mod.stage.stageHeight));
         if(rect.width<1 || rect.height<1)return 0;
         var a:BitmapData=new BitmapData(Math.ceil(rect.width),Math.ceil(rect.height),false,0),z:BitmapData=a.clone();
         var matrix:Matrix=new Matrix(1,0,0,1,-rect.x,-rect.y);a.draw(root,matrix);
         var visible:Boolean=u.vis.visible;u.vis.visible=false;z.draw(root,matrix);u.vis.visible=visible;
         var av:Vector.<uint>=a.getVector(a.rect),zv:Vector.<uint>=z.getVector(z.rect),count:int=0;
         for(var i:int=0;i<av.length;i++)if(av[i]!=zv[i])count++;
         a.dispose();z.dispose();return count;
      }
      private function rectangleTiles():void {
         var b:GameBridge=new GameBridge({}),space:Array=[];
         for(var x:int=0;x<5;x++){space[x]=[];for(var y:int=0;y<2;y++)space[x][y]={X:x,Y:y,phis:1,front:"A",back:"",zad:"",zForm:0,water:0,stair:0,hp:60,opac:1};}
         b.loc={space:space,spaceX:5,spaceY:2};b.readTilePatch();
         space[4][1].hp=0;space[4][1].phis=0;space[4][1].front="";space[4][1].opac=0;
         var patch:Array=b.readTilePatch();
         check(patch!=null && patch.length==1 && patch[0].x==4 && patch[0].y==1,"rectangular room includes far-column tile destruction");
         b.applyTilePatch([{x:3,y:1,p:0,f:"",h:0,o:0}]);
         check(space[3][1].phis==0 && space[3][1].opac==0,"tile state applies at x-y coordinates including light opacity");
      }
      private function finish():void {phase="done";timer.stop();removeEventListener(Event.ENTER_FRAME,frame);Log.d("COOP EFFECTS DONE "+(host?"host":"join"));}
   }
}

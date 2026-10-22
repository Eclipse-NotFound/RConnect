package {
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.utils.getQualifiedClassName;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;
   import rconnect.game.MirrorHitUnit;

   /** One-time external arena preparation; never called from a measured frame. */
   public class CorridorFixture {
      public static const ID:String="native-open-corridor-v1";
      private static const TILE_KEYS:Array=["X","Y","indestruct","phis","shelf","hp","thre",
         "phX1","phX2","phY1","phY2","zForm","diagon","stair","water","fake","t_ghost","recalc",
         "vid","vid2","front","back","zad","fRear","vRear","v2Rear","opac","mat","grav","lurk",
         "kontur","konturRot","floor","place","kont1","kont2","kont3","kont4","pont1","pont2","pont3","pont4","door","trap"];
      private static const LISTS:Array=["objs","bonuses","acts","areas","grenades"];
      private static var applied:Boolean=false,removed:Array=[],geometry:Array=[],start:int=0,end:int=0;

      private static function cls(o:Object):String{return o==null?"null":getQualifiedClassName(o);}
      private static function kept(o:Object,mod:Object,actors:Array):Boolean {
         return o===mod.game.gg || actors.indexOf(o)>=0 || o is MirrorHitUnit
            || cls(o)=="rconnect.game::RemoteDamageUnit" || cls(o)=="rconnect.game::PlayerMineGate";
      }
      private static function removable(o:Object):Boolean {
         var c:String=cls(o);
         return c.indexOf("fe.loc::")==0 || c=="rconnect.game::CooperativeBonus" || c=="rconnect.game::RemoteLoot"
            || c=="fe.graph::Part" || c=="fe.weapon::Bullet" || c=="fe.weapon::SmartBullet";
      }
      private static function unlink(o:Object,loc:Object):void {
         if(o==null)return;
         removed.push(DensityFixture.fields(o,["id","X","Y","scX","scY","in_chain"]));
         removed[removed.length-1].cls=cls(o);
         if(Boolean(GameBridge.probe(o,"in_chain")))loc.remObj(o);
         // Native Location.remObj only unlinks the chain. Remove interaction
         // displays of list-only native objects too, without death/rewards.
         else {var v:DisplayObject=GameBridge.probe(o,"vis") as DisplayObject;if(v!=null && v.parent!=null)v.parent.removeChild(v);}
      }
      public static function apply(mod:Object,actors:Array,guns:Array,host:Boolean):void {
         if(applied)throw new Error("corridor preparation applied twice");start=getTimer();
         var loc:Object=mod.game.loc;
         if(loc.spaceX!=48 || loc.spaceY!=25 || loc.limX!=1920 || loc.limY!=1000)
            throw new Error("corridor requires native 48x25 room");
         var obj:Object=loc.firstObj,next:Object,seen:Array=[],n:int=0;
         while(obj!=null && n++<10000) {
            next=obj.nobj;if(seen.indexOf(obj)>=0)throw new Error("corridor cyclic chain");seen.push(obj);
            if(!kept(obj,mod,actors)) {
               if(!removable(obj))throw new Error("corridor unknown active object "+cls(obj));
               unlink(obj,loc);
            }obj=next;
         }
         if(obj!=null)throw new Error("corridor object chain too long");
         // Only this disposable test room: all optional native static objects
         // are explicitly absent. No take(), activate(), die(), or damage().
         for each(var name:String in LISTS) {
            var list:Array=loc[name] as Array;
            if(list==null)throw new Error("corridor missing native list "+name);
            for each(obj in list)if(obj!=null && seen.indexOf(obj)<0) {
               if(!removable(obj))throw new Error("corridor unknown listed object "+name+" "+cls(obj));
               unlink(obj,loc);seen.push(obj);
            }
            list.length=0;
         }
         loc.cp=null;loc.celObj=null;loc.celDist=-1;loc.backobjs.length=0;
         for each(var sign:DisplayObject in loc.signposts)if(sign.parent!=null)sign.parent.removeChild(sign);
         loc.signposts.length=0;
         loc.enspawn.length=0;loc.kolEnSpawn=0;loc.t_alarm=loc.t_alarmsp=0;
         loc.recalcTiles.length=0;loc.isRebuild=loc.isRecalc=false;
         loc.gas=0;loc.waterLevel=100;loc.tipWater=0;loc.opacWater=0;
         loc.backwall="tBackWall";loc.backform=0;loc.transpFon=false;
         loc.darkness=-20;loc.lightOn=0;loc.black=true;
         var tileClass:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.loc.Tile") as Class;
         for(var y:int=0;y<25;y++)for(var x:int=0;x<48;x++) {
            var tile:Object=loc.space[x][y],blank:Object=new tileClass(x,y);
            // Preserve the original Tile identity: installed modules may retain
            // references. Public native defaults reset ALL collision/art fields.
            for each(name in TILE_KEYS)tile[name]=blank[name];
            tile.visi=tile.t_visi=0;
            if(x==0 || x==47 || y==0 || y==24)tile.mainFrame("A");
         }
         // Native renderer, once before timing, clears old wall/background
         // bitmaps. No replacement room, world, Bullet.step or physics engine.
         mod.game.world.redrawLoc();restoreVisuals(mod,actors);DensityFixture.place(mod);
         if(host)geometry=inspectGuns(guns);
         applied=true;end=getTimer();
      }
      // drawAllObjs replaces every layer, but Unit.addVisual immediately
      // returns for disabled actors. Restore the exact native chain order once,
      // then the local player (the same order as Grafon.drawAllObjs). Never
      // attach a MirrorHitUnit: it borrows the actual body's visual. The mine
      // gate is intentionally invisible and must remain so.
      private static function displayUnits(mod:Object,actors:Array):Array {
         var out:Array=[],o:Object=mod.game.loc.firstObj,n:int=0;
         while(o!=null && n++<10000) {
            if(actors.indexOf(o)>=0 || cls(o)=="rconnect.game::RemoteDamageUnit") {
               if(out.indexOf(o)>=0)throw new Error("corridor duplicate display unit");
               out.push(o);
            }
            o=o.nobj;
         }
         if(o!=null)throw new Error("corridor display chain too long");
         for each(o in actors)if(out.indexOf(o)<0)throw new Error("corridor actor left native chain");
         if(out.indexOf(mod.game.gg)<0)out.push(mod.game.gg);
         return out;
      }
      private static function restoreVisuals(mod:Object,actors:Array):void {
         for each(var u:Object in displayUnits(mod,actors)) {
            var wasDisabled:Boolean=Boolean(u.disabled),wasTrigger:Boolean=Boolean(u.trigDis);
            try {u.disabled=false;u.addVisual();}
            finally {u.disabled=wasDisabled;}
            if(Boolean(u.trigDis)!=wasTrigger)throw new Error("corridor addVisual changed native trigger eligibility");
         }
      }
      private static function viewRow(mod:Object,v:DisplayObject,expected:Object,label:String,visible:Boolean,owner:DisplayObject=null):Object {
         var attached:Boolean=v!=null && v.stage===mod.stage && v.parent===expected;
         if(owner!=null)attached=v!=null && v.stage===mod.stage && owner is DisplayObjectContainer
            && DisplayObjectContainer(owner).contains(v);
         var shown:Boolean=v!=null && v.width>0 && v.height>0,p:DisplayObject=v;
         while(p!=null){shown=shown && p.visible && p.alpha>0;p=p.parent;}
         return {label:label,attached:attached,shown:shown,requiredVisible:visible,
            ok:attached && (!visible || shown),cls:cls(v),parent:v==null?"null":cls(v.parent),
            stage:v!=null && v.stage===mod.stage,visible:v!=null && v.visible,alpha:v==null?0:v.alpha};
      }
      private static function visualStatus(mod:Object,actors:Array):Object {
         var rows:Array=[],bad:Array=[],counts:Object={actors:0,actorWeapons:0,localPlayer:0,remotePlayer:0},
            layers:Object=mod.game.world.grafon.visObjs;
         for each(var u:Object in displayUnits(mod,actors)) {
            var actor:Boolean=actors.indexOf(u)>=0,local:Boolean=u===mod.game.gg;
            var label:String=actor?"actor:"+actors.indexOf(u):(local?"local-player":"remote-player");
            counts[actor?"actors":(local?"localPlayer":"remotePlayer")]++;
            var v:DisplayObject=GameBridge.probe(u,"vis") as DisplayObject;
            rows.push(viewRow(mod,v,layers[int(u.sloy)],label,true));
            var part:DisplayObject=GameBridge.probe(u,"visBmp") as DisplayObject;
            if(part==null)part=GameBridge.probe(v,"osn") as DisplayObject;
            if(part!=null)rows.push(viewRow(mod,part,null,label+":body-part",true,v));
            var bar:DisplayObject=GameBridge.probe(u,"hpbar") as DisplayObject;
            // Native hidden health bars need correct attachment, not visibility.
            if(bar!=null)rows.push(viewRow(mod,bar,layers[3],label+":health-bar",false));
            if(actor || local) {
               var guns:Array=[],current:Object=GameBridge.probe(u,"currentWeapon"),child:Object;
               if(current!=null)guns.push(current);
               if(u.childObjs is Array)for each(child in u.childObjs)
                  if(child!=null && guns.indexOf(child)<0 && GameBridge.probe(child,"vis")!=null)guns.push(child);
               for each(var gun:Object in guns) {
                  var wv:DisplayObject=GameBridge.probe(gun,"vis") as DisplayObject;
                  rows.push(viewRow(mod,wv,layers[int(gun.sloy)],label+":weapon:"+String(gun.id),true));
                  part=GameBridge.probe(wv,"kor") as DisplayObject;
                  if(part!=null)rows.push(viewRow(mod,part,null,label+":weapon-body",true,wv));
               }
               if(actor && current!=null)counts.actorWeapons++;
            } else {
               // RConnect's real peer weapon is a child of visualPlayer, not
               // a native independent object-layer weapon.
               current=GameBridge.probe(u,"currentWeapon");
               wv=GameBridge.probe(current,"vis") as DisplayObject;
               if(current!=null && wv!=null)rows.push(viewRow(mod,wv,null,label+":peer-weapon",true,v));
            }
         }
         for each(var row:Object in rows)if(!row.ok)bad.push(["visual",row.label,row]);
         if(counts.actors!=80 || counts.actorWeapons!=39 || counts.localPlayer!=1 || counts.remotePlayer!=1)
            bad.push(["visual-counts",counts]);
         return {counts:counts,rows:rows,bad:bad,ok:bad.length==0};
      }
      private static function inspectGuns(guns:Array):Array {
         if(guns.length!=12)throw new Error("corridor expected 12 native firing guns");
         var rows:Array=[];
         for each(var gun:Object in guns) {
            var owner:Object=gun.owner;
            // Only initial presentation placement. Later fire/step/frame code
            // is exactly the frozen driver03 stimulus, including native recoil.
            // Native actions() ignores forceRot while findCel=true (default).
            // Fix the intended aim at setup, not by modifying measured firing.
            gun.findCel=false;owner.setWeaponPos(gun.tip);
            gun.X=owner.weaponX;gun.Y=owner.weaponY;gun.rot=gun.forceRot=-Math.PI/3;
            gun.animate();gun.getBulXY();
            var row:Object={id:String(gun.id),x:Number(gun.bulX),y:Number(gun.bulY),speed:Number(gun.speed),
               speedMult:Number(gun.speedMult),recoilUp:Number(gun.recoilUp),recoilMult:Number(gun.recoilMult),
               deviation:Number(gun.deviation),devMult:Number(gun.devMult),mazil:Number(owner.mazil),
               grav:Number(gun.grav),volna:Boolean(gun.volna),direction:Number(owner.storona),
               findCel:Boolean(gun.findCel),fixRot:Number(gun.fixRot),weaponX:Number(owner.weaponX),weaponY:Number(owner.weaponY)};
            row.ok=row.id=="lmg" && row.x>=240 && row.x<=460 && row.y>=860 && row.y<=950
               && row.speed==200 && row.speedMult==1 && row.recoilUp==0 && row.deviation==0
               && row.devMult>=0 && row.devMult<=1 && row.mazil>=0 && row.mazil<=30
               && row.grav==0 && !row.volna && row.direction==1 && !row.findCel && row.fixRot==0;
            rows.push(row);if(!row.ok)throw new Error("corridor native flight bound not satisfied "+DensityFixture.canonical(row));
         }return rows;
      }
      public static function status(mod:Object,actors:Array):Object {
         var loc:Object=mod.game.loc,cells:Array=[],bad:Array=[],counts:Object={},obj:Object,n:int=0;
         for(var y:int=0;y<25;y++)for(var x:int=0;x<48;x++) {
            var t:Object=loc.space[x][y],edge:Boolean=x==0 || x==47 || y==0 || y==24;
            cells.push(DensityFixture.fields(t,TILE_KEYS));
            if(int(t.phis)!=(edge?1:0) || t.door!=null || t.trap!=null || t.water!=0 || t.shelf
               || t.zForm!=0 || t.diagon!=0 || t.stair!=0 || t.fake || (edge && !t.indestruct))
               bad.push([x,y,"collision"]);
         }
         for each(var name:String in LISTS){counts[name]=loc[name].length;if(counts[name]!=0)bad.push([name,counts[name]]);}
         if(loc.backobjs.length!=0 || loc.signposts.length!=0 || loc.cp!=null || loc.backwall!="tBackWall" || loc.backform!=0 || loc.transpFon)
            bad.push(["static-render-state"]);
         obj=loc.firstObj;
         while(obj!=null && n++<10000) {
            // Newly emitted Part visuals are dynamic observations, not static
            // room identity. Unknown static/collision objects block readiness.
            if(!kept(obj,mod,actors) && cls(obj)!="fe.graph::Part")bad.push(["chain",cls(obj)]);
            obj=obj.nobj;
         }
         if(obj!=null)bad.push(["chain-limit"]);
         for each(obj in loc.units)if(!kept(obj,mod,actors)) {
            // Inactive native pet with NaN coordinates exists in both original
            // fixtures. Do not destroy the player's persistent pet reference.
            if(cls(obj)!="fe.unit::UnitPet" || Boolean(obj.in_chain) || isFinite(Number(obj.X)) || isFinite(Number(obj.Y)))
               bad.push(["units",cls(obj)]);
         }
         var views:Object=applied?visualStatus(mod,actors):null;
         if(views!=null)bad=bad.concat(views.bad);
         return {ok:applied && bad.length==0,visuals:views,common:{fixture:ID,tileHash:DensityFixture.hash(cells),
            staticLists:counts,backobjs:int(loc.backobjs.length),signposts:int(loc.signposts.length),backwall:String(loc.backwall),backform:int(loc.backform)},
            cells:cells,bad:bad};
      }
      public static function log(mod:Object,actors:Array,host:Boolean):void {
         var s:Object=status(mod,actors);
         Log.d("DENSITY CORRIDOR "+DensityFixture.canonical({schema:1,role:host?"host":"join",fixture:ID,
            applied:applied,prepareMs:end-start,common:s.common,bad:s.bad,cells:s.cells,removed:removed,geometry:geometry,
            visuals:s.visuals,nativeVisualRestore:true,
            changedWorkload:"new open rectangle, zero optional static objects; compare same driver only",
            nativeFlightUnmodified:true,geometryOnlyNotRuntimePass:true}));
      }
   }
}

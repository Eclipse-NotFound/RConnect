package authority {
   import flash.display.DisplayObject;
   import flash.display.MovieClip;
   import flash.geom.ColorTransform;
   import flash.utils.Dictionary;
   import flash.utils.getTimer;
   import flash.utils.getQualifiedClassName;
   import fe.unit.AuthorityAnimation;
   import fe.unit.Unit;
   /** Native geometry and target entities with no client-side combat execution. */
   public final class ReplicaScene {
      public var key:String="",room:Object,units:Object={},objects:Object={};
      public var applications:uint=0,terrainApplications:uint=0;
      public var terrainRedraws:uint=0;
      public var terrainCacheHits:uint=0,terrainCacheStores:uint=0;
      public var incrementalWalls:uint=0;
      public var terrainRevision:uint=0;
      public var effects:SceneEffects;
      private var access:NativeAccess;
      private var terrainCache:TerrainBitmapCache=new TerrainBitmapCache();
      private var vision:SharedVision,lightDirty:Boolean=true,lightX:Number=NaN,lightY:Number=NaN;
      private var players:Dictionary=new Dictionary(true);
      private var confirmedTiles:Array=[];
      private var backdrops:SceneBackdrops;
      public function ReplicaScene(access:NativeAccess,vision:SharedVision=null){this.access=access;this.vision=vision;effects=new SceneEffects(access);backdrops=new SceneBackdrops(access);}
      public function keyFor(unit:Object):uint {if(players[unit])return players[unit];for(var id:String in units)if(units[id].unit===unit)return uint(id);return 0;}
      public function registerPlayer(unit:Object,key:uint):void {players[unit]=key;}
      /** Only selects confirmed objects for native GUI text. Never steps an
       * interaction, a weapon, or a local copy of the authoritative world. */
      public function pointer(extra:Array=null):void {
         if(room==null)return;
         var w:Object=access.world,chosen:Object=selection(extra,w.celX,w.celY,true);
         room.celObj=chosen;
         room.celDist=chosen==null?-1:Math.pow(w.gg.X-chosen.X,2)+Math.pow(w.gg.Y-chosen.Y,2);
      }
      /** Read the old displayed scene before present() advances it. This
       * does not mutate hover state or execute an interaction. */
      public function selection(extra:Array,x:Number,y:Number,mark:Boolean=false):Object {
         if(room==null)return null;
         var chosen:Object=null,rec:Object,o:Object;
         for each(rec in units){o=rec.unit;chosen=hover(o,chosen,x,y,mark);}
         for each(rec in objects){o=rec.object;chosen=hover(o,chosen,x,y,mark);}
         for each(rec in effects.records)if(rec.pointer!=null)chosen=hover(rec.pointer,chosen,x,y,mark);
         if(extra!=null)for each(o in extra)chosen=hover(o,chosen,x,y,mark);
         return chosen;
      }
      private function hover(o:Object,chosen:Object,x:Number,y:Number,mark:Boolean):Object {
         var eligible:Boolean=o!==access.world.gg && !NativeAccess.get(o,"disabled",false) &&
            int(NativeAccess.get(o,"sost",1))<4 && NativeAccess.get(o,"isVis",true)!==false &&
            NativeAccess.get(o,"invis",false)!==true;
         var x1:Number=isFinite(o.X1)?o.X1:o.X-o.scX/2,x2:Number=isFinite(o.X2)?o.X2:o.X+o.scX/2;
         var y1:Number=isFinite(o.Y1)?o.Y1:o.Y-o.scY,y2:Number=isFinite(o.Y2)?o.Y2:o.Y;
         var priority:Number=eligible && x1<x && x2>x && y1<y && y2>y?o.prior:0;
         if(mark)o.onCursor=priority;
         return priority>0 && (chosen==null || priority>=chosen.prior)?o:chosen;
      }
      /** Constructors may attach extra limbs/arcs of their own. The host's
       * display manifest owns those parts too; discard only unconfirmed roots
       * in world layers, retaining local masks used by confirmed displays. */
      public function prune(extra:Array):void {
         var keep:Dictionary=new Dictionary(true),rec:Object,gun:Object,d:DisplayObject;
         for each(d in extra)if(d!=null)keep[d]=true;
         for each(rec in units) {
            if(rec.unit.vis!=null)keep[rec.unit.vis]=true;
            if(rec.unit.hpbar!=null)keep[rec.unit.hpbar]=true;
            for each(gun in rec.weapons)if(gun.vis!=null)keep[gun.vis]=true;
         }
         for each(rec in objects) {
            if(rec.object.vis!=null)keep[rec.object.vis]=true;
            if(rec.shadow!=null)keep[rec.shadow]=true;
         }
         for each(rec in effects.records)keep[rec.clip]=true;
         for(var value:Object in keep){d=value as DisplayObject;if(d!=null && d.mask!=null)keep[d.mask]=true;}
         for each(var layer:Object in access.world.grafon.visObjs)
            for(var i:int=layer.numChildren-1;i>=0;i--)if(!keep[layer.getChildAt(i)])layer.removeChildAt(i);
      }
      public function petFor(player:int):Object {for each(var rec:Object in units)if(rec.petOwner===player)return rec.unit;return null;}
      public function apply(s:Object):Boolean {
         var began:int=Timing.start();
         var changed:Boolean=key!==s.key,w:Object=access.world;
         if(changed) {
            if(!s.full || s.fields==null)throw new Error("Room transition requires a complete authoritative scene");
            if(room!=null && vision!=null)vision.remember(room);
            dispose(true);
            var Location:Class=access.definition("fe.loc.Location");
            var definition:XML=<room/>;
            for(var row:int=0;row<int(s.fields.spaceY);row++)definition.appendChild(<a>{new Array(int(s.fields.spaceX)+1).join(".")}</a>);
            room=new Location(w.land,definition,false,{ramka:0});
            NativeFields.apply(room,s.fields);key=s.key;
            room.units=[];room.objs=[];room.acts=[];room.bonuses=[];
            room.firstObj=room.lastObj=room.nextObj=null;
            room.gg=w.gg;room.active=true;room.visited=true;room.grafon=w.grafon;
            room.cTransform=color(s.tint);room.cTransformFon=color(s.fonTint);
            w.loc=room;w.land.loc=room;w.land.locX=room.landX;w.land.locY=room.landY;w.land.locZ=room.landZ;
            w.land.prob=room.landProb;w.gg.loc=room;room.units.push(w.gg);
         }
         var wasBlack:Boolean=room.black;
         NativeFields.apply(room,s.fields);
         if(changed || wasBlack!==room.black) {
            lightDirty=true;
            if(!room.black)for(var lx:int=0;lx<room.spaceX;lx++)for(var ly:int=0;ly<room.spaceY;ly++)
               room.space[lx][ly].visi=room.space[lx][ly].t_visi=1;
         }
         var backdropChanged:Boolean=backdrops.apply(room,s.backdrop);
         var geometry:Boolean=changed || backdropChanged || wasBlack!==room.black || access.ink.needsRedraw(w.grafon,s.ink);
         var redrawReasons:Object=Timing.enabled?{room:changed,dark:wasBlack!==room.black,ink:access.ink.needsRedraw(w.grafon,s.ink),fields:{}}:null;
         var patchCount:uint=0;
         for each(var tile:Object in s.tiles) {
            var t:Object=room.space[int(tile.x)][int(tile.y)];
            var tileIndex:int=int(tile.x)*room.spaceY+int(tile.y),before:Array=confirmedTiles[tileIndex];
            var patched:Boolean=!geometry && TerrainPatch.isFrontDestruction(before,tile.v,tile.plainFront===true) &&
               access.ink.coversFrontChange(w.grafon,s.ink,int(tile.x)*int(Object(w).constructor.tileX),
                  int(tile.y)*int(Object(w).constructor.tileY),int(Object(w).constructor.tileX),int(Object(w).constructor.tileY));
            if(patched){++patchCount;lightDirty=true;}
            for(var i:int=0;i<SceneSnapshot.TILE.length;i++) {
               var field:String=SceneSnapshot.TILE[i];
               // Durability changes do not change native tile artwork.
               // A full drawLoc here costs hundreds of milliseconds under
               // sustained fire and replaces every object layer. Actual
               // destruction still changes collision/art fields; native
               // bullet holes have their independent changed-block stream.
               // drawLoc recomputes its local corner caches (kont/pont).
               // Compare consecutive authority states, not that mutated
               // renderer cache, or each subsequent bullet hit redraws the
               // entire room even when only durability changed.
               if(!patched && (before==null || before[i]!==tile.v[i]) && field!="hp" && field!="thre" && field!="indestruct") {
                  geometry=true;if(redrawReasons!=null)redrawReasons.fields[field]=uint(redrawReasons.fields[field])+1;
               }
               t[field]=tile.v[i];
            }
            confirmedTiles[tileIndex]=tile.v;
            ++terrainApplications;
         }
         if(changed) {
            if(vision!=null)vision.restore(room);
            if(!room.black)for(var x:int=0;x<room.spaceX;x++)for(var y:int=0;y<room.spaceY;y++)room.space[x][y].visi=room.space[x][y].t_visi=1;
            w.grafon.drawFon(w.vfon,s.fon);
         }
         if(geometry) {
            if(redrawReasons!=null)Log.write("terrain-redraw",redrawReasons);
            var cacheBegan:int=getTimer();
            var cacheHit:Boolean=changed && terrainCache.restore(s,room,w.grafon,confirmedTiles,w.black);
            if(cacheHit) {
               terrainCacheHits=terrainCache.hits;
               Log.write("terrain-cache-hit",{key:s.key,tiles:s.tiles.length,ms:getTimer()-cacheBegan});
            }else {
               var drawBegan:int=getTimer();
               ++terrainRedraws;
               lightDirty=true;
               w.grafon.drawLoc(room);
               var drawMs:int=getTimer()-drawBegan;
               if(changed) {
                  terrainCache.store(s,room,w.grafon,confirmedTiles);
                  terrainCacheStores=terrainCache.stores;
               }
               Log.write(changed?"terrain-cache-store":"terrain-cache-redraw",{key:s.key,tiles:s.tiles.length,drawMs:drawMs,storeMs:getTimer()-drawBegan-drawMs,cached:changed});
            }
            w.cam.setLoc(room);
            for each(var rec:Object in units)attach(rec.unit,rec.layer);
            for each(rec in objects)attachObject(rec);
         }else incrementalWalls+=patchCount;
         access.ink.apply(w.grafon,s.ink,geometry);
         var live:Object={};
         Timing.end("replica.terrain",began);began=Timing.start();
         for each(var state:Object in s.units) {applyUnit(state);live[state.key]=true;}
         for(var id:String in units)if(!live[id])removeUnit(id);
         Timing.end("replica.units",began);began=Timing.start();
         live={};
         for each(state in s.objects){applyObject(state);live[state.key]=true;}
         for(id in objects)if(!live[id])removeObject(id);
         effects.apply(s.effects);
         Timing.end("replica.objectsAndEffects",began);
         terrainRevision=s.terrainRevision;
         ++applications;return changed;
      }
      /** Native lighting is a local view calculation, not a second battle step. */
      public function light(paused:Boolean):void {
         if(room==null || !room.black || paused)return;
         var g:Object=access.world.gg;
         if(lightDirty || Math.abs(g.X-lightX)>.5 || Math.abs(g.Y-lightY)>.5) {
            room.lighting();lightX=g.X;lightY=g.Y;lightDirty=false;
         }else if(room.relight_t>0)room.lighting2();
      }
      /** The confirmed state has already been consumed. Between its timestamps
       * update only motion/display: no inventory, terrain, constructors or UI. */
      public function interpolate(s:Object):void {
         if(s.key!==key)throw new Error("Interpolation crossed a room boundary");
         for each(var state:Object in s.units) {
            var rec:Object=units[state.key];if(rec==null)throw new Error("Interpolation lacks a confirmed unit");
            var u:Object=rec.unit;NativeFields.motion(u,state.motion!=null?state.motion:state.fields);VisualPose.motion(u.vis,state.pose);
            if(state.attached && u.hpbar!=null && state.healthBar==null)u.setHpbarPos();
            healthBar(u,state,true);
            for(var i:int=0;i<state.weapons.length;i++)VisualPose.motion(rec.weapons[i].vis,state.weapons[i].pose);
         }
         for each(state in s.objects) {
            rec=objects[state.key];if(rec==null)throw new Error("Interpolation lacks a confirmed object");
            NativeFields.motion(rec.object,state.fields);VisualPose.motion(rec.object.vis,state.pose);
            if(rec.shadow!=null && state.shadow!=null)VisualPose.motion(rec.shadow,state.shadow.pose);
         }
         effects.interpolate(s.effects);
      }
      /** Skip rewriting an unchanged immutable base; sparse deltas still apply. */
      private function applyConfirmed(target:Object,s:Object,rec:Object):void {
         if(rec.appliedBase!==s.fields) {
            NativeFields.apply(target,s.fields);rec.appliedBase=s.fields;rec.appliedDelta=null;
         }
         if(s.fieldsDelta!=null && rec.appliedDelta!==s.fieldsDelta) {
            NativeFields.apply(target,s.fieldsDelta);rec.appliedDelta=s.fieldsDelta;
         }
      }
      private function applyUnit(s:Object):void {
         var rec:Object=units[s.key],u:Object;
         if(rec!=null && rec.burning && !s.burning){removeUnit(String(s.key));rec=null;}
         if(rec==null) {
            var ClassRef:Class=access.definition(String(s.cls).replace("::",".")),cid:String=NativeFields.get(s,"id");
            var placement:XML=<unit/>;
            if(int(NativeFields.get(s,"tr"))>0)placement.@tr=int(NativeFields.get(s,"tr"));
            if(s.cls.indexOf("UnitAlicorn")>=0)cid=String(NativeFields.get(s,"tr"));
            // UnitBat.tr is package-internal; its public id still identifies
            // the authored variant. Passing "bloodwing2" as a numeric cid
            // silently constructs the first variant instead.
            if(s.cls=="fe.unit::UnitBat")cid=NativeFields.get(s,"id")=="bloodwing"?"1":String(NativeFields.get(s,"id")).replace(/^bloodwing/,"");
            if(s.cls.indexOf("UnitTurret")>=0)cid=["","land","wall","arm","combat","boss"][int(s.mount)];
            if(s.cls=="fe.unit::UnitTrap")cid=null;
            u=new ClassRef(cid,Number(room.locDifLevel),placement,null);
            u.putLoc(room,NativeFields.get(s,"X"),NativeFields.get(s,"Y"));
            room.units.push(u);rec=units[s.key]={unit:u,weapons:[],layer:s.layer};
         }
         u=rec.unit;
         if(s.clip!=null && (getQualifiedClassName(u.vis)!==s.clip || s.burning && !rec.burning)) {
            u.remVisual();VisualPose.dispose(u.vis);
            var Body:Class=access.visualClass(s.clip);u.vis=new Body();
            rec.appliedPose=null;rec.appliedBlit=null;rec.appliedHealthBar=null;
         }
         rec.burning=s.burning;
         rec.petOwner=s.petOwner;
         applyConfirmed(u,s,rec);u.loc=room;
         NativeFields.apply(u.inter,s.inter);
         if(s.attached)attach(u,s.layer);else u.remVisual();u.setVisPos();
         if(rec.appliedBlit!==s.blit) {
            AuthorityAnimation.apply(u as Unit,s.blit);rec.appliedBlit=s.blit;
         }
         // Health bars are native render-only methods; no damage/AI is replayed.
         if(s.attached && !u.player && u.vis!=null && !u.disabled && u.sost<3) {
            if(u.hpbar==null || s.healthBar==null || u.boss) {
               // Keep native creation and the separate boss HUD side effect.
               u.addVisual();u.visDetails();u.setHpbarPos();
            }else if(s.healthBar.attached) {
               // Its complete confirmed pose follows below. Recalculating the
               // same bar with replica-private maxima only gets overwritten;
               // retain native layer order without that second calculation.
               access.world.grafon.visObjs[3].addChild(u.hpbar);
            }
         }
         if(rec.appliedPose!==s.pose) {
            VisualPose.apply(u.vis,s.pose);rec.appliedPose=s.pose;
         }
         if(rec.appliedHealthBar!==s.healthBar) {
            healthBar(u,s);rec.appliedHealthBar=s.healthBar;
         }
         for(var i:int=0;i<s.weapons.length;i++) {
            var gs:Object=s.weapons[i],gun:Object=rec.weapons[i];
            if(gun==null || gun.id!=gs.id || gun.variant!=gs.variant) {
               if(gun!=null)gun.remVisual();
               gun=access.definition("fe.weapon.Weapon")["create"](u,gs.id,int(gs.variant));
               rec.weapons[i]=gun;if(rec.weaponApplied!=null)rec.weaponApplied[i]=null;
            }
            if(rec.weaponApplied==null)rec.weaponApplied=[];
            var weaponState:Object=rec.weaponApplied[i];if(weaponState==null){weaponState={};rec.weaponApplied[i]=weaponState;}
            applyConfirmed(gun,gs,weaponState);gun.loc=room;
            if(gs.attached)attach(gun,gun.sloy);else gun.remVisual();
            if(weaponState.appliedPose!==gs.pose) {
               VisualPose.apply(gun.vis,gs.pose);weaponState.appliedPose=gs.pose;
            }
         }
         while(rec.weapons.length>s.weapons.length){rec.weapons.pop().remVisual();if(rec.weaponApplied!=null)rec.weaponApplied.pop();}
         // Native constructor child weapons may be different from the confirmed loadout.
         for each(var original:Object in u.childObjs)if(original!=null && rec.weapons.indexOf(original)<0)original.remVisual();
         u.childObjs=rec.weapons;
      }
      private function applyObject(s:Object):void {
         var rec:Object=objects[s.key],o:Object;
         if(rec==null) {
            var Obj:Class=access.definition("fe.Obj");o=new Obj();o.loc=room;
            if(s.clip!=null) {
               var Clip:Class=access.visualClass(s.clip);o.vis=new Clip();
            }
            rec=objects[s.key]={object:o,layer:int(NativeFields.get(s,"sloy")),inter:s.inter,attached:false,shadow:null,shadowState:null};
         }
         o=rec.object;
         if(s.inter!=null && s.inter.hasOwnProperty("active")) {
            if(o.inter==null){var Interact:Class=access.definition("fe.serv.Interact");o.inter=new Interact(o);}
            NativeFields.apply(o.inter,s.inter);
         }else o.inter=null;
         // The native Interact constructor increments priority; restore the
         // host's actual object fields after constructing the read-only view.
         applyConfirmed(o,s,rec);rec.inter=s.inter;rec.layer=int(NativeFields.get(s,"sloy"));rec.attached=s.attached;
         if(s.shadow==null)removeShadow(rec);
         else {
            if(rec.shadow==null || getQualifiedClassName(rec.shadow)!==s.shadow.clip) {
               removeShadow(rec);
               var Shadow:Class=access.visualClass(s.shadow.clip);rec.shadow=new Shadow() as DisplayObject;
               if(rec.shadow==null)throw new Error("Unsupported native box shadow: "+s.shadow.clip);
               rec.appliedShadowPose=null;
            }
            rec.shadowState=s.shadow;
            if(rec.appliedShadowPose!==s.shadow.pose) {
               VisualPose.apply(rec.shadow,s.shadow.pose);rec.appliedShadowPose=s.shadow.pose;
            }
         }
         attachObject(rec);
         if(rec.appliedPose!==s.pose) {
            VisualPose.apply(o.vis,s.pose);rec.appliedPose=s.pose;
         }
      }
      private function attachObject(rec:Object):void {
         var state:Object=rec.shadowState;
         if(state==null || state.beforeBody!==false)attachShadow(rec);
         if(rec.attached)attach(rec.object,rec.layer);else rec.object.remVisual();
         if(state!=null && state.beforeBody===false)attachShadow(rec);
      }
      private function attachShadow(rec:Object):void {
         var shadow:DisplayObject=rec.shadow as DisplayObject,state:Object=rec.shadowState;
         if(shadow==null)return;
         if(state!=null && state.attached)access.world.grafon.visObjs[int(state.layer)].addChild(shadow);
         else if(shadow.parent!=null)shadow.parent.removeChild(shadow);
      }
      private function removeShadow(rec:Object):void {
         var shadow:DisplayObject=rec.shadow as DisplayObject;
         if(shadow!=null) {
            if(shadow.parent!=null)shadow.parent.removeChild(shadow);
            VisualPose.dispose(shadow);
         }
         rec.shadow=null;rec.shadowState=null;
      }
      private function removeObject(id:String):void {
         var rec:Object=objects[id];removeShadow(rec);
         rec.object.remVisual();VisualPose.dispose(rec.object.vis);delete objects[id];
      }
      private function healthBar(u:Object,s:Object,interpolated:Boolean=false):void {
         if(u.hpbar==null || s.healthBar==null)return;
         // The native bar can depend on private per-enemy armor/shield maxima.
         // Its confirmed pose preserves the real calculation and cloak alpha.
         if(s.healthBar.attached) {
            if(u.hpbar.parent!==access.world.grafon.visObjs[3])access.world.grafon.visObjs[3].addChild(u.hpbar);
         }else if(u.hpbar.parent!=null)u.hpbar.parent.removeChild(u.hpbar);
         HealthBarPose.apply(u.hpbar,s.healthBar,interpolated);
      }
      private function attach(o:Object,layer:int):void {
         if(o.vis!=null && int(NativeAccess.get(o,"sost",1))<4)
            access.world.grafon.visObjs[Math.max(0,Math.min(5,layer))].addChild(o.vis);
         else if(o.vis!=null && o.vis.parent!=null)o.vis.parent.removeChild(o.vis);
      }
      private function color(a:Array):ColorTransform{return a==null?null:new ColorTransform(a[0],a[1],a[2],a[3],a[4],a[5],a[6],a[7]);}
      private function removeUnit(id:String):void {
         var rec:Object=units[id];rec.unit.remVisual();VisualPose.dispose(rec.unit.vis);
         for each(var gun:Object in rec.weapons)gun.remVisual();
         var at:int=room.units.indexOf(rec.unit);if(at>=0)room.units.splice(at,1);delete units[id];
      }
      public function dispose(keepTerrainCache:Boolean=false):void {
         if(room!=null){room.celObj=null;room.celDist=-1;}
         for(var id:String in units)removeUnit(id);
         for(id in objects)removeObject(id);
         units={};objects={};confirmedTiles=[];room=null;key="";
         lightDirty=true;lightX=lightY=NaN;
         effects.dispose();
         backdrops.dispose();
         if(!keepTerrainCache)terrainCache.dispose();
      }
   }
}

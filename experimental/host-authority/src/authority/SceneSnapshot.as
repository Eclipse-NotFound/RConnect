package authority {
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.Sprite;
   import flash.display.MovieClip;
   import flash.display.Shape;
   import flash.utils.Dictionary;
   import flash.utils.getQualifiedClassName;
   import fe.unit.AuthorityAnimation;
   import fe.unit.Unit;
   import fe.graph.AuthorityParticle;
   /** One authoritative room, stable entity IDs and terrain changes. */
   public final class SceneSnapshot {
      public static const TILE:Array=["phis","shelf","hp","thre","zForm","diagon","stair","water","fake","vid","vid2",
         "front","back","zad","fRear","vRear","v2Rear","opac","mat","grav","lurk","kontur","konturRot","floor","place",
         "kont1","kont2","kont3","kont4","pont1","pont2","pont3","pont4","indestruct"];
      private var access:NativeAccess,ids:Dictionary=new Dictionary(true),nextId:uint=0;
      private var previousRoom:Object,tiles:Array=[];
      private var targets:Object={};
      private var masks:DisplayMasks=new DisplayMasks();
      private var terrainRevision:uint=0;
      public function SceneSnapshot(access:NativeAccess){this.access=access;}
      public function id(object:Object):uint {
         if(object==null)return 0;
         if(!ids[object])ids[object]=++nextId;
         // Only native units can be SATS targets. Particles and loot do not
         // acquire a permanent strong reference just because they were drawn.
         if(object is Unit)targets[ids[object]]=object;
         return ids[object];
      }
      public function target(id:uint):Object{return targets[id];}
      public function reset():void {ids=new Dictionary(true);targets={};previousRoom=null;tiles=[];masks.reset();}
      public function fullNext():void {previousRoom=null;tiles=[];}
      public function capture(room:Object,actors:Array,tick:uint):Object {
         var began:int=Timing.start();
         var full:Boolean=previousRoom!==room;
         if(full){previousRoom=room;tiles=[];}
         var result:Object={key:access.keyFor(room),full:full,tiles:[],units:[],objects:[],effects:[]};
         result.fields=NativeFields.capture(room);
         result.ink=access.ink.snapshot(room.grafon);
         var rendered:Dictionary=new Dictionary(true);
         for each(var actor:PlayerActor in actors) {
            rendered[actor.unit.vis]=true;
            if(actor.unit.hpbar!=null)rendered[actor.unit.hpbar]=true;
            // Quick magic/throw slots are stepped by UnitPlayer even when they
            // are outside childObjs. Capture every attached auxiliary weapon
            // once, through the same native pose/effect lifetime path.
            var actorVisuals:Array=actor.unit.childObjs.concat([actor.unit.throwWeapon,actor.unit.magicWeapon]);
            for each(var child:Object in actorVisuals)if(child!=null && child.vis!=null && !rendered[child.vis]) {
               rendered[child.vis]=true;
               if(actor.unit.loc===room && child!==actor.unit.currentWeapon && !(child is Unit) && child.vis.parent!=null)
                  result.effects.push({key:id(child),positionEpoch:access.positionEpoch(actor.unit),clip:getQualifiedClassName(child.vis),layer:child.sloy,pose:VisualPose.capture(child.vis),atlas:null});
            }
         }
         if(full) {
            result.fields=NativeFields.capture(room);result.fon=room.land.act.fon;
            result.tint=color(room.cTransform);result.fonTint=color(room.cTransformFon);
         }
         var tilesStarted:int=Timing.start();
         // Collision and displayed terrain come from the same host tile state.
         for(var x:int=0;x<room.spaceX;x++)for(var y:int=0;y<room.spaceY;y++) {
            var at:int=x*room.spaceY+y,t:Object=room.space[x][y],old:Array=full?null:tiles[at];
            var values:Array=TerrainScan.capture(t,old);
            if(values!==old) {
               tiles[at]=values;result.tiles.push({x:x,y:y,v:values});
            }
         }
         Timing.end("capture.tiles",tilesStarted);
         var unitsStarted:int=Timing.start();
         for each(var u:Object in room.units)if(u!=null && !u.player) {
            var burning:Boolean=AuthorityAnimation.burning(u as Unit);
            var replay:Boolean=access.time!=null && access.time.phase=="replay";
            var us:Object={key:id(u),positionEpoch:access.positionEpoch(u),cls:getQualifiedClassName(u),fields:NativeFields.capture(u),inter:NativeFields.capture(u.inter),pose:VisualPose.capture(u.vis,0,burning || replay),
               clip:u.vis==null?null:getQualifiedClassName(u.vis),burning:burning,
               blit:burning || replay?null:AuthorityAnimation.capture(u as Unit),weapons:[],petOwner:-1,layer:u.sloy,attached:u.vis!=null && u.vis.parent!=null};
            us.healthBar=u.hpbar==null?null:{pose:VisualPose.capture(u.hpbar),attached:u.hpbar.parent!=null};
            for each(actor in actors)if(actor.unit.pet===u)us.petOwner=actor.id;
            if(us.cls.indexOf("UnitTurret")>=0)us.mount=int(getQualifiedClassName(u.vis).replace(/^.*visualTurret/,""));
            for each(var weapon:Object in u.childObjs)if(weapon!=null && "kol_shoot" in weapon)
               us.weapons.push({id:weapon.id,variant:weapon.variant,pose:VisualPose.capture(weapon.vis),fields:NativeFields.capture(weapon),attached:weapon.vis!=null && weapon.vis.parent!=null});
            result.units.push(us);
            if(u.vis!=null)rendered[u.vis]=true;
            if(u.hpbar!=null)rendered[u.hpbar]=true;
            for each(child in u.childObjs)if(child!=null && child.vis!=null)rendered[child.vis]=true;
         }
         Timing.end("capture.units",unitsStarted);
         Timing.end("capture.unitsAndTiles",began);began=Timing.start();
         var seen:Dictionary=new Dictionary(true);
         for each(var list:Array in [room.objs,room.acts,room.bonuses])for each(var o:Object in list)if(o!=null && !seen[o]) {
            seen[o]=true;result.objects.push({key:id(o),cls:getQualifiedClassName(o),fields:NativeFields.capture(o),
               pose:VisualPose.capture(o.vis),clip:o.vis==null?null:getQualifiedClassName(o.vis),inter:NativeFields.capture(o.inter)});
            result.objects[result.objects.length-1].attached=o.vis!=null && o.vis.parent!=null;
            if(o.vis!=null)rendered[o.vis]=true;
         }
         o=room.firstObj;var count:int=0;
         var atlas:Object=access.definition("fe.graph.Grafon")["spriteLists"];
         while(o!=null && ++count<=10000) {
            var projectile:Boolean="begx" in o;
            if(o.vis!=null && o.vis.parent!=null && !rendered[o.vis] && !projectile) {
               var effect:Object={key:id(o),clip:getQualifiedClassName(o.vis),layer:o.sloy,
                  pose:VisualPose.capture(o.vis),atlas:AuthorityParticle.capture(o,atlas)};
               if(getQualifiedClassName(o)=="fe.loc::Loot")effect.loot={id:o.item.id,kol:o.item.kol,x:o.X,y:o.Y,w:o.scX,h:o.scY};
               result.effects.push(effect);
               rendered[o.vis]=true;
            }
            // Projectiles have their own lifetime stream. Still reserve their
            // native display identity so the loose-display pass cannot clone it.
            if(o.vis!=null && projectile)rendered[o.vis]=true;
            o=o.nobj;
         }
         Timing.end("capture.objectsAndParticles",began);began=Timing.start();
         if(count>10000)throw new Error("Visual object chain exceeds bound");
         // Native melee arcs, griffon arms and public mod effects can attach
         // directly to a layer without a Pt/object-chain entry. Keep all remaining
         // native symbols once, rather than guessing a class-name allowlist.
         // Mask shapes belong to their local view. Serializing them as ordinary
         // effects both exposes opaque mask pixels and rasterizes every RV
         // enemy visibility mask on every network frame.
         // An invisible/detached body or health bar can still own a mask
         // attached to the layer. Inspect native owners too, then remember
         // their mask identities across the native cleanup frame.
         for(var owner:Object in rendered)masks.remember(owner as DisplayObject);
         for each(var maskLayer:DisplayObjectContainer in room.grafon.visObjs)
            for(var mi:int=0;mi<maskLayer.numChildren;mi++)masks.remember(maskLayer.getChildAt(mi));
         for(var layer:int=0;layer<room.grafon.visObjs.length;layer++) {
            var container:DisplayObjectContainer=room.grafon.visObjs[layer];
            for(var ci:int=0;ci<container.numChildren;ci++) {
               var drawn:DisplayObject=container.getChildAt(ci);
               var kind:String=getQualifiedClassName(drawn);
               if(!rendered[drawn] && !masks.contains(drawn))
                  result.effects.push({key:id(drawn),name:drawn.name,clip:getQualifiedClassName(drawn),layer:layer,pose:VisualPose.capture(drawn,0,true),atlas:null});
            }
         }
         for(var targetKey:String in targets) {
            var target:Object=targets[targetKey];
            if(target.loc==null || target.sost>=3 || target.loc.units.indexOf(target)<0)delete targets[targetKey];
         }
         Timing.end("capture.untrackedEffects",began);
         if(full || result.tiles.length>0)++terrainRevision;
         result.terrainRevision=terrainRevision;
         return result;
      }
      private function color(c:Object):Array {return c==null?null:[c.redMultiplier,c.greenMultiplier,c.blueMultiplier,c.alphaMultiplier,c.redOffset,c.greenOffset,c.blueOffset,c.alphaOffset];}
   }
}

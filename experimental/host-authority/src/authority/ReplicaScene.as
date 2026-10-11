package authority {
   import flash.display.DisplayObject;
   import flash.display.MovieClip;
   import flash.geom.ColorTransform;
   import flash.utils.Dictionary;
   import fe.unit.AuthorityAnimation;
   import fe.unit.Unit;
   /** Native geometry and target entities with no client-side combat execution. */
   public final class ReplicaScene {
      public var key:String="",room:Object,units:Object={},objects:Object={};
      public var applications:uint=0,terrainApplications:uint=0;
      public var effects:SceneEffects;
      private var access:NativeAccess;
      private var players:Dictionary=new Dictionary(true);
      public function ReplicaScene(access:NativeAccess){this.access=access;effects=new SceneEffects(access);}
      public function keyFor(unit:Object):uint {if(players[unit])return players[unit];for(var id:String in units)if(units[id].unit===unit)return uint(id);return 0;}
      public function registerPlayer(unit:Object,key:uint):void {players[unit]=key;}
      public function apply(s:Object):Boolean {
         var changed:Boolean=key!==s.key,w:Object=access.world;
         if(changed) {
            if(!s.full || s.fields==null)throw new Error("Room transition requires a complete authoritative scene");
            dispose();
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
         NativeFields.apply(room,s.fields);
         var geometry:Boolean=changed;
         for each(var tile:Object in s.tiles) {
            var t:Object=room.space[int(tile.x)][int(tile.y)];
            for(var i:int=0;i<SceneSnapshot.TILE.length;i++) {
               var field:String=SceneSnapshot.TILE[i];
               if(field!="visi" && field!="t_visi" && t[field]!==tile.v[i])geometry=true;
               t[field]=tile.v[i];
            }
            ++terrainApplications;
         }
         if(changed)w.grafon.drawFon(w.vfon,s.fon);
         if(geometry) {
            w.grafon.drawLoc(room);w.cam.setLoc(room);
            for each(var rec:Object in units)attach(rec.unit,rec.layer);
            for each(rec in objects)attach(rec.object,rec.layer);
         }
         var live:Object={};
         for each(var state:Object in s.units) {applyUnit(state);live[state.key]=true;}
         for(var id:String in units)if(!live[id])removeUnit(id);
         live={};
         for each(state in s.objects){applyObject(state);live[state.key]=true;}
         for(id in objects)if(!live[id]) {
            objects[id].object.remVisual();delete objects[id];
         }
         effects.apply(s.effects);
         ++applications;return changed;
      }
      private function applyUnit(s:Object):void {
         var rec:Object=units[s.key],u:Object;
         if(rec==null) {
            var ClassRef:Class=access.definition(String(s.cls).replace("::",".")),cid:String=s.fields.id;
            var placement:XML=<unit/>;
            if(int(s.fields.tr)>0)placement.@tr=int(s.fields.tr);
            if(s.cls.indexOf("UnitAlicorn")>=0)cid=String(s.fields.tr);
            if(s.cls.indexOf("UnitTurret")>=0)cid=["","land","wall","arm","combat","boss"][int(s.mount)];
            if(s.cls=="fe.unit::UnitTrap")cid=null;
            u=new ClassRef(cid,Number(room.locDifLevel),placement,null);
            u.putLoc(room,s.fields.X,s.fields.Y);
            room.units.push(u);rec=units[s.key]={unit:u,weapons:[],layer:s.layer};
         }
         u=rec.unit;
         NativeFields.apply(u,s.fields);u.loc=room;
         NativeFields.apply(u.inter,s.inter);
         if(s.attached)attach(u,s.layer);else u.remVisual();u.setVisPos();
         VisualPose.apply(u.vis,s.pose);AuthorityAnimation.apply(u as Unit,s.blit);
         // Health bars are native render-only methods; no damage/AI is replayed.
         if(s.attached && !u.player && u.vis!=null && !u.disabled && u.sost<3) {
            u.addVisual();u.visDetails();u.setHpbarPos();VisualPose.apply(u.vis,s.pose);
         }
         for(var i:int=0;i<s.weapons.length;i++) {
            var gs:Object=s.weapons[i],gun:Object=rec.weapons[i];
            if(gun==null || gun.id!=gs.id || gun.variant!=gs.variant) {
               if(gun!=null)gun.remVisual();
               gun=access.definition("fe.weapon.Weapon")["create"](u,gs.id,int(gs.variant));
               rec.weapons[i]=gun;
            }
            NativeFields.apply(gun,gs.fields);gun.loc=room;
            if(gs.attached)attach(gun,gun.sloy);else gun.remVisual();VisualPose.apply(gun.vis,gs.pose);
         }
         while(rec.weapons.length>s.weapons.length)rec.weapons.pop().remVisual();
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
            rec=objects[s.key]={object:o,layer:int(s.fields.sloy),inter:s.inter};
         }
         o=rec.object;NativeFields.apply(o,s.fields);rec.inter=s.inter;
         if(s.attached)attach(o,rec.layer);else o.remVisual();VisualPose.apply(o.vis,s.pose);
      }
      private function attach(o:Object,layer:int):void {
         if(o.vis!=null && int(NativeAccess.get(o,"sost",1))<4)
            access.world.grafon.visObjs[Math.max(0,Math.min(5,layer))].addChild(o.vis);
         else if(o.vis!=null && o.vis.parent!=null)o.vis.parent.removeChild(o.vis);
      }
      private function color(a:Array):ColorTransform{return a==null?null:new ColorTransform(a[0],a[1],a[2],a[3],a[4],a[5],a[6],a[7]);}
      private function removeUnit(id:String):void {
         var rec:Object=units[id];rec.unit.remVisual();
         for each(var gun:Object in rec.weapons)gun.remVisual();
         var at:int=room.units.indexOf(rec.unit);if(at>=0)room.units.splice(at,1);delete units[id];
      }
      public function dispose():void {
         for(var id:String in units)removeUnit(id);
         for each(var rec:Object in objects)rec.object.remVisual();
         units={};objects={};room=null;key="";
         effects.dispose();
      }
   }
}

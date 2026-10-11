package authority {
   import flash.display.Sprite;
   import flash.display.MovieClip;
   import flash.display.DisplayObjectContainer;
   import flash.utils.Dictionary;
   /** Retained native rooms. Simulation occupancy and the host's display are separate. */
   public class OccupiedRooms {
      private var access:NativeAccess,actors:Array,rooms:Dictionary=new Dictionary(true);
      private var sharedGrafon:Object,shown:Object;
      public var records:Array=[];
      public function OccupiedRooms(access:NativeAccess,actors:Array) {
         this.access=access;this.actors=actors;
         var w:Object=access.world;
         sharedGrafon=w.grafon;
         shown={room:w.loc,grafon:w.grafon,cam:w.cam,visual:w.visual,vfon:w.vfon,vscene:w.vscene,steps:0,drawn:true};
         rooms[w.loc]=shown;records.push(shown);
         access.scope.roomServices=services;
         // Native map construction inserts the one original player in every
         // room's units array. Remove those stale references before multi-room AI.
         for each(var column:Array in w.land.locs)for each(var row:Array in column)for each(var room:Object in row)repairRoster(room);
         for each(room in w.land.listLocs)repairRoster(room);
      }
      public function services(room:Object):Object {
         var record:Object=rooms[room];
         if(record==null)throw new Error("Native room has no authority services");
         return record;
      }
      public function ensure(room:Object):Object {
         if(room.land!==actors[0].unit.loc.land)throw new Error("Independent maps are not supported");
         if(rooms[room]!=null)return rooms[room];
         var Grafon:Class=access.definition("fe.graph.Grafon"),Camera:Class=access.definition("fe.inter.Camera");
         var visual:Sprite=new Sprite(),grafon:Object=new Grafon(visual,sharedGrafon);
         var record:Object={room:room,grafon:grafon,cam:new Camera(access.world),visual:visual,
            vfon:new MovieClip(),vscene:new MovieClip(),steps:0,drawn:false};
         rooms[room]=record;records.push(record);room.grafon=grafon;
         return record;
      }
      public function prepare(actor:PlayerActor):void {
         var room:Object=actor.unit.loc,record:Object=ensure(room);
         room.active=true;room.visited=true;room.gg=actor.unit;
         repairRoster(room);
         access.scope.run(actor.context,function():void {
            if(!record.drawn) {
               record.grafon.drawFon(record.vfon,room.land.act.fon);
               record.grafon.drawLoc(room);record.cam.setLoc(room);
               record.drawn=true;
            }
            actor.unit.addVisual();
         });
      }
      public function repairRoster(room:Object):void {
         if(room==null)return;
         for each(var actor:PlayerActor in actors) {
            var at:int;
            while((at=room.units.indexOf(actor.unit))>=0)room.units.splice(at,1);
            if(actor.unit.loc===room)room.units.push(actor.unit);
         }
      }
      public function occupied():Array {
         var result:Array=[];
         for each(var actor:PlayerActor in actors)if(result.indexOf(actor.unit.loc)<0)result.push(actor.unit.loc);
         for each(var record:Object in records)record.room.active=result.indexOf(record.room)>=0;
         return result;
      }
      public function showHost():void {
         var w:Object=access.world,room:Object=actors[0].unit.loc,next:Object=services(room);
         if(next!==shown) {
            // Swap only the visual and background slots; HUD and input stay on the host.
            for each(var name:String in ["visual","vfon"]) {
               var parent:DisplayObjectContainer=shown[name].parent;
               if(parent==null)throw new Error("Host room display was detached unexpectedly");
               var index:int=parent.getChildIndex(shown[name]);parent.removeChild(shown[name]);parent.addChildAt(next[name],index);
               next[name].visible=true;
            }
            shown=next;
         }
         room.gg=actors[0].unit;
         w.loc=room;w.land=room.land;w.grafon=next.grafon;w.cam=next.cam;w.visual=next.visual;w.vfon=next.vfon;
         room.land.loc=room;room.land.gg=actors[0].unit;
         room.land.locX=room.landX;room.land.locY=room.landY;room.land.locZ=room.landZ;room.land.prob=room.landProb;
         room.land.loc_t=0;
      }
      public function summary():Array {
         var result:Array=[];
         for each(var record:Object in records)result.push({room:access.keyFor(record.room),steps:record.steps,active:record.room.active});
         return result;
      }
      public function dispose():void {access.scope.roomServices=null;rooms=new Dictionary(true);records=[];}
   }
}

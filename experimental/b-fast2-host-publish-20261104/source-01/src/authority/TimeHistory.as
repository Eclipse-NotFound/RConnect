package authority {
   import flash.display.Bitmap;
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.MovieClip;
   import flash.display.Shape;
   import flash.display.Sprite;
   import flash.text.TextField;
   import flash.utils.Dictionary;
   import flash.utils.getQualifiedClassName;
   /** B replay borrows motion and native display symbols, never health,
    * inventory, AI or weapon simulation. Originals retain their frame scripts.
    * Every borrow is unwound before native hits and on all exit paths. */
   public final class TimeHistory {
      private static const MOTION:Array=NativeFields.MOTION.concat(["storona","scX","scY"]);
      private var host:HostSession,access:NativeAccess,frames:Array=[];
      private var objects:Dictionary=new Dictionary(true),copies:Dictionary=new Dictionary(true);
      private var knownDisplays:Dictionary=new Dictionary(true),existingEffects:Dictionary=new Dictionary(true);
      private var ending:Array=[],rosters:Array=[],bindings:Array=[],layers:Array=[];
      private var frame:Object,playing:Boolean=false;
      public var captures:uint=0,displays:uint=0;
      public function TimeHistory(host:HostSession){this.host=host;access=host.access;VisualPose.resolve=access.visualClass;}
      private function motion(object:Object):Object {
         var values:Object={};for each(var key:String in MOTION)if(key in object)values[key]=object[key];return values;
      }
      private function place(object:Object,state:Object):void {
         // Direction and body size also participate in native front shields
         // and hit geometry. They are borrowed/restored with position only.
         for each(var key:String in MOTION)if(state.hasOwnProperty(key))object[key]=state[key];
      }
      private function remember(object:Object,states:Array,owners:Dictionary,seen:Dictionary):void {
         if(object==null || seen[object])return;seen[object]=true;
         if("X" in object && "loc" in object) {
            states.push({object:object,loc:object.loc,motion:motion(object)});objects[object]=true;
         }
         for each(var field:String in ["vis","hpbar"])if(field in object && object[field] is DisplayObject)
            owners[object[field]]={object:object,field:field};
         if("childObjs" in object && object.childObjs is Array)
            for each(var child:Object in object.childObjs)remember(child,states,owners,seen);
         for each(field in ["currentWeapon","throwWeapon","magicWeapon","punchWeapon"])
            if(field in object)remember(object[field],states,owners,seen);
      }
      public function capture(index:int):void {
         if(index<1 || index>3600)throw new Error("Invalid time history frame");
         if(frames[index]!=null)return; // A shared-pause confirmation is not a new action.
         var saved:Object={rooms:[],states:[],players:[]},owners:Dictionary=new Dictionary(true),seen:Dictionary=new Dictionary(true);
         for each(var a:PlayerActor in host.actors) {
            saved.players.push({actor:a,room:a.unit.loc,weapon:a.unit.currentWeapon});remember(a.unit,saved.states,owners,seen);
         }
         for each(var room:Object in host.runtime.rooms.occupied()) {
            var record:Object={room:room,units:room.units.concat(),layers:[]};saved.rooms.push(record);
            for each(var list:Array in [room.units,room.objs,room.acts,room.bonuses])for each(var object:Object in list)remember(object,saved.states,owners,seen);
            var count:int=0;for(object=room.firstObj;object!=null && ++count<=10000;object=object.nobj)remember(object,saved.states,owners,seen);
            if(count>10000)throw new Error("Time history object chain exceeds bound");
            var masks:DisplayMasks=new DisplayMasks();
            for each(var layer:DisplayObjectContainer in room.grafon.visObjs)
               for(var i:int=0;i<layer.numChildren;i++)masks.remember(layer.getChildAt(i));
            for each(layer in room.grafon.visObjs) {
               var roots:Array=[];record.layers.push(roots);
               for(i=0;i<layer.numChildren;i++) {
                  var display:DisplayObject=layer.getChildAt(i);if(masks.contains(display))continue;
                  knownDisplays[display]=true;
                  roots.push({original:display,kind:getQualifiedClassName(display),owner:owners[display],pose:VisualPose.capture(display,0,true)});
               }
            }
         }
         frames[index]=saved;++captures;
      }
      public function begin():void {
         if(playing)throw new Error("Time replay already owns the display");playing=true;
         for(var object:Object in objects)ending.push({object:object,loc:object.loc,motion:motion(object)});
         for each(var a:PlayerActor in host.actors)ending.push({actor:a,room:a.unit.loc,weapon:a.unit.currentWeapon});
         for each(var record:Object in host.runtime.rooms.records)for(object=record.room.firstObj;object!=null;object=object.nobj)existingEffects[object]=true;
      }
      private function dead(object:Object):Boolean{return NativeAccess.get(object,"sost",1)>=3 || NativeAccess.get(object,"player",false) && object.hp<=0;}
      /** Temporarily place real native targets at the recorded hit coordinates. */
      public function position(index:int):void {
         restore();frame=frames[index];if(frame==null)throw new Error("Missing confirmed time history frame "+index);
         for each(var state:Object in frame.states)if(!dead(state.object)) {state.object.loc=state.loc;place(state.object,state.motion);}
         for each(state in frame.players) {
            state.actor.unit.loc=state.room;state.actor.context.loc=state.room;state.actor.unit.currentWeapon=state.weapon;
         }
         for each(var record:Object in frame.rooms) {
            rosters.push({room:record.room,original:record.room.units,before:record.units.concat()});
            record.room.units=record.units.concat();
         }
         host.runtime.rooms.showHost();
      }
      /** Merge actual native deaths/spawns before restoring the retained roster. */
      public function commit():void {
         for each(var record:Object in rosters) {
            var current:Array=record.room.units,original:Array=record.original;
            for each(var object:Object in record.before)if(current.indexOf(object)<0 && original.indexOf(object)>=0)original.splice(original.indexOf(object),1);
            for each(object in current)if(record.before.indexOf(object)<0 && original.indexOf(object)<0)original.push(object);
            record.before=current.concat();
         }
      }
      private function copy(root:Object):DisplayObject {
         var result:DisplayObject=copies[root.original];
         if(result!=null)return result;
         if(root.kind=="flash.display::Bitmap")result=new Bitmap();
         else if(root.kind=="flash.text::TextField")result=new TextField();
         else if(root.kind=="flash.display::MovieClip")result=new MovieClip();
         else if(root.pose.vector!=null)result=root.kind=="flash.display::Shape"?new Shape():new Sprite();
         else {var type:Class=access.visualClass(root.kind);result=new type() as DisplayObject;}
         if(result==null)throw new Error("Unsupported replay display "+root.kind);
         result.name=root.original.name;copies[root.original]=result;return result;
      }
      public function draw():void {
         if(frame==null)return;
         for each(var record:Object in frame.rooms) {
            var grafon:Object=record.room.grafon,original:Array=grafon.visObjs,next:Array=[];
            var owners:Dictionary=new Dictionary(true),seen:Dictionary=new Dictionary(true),drawnRoots:Dictionary=new Dictionary(true),unused:Array=[];
            for each(var unit:Object in record.room.units)remember(unit,unused,owners,seen);
            for(var object:Object=record.room.firstObj;object!=null;object=object.nobj)remember(object,unused,owners,seen);
            var saved:Object={grafon:grafon,original:original,visibility:[],copies:next};layers.push(saved);
            for(var i:int=0;i<original.length;i++) {
               var old:DisplayObjectContainer=original[i],layer:Sprite=new Sprite();next.push(layer);saved.visibility.push(old.visible);
               old.parent.addChildAt(layer,old.parent.getChildIndex(old)+1);layer.transform.matrix=old.transform.matrix;
               layer.visible=old.visible;old.visible=false;
               for each(var root:Object in record.layers[i])drawRoot(layer,root,drawnRoots);
               // Damage numbers, death bursts and drops are new native results,
               // not part of the old film. Display them once alongside it.
               for(var j:int=0;j<old.numChildren;j++) {
                  var fresh:DisplayObject=old.getChildAt(j);
                  if(!knownDisplays[fresh] && !drawnRoots[fresh])drawRoot(layer,{original:fresh,kind:getQualifiedClassName(fresh),
                     pose:VisualPose.capture(fresh,0,true),owner:owners[fresh]},drawnRoots);
               }
            }
            grafon.visObjs=next;
         }
         ++displays;
      }
      private function drawRoot(layer:Sprite,root:Object,seen:Dictionary):void {
         var owner:Object=root.owner,pose:Object=root.pose,actual:DisplayObject;
         if(owner!=null && (dead(owner.object) || owner.field=="hpbar")) {
            actual=owner.object[owner.field] as DisplayObject;if(actual==null || actual.parent==null)return;
            pose=PoseTween.copy(VisualPose.capture(actual,0,true));
            if(owner.field=="hpbar"){pose.x=root.pose.x;pose.y=root.pose.y;pose.m=root.pose.m;}
            root={original:actual,kind:getQualifiedClassName(actual),pose:pose,owner:owner};
         }
         if(seen[root.original])return;seen[root.original]=true;
         var display:DisplayObject=copy(root);VisualPose.apply(display,pose);layer.addChild(display);
         if(owner!=null){bindings.push({object:owner.object,field:owner.field,original:owner.object[owner.field],display:display,pose:pose});owner.object[owner.field]=display;}
      }
      public function inspect():Object {
         var result:Object={frames:frames.length,layers:layers.length,copies:0,bindings:[]};
         for each(var copy:DisplayObject in copies)++result.copies;
         for each(var b:Object in bindings)for each(var a:PlayerActor in host.actors)
            if(b.object===a.unit || b.object===a.unit.currentWeapon) {
               var pose:Object=VisualPose.capture(b.display);
               result.bindings.push({player:a.id,field:b.field,body:b.object===a.unit,attached:b.object[b.field]===b.display,
                  actual:pose.m,wanted:b.pose.m});
            }
         return result;
      }
      public function advanceEffects():void {
         if(frame==null)return;
         for each(var record:Object in frame.rooms) {
            var room:Object=record.room;
            for(var object:Object=room.firstObj;object!=null;) {
               var next:Object=object.nobj;
               if(!existingEffects[object] && getQualifiedClassName(object)=="fe.graph::Part")
                  access.scope.runRoom(host.actors[0].context,room,function():void {object.step();});
               object=next;
            }
         }
      }
      private function restore():void {
         for(var i:int=bindings.length-1;i>=0;i--)bindings[i].object[bindings[i].field]=bindings[i].original;bindings=[];
         for each(var layer:Object in layers) {
            layer.grafon.visObjs=layer.original;
            for(i=0;i<layer.copies.length;i++){var drawn:DisplayObject=layer.copies[i];if(drawn.parent!=null)drawn.parent.removeChild(drawn);layer.original[i].visible=layer.visibility[i];}
         }
         layers=[];
         for each(var record:Object in rosters)record.room.units=record.original;rosters=[];
         for each(var state:Object in ending) {
            if(state.actor!=null){state.actor.unit.loc=state.room;state.actor.context.loc=state.room;state.actor.unit.currentWeapon=state.weapon;}
            else if(!dead(state.object)){state.object.loc=state.loc;place(state.object,state.motion);}
         }
         if(playing)host.runtime.rooms.showHost();
      }
      public function get visibleRooms():Array {var rooms:Array=[];if(frame!=null)for each(var rec:Object in frame.rooms)rooms.push(rec.room);return rooms;}
      public function finish():void {restore();playing=false;frame=null;ending=[];}
      public function dispose():void {
         finish();for each(var display:DisplayObject in copies)VisualPose.dispose(display);
         copies=new Dictionary(true);objects=new Dictionary(true);frames=[];
         knownDisplays=new Dictionary(true);existingEffects=new Dictionary(true);
      }
   }
}

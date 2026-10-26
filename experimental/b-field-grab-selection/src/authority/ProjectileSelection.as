package authority {
   import flash.utils.getTimer;
   import flash.utils.getQualifiedClassName;
   /** A cursor claim names a picture the host actually sent, not a rewind of
    * the projectile. Only the current native object may execute the grab. */
   public final class ProjectileSelection {
      private static const MAX_FRAMES:int=96,MAX_ITEMS:int=256,MAX_AGE:int=2000;
      private var runtime:RoomRuntime;
      private var records:Object={},order:Array=[],identity:String="";
      public var verified:uint=0,rejected:uint=0,last:Object;
      public function ProjectileSelection(runtime:RoomRuntime){this.runtime=runtime;}
      private static function positive(value:*,unsigned:Boolean=false):Boolean {
         return value is Number && isFinite(value) && value>0 &&
            (unsigned?value==uint(value):value==int(value));
      }
      public static function valid(value:Object):Boolean {
         if(value==null)return true;
         return positive(value.id,true) && positive(value.a,true) &&
            value.b is Number && value.b>=0 && value.b==uint(value.b) &&
            value.t is Number && isFinite(value.t) && value.t>=0 && value.t<=1 &&
            (value.t==0?value.b==0:value.b==value.a+1) &&
            value.x is Number && value.y is Number && isFinite(value.x) && isFinite(value.y) &&
            Math.abs(value.x)<=100000 && Math.abs(value.y)<=100000 &&
            value.room is String && value.room.length>0 && value.room.length<=512 &&
            positive(value.epoch) && positive(value.roomEpoch);
      }
      public static function copy(value:Object):Object {
         return value==null?null:{id:value.id,a:value.a,b:value.b,t:value.t,x:value.x,y:value.y,
            room:value.room,epoch:value.epoch,roomEpoch:value.roomEpoch};
      }
      private function trim(now:int):void {
         while(order.length>0 && (order.length>MAX_FRAMES || now-records[order[0]].time>MAX_AGE))delete records[order.shift()];
      }
      /** Called only after Link.send succeeded; paused publications can share
       * a simulation tick, so the key must be presentation, never tick. */
      public function published(frame:Object):void {
         var player:Object=frame.players[1];
         var token:String=frame.room+":"+player.epoch+":"+player.roomEpoch;
         if(identity!==token){clear();identity=token;}
         var values:Object={},count:int=0;
         for each(var p:Object in frame.projectiles)if(p.room===frame.room && p.grip!=null && count<MAX_ITEMS) {
            values[p.id]={x:p.x,y:p.y,w:p.grip.w,h:p.grip.h,active:p.grip.active===true && !p.ended,
               visible:p.clip!="" && p.visual!=null && p.visual.v===true && p.visual.a>0};++count;
         }
         records[frame.presentation]={id:frame.presentation,time:frame.time,room:frame.room,
            epoch:player.epoch,roomEpoch:player.roomEpoch,paused:frame.paused,pauseEpoch:frame.pauseEpoch,
            phase:frame.timeControl==null?"":frame.timeControl.phase,
            cycle:frame.timeControl==null?0:frame.timeControl.cycle,items:values};
         order.push(frame.presentation);trim(frame.time);
      }
      private function reject(reason:String,hint:Object):Object {
         ++rejected;last={accepted:false,reason:reason,id:hint==null?0:hint.id};
         Log.write("projectile-pick",last);return null;
      }
      public function target(actor:PlayerActor,input:Object):Object {
         var hint:Object=input.projectilePick;
         if(actor.id!=1 || hint==null || (input.pressed&Commands.TELE)==0 ||
            !actor.context.ctr.keyTele || actor.context.ctr.keyAction || actor.unit.teleObj!=null)return null;
         if(!valid(hint))return reject("shape",hint);
         var room:Object=actor.unit.loc;
         if(hint.room!==actor.access.keyFor(room) || hint.epoch!=actor.epoch || hint.roomEpoch!=actor.roomEpoch)return reject("identity",hint);
         var now:int=getTimer();trim(now);
         var a:Object=records[hint.a],b:Object=hint.b==0?null:records[hint.b];
         if(a==null || hint.t>0 && b==null)return reject("unpublished-or-expired",hint);
         if(a.room!==hint.room || a.epoch!=hint.epoch || a.roomEpoch!=hint.roomEpoch)return reject("picture-identity",hint);
         if(a.phase=="replay")return reject("replay",hint);
         var p:Object=a.items[hint.id],q:Object=b==null?null:b.items[hint.id];
         if(p==null || !p.active || !p.visible)return reject("unavailable-in-picture",hint);
         var x:Number=p.x,y:Number=p.y;
         if(hint.t>0) {
            if(b.room!==a.room || b.epoch!=a.epoch || b.roomEpoch!=a.roomEpoch ||
               a.paused || b.pauseEpoch!=a.pauseEpoch || b.phase!==a.phase || b.cycle!=a.cycle || b.time<=a.time)
               return reject("picture-boundary",hint);
            // Match the published projectile interpolation contract. The
            // width/height and availability belong to the left discrete frame.
            if(q!=null && Math.abs(p.x-q.x)<160 && Math.abs(p.y-q.y)<160) {
               x+=(q.x-x)*hint.t;y+=(q.y-y)*hint.t;
            }
         }
         if(!isFinite(x) || !isFinite(y) || !(p.w>0) || !(p.h>0) ||
            !(hint.x>x-p.w/2 && hint.x<x+p.w/2 && hint.y>y-p.h/2 && hint.y<y+p.h/2))return reject("cursor-outside-picture",hint);
         var object:Object=room.firstObj,count:int=0;
         while(object!=null && ++count<=10000) {
            if(runtime.projectileId(object)==hint.id) {
               if(getQualifiedClassName(object)!="fe.weapon::PhisBullet" || object.loc!==room ||
                  !object.in_chain || object.babah || object.liv<=5 || !object.levitPoss)return reject("retired",hint);
               if(actor.grips!=null && actor.grips.heldByOther(actor,object))return reject("held-by-other",hint);
               ++verified;last={accepted:true,id:hint.id,source:hint.a,next:hint.b,fraction:hint.t,
                  pictureX:x,pictureY:y,currentX:object.X,currentY:object.Y};Log.write("projectile-pick",last);
               return object;
            }
            object=object.nobj;
         }
         if(count>10000)throw new Error("Projectile selection chain exceeds bound");
         return reject("retired",hint);
      }
      public function clear():void {records={};order=[];identity="";}
   }
}

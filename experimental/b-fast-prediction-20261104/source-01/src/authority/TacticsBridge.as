package authority {
 import flash.display.DisplayObjectContainer;
 /** Narrow optional public contract; no tactical algorithm is copied into B. */
 public class TacticsBridge {
  private var api:Object,access:NativeAccess,actors:Array;
  public function TacticsBridge(main:Object,access:NativeAccess,session:String,role:String) {
   this.access=access;
   var container:DisplayObjectContainer=main as DisplayObjectContainer;
   var carrier:Object=container==null?null:container.getChildByName("TDFCAuthorityCarrier");
   var entry:Object=NativeAccess.get(carrier,"authorityAPI");
   if(entry==null || entry.version!==1 || !(entry.attach is Function))throw new Error("The pinned TDFC authority interface is unavailable");
   api=entry.attach({version:1,session:session,role:role,withPlayer:withPlayer});
   if(api==null || api.version!==1 || !(api.stepRoom is Function) || !(api.detach is Function))throw new Error("TDFC authority API mismatch");
   Log.write("tactics-attached",{role:role,version:api.version});
  }
  public function bind(players:Array):void {actors=players;}
  private function withPlayer(key:String,operation:Function):* {
   for each(var actor:PlayerActor in actors)if(String(actor.id)==key)return access.scope.run(actor.context,operation);
   throw new Error("TDFC requested an unknown player context");
  }
  public function step(room:Object,tick:uint):void {
   var roster:Array=[],live:Boolean=false;
   for each(var actor:PlayerActor in actors)if(actor.unit.loc===room) {
    roster.push({key:String(actor.id),epoch:actor.epoch,unit:actor.unit});
    if(actor.unit.sost==1 && !actor.unit.disabled && !actor.unit.trigDis && !actor.unit.unres)live=true;
   }
   // Native death/respawn still occupies a retained room. TDFC deliberately
   // does not advance its tactical clock when there is no living participant;
   // the room physics and the player's separate revival countdown continue.
   // Still submit the roster/tick so its identity checks remain in force.
   if(!api.stepRoom(room,roster,tick) && live)throw new Error("Occupied B room was not advanced by TDFC");
  }
  public function inspect(room:Object):Object {return api.inspect(room);}
  public function dispose():void {if(api!=null){api.detach();api=null;}actors=null;}
 }
}

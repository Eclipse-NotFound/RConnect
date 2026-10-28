package authority {
 import flash.display.DisplayObjectContainer;
 /** Optional PI bridge. Native damage is canonical; the replica only presents. */
 public final class InjuryBridge {
  private var access:NativeAccess,api:Object;
  public function InjuryBridge(main:Object,access:NativeAccess,session:String,role:String) {
   this.access=access;
   var carrier:Object=(main as DisplayObjectContainer).getChildByName("PermanentInjuryCarrier");
   var entry:Object=NativeAccess.get(carrier,"authorityAPI");
   if(entry==null||entry.version!==1||!(entry.attach is Function))throw new Error("Independent PI B API unavailable");
   api=entry.attach({version:1,role:role=="join"?"client":role,session:session});
   if(api==null||api.version!==1||!(api.beforePlayer is Function)||!(api.snapshot is Function)||!(api.present is Function)||!(api.detach is Function))throw new Error("PI B API mismatch");
  }
  // Called inside actor.scope, only for a native player step (never SATS idle).
  public function beforePlayer(actor:PlayerActor):void {api.beforePlayer(actor.context.pers,1/30);}
  public function afterPlayer(actor:PlayerActor):void {api.afterPlayer(actor.context.pers);}
  // Enemy/projectile hits happen after a player's own step. Flush both actors
  // after all occupied rooms, before captures/saves, just like native World.
  public function afterWorld(actors:Array):void {
   for each(var actor:PlayerActor in actors)access.scope.run(actor.context,function():void {api.afterPlayer(actor.context.pers);});
  }
  public function snapshot(actor:PlayerActor):Object {
   return access.scope.run(actor.context,function():Object {return api.snapshot(actor.context.pers);});
  }
  public function present(value:Object):void {api.present(value);}
  public function dispose():void {if(api!=null){api.detach();api=null;}}
 }
}

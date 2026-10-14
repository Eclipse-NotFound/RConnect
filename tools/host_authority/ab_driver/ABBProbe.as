package {
 import authority.*;
 public class ABBProbe extends Probe {
  private var bench:ABBench;
  public function ABBProbe(a:NativeAccess,h:Boolean,b:ABBench){super(a,h);bench=b;}
  override public function prepare():void {bench.equip(access.world.gg);}
  override public function message(v:Object):void {bench.message(v);}
  override public function input(f:Object,s:HostSession):Object {f.buttons=bench.fire()?8:0;f.actions=[];f.aimX=access.world.gg.X+380;f.aimY=access.world.gg.Y-45;return f;}
  override public function observe(s:HostSession,r:ClientReplica):void {}
 }
}

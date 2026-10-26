package { import flash.display.Sprite; import authority.Timing; public class ABPayloadB extends Sprite {
 public static function install(mod:Object,main:Object,cfg:Object):void {
  var bench:ABBench=new ABBench(mod,main,cfg);mod.probe=new ABBProbe(mod.access,cfg.role=="host",bench);
  bench.finishProbe=function():void {mod.probe.finish();};
  if(cfg.profile===true){
   bench.profileBegin=function():void {Timing.enabled=true;Timing.reset();};
   bench.profileEnd=function():Object {var result:Object=Timing.snapshot();Timing.enabled=false;return result;};
  }
 }
} }

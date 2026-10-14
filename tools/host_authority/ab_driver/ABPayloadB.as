package { import flash.display.Sprite; public class ABPayloadB extends Sprite {
 public static function install(mod:Object,main:Object,cfg:Object):void {
  var bench:ABBench=new ABBench(mod,main,cfg);mod.probe=new ABBProbe(mod.access,cfg.role=="host",bench);
 }
} }

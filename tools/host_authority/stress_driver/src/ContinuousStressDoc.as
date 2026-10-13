package {
   import flash.display.Sprite;
   import testdriver.ContinuousStressProbe;
   import flash.utils.getQualifiedClassName;
   public class ContinuousStressDoc extends Sprite {
      public static function install(mod:Object,source:String):void {
         if(mod.config.scenario!=="stress" || mod.config.stressExternal!==true || mod.host!=null || mod.replica!=null)
            throw new Error("Install test probe before native network assembly");
         if(getQualifiedClassName(mod.probe)!="authority::StressProbe")throw new Error("Original frozen stress probe required");
         ContinuousStressProbe.send=function(value:Object):void{mod.link.send(value);};
         mod.probe=new ContinuousStressProbe(mod.access,mod.role=="host",Number(mod.config.stressSeconds),source);
      }
   }
}

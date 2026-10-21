package {
   /** Native hard/soft wall materials, both TCP directions. Materials 3/4/6
    * genuinely emit no Bullet spark burst, so silence is the required result. */
   public class RecoveryWallMaterialsTestDoc extends EnergyImpactTestDoc {
      public function RecoveryWallMaterialsTestDoc() {super(scenarios(),true);}
      private static function scenarios():Array {
         var cases:Array=[];
         for each(var mat:int in [1,2,3,4,5,6,7])
            for each(var actor:String in ["host","join"])
               cases.push({id:"lmg",actor:actor,target:"wall",mat:mat,noParticles:mat==3||mat==4||mat==6});
         return cases;
      }
   }
}

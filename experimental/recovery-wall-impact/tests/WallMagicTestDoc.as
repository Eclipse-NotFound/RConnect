package {
   public class WallMagicTestDoc extends EnergyImpactTestDoc {
      public function WallMagicTestDoc() {super(scenarios());}
      private static function scenarios():Array {
         var cases:Array=[];
         for each(var id:String in ["telebul","mbul","ice","lightning","mray","dray","skybolt"])
            for each(var actor:String in ["host","join"])cases.push({id:id,actor:actor,target:"wall"});
         return cases;
      }
   }
}

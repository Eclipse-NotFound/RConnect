package {
   public class WallBallisticTestDoc extends EnergyImpactTestDoc {
      public function WallBallisticTestDoc() {super(scenarios(),true);}
      private static function scenarios():Array {
         var cases:Array=[];
         for each(var id:String in ["lmg","autor","shotgun"])
            for each(var actor:String in ["host","join"])cases.push({id:id,actor:actor,target:"wall"});
         cases.push({id:"lmg",actor:"enemy",target:"wall"});
         cases.push({id:"lmg",actor:"enemy",target:"wall",slow:true});
         for each(actor in ["host","join"])cases.push({id:"lmg",actor:actor,target:"wall",burst:12});
         for each(actor in ["host","join"])cases.push({id:"lmg",actor:actor,target:"expiry"});
         for each(actor in ["host","join"])cases.push({id:"lmg",actor:actor,target:"unit"});
         return cases;
      }
   }
}

package {
   public class WallEnergyTestDoc extends EnergyImpactTestDoc {
      public function WallEnergyTestDoc() {super(scenarios());}
      private static function scenarios():Array {
         var cases:Array=[];
         for each(var id:String in ["nova","plam","prism","blaster"])
            for each(var actor:String in ["host","join"])cases.push({id:id,actor:actor,target:"wall"});
         for each(actor in ["host","join"])cases.push({id:"plamg",actor:actor,target:"wall",burst:12});
         cases.push({id:"alilight",actor:"enemy",target:"wall"});
         for each(actor in ["host","join"])cases.push({id:"cflamer",actor:actor,target:"wall"});
         for each(actor in ["host","join"])cases.push({id:"plamg",actor:actor,target:"expiry"});
         return cases;
      }
   }
}

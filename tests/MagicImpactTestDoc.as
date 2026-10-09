package {
   /** Native magic weapons and direct Spell particles, both TCP directions. */
   public class MagicImpactTestDoc extends EnergyImpactTestDoc {
      public function MagicImpactTestDoc() {super(scenarios());}
      private static function scenarios():Array {
         var cases:Array=[];
         for each(var id:String in ["telebul","mbul","ice","lightning","mray","dray","skybolt"])
            for each(var actor:String in ["host","join"])cases.push({id:id,actor:actor,target:"wall"});
         for each(id in ["sp_blast","sp_gwall"])
            for each(actor in ["host","join"])cases.push({id:id,actor:actor,target:"spell",spell:true});
         for each(id in ["mace","kosa","elsword"])
            for each(actor in ["host","join"])cases.push({id:id,actor:actor,target:"unit",melee:true,noFlare:id!="kosa"});
         for each(id in ["mace","elsword"])
            for each(actor in ["host","join"])cases.push({id:id,actor:actor,target:"unit",melee:true,metal:true});
         return cases;
      }
   }
}

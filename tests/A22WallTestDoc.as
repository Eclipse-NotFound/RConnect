package {
   public class A22WallTestDoc extends WallImpactTestDoc {
      public function A22WallTestDoc() {
         super([{weapon:"quick",actor:"host",mat:2,locked:false,hole:true,burst:8},
            {weapon:"quick",actor:"join",mat:2,locked:false,hole:true,burst:8},
            {weapon:"lmg",actor:"host",mat:3,locked:true,hole:true,burst:8},
            {weapon:"lmg",actor:"join",mat:3,locked:true,hole:true,burst:8},
            {weapon:"minigun",actor:"host",mat:3,locked:true,hole:true,burst:12},
            {weapon:"minigun",actor:"join",mat:3,locked:true,hole:true,burst:12}],"rbl");
      }
   }
}

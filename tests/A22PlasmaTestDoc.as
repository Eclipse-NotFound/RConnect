package {
   public class A22PlasmaTestDoc extends EnergyImpactTestDoc {
      public function A22PlasmaTestDoc() {
         super([{id:"quick",actor:"host",target:"wall",burst:8,interpolate:true},
            {id:"quick",actor:"join",target:"wall",burst:8,interpolate:true},
            {id:"plam",actor:"host",target:"wall",burst:4,interpolate:true},
            {id:"plam",actor:"join",target:"wall",burst:4,interpolate:true},
            {id:"prism",actor:"host",target:"wall",burst:4},
            {id:"prism",actor:"join",target:"wall",burst:4}],false,"rbl");
      }
   }
}

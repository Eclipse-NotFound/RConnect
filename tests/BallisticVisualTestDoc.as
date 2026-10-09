package {
   public class BallisticVisualTestDoc extends EnergyImpactTestDoc {
      public function BallisticVisualTestDoc() {
         super([{id:"lmg",actor:"host",target:"wall"},{id:"lmg",actor:"join",target:"wall"},
            {id:"autor",actor:"host",target:"wall"},{id:"autor",actor:"join",target:"wall"},
            {id:"lmg",actor:"host",target:"unit"},{id:"lmg",actor:"join",target:"unit"},
            {id:"lmg",actor:"host",target:"expiry"},{id:"lmg",actor:"join",target:"expiry"}],true);
      }
   }
}

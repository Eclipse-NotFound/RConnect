package {
   /** Same real-input/TCP oracle as the ordinary explosives, with distinct
    * ground/splash/pulse assertions. Baseline 22 must expose omitted effects. */
   public class SpecialWeaponTestDoc extends ExplosiveVisualTestDoc {
      public function SpecialWeaponTestDoc() {
         super([
            {id:"acidgr",quick:true,water:false,part:"acidexpl",ground:"acid",impact:true},
            {id:"plagr",quick:true,water:false,part:"plaexpl"},
            {id:"impgr",quick:true,water:false,part:"impexpl"},
            {id:"cryogr",quick:true,water:false,part:"iceexpl"},
            {id:"gasgr",quick:true,water:false,part:"gas",pulses:true},
            {id:"molotov",quick:true,water:false,part:"fireexpl",ground:"fire",impact:true}
         ]);
      }
   }
}

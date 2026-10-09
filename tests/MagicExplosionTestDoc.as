package {
   /** Native quick-magic input, separate from the equipped weapon. */
   public class MagicExplosionTestDoc extends ExplosiveVisualTestDoc {
      public function MagicExplosionTestDoc() {
         super([{id:"fireball",magic:true,water:false,part:"fireexpl",ground:"fire"},
            {id:"eclipse",magic:true,water:false,part:"eclipse"}]);
      }
   }
}

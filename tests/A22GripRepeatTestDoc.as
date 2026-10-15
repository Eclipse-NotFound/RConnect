package {
   /** Repeat the same native body/receiver and AI handoffs in one connection.
    * This is a diagnostic for intermittent refusal, not automatic test retries:
    * every failed assertion remains in the run's result. */
   public class A22GripRepeatTestDoc extends A22BehaviorTestDoc {
      public function A22GripRepeatTestDoc() {super(4);}
   }
}

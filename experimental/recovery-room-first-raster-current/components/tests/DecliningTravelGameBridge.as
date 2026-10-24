package {
   import flash.display.Sprite;
   import rconnect.game.GameBridge;

   /** Test-only native refusal; separate source file for the AIR compiler. */
   public class DecliningTravelGameBridge extends GameBridge {
      public function DecliningTravelGameBridge(root:Sprite){super(root);}
      override public function startSharedTravel(info:Object):Boolean{startCalls++;return false;}
   }
}

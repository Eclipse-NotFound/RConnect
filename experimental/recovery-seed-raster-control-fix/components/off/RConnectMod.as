package {
   import flash.display.*;
   import rconnect.core.Session;
   import rconnect.game.GameBridge;
   public class RConnectMod {
      public var stage:Stage,main:Sprite,game:GameBridge,session:Session;
      public var enemyGrip:Object,peerGrip:Object,hud:Object;
      public var config:Object={getValue:function(k:String):String{return "0";}};
      public function RConnectMod(surface:Stage) {
         stage=surface;main=new Sprite();stage.addChild(main);game=new GameBridge(main);
         session=new Session(this);
      }
   }
}

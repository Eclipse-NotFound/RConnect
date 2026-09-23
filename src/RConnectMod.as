package
{
   import flash.display.Stage;
   import flash.utils.getQualifiedClassName;
   import rconnect.core.Config;
   import rconnect.core.Log;
   import rconnect.core.Session;
   import rconnect.game.GameBridge;
   import rconnect.game.ExplorationSync;
   import rconnect.game.VersionProbe;
   import rconnect.ui.NetHud;

   /**
    * RConnect 模组入口类（必须位于默认包，类名精确为 RConnectMod）。
    *
    * 加载契约（见 knowledge/facts/loader-contract.md）：
    * 补丁后游戏 MainFE 用 Loader + LoaderContext(false)（子 ApplicationDomain）
    * 加载 release/RConnectMod.swf，然后调用：
    *     applicationDomain.getDefinition("RConnectMod").init(main);
    * 其中 init 必须是静态方法，main 是 MainFE 实例。
    */
   public class RConnectMod
   {
      public static const VERSION:String = "0.2.7-dev";

      public static var instance:RConnectMod;

      /** 加载器契约要求的静态入口。失败只 trace，不阻断游戏。 */
      public static function init(main:Object):void
      {
         try
         {
            instance = new RConnectMod(main);
            Log.d("RConnectMod: v" + VERSION + " initialized");
         }
         catch(err:*)
         {
            trace("RConnectMod: init failed: " + err);
         }
      }

      public var main:Object;
      public var stage:Stage;
      public var config:Config;
      public var game:GameBridge;
      public var exploration:ExplorationSync;
      public var session:Session;
      public var hud:NetHud;
      public var versionInfo:Object;

      public function RConnectMod(main:Object)
      {
         this.main = main;
         this.stage = main["stage"] as Stage;
         // 自检：确认 main 身份（版本探测与游戏接入都依赖它）
         try
         {
            Log.d("RConnectMod: main class=" + getQualifiedClassName(main));
         }
         catch(err:*)
         {
            Log.d("RConnectMod: main introspection failed: " + err);
         }
         this.versionInfo = VersionProbe.detect(main);
         this.config = new Config();
         this.game = new GameBridge(main);
         var fz:String = String(config.getValue("freezeAI"));
         game.freezeAI = (fz == "1" || fz == "true" || fz == "yes");
         var gc:String = String(config.getValue("ghostCombat"));
         game.ghostCombat = (gc != "0" && gc != "false" && gc != "no");
         game.testGhostDmg = Number(config.getValue("testGhostDmg"));
         this.exploration = new ExplorationSync(this);
         this.hud = new NetHud(stage, this);
         this.session = new Session(this);
         hud.refresh();
         session.autoStart();
         Log.d("RConnectMod: game version=" + versionInfo.version
            + " bd=" + versionInfo.boxDamage
            + " instMatch=" + versionInfo.instanceMatchesClass
            + " world=" + (game.world != null));
      }
   }
}

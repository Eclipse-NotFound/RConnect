package
{
   import flash.display.Sprite;
   import flash.display.MovieClip;
   import flash.display.DisplayObjectContainer;

   /**
    * TDFC 模组文档类（默认包，文件名 = 类名）。
    *
    * 加载契约（shared-knowledge/knowledge-validation/discoveries/mod-loader-patch-structure.md）：
    *  - 游戏补丁 loader 用 getDefinition("<文档类名>") 取类后调 cls.init(this)；
    *  - 实参是 MainFE 实例，从 main.stage 注册事件。
    */
   public class TDFCMod extends Sprite
   {
      private static var authorityCarrier:MovieClip;
      public function TDFCMod()
      {
         super();
      }

      public static function init(main:*):void
      {
         TdfcLog.init();    // 内部先打版本标记行
         TdfcRuntime.init(main);
         // Public discovery surface across sibling loader domains. No caller
         // needs access to MainFE's internal loader dictionary.
         if(authorityCarrier==null) {
            var container:DisplayObjectContainer=main as DisplayObjectContainer;
            if(container==null || container.getChildByName("TDFCAuthorityCarrier")!=null)throw new Error("TDFC authority carrier unavailable or occupied");
            authorityCarrier=new MovieClip();authorityCarrier.name="TDFCAuthorityCarrier";
            authorityCarrier.visible=false;authorityCarrier.mouseEnabled=false;
            authorityCarrier.authorityAPI={version:1,attach:attachAuthority};
            container.addChild(authorityCarrier);
         }
      }
      public static function attachAuthority(owner:Object):Object
      {
         return TdfcRuntime.attachAuthority(owner);
      }
   }
}

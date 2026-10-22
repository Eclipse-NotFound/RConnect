package
{
   import flash.display.Sprite;

   /**
    * 编译用文档类：空的 Sprite，满足 Loader 链接根的需求（#2023）。
    * 真正的模组入口是 RConnectMod（普通类 + 静态 init），
    * 由游戏加载器 getDefinition("RConnectMod").init(main) 调用。
    */
   public class RConnectDoc extends Sprite
   {
      /** 强引用 RConnectMod，防止 mxmlc 死代码消除把它从 SWF 里剪掉。 */
      public static const MOD_CLASS:Class = RConnectMod;

      public function RConnectDoc()
      {
      }
   }
}

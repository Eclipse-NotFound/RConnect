package rconnect.game
{
   import flash.utils.getQualifiedClassName;

   /**
    * 运行时版本与能力探测。
    * 游戏类 API 随版本可能不同：所有结论都来自探测，不假设单一版本。
    */
   public class VersionProbe
   {
      public static const V_102:String = "1.02";
      /** 1.03 与 1.04 的类结构与公开 API 面完全一致（1016 类同名同字段），
       *  差异仅在游戏数据与内部逻辑，联机接入无需细分。 */
      public static const V_103X:String = "1.03/1.04";
      public static const V_TEST:String = "test";
      public static const V_UNKNOWN:String = "unknown";

      public static function detect(main:Object):Object
      {
         var out:Object = {version: V_UNKNOWN, url: ""};

         // 0) URL 只作日志参考：实测从模组子域访问 main/stage 的 loaderInfo
         //    会错误返回模组自己的 URL（见 knowledge/discoveries/），不可作判定依据
         try
         {
            out.url = String(main["loaderInfo"]["url"]);
         }
         catch(err:*)
         {
         }

         // 1) 版本指纹：fe.World.boxDamage（公开静态常量）
         //    反编译对比：1.02 = 0.2；1.03 = 0.3；1.04 = 0.3（与 1.03 一致）
         try
         {
            var ad:Object = main["loaderInfo"]["applicationDomain"];
            var worldCls:Object = ad["getDefinition"]("fe.World");
            if(worldCls != null)
            {
               out.hasWorldClass = true;
               // 关键：从 World 实例的 constructor 反推真实类。
               // 实测 getDefinition 在模组子域里可能解析到"另一个"游戏 SWF 的
               // 同名类（域链混乱），而实例的 constructor 一定属于它自己。
               var w:Object = worldCls["w"];
               var cls:Object = w != null ? w["constructor"] : worldCls;
               var bd:Number = Number(cls["boxDamage"]);
               out.boxDamage = bd;
               out.instanceMatchesClass = (w != null && w["constructor"] == worldCls);
               if(bd == 0.2)
               {
                  out.version = V_102;
               }
               else if(bd == 0.3)
               {
                  out.version = V_103X;
               }
               out.hasWorldInstance = w != null;
            }
         }
         catch(err:*)
         {
         }

         // 2) 测试容器兜底（无 fe.World）：按文档类类名（URL 探测在子域里不可靠）
         try
         {
            if(out.version == V_UNKNOWN
               && getQualifiedClassName(main) == "TestMain")
            {
               out.version = V_TEST;
            }
         }
         catch(err:*)
         {
         }

         return out;
      }
   }
}

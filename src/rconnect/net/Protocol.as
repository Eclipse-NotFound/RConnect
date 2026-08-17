package rconnect.net
{
   /**
    * 线协议（MVP：TCP + 长度前缀 JSON）。
    *
    * 帧格式：uint32 大端字节序长度 + UTF-8 JSON。
    * 字段缺失时各端按默认值兜底，保证小版本兼容。
    */
   public class Protocol
   {
      public static const PROTO:int = 1;

      public static const MSG_HELLO:String = "hello";
      public static const MSG_WELCOME:String = "welcome";
      public static const MSG_PLAYERSTATE:String = "playerstate";
      public static const MSG_WORLDSTATE:String = "worldstate";
      public static const MSG_CHAT:String = "chat";
      public static const MSG_GOODBYE:String = "goodbye";
      public static const MSG_UNITSYNC:String = "unitsync";
      public static const MSG_DAMAGE:String = "damage";
      public static const MSG_PLAYERDMG:String = "playerdmg";

      /** 构造消息对象（type + 字段）。 */
      public static function make(type:String, fields:Object):Object
      {
         var m:Object = fields ? fields : {};
         m.type = type;
         m.proto = PROTO;
         return m;
      }

      /** 序列化为线上字节序列（长度前缀帧）。 */
      public static function encode(msg:Object):String
      {
         var body:String = JSON.stringify(msg);
         return body;
      }

      /** 反序列化并做基本合法性检查。 */
      public static function decode(json:String):Object
      {
         var m:Object;
         try
         {
            m = JSON.parse(json);
         }
         catch(err:*)
         {
            return null;
         }
         if(m == null || !(m is Object) || m.type == undefined)
         {
            return null;
         }
         return m;
      }
   }
}

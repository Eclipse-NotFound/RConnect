package rconnect.net
{
   /**
    * 消息结构与 JSON 后备编码。TcpLink 负责长度前缀和编码协商。
    *
    * 正长度：UTF-8 JSON；双方问候确认后，负长度：受限的 AMF3 纯数据。
    * 业务对象结构不变。未协商时始终保留 JSON，不假定其它版本能力。
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
      public static const MSG_LOOT:String = "loot";
      public static const MSG_LOOT_ACK:String = "loot-ack";
      public static const MSG_OBJS:String = "objs";
      public static const MSG_TERRAIN:String = "terrain";
      public static const MSG_TERRAIN_ACK:String = "terrain-ack";
      public static const MSG_EXPLORATION:String = "exploration";

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

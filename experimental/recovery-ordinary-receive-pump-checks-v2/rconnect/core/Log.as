package rconnect.core
{
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;

   /**
    * 模组日志：trace 之外追加写入 app:/mods/Rconnect/RConnect.log。
    * ADL 的 trace 在 Windows 下不进 stdout，文件日志是唯一的无头验证手段。
    * 写入失败静默（打包后的正式应用目录可能只读）。
    */
   public class Log
   {
      private static var _file:File = null;
      private static var _fallback:File = null;

      public static function d(msg:String):void
      {
         trace(msg);
         try
         {
            if(_file == null)
            {
               // 首选 app:/mods/Rconnect/RConnect.log（游戏下 ADL 可写）；
               // 失败则落到 applicationStorageDirectory（一定可写）。
               var f:File = File.applicationDirectory.resolvePath(
                  "mods/Rconnect/RConnect.log");
               var dir:File = f.parent;
               if(!dir.exists)
               {
                  dir.createDirectory();
               }
               _file = f;
               _fallback = File.applicationStorageDirectory.resolvePath(
                  "RConnect.log");
            }
            var fs:FileStream = new FileStream();
            try
            {
               fs.open(_file, FileMode.APPEND);
            }
            catch(e1:*)
            {
               fs.open(_fallback, FileMode.APPEND);
            }
            fs.writeUTFBytes(msg + "\r\n");
            fs.close();
         }
         catch(err:*)
         {
            // 日志写不进去不影响功能
         }
      }
   }
}

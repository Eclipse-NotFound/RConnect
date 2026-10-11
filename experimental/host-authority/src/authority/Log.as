package authority {
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.utils.getTimer;
   public class Log {
      public static function write(kind:String, data:Object=null):void {
         var stream:FileStream=new FileStream();
         try {
            stream.open(File.applicationStorageDirectory.resolvePath("RConnect-B.log"),FileMode.APPEND);
            stream.writeUTFBytes(JSON.stringify({at:getTimer(),kind:kind,data:data})+"\n");
         } finally {stream.close();}
      }
      public static function error(error:*):void {
         write("error", {message:String(error),stack:error is Error?(error as Error).getStackTrace():null});
      }
   }
}

package lad {
    import flash.filesystem.File;
    import flash.filesystem.FileMode;
    import flash.filesystem.FileStream;
    public final class LadLog {
        public static function write(message:String):void {
            var stream:FileStream = new FileStream();
            try {
                stream.open(File.applicationStorageDirectory.resolvePath("LightAndDarkness.log"), FileMode.APPEND);
                stream.writeUTFBytes(new Date().toUTCString() + " [LightAndDarkness] " + message + "\n");
            } catch(error:*) { trace("LightAndDarkness log: " + error); }
            finally { try { stream.close(); } catch(ignored:*) {} }
        }
    }
}

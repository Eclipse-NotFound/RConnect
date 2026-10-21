package {
   import flash.filesystem.*;
   /** Immutable external fixture input copied into the isolated test root. */
   public final class SeedGateNativeIntent {
      public static function read():Object {
         var file:File=File.applicationDirectory.resolvePath("tests/seed-gate-intent.json");
         if(!file.exists)throw new Error("Missing explicit seed raster test intent");
         var stream:FileStream=new FileStream();var raw:String;
         stream.open(file,FileMode.READ);try{raw=stream.readUTFBytes(stream.bytesAvailable);}finally{stream.close();}
         var value:Object=JSON.parse(raw);
         if(value==null || value.schema!==1 || !(value.expectSeedTicket is Boolean)
            || value.candidateSha==null || !/^[0-9a-f]{64}$/.test(String(value.candidateSha)))
            throw new Error("Invalid explicit seed raster test intent");
         return value;
      }
   }
}

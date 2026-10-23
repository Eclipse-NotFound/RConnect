package {
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import rconnect.core.Log;
   public class RoomTravelSceneTestDoc extends RoomTravelTimingTestDoc {
      public function RoomTravelSceneTestDoc() {
         super();
         var file:File=File.applicationStorageDirectory.resolvePath("ContinuousScene.preferences.json");
         var stream:FileStream=new FileStream(),ok:Boolean=false;
         try {
            stream.open(file,FileMode.READ);
            var value:Object=JSON.parse(stream.readUTFBytes(stream.bytesAvailable));
            ok=value.nativeEnabled===true;
         }catch(error:Error){Log.d("COOP FAIL scene preconnection preference receipt: "+error);}
         finally {try{stream.close();}catch(ignored:Error){}}
         Log.d("COOP "+(ok?"PASS ":"FAIL ")+"scene preconnection preference file is true");
         Log.d("SCENE PREFERENCE BASELINE "+JSON.stringify({expected:true,file:file.nativePath,
            mode:RConnectMod.instance==null?"not-initialized":RConnectMod.instance.session.mode}));
      }
      override protected function merged():Boolean{return true;}
   }
}

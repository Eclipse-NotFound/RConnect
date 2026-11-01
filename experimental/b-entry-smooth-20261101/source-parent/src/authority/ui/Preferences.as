package authority.ui {
   import flash.net.SharedObject;
   import authority.Log;
   /** Local AIR profile preferences, separate from the pinned launch manifest. */
   public final class Preferences {
      private var store:SharedObject;
      private var values:Object={nickname:"Pony",hostIp:"127.0.0.1",port:23456,followTeammate:"0",sharedExploration:"1",
         allowPeerGrip:"0",peerGripStruggle:"1",peerThrowDamage:"0",friendlyFire:"0",pauseMenus:"0",pauseSats:"0",sharedSecurityHack:"1",shareHorseshoeXP:"1"};
      public function Preferences(launch:Object) {
         store=SharedObject.getLocal("RConnectBPreferences","/");
         for(var key:String in values)if(store.data[key]!=null)values[key]=store.data[key];
         for each(key in ["port","nickname","hostIp"])if(launch[key]!=null)values[key]=launch[key];
      }
      public function getValue(key:String):* {return values[key];}
      public function setValue(key:String,value:*):void {if(values.hasOwnProperty(key))values[key]=value;}
      public function save():void {try {for(var key:String in values)store.data[key]=values[key];store.flush();}catch(e:*){Log.write("preferences-save-failed",{reason:String(e)});}}
   }
}

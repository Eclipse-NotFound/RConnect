package authority {
   /** A remote checkpoint must never overwrite the host's native character slot. */
   public final class PersonalSaves {
      private var access:NativeAccess,host:HostSession,input:InputSource,previous:Function;
      private var applying:Boolean=false,lastSaved:uint=0;
      public function PersonalSaves(access:NativeAccess,host:HostSession=null,input:InputSource=null) {
         this.access=access;this.host=host;this.input=input;
         var World:Class=access.definition("fe.World");previous=World["rconnectSave"];
         if(previous!=null)throw new Error("Native save seam already occupied");
         World["rconnectSave"]=save;
      }
      private function save(w:Object,slot:int):Boolean {
         if(applying)return false;
         if(host!=null) {
            if(!host.active)return false;
            if(w.gg===host.actors[1].unit){++host.actors[1].saveSerial;return true;}
            return false;
         }
         if(NativeIntents.replaying==0)input.enqueue({type:"native",key:"save",args:[slot]});
         return true;
      }
      public function confirm(serial:uint):void {
         if(serial<=lastSaved)return;
         applying=true;
         try {
            // Explicit slot bypasses only the vanilla autosave tick cooldown;
            // the joining world's simulation clock intentionally does not run.
            access.world.saveGame(access.world.autoSaveN);
            lastSaved=serial;Log.write("personal-save",{serial:serial,slot:access.world.autoSaveN});
         }finally {applying=false;}
      }
      public function dispose():void {access.definition("fe.World")["rconnectSave"]=previous;}
   }
}

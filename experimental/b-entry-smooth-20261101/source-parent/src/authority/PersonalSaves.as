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
            if(w.gg===host.actors[1].unit){host.actors[1].requestSave(slot);return true;}
            if(access.weapons!=null)access.weapons.carryState(w.game);
            if(access.addons!=null)access.addons.carryState(w.game);
            return false;
         }
         if(NativeIntents.replaying==0)input.enqueue({type:"native",key:"save",args:[slot]});
         return true;
      }
      public function confirm(requests:Array):void {
         for each(var request:Object in requests) {
            if(request.serial<=lastSaved)continue;
            var slot:int=request.slot<0?access.world.autoSaveN:int(request.slot);
            if(slot<0 || access.world.getSave(slot)==null)throw new Error("Requested character save slot is unavailable");
            applying=true;
            try {
            // Explicit slot bypasses only the vanilla autosave tick cooldown;
            // the joining world's simulation clock intentionally does not run.
               if(access.addons!=null)access.addons.carryState(access.world.game);
               access.world.saveGame(slot);
               lastSaved=request.serial;Log.write("personal-save",{serial:lastSaved,slot:slot});
            }finally {applying=false;}
         }
      }
      public function dispose():void {access.definition("fe.World")["rconnectSave"]=previous;}
   }
}

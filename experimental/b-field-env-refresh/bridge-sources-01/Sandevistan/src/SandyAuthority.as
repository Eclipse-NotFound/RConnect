package {
   import flash.display.Sprite;
   /** Opt-in B boundary. This carrier never steps a world or applies damage.
    * The original single-player path remains the default until attach. */
   public final class SandyAuthority extends Sprite {
      public var authorityAPI:Object;
      private var client:Object,settings:Function,paint:Function,available:Function;
      private var held:Boolean=false;
      public function SandyAuthority(settings:Function,paint:Function,available:Function) {
         this.settings=settings;this.paint=paint;this.available=available;
         name="SandyAuthorityAPI";visible=false;mouseEnabled=mouseChildren=false;
         authorityAPI={version:1,attach:attach};
      }
      public function get attached():Boolean{return client!=null;}
      private function attach(options:Object):Object {
         if(client!=null || options==null || options.version!==1 ||
            ["host","join"].indexOf(options.role)<0 || !(options.session is String) ||
            !(options.submit is Function) || !available())throw new Error("Sandevistan B attachment rejected");
         client=options;held=false;paint({phase:"idle",left:0,cooldown:0,paused:false});
         return {version:1,profile:settings,present:present,detach:detach};
      }
      public function key(code:uint,down:Boolean):void {
         if(client==null || code!=uint(settings().hotkey))return;
         if(down && !held){held=true;client.submit();}
         if(!down)held=false;
      }
      public function release():void {held=false;}
      private function present(state:Object):void {
         if(client==null || state==null || ["idle","record","replay"].indexOf(state.phase)<0)
            throw new Error("Invalid Sandevistan B presentation");
         paint(state);
      }
      private function detach():void {
         if(client==null)return;client=null;held=false;paint(null);
      }
   }
}

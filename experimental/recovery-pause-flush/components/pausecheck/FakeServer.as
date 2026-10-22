package pausecheck {
   public class FakeServer {
      public var bound:Boolean=true,clients:Array=[{}],sent:Array=[],calls:int=0;
      public var throwOnce:Boolean=false,hook:Function;
      public function broadcast(o:Object):void {
         calls++;Probe.events.push("world-send");
         if(hook!=null)hook();
         if(throwOnce){throwOnce=false;throw new Error("fixture send failed");}
         sent.push(o);
      }
   }
}

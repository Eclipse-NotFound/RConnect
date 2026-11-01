package fe.inter {
   import flash.display.MovieClip;
   import authority.NativeAccess;
   import authority.VisualPose;
   /** Keep native formatting/bulb text, while delivering feedback to its owner. */
   public class AuthorityGUI extends GUI {
      private var events:Array=[],serial:uint=0;
      public var authorityWorld:Object;
      public function AuthorityGUI(visual:MovieClip){super(visual);}
      private function remember(key:String,args:Array):void {
         events.push({id:++serial,key:key,args:args});if(events.length>64)events.shift();
      }
      public function rconnectMessages():Array{return events.concat();}
      public function modalState():Object {
         var result:Object={paused:guiPause};
         for each(var key:String in ["dial","inform","imp"])result[key]=vis[key].visible?VisualPose.capture(vis[key]):null;
         return result;
      }
      public static function applyModal(gui:Object,state:Object):void {
         if(state==null)return;
         for each(var key:String in ["dial","inform","imp"]) {
            if(state[key]==null)gui.vis[key].visible=false;
            else VisualPose.apply(gui.vis[key],state[key]);
         }
         gui.guiPause=state.paused;
      }
      override public function infoText(key:String,arg:*=0,arg2:*=null,log:Boolean=true):* {
         remember("infoText",[key,arg==null?null:String(arg),arg2==null?null:String(arg2),log]);
         // The client invokes its own native log write on confirmation.
         super.infoText(key,arg,arg2,false);
      }
      override public function infoEffText(key:String):* {remember("infoEffText",[key]);super.infoEffText(key);}
      override public function messText(key:String,arg:String="",down:Boolean=false,append:Boolean=false,ticks:*=150):* {
         remember("messText",[key,arg,down,append,ticks]);super.messText(key,arg,down,append,ticks);
      }
   }
}

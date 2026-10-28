package rconnect.game {
   import fe.graph.Emitter;
   import fe.graph.Part;
   import fe.loc.Location;
   /** Observe the actual native cast; never run damage or choose a new line. */
   public class NativeTextEmitter extends Emitter {
      public var source:Emitter;
      private var observe:Function;
      private var context:Function;
      public function NativeTextEmitter(original:Emitter,callback:Function,onCast:Function=null) {
         super(<part/>);source=original;observe=callback;context=onCast;id=original.id;
      }
      override public function cast(loc:Location,x:Number,y:Number,options:Object=null):Part {
         var part:Part=source.cast(loc,x,y,options);
         // A display observer must never interrupt native damage or dialogue.
         if(part!=null && observe!=null)try{observe(part);}catch(error:Error){}
         // Context observes a native invocation even if the particle budget
         // suppresses its cosmetic Part; it never suppresses the native call.
         if(context!=null)try{context(loc,x,y,options,part);}catch(contextError:Error){}
         return part;
      }
   }
}

package fe.graph {
   import fe.loc.Location;
   import flash.utils.describeType;
   /** Delegate native speech creation unchanged, observing its exact birth view.
    * This wrapper is only installed for the two native NPC speech emitters. */
   public final class AuthoritySpeechEmitter extends Emitter {
      private var original:Object,camera:Function,observe:Function;
      private var names:Array=[],mirrored:Object={};
      private var nativeId:String,nativeVisual:String;
      public function AuthoritySpeechEmitter(original:Object,camera:Function,observe:Function) {
         super(<part/>);
         this.original=original;this.camera=camera;this.observe=observe;
         nativeId=original.id;nativeVisual=original.vis;
         for each(var field:XML in describeType(original).variable) {
            if(field.hasOwnProperty("@uri"))continue;
            var name:String=String(field.@name);names.push(name);
            Object(this)[name]=mirrored[name]=original[name];
         }
      }
      override public function cast(room:Location,x:Number,y:Number,options:Object=null):Part {
         // Keep public emitter changes made through either the array entry or
         // an existing reference. Native cast also updates frame/dframe itself.
         for each(var name:String in names) {
            var value:*=Object(this)[name];
            if(value!==mirrored[name])original[name]=value;
            else Object(this)[name]=original[name];
         }
         var before:Object=room==null?null:Object(room).lastObj;
         var scale:Number=Number(camera());
         var tracked:Boolean=original.camscale && original.id===nativeId && original.vis===nativeVisual && isFinite(scale) && scale>0;
         var result:Part;
         try {result=original.cast(room,x,y,options);}
         finally {for each(name in names)Object(this)[name]=mirrored[name]=original[name];}
         if(tracked && room!=null) {
            // Emitter.cast can add up to fifty Part instances (options.kol),
            // and its return value names only the last one. Preserve all births.
            var part:Object=before==null?Object(room).firstObj:before.nobj;
            var last:Object=Object(room).lastObj;
            while(part!=null) {
               if(part is Part)observe(part,scale);
               if(part===last)break;
               part=part.nobj;
            }
         }
         return result;
      }
   }
}

package authority {
   import fe.graph.AuthoritySpeechEmitter;
   import flash.utils.Dictionary;
   import flash.utils.getQualifiedClassName;
   /** Camera compensation belongs to a particle's birth, not its later frame.
    * Preserve the native custom scale; only exchange the camera's inverse scale. */
   public final class SpeechScale {
      private var births:Dictionary=new Dictionary(true),bindings:Array=[];
      public function SpeechScale(access:NativeAccess) {
         var array:Array=access.definition("fe.graph.Emitter")["arr"];
         if(array==null)return;
         for each(var id:String in ["replic","replic2"]) {
            var original:Object=array[id],visual:String=id=="replic"?"visReplic":"visReplic2";
            // Public mods may replace emitters. Leave unknown implementations
            // and already-existing particles on the unchanged complete-pose path.
            if(original==null || getQualifiedClassName(original)!=="fe.graph::Emitter" || !original.camscale || original.id!==id || original.vis!==visual)continue;
            var wrapper:AuthoritySpeechEmitter=new AuthoritySpeechEmitter(original,function():Number{return Number(access.world.cam.scaleV);},remember);
            bindings.push({array:array,id:id,original:original,wrapper:wrapper});array[id]=wrapper;
         }
      }
      private function remember(part:Object,scale:Number):void {births[part]=scale;}
      public function capture(part:Object):Number {return births[part]==null?0:Number(births[part]);}
      public static function localPose(pose:Object,birthScale:Number,localScale:Number):Object {
         if(pose==null || !isFinite(birthScale) || birthScale<=0 || !isFinite(localScale) || localScale<=0)return pose;
         var ratio:Number=birthScale/localScale;
         if(ratio==1)return pose;
         var out:Object=PoseTween.copy(pose);
         out.sx=pose.sx*ratio;out.sy=pose.sy*ratio;
         if(pose.m!=null) {
            out.m=pose.m.concat();
            for(var i:int=0;i<4;i++)out.m[i]=pose.m[i]*ratio;
         }
         return out;
      }
      public function dispose():void {
         for each(var binding:Object in bindings)
            if(binding.array[binding.id]===binding.wrapper)binding.array[binding.id]=binding.original;
         bindings=[];births=new Dictionary(true);
      }
   }
}

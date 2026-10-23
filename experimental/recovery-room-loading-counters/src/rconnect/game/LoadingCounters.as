package rconnect.game {
   import flash.desktop.NativeApplication;
   import flash.utils.getTimer;
   /** Temporary diagnostic only. All times include nested work; do not add them. */
   public final class LoadingCounters {
      private static var enabled:Boolean=false,data:Object=null,nextIndex:int=0;
      public static function begin(kind:String,index:int):Boolean {
         var app:String=NativeApplication.nativeApplication.applicationID;
         if(app.indexOf("pfe-modsettings-rconnect-coop-join-")!=0 || enabled || index!=nextIndex || index>2
            || kind!=(index==0?"grant":"enter-to-render"))return false;
         nextIndex++;data={kind:kind,index:index,begin:getTimer(),end:null,methods:{},faults:[]};
         for each(var key:String in ["GameBridge.onPerceptionFrame","GameBridge.onMirrorFrame","GameBridge.onMirrorMaskFrame",
            "GameBridge.onVisForceFrame","MirrorMasks.capture","MirrorMasks.bitmapSignature","MirrorMasks.maskReferences",
            "MirrorMasks.restore","MirrorMasks.clean"])data.methods[key]={calls:0,totalMs:0,maxMs:0};
         data.methods["MirrorMasks.maskReferences"].nodes=0;enabled=true;return true;
      }
      public static function enter():int {return enabled?getTimer():-1;}
      public static function end(key:String,at:int):void {
         if(at<0 || !enabled)return;
         var elapsed:int=getTimer()-at;
         try {
            var row:Object=data.methods[key];row.calls++;row.totalMs+=elapsed;
            row.maxMs=Math.max(row.maxMs,elapsed);
            if(elapsed<0 && data.faults.length<8)data.faults.push("negative-clock:"+key);
         }catch(error:*){fault("counter:"+key);}
      }
      public static function node():void {
         if(!enabled)return;
         try{data.methods["MirrorMasks.maskReferences"].nodes++;}catch(error:*){fault("reference-node");}
      }
      private static function fault(where:String):void {
         try{if(data!=null && data.faults.length<8)data.faults.push(where);}catch(ignored:*){}
      }
      public static function finish():Object {
         if(!enabled)return null;
         enabled=false;data.end=getTimer();var result:Object=data;data=null;return result;
      }
   }
}

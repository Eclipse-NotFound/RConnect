package authority {
   import flash.display.DisplayObjectContainer;
   /** Separate opt-in lease. Shared exploration retains its original API. */
   public final class ViewBridge {
      private var api:Object;
      public function ViewBridge(main:Object,session:String,role:String) {
         var container:DisplayObjectContainer=main as DisplayObjectContainer;
         var carrier:Object=container==null?null:container.getChildByName("RVAuthorityViewAPI");
         var entry:Object=NativeAccess.get(carrier,"authorityAPI");
         if(entry==null || entry.version!==1 || !(entry.attach is Function))throw new Error("Pinned RV B interface is unavailable");
         api=entry.attach({version:1,session:session,role:role});
         if(api==null || api.version!==1 || !(api.prepare is Function) || !(api.readNative is Function) || !(api.detach is Function))throw new Error("RV B interface mismatch");
         Log.write("view-attached",{role:role,version:api.version});
      }
      public function prepare():void {if(api!=null)api.prepare();}
      public function readNative(operation:Function):* {return api==null?operation():api.readNative(operation);}
      public function dispose():void {if(api!=null){api.detach();api=null;}}
   }
}

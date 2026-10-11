package authority {
   import flash.utils.Dictionary;
   /** Ordered reliable deltas keep unchanged native poses out of the wire. */
   public final class FrameDelta {
      private var prior:Object,serial:uint=0;
      public function encode(frame:Object):Object {
         var result:Object={type:"frame",session:frame.session,serial:++serial,base:serial-1};
         if(prior==null)result.full=frame;
         else {result.changes=[];diff(prior,frame,[],result.changes);}
         prior=frame;return result;
      }
      public function decode(packet:Object):Object {
         if(packet.base!==serial || packet.serial!==serial+1)throw new Error("Confirmation delta sequence gap");
         if(packet.full!=null)prior=packet.full;
         else {
            if(prior==null || !(packet.changes is Array))throw new Error("Confirmation delta has no baseline");
            // A render buffer retains older confirmations. Clone only branches
            // changed by this packet; never mutate a previously returned frame.
            var clones:Dictionary=new Dictionary(true),root:Object=prior;
            prior=branch(root);clones[root]=prior;
            for each(var op:Array in packet.changes) {
               var target:Object=prior,path:Array=op[0];
               if(path.length==0){prior=op[2];continue;}
               for(var i:int=0;i<path.length-1;i++) {
                  var child:Object=target[path[i]],copy:Object=clones[child];
                  if(copy==null){copy=branch(child);clones[child]=copy;clones[copy]=copy;}
                  target[path[i]]=copy;target=copy;
               }
               if(op[1]==0)delete target[path[path.length-1]];else target[path[path.length-1]]=op[2];
            }
         }
         serial=packet.serial;return prior;
      }
      private static function branch(value:Object):Object {
         var result:Object=value is Array?[]:{};
         for(var key:String in value)result[key]=value[key];
         return result;
      }
      private static function simple(value:*):Boolean {return value==null || value is String || value is Number || value is Boolean;}
      private static function diff(a:*,b:*,path:Array,out:Array):void {
         if(a===b)return;
         if(simple(a) || simple(b) || (a is Array)!=(b is Array)) {out.push([path,1,b]);return;}
         if(a is Array && a.length!=b.length) {out.push([path,1,b]);return;}
         for(var key:String in b) {
            var before:*=a[key],after:*=b[key];
            // Most native storage and authored symbol properties did not
            // change. Do not allocate a path or recurse for every such scalar.
            if(before===after)continue;
            var next:Array=path.concat([key]);
            if(!(key in a) || simple(before) || simple(after) || (before is Array)!=(after is Array))out.push([next,1,after]);
            else diff(before,after,next,out);
         }
         for(key in a)if(!(key in b))out.push([path.concat([key]),0]);
      }
   }
}

package {
   import flash.system.ApplicationDomain;
   import flash.utils.Dictionary;
   import flash.utils.ByteArray;
   /** Ordered reliable deltas keep unchanged native poses out of the wire. */
   public final class BDeltaReferenceChecks {
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
            var writable:Dictionary=new Dictionary(true);
            prior=branch(prior);writable[prior]=true;
            for each(var op:Array in packet.changes) {
               var target:Object=prior,path:Array=op[0];
               var grouped:Boolean=op[1]==2;
               if(path.length==0 && !grouped){prior=op[2];continue;}
               for(var i:int=0;i<path.length-(grouped?0:1);i++) {
                  var child:Object=target[path[i]];
                  // AMF can retain two references to one immutable branch.
                  // Clone at this parent/path, not once per old object identity:
                  // two entities may now acquire different animation states.
                  if(!writable[child]){child=branch(child);writable[child]=true;target[path[i]]=child;}
                  target=child;
               }
               if(grouped) {
                  var updates:Object=op[2];
                  if(updates!=null)for(var key:String in updates)target[key]=updates[key];
                  if(op[3]!=null)for each(key in op[3])delete target[key];
               }else if(op[1]==0)delete target[path[path.length-1]];else target[path[path.length-1]]=op[2];
            }
         }
         serial=packet.serial;return prior;
      }
      private static function branch(value:Object):Object {
         var result:Object=value is Array?[]:{};
         for(var key:String in value)result[key]=value[key];
         return result;
      }
      private static function simple(value:*):Boolean {return value==null || value is String || value is Number || value is Boolean || value is ByteArray;}
      private static function diff(a:*,b:*,path:Array,out:Array):void {
         if(a===b)return;
         // One encode owns this traversal stack. Only emitted operations keep
         // a path, so each operation receives its own immutable path copy.
         if(simple(a) || simple(b) || (a is Array)!=(b is Array)) {out.push([path.concat(),1,b]);return;}
         if(a is Array && a.length!=b.length) {out.push([path.concat(),1,b]);return;}
         // Native capture already compared these scalar values. Reuse only
         // its exact previous record; an unsent diagnostic capture falls back
         // to the ordinary full comparison below.
         var native:Object=ApplicationDomain.currentDomain.getDefinition("authority.NativeFields")["delta"](a,b);
         if(native!=null){out.push([path.concat(),2,native.updates,native.removed]);return;}
         var updates:Object=null,removed:Array=null;
         for(var key:String in b) {
            var before:*=a[key],after:*=b[key];
            // Most native storage and authored symbol properties did not
            // change. Do not allocate a path or recurse for every such scalar.
            if(before===after)continue;
            if(!(key in a) || simple(before) || simple(after) || (before is Array)!=(after is Array)) {
               if(updates==null)updates={};updates[key]=after;
            }else {
               path.push(key);diff(before,after,path,out);path.pop();
            }
         }
         for(key in a)if(!(key in b)){if(removed==null)removed=[];removed.push(key);}
         // A native unit changes several scalar fields together. Address its
         // record once, preserving every changed value and deletion, instead
         // of repeating a long entity path for each individual number.
         if(updates!=null || removed!=null)out.push([path.concat(),2,updates,removed]);
      }
   }
}

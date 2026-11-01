package authority {
   import flash.utils.Dictionary;
   import flash.utils.ByteArray;
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
            var writable:Dictionary=new Dictionary(true);
            prior=branch(prior);writable[prior]=true;
            // Reuse only the surviving path to the previous write target.
            // Writes can replace any child of that target, so no descendants
            // remain cached after the operation. Object sharing still clones
            // at the actual parent/path exactly as the original traversal did.
            var prefix:Array=[],parents:Array=[prior],depth:int=0;
            for each(var op:Array in packet.changes) {
               var path:Array=op[0];
               var grouped:Boolean=op[1]==2;
               // Sparse scene-unit/object fields: keep the immutable full base and
               // accumulate only this unit's changed keys. Avoids cloning the
               // complete (200+ key) native field record on every confirmation.
               if(grouped && isSceneFields(path)) {
                  var fieldLimit:int=path.length-1,fieldCommon:int=0;
                  while(fieldCommon<depth && fieldCommon<fieldLimit && prefix[fieldCommon]===path[fieldCommon])++fieldCommon;
                  var record:Object=parents[fieldCommon];
                  for(var fi:int=fieldCommon;fi<fieldLimit;fi++) {
                     var fieldChild:Object=record[path[fi]];
                     if(!writable[fieldChild]){fieldChild=branch(fieldChild);writable[fieldChild]=true;record[path[fi]]=fieldChild;}
                     record=fieldChild;prefix[fi]=path[fi];parents[fi+1]=record;
                  }
                  depth=fieldLimit;prefix.length=depth;parents.length=depth+1;
                  var priorDelta:Object=record["fieldsDelta"],sum:Object={};
                  if(priorDelta!=null)for(var pk:String in priorDelta)sum[pk]=priorDelta[pk];
                  var fieldUpdates:Object=op[2];if(fieldUpdates!=null)for(var fk:String in fieldUpdates)sum[fk]=fieldUpdates[fk];
                  var fieldRemoved:Array=op[3];
                  if(fieldRemoved!=null && fieldRemoved.length>0) {
                     // A deletion must also hide the original full value. Rebase
                     // on this uncommon path; ordinary updates stay sparse.
                     var effective:Object=branch(record.fields);
                     for(fk in sum)effective[fk]=sum[fk];
                     for each(var fr:String in fieldRemoved)delete effective[fr];
                     record.fields=effective;delete record.fieldsDelta;
                  }else record.fieldsDelta=sum;
                  continue;
               }
               if(path.length==0 && !grouped){prior=op[2];prefix.length=0;parents.length=1;parents[0]=prior;depth=0;continue;}
               var limit:int=path.length-(grouped?0:1),common:int=0;
               while(common<depth && common<limit && prefix[common]===path[common])++common;
               var target:Object=parents[common];
               for(var i:int=common;i<limit;i++) {
                  var child:Object=target[path[i]];
                  // AMF can retain two references to one immutable branch.
                  // Clone at this parent/path, not once per old object identity:
                  // two entities may now acquire different animation states.
                  if(!writable[child]){child=branch(child);writable[child]=true;target[path[i]]=child;}
                  target=child;prefix[i]=path[i];parents[i+1]=target;
               }
               depth=limit;prefix.length=depth;parents.length=depth+1;
               if(grouped) {
                  var updates:Object=op[2];
                  if(updates!=null)for(var key:String in updates)target[key]=updates[key];
                  if(op[3]!=null)for each(key in op[3])delete target[key];
               }else if(op[1]==0)delete target[path[path.length-1]];else target[path[path.length-1]]=op[2];
            }
         }
         serial=packet.serial;return prior;
      }
      private static function isSceneFields(path:Array):Boolean {
         return path.length>=3 && String(path[0])=="scene" && (String(path[1])=="units" || String(path[1])=="objects") && String(path[path.length-1])=="fields";
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
         var native:Object=NativeFields.delta(a,b);
         if(native!=null){out.push([path.concat(),2,native.updates,native.removed]);return;}
         var pose:Object=VisualPose.delta(a,b);
         if(pose!=null) {
            for each(var branchKey:String in ["children","vector","pixels"])if(a[branchKey]!==b[branchKey] && b.hasOwnProperty(branchKey)) {
               path.push(branchKey);diff(a[branchKey],b[branchKey],path,out);path.pop();
            }
            if(pose.updates!=null || pose.removed!=null)out.push([path.concat(),2,pose.updates,pose.removed]);
            return;
         }
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

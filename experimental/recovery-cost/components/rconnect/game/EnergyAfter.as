package rconnect.game { import flash.utils.Dictionary; public class EnergyAfter {
public var sources:Dictionary=new Dictionary();
public function captureDelta(w:Object):Array {
         var out:Array=[],list:Array=sources[w] as Array;
         if(list==null)return out;
         for each(var record:Object in list) {
            var wire:Object=record.wire,all:Array=wire.frames as Array;
            if(all==null || all.length==0)continue;
            var points:Array=FrameAfter.afterWithRevision(all,
               record.fastAt==null?Number.NEGATIVE_INFINITY:Number(record.fastAt),record.fastPoint,Number(record.fastAt));
            var ending:Boolean=int(wire.end)>0 && int(record.fastEnd)!=int(wire.end);
            if(points.length==0 && !ending)continue;
            // A terminal-only packet still supplies one known pose, allowing
            // a missed initial packet to recover without inventing artwork.
            if(points.length==0)points.push(all[all.length-1]);
            out.push({id:wire.id,cls:wire.cls,layer:wire.layer,blend:wire.blend,frames:points,end:wire.end,delta:true});
            record.fastPoint=points[points.length-1];record.fastAt=record.fastPoint.at;record.fastEnd=wire.end;
         }
         return out;
      }
}}

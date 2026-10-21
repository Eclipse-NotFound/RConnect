package rconnect.game { import flash.utils.Dictionary; public class EnergyBefore {
public var sources:Dictionary=new Dictionary();
public function captureDelta(w:Object):Array {
         var out:Array=[],list:Array=sources[w] as Array;
         if(list==null)return out;
         for each(var record:Object in list) {
            var wire:Object=record.wire,all:Array=wire.frames as Array;
            if(all==null || all.length==0)continue;
            var points:Array=FrameBefore.after(all,record.fastAt==null?Number.NEGATIVE_INFINITY:Number(record.fastAt));
            if(record.fastPoint!=null)for each(var revised:Object in all) {Counter.before++;
               if(Number(revised.at)==Number(record.fastAt) && !FrameBefore.samePoint(revised,record.fastPoint)) {points.unshift(revised);break;}}
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

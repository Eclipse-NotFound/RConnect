package rconnect.game { import flash.utils.Dictionary; import flash.utils.getTimer;
public class CaptureBefore {
public var hostShots:Dictionary=new Dictionary();public var weapons:Array=[];
public var energyImpacts:EnergyBefore=new EnergyBefore();public var frameTime:int=900;
private function weaponList(u:Object):Array{return weapons;}
private static function get(o:Object,k:String):*{return o[k];}
// Native captureFlight alone is a fixture: keep class/endpoint fields supplied by each case.
private function captureFlight(shot:Object):Object{if(shot.flight==null)return null;var out:Object={};for(var k:String in shot.flight)out[k]=shot.flight[k];return out;}
public function captureEffects(u:Object):Array {
         var out:Array=[];
         for each(var w:Object in weaponList(u)) {
            var r:Object=hostShots[w];if(r==null)continue;
            var events:Array=[];
            for each(var shot:Object in r.events) {
               var fresh:Boolean=shot.fastSent!==true;
               var points:Array=shot.recorded?FrameBefore.after(shot.frames as Array,
                  fresh||shot.fastAt==null?Number.NEGATIVE_INFINITY:Number(shot.fastAt)):null;
               // observeFinal may replace the last point at the SAME source
               // stamp. Preserve that correction, not just greater timestamps.
               if(!fresh && shot.recorded && shot.fastPoint!=null)
                  for each(var revised:Object in shot.frames) {Counter.before++;
                     if(Number(revised.at)==Number(shot.fastAt) && !FrameBefore.samePoint(revised,shot.fastPoint)) {points.unshift(revised);break;}}
               var ending:Boolean=int(shot.end)>0 && int(shot.fastEnd)!=int(shot.end);
               var stopping:Boolean=int(shot.stopped)>0 && int(shot.fastStop)!=int(shot.stopped);
               var exploding:Boolean=shot.explosion!=null && shot.fastExplosion!==shot.explosion;
               var impacting:Boolean=shot.impact!=null && shot.fastImpact!==shot.impact;
               if(!fresh && (points==null||points.length==0) && !ending && !stopping && !exploding && !impacting)continue;
               var flight:Object=captureFlight(shot);
               if(flight==null && shot.impact==null)continue;
               if(flight!=null && shot.impact!=null)flight.impact=shot.impact;
               if(flight!=null && shot.recorded) {
                  flight.frames=points;flight.delta=true;flight.end=shot.end;flight.explosion=shot.explosion;
                  if(points.length>0) {shot.fastPoint=points[points.length-1];shot.fastAt=Number(shot.fastPoint.at);}
               }
               shot.fastSent=true;shot.fastEnd=shot.end;shot.fastStop=shot.stopped;
               shot.fastExplosion=shot.explosion;shot.fastImpact=shot.impact;
               var packet:Object={seq:shot.seq,at:shot.at,flight:flight};
               if(flight==null)packet.impact=shot.impact;
               if(int(shot.end)>0 && int(shot.endSentAt)==0)shot.endSentAt=getTimer();
               events.push(packet);
            }
            var impacts:Array=energyImpacts.captureDelta(w);
            if(events.length>0 || impacts.length>0)out.push({id:String(get(w,"id")),variant:int(get(w,"variant")),
               stream:r.stream,sampleTime:frameTime,events:events,impacts:impacts});
         }
         return out.length?out:null;
      }
}}

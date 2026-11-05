package {
 /** Select only from current sight or remembered evidence, never hidden live coordinates. */
 public class TargetSelection {
  public static function choose(b:BrainState,players:Array,t:int):Object {
   var chosen:Object=null,best:Number=Number.POSITIVE_INFINITY,current:Object=null,currentScore:Number=Number.POSITIVE_INFINITY;
   for each(var p:Object in players) {
    var m:TargetMemory=b.targets[p.token];
    if(m==null || t-m.lastSeen>=b.profile.memory)continue;
    var dx:Number=m.knownX-b.sample.x,dy:Number=m.knownY-b.sample.y;
    var score:Number=(m.confirmed?0:1000000)+Math.sqrt(dx*dx+dy*dy);
    if(score<best){best=score;chosen=p;}
    if(p.token==b.targetId){current=p;currentScore=score;}
   }
   // Avoid alternating equally viable targets each frame; sight still wins over memory.
   if(current!=null && currentScore<=best+60)return current;
   return chosen;
  }
 }
}

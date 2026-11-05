package {
 /** One decision/execution path shared by the default and externally driven clocks. */
 public class TacticalStep {
  public static function run(b:BrainState,g:Object,loc:*,all:Array,squads:SquadMind,tick:int,fixture:Boolean=false):void {
      if(!b.profile.supported){b.action=TacticalMind.action("vanilla",b.profile.excluded,b.sample.x,b.sample.y);return;}
      if(ActionExecutor.yieldToNative(b)){squads.release(b.sample.fraction,b.key,tick);return;}
      if(fixture)ScenarioRunner.prepareBrain(b,tick);
      var context:Object=squads.context(b,all,tick);
      var target:Object={x:b.knownX,y:b.knownY,cx:b.knownX,cy:b.knownY-g.height/2,height:g.height,unit:g.unit,obs:g.obs,maxObs:g.maxObs};
      var dx:Number=b.sample.x-target.x,dy:Number=b.sample.y-target.y,distance:Number=Math.sqrt(dx*dx+dy*dy);
      var aimed:Boolean=false;
      if(b.confirmed && !isNaN(g.rot)){var angle:Number=Math.atan2(b.sample.cy-g.wy,b.sample.x-g.wx)-g.rot;while(angle>Math.PI)angle-=2*Math.PI;while(angle< -Math.PI)angle+=2*Math.PI;aimed=Math.abs(angle)<0.15;}
      // 候选缓存跨决策帧保留，避免扫描节拍与思考节拍错开后永远看不到掩体。
      if(Math.abs(b.sample.x-b.coverScanX)>40 || Math.abs(target.x-b.coverTargetX)>60 || tick-b.coverScanAt>Config.COVER_CACHE_AGE)b.coverCandidates=[];
      if(tick-b.lastSeen<b.profile.memory && tick%Config.COVER_SCAN_EVERY==b.key%Config.COVER_SCAN_EVERY && tick>=b.stuckUntil) {
       b.coverCandidates=GameBridge.covers(b,target,loc,context.side);b.coverScanAt=tick;b.coverScanX=b.sample.x;b.coverTargetX=target.x;
      }
      var coverList:Array=b.coverCandidates;
      var rx:Number=b.sample.x+(dx>=0?150:-150);
      var retreat:Object=GameBridge.walkable(loc,b.sample,rx,b.sample.y)?{x:rx,y:b.sample.y}:null;
      var env:Object={distance:distance,aimed:aimed,covers:coverList,coverSafe:b.cover==null || !GameBridge.clear(loc,b.cover.x,b.cover.y-b.sample.height/2,target.cx,target.cy),retreat:retreat,squad:context,slotOwned:squads.owns(b.sample.fraction,b.key),threat:tick%5==b.key%5?GameBridge.threat(b.sample,loc):null};
      if(fixture)ScenarioRunner.prepareDecision(b,env,tick);
      var before:String=b.action.kind,a:Object=TacticalMind.decide(b,env,tick);
      if(a.kind=="suppress" && before!="suppress" && !squads.claim(b.sample.fraction,b.key,tick,b.until-tick))a=TacticalMind.action("hold","同伴已占用压制位置",target.x,target.y);
      if(before=="suppress" && a.kind!="suppress")squads.release(b.sample.fraction,b.key,tick);
      b.action=a;
      if(before!=a.kind)TdfcLog.line("decision","#"+b.key+" "+b.profile.family+" T"+b.profile.tier+" "+a.kind+" "+a.reason);
      ActionExecutor.apply(b,b.confirmed?g:target,loc,tick);
  }
 }
}

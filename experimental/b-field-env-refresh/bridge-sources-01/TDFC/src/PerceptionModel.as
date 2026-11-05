package {
 /** 信息年龄和持续确认由真实战术时间驱动；报告不是实时目标引用。 */
 public class PerceptionModel {
  private var pending:Array=[];
  public function PerceptionModel() {}
  public function reset():void { pending=[]; }
  public function observe(b:BrainState,g:Object,sense:Object,t:int,m:TargetMemory=null):void {
   if(m==null)m=b;
   m.sensing=sense;
   m.observed=sense.visible;
   m.heard=sense.heard;
   if(sense.visible) m.confirm++; else m.confirm=0;
   var recognized:Boolean=t-m.lastVisual<b.profile.memory;
   m.confirmed=sense.visible && (recognized || m.confirm>=b.profile.confirm && g.obs>=g.maxObs);
   if(m.confirmed) {
    m.knownX=g.x; m.knownY=g.y; m.lastSeen=t; m.lastVisual=t; m.evidence="目击";
   } else if(sense.heard && t-m.lastHeard>=60 && t-m.lastSeen>30) {
    // 可复现的有限位置误差；听觉不会获得精确追踪能力。
    var seed:int=(b.key*37+t*13)%181;
    m.knownX=g.x+seed-90; m.knownY=g.y;
    m.lastSeen=t; m.lastHeard=t; m.evidence="听觉区域";
   }
   if(b.previous && b.sample.hp<b.previous.hp) b.lastHit=t;
  }
  public function schedule(all:Array,t:int,target:String=null):void {
   for each(var b:BrainState in all) {
    var m:TargetMemory=target==null?b:b.targets[target];if(m==null)continue;
    var hurt:Boolean=b.lastHit==t && t-m.lastSeen<90 && m.evidence!="听觉区域";
    if(!b.profile.supported || (!m.confirmed && !hurt) || t-m.lastReport<Config.REPORT_COOLDOWN) continue;
    m.lastReport=t;
    for each(var r:BrainState in all) {
     if(r===b || !r.profile.supported || r.sample.fraction!=b.sample.fraction) continue;
     var dx:Number=r.sample.x-b.sample.x,dy:Number=r.sample.y-b.sample.y;
     var d:Number=Math.sqrt(dx*dx+dy*dy);
     if(d>Config.REPORT_RANGE) continue;
     pending.push({to:r,source:b,target:target,at:t+b.profile.reportDelay+Math.max(1,int(d/Config.REPORT_SPEED)),seen:m.lastSeen,x:m.knownX,y:m.knownY,fraction:b.sample.fraction,hurt:hurt});
    }
   }
  }
  public function deliver(all:Array,t:int):void {
   for(var i:int=pending.length-1;i>=0;i--) {
    var p:Object=pending[i]; if(p.at>t) continue; pending.splice(i,1);
    var b:BrainState=p.to;
    if(all.indexOf(b)<0 || all.indexOf(p.source)<0 || b.sample.fraction!=p.fraction || p.source.sample.fraction!=p.fraction) continue;
    var m:TargetMemory=p.target==null?b:b.targets[p.target];
    if(m==null || m.lastSeen>=p.seen || t-p.seen>b.profile.memory) continue;
    m.knownX=p.x; m.knownY=p.y; m.lastSeen=p.seen; m.evidence=(p.hurt?"同伴受击报告 #":"同伴报告 #")+p.source.key;
   }
  }
 }
}

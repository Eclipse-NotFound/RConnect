package {
 import flash.utils.Dictionary;
 /** A room's tactical clock and decisions. Empty rooms are not advanced. */
 public class AuthorityRoom {
  public var tick:int=0,lastSimulation:Number=-1,all:Array=[];
  private var loc:*,states:Dictionary=new Dictionary(true),nextKey:int=1;
  private var perception:PerceptionModel=new PerceptionModel(),squads:SquadMind=new SquadMind();
  public function AuthorityRoom(room:*){loc=room;}
  public function dispose():void {
   for each(var b:BrainState in all)ActionExecutor.restore(b);
   states=new Dictionary(true);all=[];perception.reset();squads.reset();
  }
  public function step(players:Array,validTokens:Object,withPlayer:Function,simulationTick:Number):Boolean {
   if(simulationTick==lastSimulation)return false;
   if(simulationTick<lastSimulation)throw new Error("TDFC room simulation tick regressed");
   lastSimulation=simulationTick;if(players.length==0)return false;
   ++tick;
   var active:Object={};for each(var entry:Object in players)active[entry.token]=true;
   var units:Array=GameBridge.get(loc,"units",[]) as Array,fresh:Array=[],present:Dictionary=new Dictionary(true);
   for each(var u:* in units) {
    var isPlayer:Boolean=false;for each(var p:Object in players)if(u===p.unit)isPlayer=true;
    if(isPlayer)continue;
    var s:Object=GameBridge.snapshot(u),hostile:Boolean=false;
    for each(p in players)if(GameBridge.hostile(s,p.sample))hostile=true;
    if(!hostile)continue;
    var b:BrainState=states[u];if(!b){b=new BrainState(nextKey++,u,EnemyProfile.make(s));states[u]=b;}
    b.previous=b.sample;b.sample=s;fresh.push(b);present[u]=true;ActionExecutor.assess(b,tick);
    for(var token:String in b.targets) {
     if(!validTokens[token])delete b.targets[token];
     else {var absent:TargetMemory=b.targets[token];absent.observed=absent.confirmed=absent.heard=false;if(!active[token])absent.confirm=0;}
    }
    for each(p in players) {
     var m:TargetMemory=b.targets[p.token];if(m==null)b.targets[p.token]=m=new TargetMemory();
     if(b.profile.supported)observe(b,p,m,withPlayer);
    }
   }
   for each(var old:BrainState in all)if(!present[old.unit]){ActionExecutor.restore(old);delete states[old.unit];}
   all=fresh;perception.deliver(all,tick);
   for each(p in players)perception.schedule(all,tick,p.token);
   squads.frame(all,tick);
   for each(b in all) {
    var selected:Object=TargetSelection.choose(b,players,tick);
    if(selected==null) {
     if(b.targetId!="")resetTarget(b,"");
     b.action=TacticalMind.action("idle","没有已识别的在场目标",b.sample.x,b.sample.y);
     continue;
    }
    if(selected.token!=b.targetId)resetTarget(b,selected.token,selected.unit);
    b.copyFrom(b.targets[selected.token]);
    execute(b,selected,withPlayer);
   }
   return true;
  }
  private function observe(b:BrainState,p:Object,m:TargetMemory,withPlayer:Function):void {
   withPlayer(p.key,function():void {perception.observe(b,p.sample,GameBridge.sense(b,p.sample,loc),tick,m);});
  }
  private function execute(b:BrainState,p:Object,withPlayer:Function):void {
   withPlayer(p.key,function():void {TacticalStep.run(b,p.sample,loc,all,squads,tick);});
  }
  private function resetTarget(b:BrainState,token:String,unit:*=null):void {
   squads.release(b.sample.fraction,b.key,tick);ActionExecutor.restore(b);
   if(b.targetUnit!=null && GameBridge.get(b.unit,"celUnit")===b.targetUnit)b.unit.setCel(null,b.knownX,b.knownY);
   b.targetUnit=unit;
   b.targetId=token;b.cover=null;b.coverCandidates=[];b.coverScanAt=-100000;b.coverTargetX=NaN;
   b.order=null;b.until=0;b.decisionAt=-100000;b.peek=false;b.peekAt=0;
   b.action=TacticalMind.action("idle","目标身份改变",b.sample.x,b.sample.y);
   b.copyFrom(new TargetMemory());
  }
 }
}

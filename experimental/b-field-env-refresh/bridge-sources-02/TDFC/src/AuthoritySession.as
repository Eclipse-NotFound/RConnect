package {
 import flash.utils.Dictionary;
 /** Opt-in synchronous scheduler. The owner supplies native player scopes. */
 public class AuthoritySession {
  private var owner:Object,closed:Boolean=false,stepping:Boolean=false;
  private var rooms:Dictionary=new Dictionary(true),bindings:Object={};
  public var steps:uint=0;
  public function AuthoritySession(request:Object) {
   if(request==null || request.version!==1 || !(request.session is String) || request.session.length==0 ||
    (request.role!="host" && request.role!="join") || !(request.withPlayer is Function))throw new Error("Invalid TDFC authority contract");
   owner={session:request.session,role:request.role,withPlayer:request.withPlayer};
  }
  public function api(onDetach:Function):Object {
   return {version:1,stepRoom:stepRoom,releaseRoom:releaseRoom,inspect:inspect,
    detach:function():void {if(!closed){dispose();onDetach();}}};
  }
  public function stepRoom(room:*,players:Array,simulationTick:Number):Boolean {
   if(closed || owner.role!="host" || stepping)throw new Error("TDFC authority step is not available");
   if(room==null || players==null || players.length>2 || !isFinite(simulationTick) || simulationTick<0 || simulationTick!=Math.floor(simulationTick))throw new Error("Invalid TDFC room step");
   var state:AuthorityRoom=rooms[room];
   if(state && simulationTick==state.lastSimulation)return false;
   if(state && simulationTick<state.lastSimulation)throw new Error("TDFC room simulation tick regressed");
   var keys:Object={},prepared:Array=[],p:Object;
   // Validate the entire roster before acquiring any owned fields.
   for each(p in players) {
    if(p==null || !(p.key is String) || !/^[a-zA-Z0-9_-]{1,64}$/.test(p.key) || keys["$"+p.key] ||
     !(p.epoch is Number) || p.epoch<1 || p.epoch!=int(p.epoch) || p.unit==null || GameBridge.get(p.unit,"loc")!==room)throw new Error("Invalid TDFC player identity");
    keys["$"+p.key]=true;
    var existing:Object=bindings["$"+p.key];
    if(existing && (p.epoch<existing.epoch || p.epoch==existing.epoch && p.unit!==existing.unit))throw new Error("TDFC player incarnation mismatch");
   }
   stepping=true;var advanced:Boolean=false;
   try {
    for each(p in players) {
     var slot:String="$"+p.key;existing=bindings[slot];
     if(existing==null || existing.unit!==p.unit) {
      if(existing)existing.noise.reset();
      bindings[slot]=existing={unit:p.unit,epoch:p.epoch,token:slot+":"+p.epoch,noise:new NoiseState()};
     }
     var g:Object=owner.withPlayer(p.key,samplePlayer(p.unit,existing.noise));
     if(g.alive && !g.disabled)prepared.push({key:p.key,unit:p.unit,token:existing.token,sample:g});
    }
    var valid:Object={};for each(existing in bindings)valid[existing.token]=true;
    if(state==null)rooms[room]=state=new AuthorityRoom(room);
    advanced=state.step(prepared,valid,owner.withPlayer,simulationTick);
    if(advanced)++steps;
   }finally{stepping=false;}
   return advanced;
  }
  private function samplePlayer(unit:*,noise:NoiseState):Function {
   return function():Object {noise.update(unit);return GameBridge.snapshot(unit);};
  }
  public function releaseRoom(room:*):void {
   if(closed || stepping)throw new Error("TDFC room release during a step or after detach");
   var state:AuthorityRoom=rooms[room];if(state){state.dispose();delete rooms[room];}
  }
  public function inspect(room:*):Object {
   var state:AuthorityRoom=rooms[room],brains:Array=[];
   if(state)for each(var b:BrainState in state.all) {
    var memories:Object={};for(var token:String in b.targets) {
     var m:TargetMemory=b.targets[token];memories[token]={seen:m.lastSeen,visual:m.lastVisual,confirmed:m.confirmed,observed:m.observed,sensing:m.sensing,knownX:m.knownX,knownY:m.knownY};
    }
    brains.push({id:b.sample.id,key:b.key,target:b.targetId,action:b.action.kind,faults:b.faults,rejected:b.rejected,memories:memories});
   }
   return {role:owner.role,steps:steps,tick:state?state.tick:0,units:state?state.all.length:0,brains:brains};
  }
  public function view(room:*):Array {var state:AuthorityRoom=rooms[room];return state?state.all:[];}
  public function clock(room:*):int {var state:AuthorityRoom=rooms[room];return state?state.tick:0;}
  public function dispose():void {
   if(stepping)throw new Error("TDFC detach during a step");
   for each(var state:AuthorityRoom in rooms)state.dispose();
   for each(var binding:Object in bindings)binding.noise.reset();
   rooms=new Dictionary(true);bindings={};closed=true;owner.withPlayer=null;
  }
 }
}

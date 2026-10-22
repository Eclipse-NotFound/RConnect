package {
 import flash.desktop.NativeApplication;
 import flash.display.Sprite;
 import flash.events.Event;
 import flash.filesystem.File;
 import flash.filesystem.FileMode;
 import flash.filesystem.FileStream;

 /** Actual bridge class, external readers only; no Sandevistan simulation. */
 public final class SandyTravelHoldChecks extends Sprite {
  private var assertions:Array=[],failed:int=0;
  private var bridge:SandyTravelHoldBridge,world:HoldWorld,game:Object,live:Object,state:Object;
  private var worldThrows:Boolean=false,stateThrows:Boolean=false;
  private var worldReads:int=0,stateReads:int=0;
  private var owner:Object,other:Object;
  public function SandyTravelHoldChecks(){addEventListener(Event.ADDED_TO_STAGE,run);}
  private function readWorld():Object{worldReads++;if(worldThrows)throw new Error("fixture world read");return live;}
  private function readState():Object{stateReads++;if(stateThrows)throw new Error("fixture state read");return state;}
  private function reset():void {
   game={identity:"game"};world=new HoldWorld(game);live=world;
   state={phase:"idle",sandyLeft:23,cooldownLeft:47,replayIndex:11,enemyEnabled:true,debugTest:false};
   worldThrows=stateThrows=false;worldReads=stateReads=0;owner={id:"owner"};other={id:"owner"};
   bridge=new SandyTravelHoldBridge(readWorld,readState);
  }
  private function check(value:Boolean,label:String):void{assertions.push({label:label,passed:value});if(!value)failed++;}
  private function acquire():Boolean{return bridge.acquire(owner,world,game,"travel-1");}
  private function run(e:Event):void {
   removeEventListener(Event.ADDED_TO_STAGE,run);
   try {
    reset();
    check(bridge.name=="SandevistanTravelHoldV1"&&bridge.version==1&&bridge.contract=="sandy-travel-hold/1","01 exact discovery contract");
    check(!bridge.visible&&!bridge.mouseEnabled&&!bridge.mouseChildren,"02 carrier is noninteractive and hidden");
    check(!bridge.isHeld()&&worldReads==0&&stateReads==0,"03 no-owner isHeld does not call readers");
    var q:Object=bridge.query(world,game);
    check(q!=null&&!q.held&&q.phase=="idle"&&q.version==1&&q.contract==bridge.contract,"04 idle query identifies contract and phase");
    check(q.sandyLeft==23&&q.cooldownLeft==47&&q.replayIndex==11&&q.enemyEnabled===true&&q.debugTest===false,"05 query copies all published scalar values");
    var q2:Object=bridge.query(world,game);q.sandyLeft=-20;
    check(q!==q2&&q2.sandyLeft==23&&state.sandyLeft==23,"06 query returns a fresh scalar record");
    check(bridge.query(null,game)==null&&bridge.query(world,null)==null,"07 null query identities reject");
    check(bridge.query(new HoldWorld(game),game)==null&&bridge.query(world,{identity:"game"})==null,"08 equal-looking identity replacements reject");
    check(world.gameWrites==0&&world.onPause==17&&world.ggControl==19&&state.cooldownLeft==47,"09 queries do not write gameplay or state fields");

    reset();
    check(!bridge.acquire(null,world,game,"travel-1"),"10 null owner rejects");
    check(!bridge.acquire(owner,null,game,"travel-1"),"11 null World rejects");
    check(!bridge.acquire(owner,world,null,"travel-1"),"12 null Game rejects");
    check(!bridge.acquire(owner,world,game,null),"13 null id rejects");
    check(!bridge.acquire(owner,world,game,""),"14 empty id rejects");
    check(worldReads==0&&stateReads==0&&!bridge.isHeld(),"15 invalid argument rejection has no reader side effect");
    live=new HoldWorld(game);
    check(!acquire()&&stateReads==0,"16 wrong live World rejects before state read");
    live=world;world.replace({identity:"other-game"});
    check(!acquire()&&stateReads==0,"17 wrong current Game rejects before state read");
    reset();worldThrows=true;
    check(!acquire()&&!bridge.isHeld(),"18 failing world reader cannot acquire a new lease");
    reset();world.gameThrows=true;
    check(!acquire()&&!bridge.isHeld(),"19 failing Game getter cannot acquire a new lease");
    reset();stateThrows=true;
    check(!acquire()&&!bridge.isHeld(),"20 failing state reader cannot acquire a new lease");
    reset();state=null;
    check(!acquire()&&!bridge.isHeld(),"21 null state cannot acquire a new lease");
    reset();state.phase="active";
    check(!acquire()&&!bridge.isHeld(),"22 active player recording refuses new travel");
    state.phase="replay";
    check(!acquire()&&!bridge.isHeld(),"23 active replay refuses new travel");
    state.phase="unknown";
    check(!acquire()&&!bridge.isHeld(),"24 unknown phase refuses new travel");
    state.phase=null;
    check(!acquire()&&!bridge.isHeld(),"25 null phase refuses new travel");
    reset();state.debugTest=true;
    check(!acquire()&&!bridge.isHeld(),"26 true debug driver refuses travel");
    reset();state.enemyEnabled=false;
    check(acquire()&&bridge.isHeld(),"27 idle cooldown and disabled enemy feature do not prohibit hold");
    check(world.gameWrites==0&&world.onPause==17&&world.ggControl==19&&state.sandyLeft==23&&state.cooldownLeft==47&&state.replayIndex==11,"28 acquisition itself mutates no gameplay fields");

    reset();
    check(acquire(),"29 exact owner acquires an idle identity");
    var n:int=stateReads;
    check(acquire()&&stateReads==n,"30 exact owner id identity reentry is idempotent without rereading phase");
    check(!bridge.acquire(other,world,game,"travel-1"),"31 structurally equal competing owner cannot steal lease");
    check(!bridge.acquire(owner,world,game,"travel-2"),"32 same owner cannot replace an outstanding id");
    check(!bridge.acquire(owner,world,{identity:"game"},"travel-1"),"33 same owner id cannot substitute Game identity");
    check(bridge.isHeld()&&stateReads==n,"34 rejected contenders leave original lease intact");
    state.phase="active";state.debugTest=true;
    check(acquire()&&stateReads==n,"35 existing exact lease reentry does not re-run new-acquisition eligibility");
    q=bridge.query(world,game);
    check(q!=null&&q.held&&q.phase=="active"&&q.debugTest===true,"36 query observes reader phase without running or editing Sandy");
    stateThrows=true;n=stateReads;
    check(bridge.isHeld()&&stateReads==n,"37 held fast check does not call state reader");
    check(bridge.query(world,game)==null&&bridge.isHeld(),"38 state read failure makes query unknown without dropping valid lease");
    check(!bridge.release(other,"travel-1")&&bridge.isHeld(),"39 wrong owner cannot release");
    check(!bridge.release(owner,"travel-2")&&bridge.isHeld(),"40 wrong id cannot release");
    check(!bridge.release(null,"travel-1")&&!bridge.release(owner,null)&&bridge.isHeld(),"41 null release arguments cannot release");
    worldThrows=true;world.gameThrows=true;n=worldReads;var sn:int=stateReads;
    check(bridge.release(owner,"travel-1")&&worldReads==n&&stateReads==sn,"42 exact release works with throwing readers and performs no external reads");
    check(!bridge.isHeld()&&worldReads==n&&!bridge.release(owner,"travel-1"),"43 release and repeated release leave a cleared fast path");
    worldThrows=false;world.gameThrows=false;stateThrows=false;state.phase="idle";state.debugTest=false;
    check(bridge.acquire(other,world,game,"travel-2"),"44 different owner can acquire after precise release");
    check(!bridge.release(owner,"travel-1")&&bridge.isHeld(),"45 stale release cannot drop the successor lease");
    check(bridge.release(other,"travel-2")&&!bridge.isHeld(),"46 successor releases only its own lease");

    reset();acquire();live=new HoldWorld(game);
    check(!bridge.isHeld(),"47 actual World identity replacement invalidates old lease");
    check(!bridge.release(owner,"travel-1"),"48 invalidated lease is not resurrected by release");
    check(bridge.acquire(other,live,game,"travel-2")&&bridge.isHeld(),"49 new World can obtain a fresh lease");
    reset();acquire();var oldGame:Object=game;game={identity:"replacement"};world.replace(game);
    check(!bridge.isHeld(),"50 Game replacement on same World invalidates old lease");
    check(bridge.query(world,oldGame)==null&&bridge.query(world,game)!=null,"51 old Game query fails while new identity remains readable");
    check(bridge.acquire(other,world,game,"travel-2")&&bridge.isHeld(),"52 new Game can obtain a fresh lease");
    reset();acquire();live=null;
    check(!bridge.isHeld()&&!bridge.release(owner,"travel-1"),"53 missing live World clears former lease");
    reset();acquire();world.replace(null);
    check(!bridge.isHeld(),"54 missing current Game clears former lease");
    reset();acquire();
    check(bridge.query(new HoldWorld(game),game)==null&&bridge.isHeld(),"55 wrong query argument does not clear an otherwise valid live lease");
    world.replace({identity:"replacement"});
    check(bridge.query(null,null)==null&&!bridge.isHeld(),"56 query services live identity invalidation even when caller arguments reject");
    reset();acquire();worldThrows=true;
    check(bridge.isHeld(),"57 held world-reader exception fails closed");
    check(bridge.query(world,game)==null,"58 held world-reader exception never produces an approval query");
    check(!acquire()&&bridge.isHeld(),"59 failed re-acquire leaves exact prior hold intact");
    check(bridge.release(owner,"travel-1")&&!bridge.isHeld(),"60 exact owner cancels after world-reader exception");
    reset();acquire();world.gameThrows=true;
    check(bridge.isHeld()&&bridge.query(world,game)==null,"61 held Game-getter exception fails closed and query is unknown");
    check(!bridge.release(other,"travel-1")&&bridge.isHeld(),"62 exception does not grant a competing release");
    check(bridge.release(owner,"travel-1")&&!bridge.isHeld(),"63 exact owner cancels after Game-getter exception");
    reset();acquire();worldThrows=true;bridge.isHeld();worldThrows=false;
    check(bridge.isHeld()&&bridge.query(world,game).held===true,"64 transient read failure can recover the same exact lease");
    worldThrows=true;bridge.isHeld();live=new HoldWorld(game);worldThrows=false;
    check(!bridge.isHeld(),"65 recovery observes identity replacement instead of retaining a stale hold");
    reset();acquire();state=null;
    check(bridge.query(world,game)==null&&bridge.isHeld(),"66 null state query remains unknown while identity hold stays valid");
    check(bridge.release(owner,"travel-1"),"67 null state cannot prevent precise cancellation");

    reset();var before:String=JSON.stringify(state);acquire();bridge.query(world,game);bridge.isHeld();bridge.release(owner,"travel-1");
    check(JSON.stringify(state)==before&&world.gameWrites==0&&world.onPause==17&&world.ggControl==19,"68 full lease lifecycle writes no exposed gameplay state");
    reset();var second:SandyTravelHoldBridge=new SandyTravelHoldBridge(readWorld,readState);acquire();
    check(!second.release(owner,"travel-1")&&bridge.isHeld(),"69 same-named new carrier cannot release an old carrier ticket");
    check(second.acquire(other,world,game,"travel-1")&&bridge.isHeld()&&second.isHeld(),"70 separate carriers are independent; discovery must retain actual acquired object");
    second.release(other,"travel-1");bridge.release(owner,"travel-1");
    check(!bridge.isHeld()&&!second.isHeld(),"71 both carrier owners release their own leases");
    reset();var missing:SandyTravelHoldBridge=new SandyTravelHoldBridge(null,null);
    check(!missing.isHeld()&&missing.query(world,game)==null&&!missing.acquire(owner,world,game,"travel-1"),"72 absent injected readers fail safely for new acquisition");
    check(!missing.release(owner,"travel-1"),"73 absent readers do not fabricate a releasable owner");
    reset();acquire();bridge.release(owner,"travel-1");state.phase="replay";
    check(!acquire()&&!bridge.isHeld(),"74 released id has no cached eligibility bypass into replay");
    state.phase="idle";state.debugTest=true;
    check(!acquire()&&!bridge.isHeld(),"75 released id has no cached eligibility bypass into debug mode");
    state.debugTest=false;
    check(acquire()&&bridge.release(owner,"travel-1"),"76 same id may be acquired freshly after state becomes eligible");
   } catch(error:*) {
    assertions.push({label:"unhandled external fixture exception",passed:false,error:String(error),stack:error is Error?Error(error).getStackTrace():null});failed++;
   }
   var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
   f.writeUTFBytes(JSON.stringify({passed:failed==0,failed:failed,assertions:assertions,native_game_test:false,performance_qualified:false}));f.close();
   NativeApplication.nativeApplication.exit(failed==0?0:1);
  }
 }
}

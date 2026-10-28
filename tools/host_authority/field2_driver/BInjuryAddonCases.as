package {
 import flash.system.ApplicationDomain;
 import flash.utils.getTimer;
 /** Only the isolated field driver creates this fixture. Default PI config is
  * retained. It calls real UnitPlayer.damage under each native player scope. */
 public final class BInjuryAddonCases {
  private var mod:Object,root:Object,domain:ApplicationDomain,api:Object,side:String;
  private var phase:int=0,at:int=0,seen:int=-1,start:Array,original:Object,ready:Boolean=false;
  private var injuryClass:Object,front:Object;
  public function BInjuryAddonCases(m:Object,r:Object,d:ApplicationDomain,c:Object,role:String,a:Object) {
   mod=m;root=r;domain=d;api=a;side=role;at=getTimer();
   injuryClass=domain.getDefinition("PermanentInjuryMod");
   var carrier:Object=root.getChildByName("PermanentInjuryCarrier");
   if(carrier==null||carrier.authorityAPI.version!==1)throw new Error("PI fixture requires independent authority bridge");
   front=carrier.api;
  }
  public function input():void {
   var w:Object=mod.access.world;
   if(w.ctr!=null)for each(var key:String in ["keyLeft","keyRight","keyJump","keyAttack","keySit","keyRun","keyAction","keyTele"])w.ctr[key]=false;
  }
  private function state(a:Object):Object {return a.unit.pers.piPermanent;}
  private function stable(s:Object):String {
   return JSON.stringify({P:s.P,z:s.z,seed:s.seed,sequence:s.sequence,K:s.K,level:s.level});
  }
  private function permanent(s:Object):Number {var n:Number=0;for each(var p:String in ["head","torso","legs","blood","mana"])n+=Number(s.P[p]);return n;}
  private function copy(v:Object):Object {return JSON.parse(JSON.stringify(v));}
  private function capture(a:Object):Object {var s:Object=state(a);return {stable:stable(s),time:Number(s.time),steps:uint(a.steps),sum:permanent(s)};}
  private function saveRoundtrip(p:Object,label:String):void {
   var saved:Object=p.save(),value:Object=saved.piPermanent;
   api.check(value!=null&&stable(value)===stable(p.piPermanent),"PI native save includes own confirmed injury "+label);
   var text:String=JSON.stringify(saved),Pers:Class=domain.getDefinition("fe.unit.Pers") as Class;
   // Constructor roundtrip is distinct from a cold World.loadGame test.
   var restored:Object=new Pers(JSON.parse(text));
   api.check(stable(restored.piPermanent)===stable(value)&&restored.piPermanent.time===value.time,
    "PI JSON and native Pers constructor preserve injury and clock "+label);
   api.write("injury-pers-save-"+label+".json",{pers:saved,nativeConstructorRestored:true,coldWorldLoadTested:false});
  }
  private function damageActor(id:int):Object {
   var actors:Array=mod.host.actors,a:Object=actors[id],other:Object=actors[1-id],before:Object=capture(a),untouched:String=stable(state(other));
   var Unit:Object=domain.getDefinition("fe.unit.Unit"),g:Object=a.unit,p:Object=g.pers,loc:Object=g.loc,w:Object=mod.access.world;
   var flags:Object={base:loc.base,train:loc.train,godMode:w.godMode,invulner:g.invulner,armor:g.currentArmor,shield:g.shithp};
   var total:Number=0,hits:int=0;
   api.check(!a.context.alicorn,"PI damage fixture uses a non-alicorn actor "+id);
   try {
    loc.base=false;loc.train=false;w.godMode=false;g.invulner=false;g.currentArmor=null;g.shithp=0;
    mod.access.scope.run(a.context,function():void {
     // Ordinary wounds place the real damage path below PI's default risk
     // threshold. No permanent injury, probability or random seed is injected.
     for(var i:int=0;i<64&&permanent(state(a))>=before.sum;i++) {
      p.healAll();g.hp=g.maxhp;g.cut=g.poison=0;
      p.headHP=p.torsHP=p.legsHP=p.bloodHP=p.inMaxHP*.60;
      p.headSt=p.torsSt=p.legsSt=p.bloodSt=1;
      var amount:Number=g.damage(Math.min(50,g.maxhp*.35),Unit.D_BUL,null,false);
      p.piEvent("flush");total+=amount;++hits;
      if(g.sost!=1)throw new Error("PI damage fixture unexpectedly killed actor "+id);
     }
     p.healAll();g.hp=g.maxhp;g.cut=g.poison=0;
    });
   } finally {
    loc.base=flags.base;loc.train=flags.train;w.godMode=flags.godMode;g.invulner=flags.invulner;g.currentArmor=flags.armor;g.shithp=flags.shield;
   }
   api.check(total>0&&state(a).sequence>JSON.parse(before.stable).sequence,"PI real native direct hits create actor events "+id,{hits:hits,damage:total});
   api.check(permanent(state(a))<before.sum,"PI real native damage produces permanent injury with factory rules "+id,{hits:hits,before:before.sum,after:permanent(state(a))});
   api.check(stable(state(other))===untouched,"PI damage does not change the other player "+id);
   api.check(w.gg===actors[0].unit&&w.pers===actors[0].unit.pers&&mod.access.scope.depth==0,"PI damage restores native context "+id);
   mod.access.scope.run(a.context,function():void {saveRoundtrip(p,"host-actor"+id);});
   return {id:id,hits:hits,damage:total,stable:stable(state(a))};
  }
  private function signal(stage:int):void {
   api.write("injury-control.json",{stage:stage,presentation:mod.host.presentations+1,
    remote:stable(state(mod.host.actors[1])),local:stable(state(mod.host.actors[0]))});
   at=getTimer();
  }
  private function joining():void {
   var c:Object=api.read("injury-control.json");if(c==null)return;
   if(c.done){api.write("injury-join-done.json",{done:true});api.finish();return;}
   var replica:Object=mod.replica,f:Object=replica==null?null:replica.clock.current;
   if(f==null||c.stage==seen||f.presentation<c.presentation||f.character==null||f.character.injury==null)return;
   var value:Object=f.character.injury,w:Object=mod.access.world;
   if(stable(value.state)!==c.remote)return;
   seen=c.stage;
   api.check(stable(w.pers.piPermanent)===c.remote,"PI join matches its presented confirmed state "+seen);
   api.check(stable(w.pers.piPermanent)!==c.local,"PI join never adopts host injury state "+seen);
   var before:String=JSON.stringify(w.pers.piPermanent);
   // Exercise the actual client authority boundary, not a fake controller.
   front.dispatch(w.pers,"tick",10);
   front.dispatch(w.pers,"begin",{dot:false,shot:0});
   front.dispatch(w.pers,"part",{part:"head",D:1000,H:0,M:200});
   front.dispatch(w.pers,"end");front.dispatch(w.pers,"flush");
   api.check(JSON.stringify(w.pers.piPermanent)===before,"PI join cannot advance time or draw/settle a second injury "+seen);
   saveRoundtrip(w.pers,"join-stage"+seen);
   api.write("injury-ack-"+seen+".json",{stage:seen,remote:c.remote});
  }
  public function step():void {
   if(getTimer()-at>65000)throw new Error("PI live fixture timed out phase "+phase+" role "+side);
   if(side=="join"){joining();return;}
   var s:Object=mod.host,w:Object=mod.access.world;
   if(phase==0) {
    if(!s.active||w.t_exit>0||w.t_die>0||!s.actors[0].unit.ggControl||!s.actors[1].unit.ggControl)return;
    api.check(state(s.actors[0])!=null&&state(s.actors[1])!=null&&state(s.actors[0])!==state(s.actors[1]),"PI both actors have distinct native injury state");
    original={config:JSON.stringify(injuryClass.config)};
    api.check(injuryClass.config.enabled===true&&injuryClass.config.magicEnabled===false&&injuryClass.config.p_0===.25,"PI factory rules retained in B test");
    start=[capture(s.actors[0]),capture(s.actors[1])];phase=1;at=getTimer();return;
   }
   if(phase==1) {
    if(s.actors[0].steps-start[0].steps<30||s.actors[1].steps-start[1].steps<30)return;
    for(var id:int=0;id<2;id++) {
     var now:Object=capture(s.actors[id]),steps:Number=now.steps-start[id].steps,seconds:Number=now.time-start[id].time;
     api.check(Math.abs(seconds-steps/30)<1e-5,"PI actor clock advances exactly once per real player step "+id,{seconds:seconds,steps:steps});
     api.check(now.stable===start[id].stable,"PI no-hit actor never changes injury/seed/sequence "+id);
    }
    api.write("injury-native-hit-join.json",damageActor(1));signal(1);phase=2;return;
   }
   if(phase==2&&api.read("injury-ack-1.json")!=null) {
    api.write("injury-native-hit-host.json",damageActor(0));signal(2);phase=3;return;
   }
   if(phase==3&&api.read("injury-ack-2.json")!=null) {
    api.check(JSON.stringify(injuryClass.config)===original.config,"PI fixture never changes factory injury rules");
    api.picture("host-injury-confirmed");api.write("injury-control.json",{done:true});phase=4;at=getTimer();return;
   }
   if(phase==4&&api.read("injury-join-done.json")!=null)api.finish();
  }
 }
}

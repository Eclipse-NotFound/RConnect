package {
 import flash.system.ApplicationDomain;
 import flash.utils.getTimer;
 public final class BAddictionLiveCases {
  private var mod:Object,api:Object,side:String,phase:int=0,at:int,id:String,initial:int,hostStock:int,hostState:String;
  public function BAddictionLiveCases(m:Object,r:Object,d:ApplicationDomain,c:Object,role:String,a:Object){mod=m;api=a;side=role;at=getTimer();}
  public function input():void {
   for each(var key:String in ["keyLeft","keyRight","keyJump","keyAttack","keySit","keyRun","keyAction","keyTele"])mod.access.world.ctr[key]=false;
  }
  public function step():void {
   if(getTimer()-at>70000)throw new Error("Addiction fixture timed out at "+phase);
   if(side=="join") {
    if(phase==0) {
     var control:Object=api.read("addiction-control.json");if(control==null)return;
     var f:Object=mod.replica==null?null:mod.replica.clock.current;if(f==null || f.presentation<control.presentation)return;
     BAddictionCases.joinReplica(mod,api.check);BAddictionCases.carryIsolation(mod,api.check);
     id=control.id;initial=control.initial;
     api.check(mod.access.world.invent.items[id].kol==initial,"joining drug inventory first matches the authoritative fixture");
     api.check(BAddictionCases.joinDose(mod,id,1),"joining dose submits the real addon UI intent");
     api.write("addiction-submitted.json",{submitted:true});phase=1;return;
    }
    if(phase==1) {
     control=api.read("addiction-consumed.json");if(control==null)return;
     f=mod.replica.clock.current;if(f==null || f.presentation<control.presentation)return;
     api.check(mod.access.world.invent.items[id].kol==initial-1,"joining dose receives exactly one inventory debit");
     BAddictionCases.joinReplica(mod,api.check);BAddictionCases.carryIsolation(mod,api.check);
     api.write("addiction-join-done.json",{done:true});api.finish();phase=2;
    }
    return;
   }
   var s:Object=mod.host;
   if(phase==0) {
    if(!s.active || s.runtime.awaitingFirstView || mod.access.world.t_exit>0 || !s.actors[1].unit.ggControl)return;
    BAddictionCases.hostBindings(mod,api.check);BAddictionCases.carryIsolation(mod,api.check);BAddictionCases.rejectedHostActions(mod,api.check);
    var a:Object=s.actors[1],runtime:Object=a.unit.pers.controller;
    for each(var candidate:String in ["dash","mintals","medx","psycho"])if(runtime.handles(candidate) && a.unit.invent.items[candidate]!=null){id=candidate;break;}
    if(id==null)throw new Error("No native drug item available for fixture");
    // Only this copied test character receives a small, known stock.
    initial=int(a.unit.invent.items[id].kol)+3;a.unit.invent.items[id].kol=initial;
    hostStock=s.actors[0].unit.invent.items[id].kol;
    api.write("addiction-control.json",{id:id,initial:initial,presentation:s.presentations+1});phase=1;return;
   }
   if(phase==1) {
    if(api.read("addiction-submitted.json")==null || s.actors[1].unit.invent.items[id].kol==initial)return;
    api.check(s.actors[1].unit.invent.items[id].kol==initial-1,"host executes joining dose exactly once");
    api.check(s.actors[0].unit.invent.items[id].kol==hostStock,"joining dose does not consume host stock");
    BAddictionCases.carryIsolation(mod,api.check);
    api.write("addiction-consumed.json",{presentation:s.presentations+1});phase=2;return;
   }
   if(phase==2 && api.read("addiction-join-done.json")!=null){api.finish();phase=3;}
  }
 }
}

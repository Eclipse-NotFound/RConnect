package {
 import flash.system.ApplicationDomain;
 import flash.utils.getTimer;
 public final class BAddictionLiveCases {
  private var mod:Object,api:Object,side:String,phase:int=0,at:int,id:String,initial:int,hostStock:int,hostState:String;
  private var remoteInventory:Object,localInventory:Object;
  public function BAddictionLiveCases(m:Object,r:Object,d:ApplicationDomain,c:Object,role:String,a:Object){mod=m;api=a;side=role;at=getTimer();}
  public function input():void {
   // Observe before the product presents this screen frame: the second real
   // dose must have arrived, while its personal result is still buffered.
   if(side=="join" && phase==2 && mod.replica!=null) {
    var replica:Object=mod.replica,last:Object=replica.lastFrame;
    if(last!=null && last!==replica.clock.current && last.character.inventory.items[id]==initial-2) {
     api.check(mod.access.world.invent.items[id].kol==initial-1,"second dose is received but still absent from the older displayed inventory");
     var queued:int=replica.clock.queued,consumed:int=0,prior:Function=replica.confirmed;
     replica.confirmed=function(frame:Object):void {++consumed;if(prior!=null)prior(frame);};
     var state:String=last.character.addons.addiction.state;
     mod.leaveSession();
     api.check(queued>0 && consumed==queued && replica.clock.queued==0 && replica.clock.current===last,"leaving consumes each buffered confirmation exactly once");
     api.check(mod.access.world.invent.items[id].kol==initial-2,"return to own game retains the latest confirmed drug inventory");
     api.check(mod.access.world.game.triggers["addictionsystem.state.v1"]===state,"return to own game retains the exact latest confirmed drug state");
     api.write("addiction-return.json",{queued:queued,consumed:consumed,inventory:initial-2});phase=3;
    }
   }
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
     api.check(BAddictionCases.joinDose(mod,id,1),"second joining dose uses the real UI intent before an immediate leave");
     phase=2;return;
    }
    if(phase==3 && mod.role=="" && mod.access.world.gg.pers!=null) {
     var runtimeNow:Object=mod.access.world.gg.pers.controller;
     if(runtimeNow==null || runtimeNow.authority!=null || !runtimeNow.attached)return;
     api.check(runtimeNow.gg===mod.access.world.gg && runtimeNow.gg.childObjs["addictionsystem.tick"]===runtimeNow,"own world resumes exactly its standalone addiction controller");
     api.check(mod.access.world.invent.items[id].kol==initial-2,"restored standalone inventory keeps both actual dose debits");
     api.write("addiction-join-done.json",{done:true});api.finish();phase=4;
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
    remoteInventory=a.unit.invent;localInventory=s.actors[0].unit.invent;
    api.write("addiction-control.json",{id:id,initial:initial,presentation:s.presentations+1});phase=1;return;
   }
   if(phase==1) {
    if(api.read("addiction-submitted.json")==null || s.actors[1].unit.invent.items[id].kol==initial)return;
    api.check(s.actors[1].unit.invent.items[id].kol==initial-1,"host executes joining dose exactly once");
    api.check(s.actors[0].unit.invent.items[id].kol==hostStock,"joining dose does not consume host stock");
    BAddictionCases.carryIsolation(mod,api.check);
    api.write("addiction-consumed.json",{presentation:s.presentations+1});phase=2;return;
   }
   if(phase==2 && api.read("addiction-join-done.json")!=null){
    api.check(remoteInventory.items[id].kol==initial-2,"host confirms exactly two remote doses before leave");
    api.check(localInventory.items[id].kol==hostStock,"both remote doses preserve the host inventory");
    api.finish();phase=3;
   }
  }
 }
}

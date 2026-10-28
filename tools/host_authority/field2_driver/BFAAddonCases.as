package {
 import flash.desktop.NativeApplication;
 import flash.events.KeyboardEvent;
 import flash.events.MouseEvent;
 import flash.system.ApplicationDomain;
 import flash.utils.getTimer;

 /** External fixture only. Preparation may grant weapons; every measured
  * modification, mode switch and shot goes through the actual B input queue. */
 public final class BFAAddonCases {
  private var mod:Object,root:Object,cfg:Object,api:Object,side:String,front:Object;
  private var control:Object={},sequence:int=0,localSent:int=-1,localAck:int=-1,at:int=0,lastRead:int=0,index:int=-1;
  private var expected:Object={configured:[false,false],mode:["near","near"],ammo:[7,9],grenadeMode:[false,false],bipod:[false,false]};
  private var operations:Array=[
   {kind:"modify",owner:0},{kind:"modify",owner:1},{kind:"optic",owner:0},{kind:"optic",owner:1},
   {kind:"grenade",owner:0},{kind:"grenade",owner:1},{kind:"grenadeMode",owner:0},{kind:"grenadeMode",owner:1},
   {kind:"leaveGrenadeMode",owner:0},{kind:"leaveGrenadeMode",owner:1},{kind:"bipod",owner:0},{kind:"bipod",owner:1}];
  private var began:int,bulletSeen:Array=[false,false],duplicateSequence:int=-1,duplicateAt:int=0,reconnectStarted:Boolean=false,done:Boolean=false;

  public function BFAAddonCases(m:Object,r:Object,d:ApplicationDomain,c:Object,role:String,a:Object) {
   if(NativeApplication.nativeApplication.applicationID.indexOf("pfe-modsettings-rconnect-b-startup-")!=0)
    throw new Error("FA cases require a fresh isolated startup AIR profile");
   mod=m;root=r;cfg=c;side=role;api=a;began=at=getTimer();
   var carrier:Object=root.getChildByName("FirearmAttachmentsCarrier");
   if(carrier==null || root.getChildByName("FAAuthorityAPI")==null)throw new Error("FA B candidate was not loaded");
   front=carrier.api;
  }
  private function check(ok:Boolean,name:String,data:Object=null):void{api.check(ok,"FA B: "+name,data);}
  private function copy(value:Object):Object{return JSON.parse(JSON.stringify(value));}
  private function publish(kind:String,owner:int=-1):void {
   control={seq:++sequence,kind:kind,owner:owner,expected:copy(expected),presentation:mod.host==null?0:mod.host.presentations+1};
   at=getTimer();api.write("fa-control.json",control);
  }
  private function ammo(unit:Object):int{return int(unit.invent.items.gren40.kol);}
  private function assembly(owner:int):Object {
   return {items:["dot","magnifier","grenade","bipod",owner==0?"large_mag":"quick_mag"],
    rails:{top:6,side:0,under:5},railStarts:{top:0,side:0,under:0},
    positions:{dot:2,magnifier:0,grenade:0,bipod:0,large_mag:0,quick_mag:0},mode:"near",grenadeWait:0};
  }
  private function has(state:Object,id:String):Boolean{return state!=null && state.items is Array && state.items.indexOf(id)>=0;}
  private function matches(state:Object,id:int,e:Object):Boolean {
   if(e.configured[id] && (!has(state,id==0?"large_mag":"quick_mag") || !has(state,"grenade") || !has(state,"magnifier") || state.mode!==e.mode[id]))return false;
   return true;
  }
  public function input():void {
   if(done)return;
   if(side=="join" && getTimer()-lastRead>80) {
    lastRead=getTimer();var incoming:Object=api.read("fa-control.json");
    if(incoming!=null){if(control.seq!=incoming.seq)at=getTimer();control=incoming;}
   }
   var w:Object=mod.access.world;if(w==null || w.ctr==null)return;
   for each(var key:String in ["keyLeft","keyRight","keyJump","keyAttack","keySit","keyRun","keyAction","keyTele","keyZoom"])w.ctr[key]=false;
   // Point away from both players; native bullet creation/trajectory is untouched.
   if(w.gg!=null){w.celX=w.gg.X+300;w.celY=w.gg.Y-130;
    if(w.cam!=null){w.cam.celX=w.cam.vx+w.celX*w.cam.scaleV;w.cam.celY=w.cam.vy+w.celY*w.cam.scaleV;}}
  }
  private function nativeReady():Boolean {
   if(mod.host==null || !mod.host.active || mod.host.runtime.awaitingFirstView)return false;
   for each(var actor:Object in mod.host.actors)if(actor.unit.sost!=1 || !actor.unit.ggControl || actor.unit.work=="res" || actor.unit.work=="change")return false;
   return true;
  }
  private function prepare():void {
   for each(var actor:Object in mod.host.actors)mod.access.scope.run(actor.context,function():void {
    var g:Object=actor.unit,inv:Object=g.invent;
    if(inv.weapons.lmg==null)inv.addWeapon("lmg",1,60,0,0);
    inv.plusItem("gren40",expected.ammo[actor.id]-int(inv.items.gren40.kol));
    g.changeWeapon("lmg",true);g.invulner=true;g.dx=g.dy=0;
   });
   check(front.authorityManaged,"host global FA loop has been leased");
   publish("prepare");
  }
  private function sendLocal():void {
   if(control.seq==localSent || control.owner!=(side=="host"?0:1))return;
   if(!front.ready() || front.ui==null || front.heldWeapon()==null || front.heldWeapon().id!="lmg")return;
   localSent=control.seq;
   var before:int=ammo(mod.access.world.gg),kind:String=control.kind;
   if(kind=="modify") {
    front.ui.open("lmg");check(front.ui.opened,"actual workbench opens for "+side);
    check(front.ui.session.accept("lmg",{state:assembly(control.owner)})=="","valid distinct assembly accepted as a draft "+side);
    front.ui.render();var beforeState:String=JSON.stringify(front.state("lmg"));
    front.ui.buttons.apply.dispatchEvent(new MouseEvent(MouseEvent.CLICK,true));
    check(JSON.stringify(front.state("lmg"))==beforeState && front.ui.session.changed("lmg"),"workbench waits for host confirmation "+side);
   } else if(kind=="optic" || kind=="grenade" || kind=="bipod") {
    if(front.ui.opened)front.ui.close();
    var binding:Object=front.settings.getBinding(kind);
    check(binding!=null && binding.code>0,"default FA shortcut is available "+kind+" "+side);
    root.stage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_DOWN,true,false,0,binding.code,0,binding.ctrl,binding.alt,binding.shift));
    root.stage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_UP,true,false,0,binding.code,0,binding.ctrl,binding.alt,binding.shift));
   } else {
    if(front.ui.opened)front.ui.close();
    check(mod.requestAddonAction({addon:"fa",key:kind,args:[]}),"mode request enters B reliable queue "+kind+" "+side);
   }
   check(ammo(mod.access.world.gg)==before,"request submission alone does not consume native ammo "+kind+" "+side);
  }
  private function ownMatches():Boolean {
   var id:int=side=="host"?0:1,e:Object=control.expected,w:Object=mod.access.world;
   if(!mod.welcomed || e==null || w.gg==null || w.gg.currentWeapon==null || w.gg.currentWeapon.id!="lmg")return false;
   if(!matches(front.state("lmg"),id,e) || ammo(w.gg)!=e.ammo[id] || front.grenadeMode!==e.grenadeMode[id])return false;
   if(control.kind=="bipod" && control.owner==id && front.deployed!==e.bipod[id])return false;
   if(control.kind=="modify" && control.owner==id && (!front.ui.opened || front.ui.session.changed("lmg")))return false;
   if(side=="join") {
    var f:Object=mod.replica==null?null:mod.replica.lastFrame;
    if(f==null || f.presentation<control.presentation || f.character==null || f.character.addons==null || f.character.addons.fa==null)return false;
    var state:Object=f.character.addons.fa;
    if(!matches(state.weapons.lmg,id,e) || state.grenadeMode!==e.grenadeMode[id])return false;
   }
   return true;
  }
  private function acknowledge():void {
   if(localAck==control.seq || !ownMatches())return;
   if(control.kind=="grenade" && control.owner==(side=="host"?0:1)) {
    // Only after the actual shortcut has fired once, submit another distinct
    // request during the native cooldown. It must not debit a second round.
    if(duplicateSequence!=control.seq) {
     check(front.state("lmg").grenadeWait>0,"native grenade cooldown confirmed after shortcut "+side);
     duplicateSequence=control.seq;duplicateAt=getTimer();front.grenade();return;
    }
    if(getTimer()-duplicateAt<250)return;
   }
   localAck=control.seq;
   check(front.authorityManaged,"front remains display/input only "+control.kind+" "+side);
   if(control.kind=="modify" && control.owner==(side=="host"?0:1)) {
    check(!front.ui.session.changed("lmg"),"confirmed UI commits draft once "+side);
    api.picture(side+"-fa-confirmed");front.ui.close();
   }
   api.write(side+"-fa-ack-"+control.seq+".json",{seq:control.seq,ammo:ammo(mod.access.world.gg),managed:front.authorityManaged});
  }
  private function hostMatches():Boolean {
   var s:Object=mod.host;if(s==null)return false;
   for(var i:int=0;i<2;i++) {
    var a:Object=s.actors[i],snap:Object=mod.access.addons.snapshot(i).fa,e:Object=control.expected;
    if(a.unit.currentWeapon==null || a.unit.currentWeapon.id!="lmg" || !matches(snap.weapons.lmg,i,e) || ammo(a.unit)!=e.ammo[i] || snap.grenadeMode!==e.grenadeMode[i])return false;
    if(e.configured[i] && a.unit.invent.weapons.lmg.holder!=(i==0?120:72))return false;
    if(control.kind=="bipod" && control.owner==i && snap.deployed!==e.bipod[i])return false;
   }
   return true;
  }
  private function observeProjectiles():void {
   if(mod.host==null)return;
   for each(var actor:Object in mod.host.actors) {
    var p:Object=actor.unit.loc.firstObj,n:int=0;
    while(p!=null && n++<20000) {
     if("owner" in p && p.owner===actor.unit && "weapId" in p && p.weapId=="lmg" && "damageExpl" in p && p.damageExpl>0)bulletSeen[actor.id]=true;
     p=p.nobj;
    }
   }
  }
  private function next():void {
   if(++index>=operations.length) {
    check(bulletSeen[0] && bulletSeen[1],"both grenade commands created native owner-tagged projectiles",bulletSeen);
    // Confirm save output uses each actor's own scope and profile.
    for each(var actor:Object in mod.host.actors)mod.access.scope.run(actor.context,function():void {
     var save:Object={triggers:{}};mod.access.addons.carryState(save);
     var record:Object=JSON.parse(save.triggers["firearmattachments.v1"]);
     check(matches(record.weapons.lmg,actor.id,expected),"explicit personal save retains only the corresponding assembly "+actor.id);
    });
    publish(cfg.faReconnect===true?"disconnect":"end");return;
   }
   var op:Object=operations[index],i:int=op.owner;
   if(op.kind=="modify")expected.configured[i]=true;
   if(op.kind=="optic")expected.mode[i]="far";
   if(op.kind=="grenade")expected.ammo[i]--;
   if(op.kind=="grenadeMode")expected.grenadeMode[i]=true;
   if(op.kind=="leaveGrenadeMode")expected.grenadeMode[i]=false;
   if(op.kind=="bipod")expected.bipod[i]=true;
   publish(op.kind,i);
  }
  public function step():void {
   if(done)return;
   if(getTimer()-began>180000 || getTimer()-at>40000)throw new Error("FA B fixture timed out: "+side+" "+JSON.stringify(control));
   if(side=="host" && control.kind==null) {if(nativeReady())prepare();return;}
   if(control.kind==null)return;
   if(control.kind=="end") {
    if(side=="join"){mod.leaveSession();api.write("join-fa-end.json",{done:true});done=true;api.finish();}
    else if(api.read("join-fa-end.json")!=null && mod.role==""){done=true;api.finish();}return;
   }
   if(control.kind=="disconnect") {
    if(side=="join" && mod.role!="")mod.leaveSession();
    if(mod.role!="" || mod.access.world.t_exit>0 || !mod.access.world.gg.ggControl)return;
    if(localAck!=control.seq) {
     check(!front.authorityManaged,"FA returns to standalone ownership after leave "+side);
     check(matches(front.state("lmg"),side=="host"?0:1,control.expected),"leave keeps this player's confirmed assembly "+side);
     localAck=control.seq;api.write(side+"-fa-offline.json",{done:true});
    }
    if(side=="host" && api.read("join-fa-offline.json")!=null){mod.ui.session.startHost();publish("reconnect");}return;
   }
   if(control.kind=="reconnect") {
    if(side=="join" && !reconnectStarted){reconnectStarted=true;mod.ui.session.startJoin();}
    if(side=="host" && nativeReady()){expected.bipod=[false,false];publish("reconnected");}return;
   }
   sendLocal();observeProjectiles();acknowledge();
   if(side=="host" && hostMatches() && api.read("join-fa-ack-"+control.seq+".json")!=null && localAck==control.seq && getTimer()-at>700) {
    check(true,"native effects, resources and confirmed state match after "+control.kind,{sequence:control.seq,expected:control.expected});
    if(control.kind=="reconnected") {check(front.authorityManaged,"reconnect reacquires exactly one FA lease");publish("end");}
    else next();
   }
  }
 }
}

package {
 /** Explicit checks for an already connected isolated B game. No private
  * product fields, extra native ticks, inventory grants or source patches.
  * Root driver chooses when to call these; nothing runs automatically. */
 public final class BAddictionCases {
  private static const KEY:String='addictionsystem.state.v1';
  private static function equal(a:*,b:*):Boolean {
   if(a===b)return true;if(a==null||b==null||typeof a!='object'||typeof b!='object'||(a is Array)!=(b is Array))return false;
   if(a is Array&&a.length!=b.length)return false;
   for(var key:String in a)if(!b.hasOwnProperty(key)||!equal(a[key],b[key]))return false;
   for(key in b)if(!a.hasOwnProperty(key))return false;return true;
  }
  private static function sameState(a:String,b:String):Boolean{return equal(JSON.parse(a),JSON.parse(b));}

  private static function actor(mod:Object,id:int):Object {for each(var item:Object in mod.host.actors)if(item.id==id)return item;throw new Error('Missing test actor '+id);}
  private static function front(mod:Object):Object {return mod.main.getChildByName('AddictionSystemCarrier').api;}
  private static function checkStock(r:Object):Object {
   var out:Object={};for(var id:String in r.gg.invent.items)out[id]=r.gg.invent.items[id].kol;return out;
  }
  public static function capture(mod:Object):Object {
   var out:Object={role:mod.role,actors:[]};
   if(mod.host!=null)for each(var a:Object in mod.host.actors){var r:Object=a.unit.pers.controller;out.actors.push({id:a.id,epoch:a.epoch,state:r.engine.json(),stocks:checkStock(r),attached:r.attached,room:mod.access.keyFor(a.unit.loc)});}
   else {r=front(mod);out.actors.push({id:1,state:r.engine.json(),stocks:checkStock(r),attached:r.attached,room:mod.access.keyFor(mod.access.world.loc)});}
   return out;
  }
  public static function hostBindings(mod:Object,check:Function):void {
   var w:Object=mod.access.world,a0:Object=actor(mod,0),a1:Object=actor(mod,1),r0:Object=a0.unit.pers.controller,r1:Object=a1.unit.pers.controller;
   check(r0!==r1&&r0.engine!==r1.engine&&r0.engine.s!==r1.engine.s,'addiction_actor_engines_distinct');
   for each(var a:Object in [a0,a1]) {
    var r:Object=a.unit.pers.controller;
    check(a.unit.invent.controller===r,'addiction_wrappers_share_actor_controller_'+a.id);
    check(a.context.pers===a.unit.pers&&a.context.invent===a.unit.invent,'addiction_native_context_rebound_'+a.id);
    check(a.unit.childObjs['addictionsystem.tick']===r,'addiction_exact_native_child_'+a.id);
    check(r.gg===a.unit&&r.authority.isHost&&r.authorityKey===String(a.id),'addiction_owner_identity_'+a.id);
    var engine:Object=r.engine,pers:Object=a.unit.pers,inv:Object=a.unit.invent,panel:Object=r.ui;
    // Directly exercise the bridge's idempotent binding, not only AddonsBridge's
    // outer epoch fast path. Preserve exact native object and Engine identities.
    mod.access.scope.run(a.context,function():void {r.authorityBind(r.authority,String(a.id),r.authorityProfile(),a.id==0);});
    check(r.engine===engine&&a.unit.pers===pers&&a.unit.invent===inv&&r.ui===panel,'addiction_repeat_bind_identity_'+a.id);
   }
   check(w.gg===a0.unit&&w.pers===a0.unit.pers&&w.invent===a0.unit.invent,'addiction_root_owner_restored');
   check(w.game.triggers[KEY]===r0.engine.json(),'addiction_shared_trigger_host_only');
   check(r0.ui!=null&&r1.ui==null,'addiction_only_local_host_panel');
  }
  public static function carryIsolation(mod:Object,check:Function):void {
   var w:Object=mod.access.world,prior:*=w.game.triggers[KEY],priorGG:Object=w.gg,priorPers:Object=w.pers,priorInv:Object=w.invent;
   if(mod.host!=null)for each(var a:Object in mod.host.actors) {
    var destination:Object={triggers:{unrelated:'preserved'}},expected:String=a.unit.pers.controller.engine.json();
    mod.access.scope.run(a.context,function():void {mod.access.addons.carryState(destination);});
    check(sameState(destination.triggers[KEY],expected)&&destination.triggers.unrelated==='preserved','addiction_carry_own_state_'+a.id);
   } else {
    destination={triggers:{unrelated:'preserved'}};mod.access.addons.carryState(destination);
    check(sameState(destination.triggers[KEY],front(mod).engine.json())&&destination.triggers.unrelated==='preserved','addiction_join_carry_confirmed_own_state');
   }
   check(w.game.triggers[KEY]===prior&&w.gg===priorGG&&w.pers===priorPers&&w.invent===priorInv,'addiction_carry_does_not_change_live_world');
  }
  public static function joinReplica(mod:Object,check:Function):void {
   var r:Object=front(mod),prior:String=r.engine.json();
   check(r.authority!=null&&!r.authority.isHost&&r.authorityKey==='1','addiction_join_role');
   check(r.gg===mod.access.world.gg&&r.gg.pers.controller===r&&r.gg.invent.controller===r,'addiction_join_own_wrappers');
   check(r.gg.childObjs['addictionsystem.tick']!==r,'addiction_join_has_no_native_tick');
   r.step();check(r.engine.json()===prior,'addiction_join_step_cannot_advance');
   r.gg.pers.setParameters();check(r.engine.json()===prior&&!r.parametersAllowed(),'addiction_join_parameters_cannot_simulate');
   var confirmed:Object=mod.replica.clock.current;
   check(confirmed!=null&&sameState(confirmed.character.addons.addiction.state,prior),'addiction_join_matches_presented_confirmation');
  }
  public static function rejectedHostActions(mod:Object,check:Function):void {
   var a:Object=actor(mod,1),r:Object=a.unit.pers.controller,prior:String=r.engine.json(),inventory:String=JSON.stringify(checkStock(r));
   var actions:Array=[{addon:'addiction',key:'dose',args:['dash',0]},
    {addon:'addiction',key:'dose',args:['dash',1001]}, {addon:'addiction',key:'dose',args:['dash',1.5]},
    {addon:'addiction',key:'dose',args:['missing-drug',1]}, {addon:'addiction',key:'treat',args:['missing-family']},
    {addon:'addiction',key:'automatic',args:[]}, {addon:'addiction',key:'cancelAuto',args:[true]}];
   for(var i:int=0;i<actions.length;i++)check(!mod.access.addons.execute(a,actions[i]),'addiction_reject_action_'+i);
   check(r.engine.json()===prior&&JSON.stringify(checkStock(r))===inventory,'addiction_rejection_does_not_mutate');
  }
  /** Queues exactly the same intent as the joining Panel. Caller must wait for
   * a host confirmation and compare inventory/Engine state on both processes. */
  public static function joinDose(mod:Object,id:String,count:int):Boolean {
   if(mod.host!=null)throw new Error('joinDose requires joining test instance');
   return front(mod).dose(id,count);
  }
 }
}

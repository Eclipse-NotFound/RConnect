package {
 import flash.desktop.NativeApplication;
 import flash.system.ApplicationDomain;
 /** External isolated fixture. Exercises the installed native object hook,
  * not a reimplementation of reward calculation. Never attach to player AIR. */
 public final class BHorseshoeChecks {
  public static function run(mod:Object,check:Function):void {
   if(NativeApplication.nativeApplication.applicationID.indexOf("pfe-modsettings-rconnect-b-startup-")!=0)
    throw new Error("Horseshoe checks require isolated startup fixture");
   var s:Object=mod.host,w:Object=mod.access.world;
   if(s==null || !s.active || s.actors.length!=2)
    throw new Error("Horseshoe fixture requires an active session");
   var room:Object=s.actors[0].unit.loc;
   if(s.actors[1].unit.loc!==room)
    throw new Error("Horseshoe fixture requires both active native actors in one room");
   var Bonus:Class=mod.access.definition("fe.loc.Bonus"),Location:Class=mod.access.definition("fe.loc.Location");
   var prior:Object={active:room.active,kol:room.kolXp,max:room.maxXp,un:room.unXp,summ:room.summXp,detect:room.detecting,
    landSumm:room.land.summXp,policy:mod.preferences.getValue("shareHorseshoeXP")};
   var positions:Array=[],actor:Object,bonus:Object=null;
   for each(actor in s.actors)positions.push({x:actor.unit.X,y:actor.unit.Y,xp:actor.unit.pers.xpCur,next:actor.unit.pers.xpNext});
   try {
    room.active=true;
    for each(actor in s.actors)actor.unit.pers.xpNext=2147483647;
    for(var id:int=0;id<2;id++)for(var sharing:int=0;sharing<2;sharing++)for(var finalPoint:int=0;finalPoint<2;finalPoint++) {
     mod.ui.horseshoeXP.setShared(sharing==1);
     check(s.runtime.shareHorseshoeXP==Boolean(sharing),"horseshoe setting reaches native runtime "+id+":"+sharing+":"+finalPoint);
     var before:Array=[s.actors[0].unit.pers.xpCur,s.actors[1].unit.pers.xpCur],collector:Object=s.actors[id].unit;
     s.actors[1-id].unit.setLocPos(collector.X+200,collector.Y);
     room.kolXp=1;room.maxXp=finalPoint?3:1;room.unXp=17;room.summXp=finalPoint?29:0;room.detecting=false;
     mod.access.scope.run(s.actors[id].context,function():void {bonus=new Bonus(room,"xp",int(collector.X),int(collector.Y-30));});
     room.bonuses.push(bonus);room.addObj(bonus);
     Location["rconnectObjectStep"](room,bonus);
     var reward:int=finalPoint?80:17;
     check(bonus.sost==2 && room.kolXp==0,"one native horseshoe consumed "+id+":"+sharing+":"+finalPoint);
     for each(actor in s.actors)check(actor.unit.pers.xpCur-before[actor.id]==(actor.id==id || sharing==1?reward:0),
      "correct native horseshoe reward collector="+id+" sharing="+sharing+" final="+finalPoint+" recipient="+actor.id);
     var after:Array=[s.actors[0].unit.pers.xpCur,s.actors[1].unit.pers.xpCur];
     mod.ui.horseshoeXP.setShared(sharing==0);
     Location["rconnectObjectStep"](room,bonus);
     check(s.actors[0].unit.pers.xpCur==after[0] && s.actors[1].unit.pers.xpCur==after[1],
      "switching policy cannot re-award consumed horseshoe "+id+":"+sharing+":"+finalPoint);
     clean(room,bonus);bonus=null;
     for each(actor in s.actors)actor.unit.setLocPos(positions[actor.id].x,positions[actor.id].y);
    }
    mod.ui.horseshoeXP.setShared(true);
    before=[s.actors[0].unit.pers.xpCur,s.actors[1].unit.pers.xpCur];
    collector=s.actors[0].unit;s.actors[1].unit.setLocPos(collector.X+200,collector.Y);
    room.kolXp=room.maxXp=1;room.unXp=17;
    mod.access.scope.run(s.actors[0].context,function():void {bonus=new Bonus(room,"xp",int(collector.X),int(collector.Y-30));});
    room.bonuses.push(bonus);room.addObj(bonus);bonus.liv=1;
    Location["rconnectObjectStep"](room,bonus);
    check(bonus.sost==2 && room.kolXp==1 && s.actors[0].unit.pers.xpCur==before[0] && s.actors[1].unit.pers.xpCur==before[1],
     "expired point is not treated as a native pickup");
    clean(room,bonus);bonus=null;
    // A direct native reward represents unrelated sources. No expa hook is
    // introduced by this setting and no teammate bonus is synthesized here.
    mod.ui.horseshoeXP.setShared(false);
    before=[s.actors[0].unit.pers.xpCur,s.actors[1].unit.pers.xpCur];
    mod.access.scope.run(s.actors[1].context,function():void{s.actors[1].unit.pers.expa(11);});
    check(s.actors[0].unit.pers.xpCur==before[0] && s.actors[1].unit.pers.xpCur==before[1]+11,
     "unrelated native experience grant is unchanged");
    var Prefs:Class=ApplicationDomain.currentDomain.getDefinition("authority.ui.Preferences") as Class;
    var reload:Object=new Prefs({});
    check(reload.getValue("shareHorseshoeXP")=="0","horseshoe host preference persists in isolated AIR profile");
    check(w.gg===s.actors[0].unit && w.loc===s.actors[0].unit.loc && mod.access.scope.depth==0,
     "horseshoe reward restores host world ownership");
   } finally {
    if(bonus!=null)clean(room,bonus);
    for each(actor in s.actors){var p:Object=positions[actor.id];actor.unit.setLocPos(p.x,p.y);actor.unit.pers.xpCur=p.xp;actor.unit.pers.xpNext=p.next;}
    room.active=prior.active;room.kolXp=prior.kol;room.maxXp=prior.max;room.unXp=prior.un;room.summXp=prior.summ;
    room.detecting=prior.detect;room.land.summXp=prior.landSumm;mod.preferences.setValue("shareHorseshoeXP",prior.policy);mod.preferences.save();mod.applyPreferences();mod.ui.refresh();
   }
  }
  private static function clean(room:Object,bonus:Object):void {
   if(bonus.vis!=null)bonus.remVisual();if(bonus.in_chain)room.remObj(bonus);
   var i:int=room.bonuses.indexOf(bonus);if(i>=0)room.bonuses.splice(i,1);
  }
 }
}

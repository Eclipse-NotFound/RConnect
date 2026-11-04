package authority {
   import flash.utils.Dictionary;
   /** Direct native API probes, not claims of complete network weapon support. */
   public class RoomWeaponChecks {
      public static function run(session:HostSession,check:Function):void {
         var access:NativeAccess=session.access;
         for each(var actor:PlayerActor in session.actors) {
            var other:PlayerActor=session.actors[1-actor.id],g:Object=actor.unit,room:Object=g.loc;
            var priorMines:Dictionary=new Dictionary(true);
            for each(var u:Object in room.units)if(u!=null)priorMines[u]=true;
            var otherStock:Number=other.unit.invent.items.mine.kol;
            access.scope.run(actor.context,function():void {
               var Weapon:Class=access.definition("fe.weapon.Weapon"),mine:Object=Weapon["create"](g,"mine",0);
               var old:Object=g.currentWeapon,children:Array=g.childObjs,stock:Number=g.invent.items.mine.kol;
               try {
                  g.invent.items.mine.kol=3;mine.setPers(g,g.pers);mine.lvl=0;mine.addVisual();
                  g.currentWeapon=mine;g.childObjs=[mine];g.celX=g.X+30;g.celY=g.Y;
                  mine.step();mine.attack(true);mine.step();
                  check(g.invent.items.mine.kol==2 && other.unit.invent.items.mine.kol==otherStock,
                     "native thrown mine consumes only its owner's inventory player "+actor.id);
                  var spawned:Array=[];
                  for each(var candidate:Object in room.units)if(candidate!=null && !priorMines[candidate] && candidate.id=="mine")spawned.push(candidate);
                  check(spawned.length==1 && spawned[0].loc===room && other.unit.loc.units.indexOf(spawned[0])<0,
                     "native WThrow places its real Mine in the caster's room player "+actor.id);
                  for each(candidate in spawned){candidate.remVisual();room.remObj(candidate);room.units.splice(room.units.indexOf(candidate),1);}
               } finally {mine.remVisual();g.currentWeapon=old;g.childObjs=children;g.invent.items.mine.kol=stock;}
            });
         }
         var a:PlayerActor=session.actors[0],b:PlayerActor=session.actors[1];
         var permission:Array=[a.unit.pers.spellsPoss,b.unit.pers.spellsPoss];
         a.unit.pers.spellsPoss=0;b.unit.pers.spellsPoss=1;
         try {
            for each(actor in session.actors) {
               other=session.actors[1-actor.id];g=actor.unit;room=g.loc;
               var otherMana:Number=other.unit.mana,otherHealth:Number=other.unit.pers.manaHP;
               access.scope.run(actor.context,function():void {
                  var Weapon:Class=access.definition("fe.weapon.Weapon"),spell:Object=Weapon["create"](g,"telebul",0);
                  var old:Object=g.currentWeapon,children:Array=g.childObjs,mana:Number=g.mana,manaHP:Number=g.pers.manaHP;
                  try {
                     g.mana=10000;g.pers.manaHP=10000;spell.setPers(g,g.pers);spell.lvl=spell.perslvl=0;
                     g.currentWeapon=spell;g.childObjs=[spell];spell.addVisual();g.celX=g.X+300;g.celY=g.Y-55;
                     spell.step();spell.t_prep=spell.prep;
                     var accepted:Boolean=spell.attack(true);spell.step();
                     var bullets:int=0,object:Object=room.firstObj;
                     while(object!=null) {
                        if(NativeAccess.get(object,"owner")===g && NativeAccess.get(object,"weap")===spell)++bullets;
                        object=object.nobj;
                     }
                     if(actor.id==0)check(!accepted && bullets==0 && g.mana==10000,"native magic respects the host's disabled spell permission");
                     else check(accepted && bullets>0 && g.mana==10000-spell.dmagic,"native remote magic creates a real projectile and pays its own magic cost");
                     check(other.unit.mana==otherMana && other.unit.pers.manaHP==otherHealth,
                        "native magic leaves the other player's mana resources unchanged player "+actor.id);
                     Log.write("room-weapon-evidence",{player:actor.id,room:access.keyFor(room),id:spell.id,accepted:accepted,bullets:bullets,
                        dmagic:spell.dmagic,dmana:spell.dmana,mana:g.mana,manaHP:g.pers.manaHP});
                  } finally {spell.remVisual();g.currentWeapon=old;g.childObjs=children;g.mana=mana;g.pers.manaHP=manaHP;}
               });
            }
         } finally {a.unit.pers.spellsPoss=permission[0];b.unit.pers.spellsPoss=permission[1];}
      }
   }
}

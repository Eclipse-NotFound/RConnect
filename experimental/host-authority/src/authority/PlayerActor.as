package authority {
   import flash.display.DisplayObject;
   public class PlayerActor {
      public var access:NativeAccess,id:int,unit:Object,context:Object={},steps:uint=0;
      public var failed:Function;
      public var weaponEpoch:int=1;
      public function PlayerActor(access:NativeAccess,id:int){this.access=access;this.id=id;}
      public static function local(access:NativeAccess):PlayerActor {
         var a:PlayerActor=new PlayerActor(access,0),w:Object=access.world;
         a.unit=w.gg;
         for each(var name:String in ["gg","pers","invent","ctr","sats","gui","loc","land","app","alicorn","hardInv","calcMass","calcMassW","checkLoot"])
            a.context[name]=w[name];
         a.context.appearance=AppearanceState.capture(access.definition("fe.inter.Appear"));
         access.scope.register(a.context);
         return a;
      }
      public function step(input:Object):void {
         context.loc=unit.loc;context.land=unit.loc.land;
         context.celX=input.aimX;context.celY=input.aimY;
         access.scope.run(context,function():void {
            var ctr:Object=context.ctr;
            ctr.clearAll();ctr.keyAction=ctr.keyCrack=ctr.keyFly=ctr.keyTest1=false;
            ctr.keyLeft=(input.buttons&Commands.LEFT)!=0;ctr.keyRight=(input.buttons&Commands.RIGHT)!=0;
            ctr.keyJump=(input.buttons&Commands.JUMP)!=0;ctr.keyAttack=(input.buttons&Commands.FIRE)!=0;
            ctr.keySit=(input.buttons&Commands.SIT)!=0;ctr.keyRun=(input.buttons&Commands.RUN)!=0;
            for each(var action:Object in input.actions) {
               if(action.type=="reload")ctr.keyReload=true;
               else if(action.type=="equip" && unit.invent.weapons[action.weapon]!=null &&
                  (unit.currentWeapon==null || unit.currentWeapon.id!=action.weapon)) {
                  ++weaponEpoch;unit.changeWeapon(action.weapon);
               }
            }
            unit.celX=input.aimX;unit.celY=input.aimY;
            unit.step();++steps;
         });
      }
      public function finishWorldServices():void {
         // The native World loop handles the local actor after Land.step.
         if(id==0)return;
         access.scope.run(context,function():void {
            var w:Object=access.world;
            context.sats.step2();
            if(w.calcMass){context.invent.calcMass();w.calcMass=false;}
            if(w.calcMassW){context.invent.calcWeaponMass();w.calcMassW=false;}
         });
      }
      public function onExit(direction:int,x:Number,y:Number):Boolean {
         // The B1 capability is intentionally one room; B2 replaces this seam.
         Log.write("unsupported",{feature:"room-transition",player:id,direction:direction});return false;
      }
      public function onDeath(type:int):void {
         if(failed!=null)failed("B1 death lifecycle has not passed validation");
         else throw new Error("B1 death lifecycle has not passed validation");
      }
      public function snapshot(ack:int):Object {
         var g:Object=unit,v:Object=g.vis,w:Object=g.currentWeapon,weapon:Object=null;
         if(w!=null && w.vis!=null) {
            var p:DisplayObject=w.vis as DisplayObject;
            weapon={id:w.id,x:p.x,y:p.y,rotation:p.rotation,sx:p.scaleX,sy:p.scaleY,
               frame:NativeAccess.get(w.vis,"currentFrame",1),hold:w.hold,ammo:w.ammo,reserve:g.invent.items[w.ammo].kol,
               reload:NativeAccess.get(w,"t_reload",0),attack:NativeAccess.get(w,"t_attack",0)};
         }
         return {id:id,epoch:1,weaponEpoch:weaponEpoch,ack:ack,x:g.X,y:g.Y,dx:g.dx,dy:g.dy,hp:g.hp,maxhp:g.maxhp,mana:g.mana,
            direction:g.storona,sx:v.scaleX,sy:v.scaleY,pose:v.osn.currentFrame,
            body:v.osn.body.currentFrame,weapon:weapon,steps:steps};
      }
      public function destroy():void {
         context.ctr.clearAll();
         access.scope.unregister(context);
         if(id!=0 && unit!=null) {
            unit.remVisual();
            var list:Array=unit.loc.units,index:int=list.indexOf(unit);
            if(index>=0)list.splice(index,1);
            unit.disabled=true;
            unit.onDeath=null;unit.onExit=null;unit.context=null;unit.scope=null;
         }
      }
   }
}

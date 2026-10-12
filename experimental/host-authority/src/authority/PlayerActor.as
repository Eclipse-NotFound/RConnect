package authority {
   import flash.display.DisplayObject;
   public class PlayerActor {
      public var access:NativeAccess,id:int,unit:Object,context:Object={},steps:uint=0;
      public var failed:Function;
      public var interacting:Object;
      public var requestMeet:Function;
      public var resolveTarget:Function,owned:Boolean=false;
      public var weaponEpoch:int=1;
      public var roomEpoch:int=1,lastStep:uint=0;
      public var epoch:int=1,deathTicks:int=0,spawn:Object,saveSerial:uint=0;
      public var saveRequests:Array=[];
      public var personal:Object={allowGrab:false,struggle:true,thrownDamage:false,follow:false};
      public var grips:PeerGrabs;
      public var sight:ActorSight;
      public var originalLevitPoss:Boolean=false;
      private var consumedButtons:int=0;
      private var observedWeapon:Object,weaponKnown:Boolean=false,observedVariant:int=0;
      public function PlayerActor(access:NativeAccess,id:int){this.access=access;this.id=id;sight=new ActorSight(this);}
      public static function local(access:NativeAccess):PlayerActor {
         var a:PlayerActor=new PlayerActor(access,0),w:Object=access.world;
         a.unit=w.gg;
         a.originalLevitPoss=a.unit.levitPoss;
         for each(var name:String in ["gg","pers","invent","ctr","sats","gui","pip","vpip","stand","vstand","loc","land","app","alicorn","hardInv","calcMass","calcMassW","checkLoot","t_battle"])
            a.context[name]=w[name];
         a.context.appearance=AppearanceState.capture(access.definition("fe.inter.Appear"));
         access.scope.register(a.context);
         return a;
      }
      public function step(input:Object):void {
         var actor:PlayerActor=this;
         context.loc=unit.loc;context.land=unit.loc.land;
         context.celX=input.aimX;context.celY=input.aimY;
         access.scope.run(context,function():void {
            if(grips!=null)grips.prepare(actor,input);
            var ctr:Object=context.ctr;
            // Native actions can consume a held key (throw, grab, single shot).
            // Do not resurrect it every network tick before a release/new press.
            consumedButtons&=int(input.held)&~int(input.pressed);
            ctr.keyReload=ctr.keyFly=ctr.keyTest1=false;
            for(var i:int=0;i<Commands.HELD.length;i++)ctr[Commands.HELD[i]]=(input.buttons&~consumedButtons&(1<<i))!=0;
            for each(var key:String in Commands.ONCE)ctr[key]=false;
            for each(var action:Object in input.actions) {
               if(action.type=="reload")ctr.keyReload=true;
               else if(action.type=="control")ctr[action.key]=true;
               else if(action.type=="sats")SatsActions.execute(actor,action.plan);
               else if(action.type=="native")NativeIntents.execute(actor,action.key,action.args);
               else if(action.type=="equip" && unit.invent.weapons[action.weapon]!=null &&
                  (unit.currentWeapon==null || unit.currentWeapon.id!=action.weapon)) {
                  unit.changeWeapon(action.weapon);
               }
            }
            unit.celX=input.aimX;unit.celY=input.aimY;
            if(access.weapons!=null)access.weapons.beforePlayer(actor,input);
            if(!context.sats.active) {
               var heldBefore:Object=unit.teleObj,throwRequested:Boolean=ctr.keyAction;
               if(grips!=null)grips.flights.before(actor);
               try {PlayerPointer.run(actor,input,function():void {unit.step();});}
               finally {if(grips!=null)grips.flights.after(actor);}
               if(grips!=null)grips.afterStep(actor,heldBefore,throwRequested);
               for(i=0;i<Commands.HELD.length;i++)if((input.buttons&(1<<i))!=0 && !ctr[Commands.HELD[i]])consumedButtons|=1<<i;
            }
            if(access.weapons!=null)access.weapons.afterPlayer(actor);
            ++steps;
            if(context.transitionCooldown>0)--context.transitionCooldown;
         });
         observeWeapon();
      }
      public function observeWeapon():void {
         var current:Object=unit.currentWeapon,variant:int=current==null?0:current.variant;
         if(weaponKnown && (current!==observedWeapon || variant!=observedVariant))++weaponEpoch;
         observedWeapon=current;observedVariant=variant;weaponKnown=true;
      }
      public function requestSave(slot:int=-1):void {
         saveRequests.push({serial:++saveSerial,slot:slot});
         if(saveRequests.length>64)saveRequests.shift();
      }
      public function finishWorldServices():void {
         // The native World loop handles the local actor after Land.step.
         if(id==0)return;
         sight.update();
         access.scope.run(context,function():void {
            var w:Object=access.world;
            context.sats.step2();
            if(w.t_battle>0)--w.t_battle;
            if(w.calcMass){context.invent.calcMass();w.calcMass=false;}
            if(w.calcMassW){context.invent.calcWeaponMass();w.calcMassW=false;}
         });
      }
      public function snapshot(ack:int):Object {
         var g:Object=unit,v:Object=g.vis,w:Object=g.currentWeapon,weapon:Object=null;
         if(w!=null && w.vis!=null) {
            var p:DisplayObject=w.vis as DisplayObject;
            weapon={id:w.id,x:p.x,y:p.y,rotation:p.rotation,sx:p.scaleX,sy:p.scaleY,layer:w.sloy,attached:p.parent!=null,
               variant:w.variant,visual:VisualPose.capture(w.vis),
               native:NativeFields.capture(w),
               frame:NativeAccess.get(w.vis,"currentFrame",1),hold:w.hold,ammo:w.ammo,reserve:g.invent.items[w.ammo]==null?0:g.invent.items[w.ammo].kol,
               reload:NativeAccess.get(w,"t_reload",0),attack:NativeAccess.get(w,"t_attack",0)};
         }
         var held:Object=g.teleObj==null?null:{positionEpoch:access.positionEpoch(g.teleObj),X:g.teleObj.X,Y:g.teleObj.Y,scX:g.teleObj.scX,scY:g.teleObj.scY,
            massa:g.teleObj.massa,nazv:g.teleObj.nazv,warn:g.teleObj.warn};
         return {id:id,epoch:epoch,positionEpoch:access.positionEpoch(g),native:NativeFields.capture(g),held:held,personal:PlainData.copy(personal),room:access.keyFor(g.loc),roomEpoch:roomEpoch,weaponEpoch:weaponEpoch,ack:ack,x:g.X,y:g.Y,dx:g.dx,dy:g.dy,hp:g.hp,maxhp:g.maxhp,mana:g.mana,
            direction:g.storona,sx:v.scaleX,sy:v.scaleY,pose:v.osn.currentFrame,
            body:v.osn.body.currentFrame,visual:VisualPose.capture(v as DisplayObject),weapon:weapon,steps:steps,motion:id==1?GroundMotion.capture(g):null};
      }
      public function destroy():void {
         sight.dispose();
         context.ctr.clearAll();
         access.scope.unregister(context);
         if(unit!=null)unit.levitPoss=originalLevitPoss;
         if(owned && unit!=null) {
            unit.remVisual();
            var list:Array=unit.loc.units,index:int=list.indexOf(unit);
            if(index>=0)list.splice(index,1);
            if(unit.pet!=null) {
               var pet:Object=unit.pet;pet.remVisual();pet.disabled=true;pet.sost=4;
               if(pet.loc!=null){pet.loc.remObj(pet);index=pet.loc.units.indexOf(pet);if(index>=0)pet.loc.units.splice(index,1);}
            }
            unit.disabled=true;unit.sost=4;unit.hp=0;
            unit.onDeath=null;unit.context=null;unit.scope=null;
         }
      }
   }
}

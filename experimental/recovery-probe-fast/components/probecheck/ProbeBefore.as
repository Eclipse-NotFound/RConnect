package probecheck {
   import flash.display.DisplayObject;
   import fe.unit.Unit;
   import fe.Pt;
   import fe.serv.Interact;
   import fe.weapon.Weapon;
   import fe.weapon.Bullet;
   public class ProbeBefore {
private static const NATIVE_UNIT_FIELDS:Object={X:true,Y:true,X1:true,X2:true,Y1:true,Y2:true,
         loc:true,nobj:true,pobj:true,in_chain:true,stay:true,sloy:true,dx:true,dy:true,vis:true,
         id:true,animState:true,blitData:true,disabled:true,sost:true,hp:true,maxhp:true,shithp:true,
         hpbar:true,doop:true,unres:true,invulner:true,isVis:true,isSats:true,invis:true,
         levit:true,levitPoss:true,fracLevit:true,fraction:true,scX:true,scY:true,storona:true,
         currentWeapon:true,prior:true,priorUnit:true,onCursor:true,celX:true,celY:true,celUnit:true,
         inter:true,trigDis:true,armor_hp:true,demask:true,isSit:true,noise:true,overLook:true,
         stealthMult:true,visibility:true,scrDie:true,scrAlarm:true,questId:true,
         massa:true,massaMove:true,levit_max:true,levit_r:true,t_throw:true,isFly:true,isLaz:true,
         nazv:true,level:true,npc:true,noAgro:true};
private static const NATIVE_POINT_FIELDS:Object={loc:true,nobj:true,pobj:true,in_chain:true,
         stay:true,X:true,Y:true,sloy:true,dx:true,dy:true,vis:true};
private static const NATIVE_INTERACT_FIELDS:Object={owner:true,action:true,prob:true,allact:true,
         userAction:true,scrAct:true,scrOpen:true,scrClose:true,scrTouch:true};
public static function probe(o:Object, name:String):*
      {
         if(o==null)return null;
         if(o is Unit && NATIVE_UNIT_FIELDS[name]===true
            || o is Pt && NATIVE_POINT_FIELDS[name]===true
            || o is Interact && NATIVE_INTERACT_FIELDS[name]===true) {
            var value:*=o[name];return value===undefined?null:value;
         }
         // These native hierarchies cannot also be flash.utils.Proxy. A missing
         // timeline child/public name can be rejected without a catch scope;
         // existing getters still take the protected read below. Even native
         // DisplayObject getters such as width may be overridden by a subclass.
         if((o is Pt || o is DisplayObject || o is Interact) && !(name in o))return null;
         return probeOptional(o,name);
      }
private static function probeOptional(o:Object,name:String):*
      {
         try
         {
            if(!(name in o))return null;
            var v:* = o[name];
            return (v === undefined) ? null : v;
         }
         catch(err:*)
         {
            return null;
         }
      }
   }
}

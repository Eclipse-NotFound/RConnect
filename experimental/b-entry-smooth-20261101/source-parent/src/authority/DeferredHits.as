package authority {
   import flash.utils.Dictionary;
   /** Retain native hit arguments, not a second copy of the damage formula.
    * Only the host can consume the ordered ledger, once, during replay. */
   public final class DeferredHits {
      private static const BULLET:Array=["damage","armorMult","pier","probiv","critCh","critDamMult","critInvis","desintegr",
         "X","Y","dx","dy","vel","weapId"];
      private static const WEAPON:Array=["id","dopEffect","dopCh","dopDamage","ammoFire"];
      private static const PERS:Array=["damPony","damZombie","damRobot","damInsect","damMonster","damAlicorn"];
      private var host:HostSession,entries:Array=[],cursor:int=0;
      private var piercing:Dictionary=new Dictionary(true);
      public var queued:uint=0,applied:uint=0,discarded:uint=0,total:Number=0;
      public function DeferredHits(host:HostSession){this.host=host;}
      private static function read(object:Object,names:Array):Object {
         var result:Object={};if(object!=null)for each(var key:String in names)if(key in object)result[key]=object[key];return result;
      }
      private static function write(object:Object,fields:Object):void {if(object!=null)for(var key:String in fields)object[key]=fields[key];}
      public function add(frame:int,target:Object,amount:Number,type:int,bullet:Object,periodic:Boolean,source:Object):Boolean {
         if(amount<=0 || !isFinite(amount) || target==null || target.invulner)return false;
         var owner:Object=bullet!=null?bullet.owner:source;
         var actor:PlayerActor=null,life:int=-1;
         for(var depth:int=0;owner!=null && depth<=4;depth++) {
            actor=host.combat.actor(owner);if(actor!=null)break;
            owner=NativeAccess.get(owner,"owner");
         }
         for each(var a:PlayerActor in host.actors)if(a.unit===target)life=a.epoch;
         if(actor==null || bullet==null && (target===actor.unit || periodic))return false;
         if(entries.length>=32768)throw new Error("Deferred native hit ledger exceeded its bounded capacity");
         entries.push({frame:frame,target:target,life:life,room:target.loc,owner:actor,epoch:actor.epoch,
            amount:amount,type:type,periodic:periodic,bullet:bullet,bulletOwner:bullet==null?null:bullet.owner,bulletFields:read(bullet,BULLET),
            weapon:bullet==null?null:bullet.weap,weaponFields:read(bullet==null?null:bullet.weap,WEAPON),pers:read(actor.unit.pers,PERS)});
         ++queued;return true;
      }
      public function through(frame:int):void {
         while(cursor<entries.length && int(entries[cursor].frame)<=frame) {
            // Consume before invoking native code: an error cannot replay the
            // same hit again, and its original exception stops the session.
            var hit:Object=entries[cursor++],a:PlayerActor=hit.owner,target:Object=hit.target;
            if(a.epoch!=hit.epoch || a.unit.loc.land!==hit.room.land){++discarded;continue;}
            var stale:Boolean=false;
            if(hit.life>=0)for each(var member:PlayerActor in host.actors)if(member.unit===target && member.epoch!=hit.life)stale=true;
            if(stale || target.loc!==hit.room || target.sost>2 || target.hp<=0){++discarded;continue;}
            var b:Object=hit.bullet,old:Object=read(b,BULLET),oldW:Object=read(hit.weapon,WEAPON),oldP:Object=read(a.unit.pers,PERS);
            var oldOwner:Object=b==null?null:b.owner,oldWeapon:Object=b==null?null:b.weap;
            var amount:Number=hit.amount;
            try {
               write(b,hit.bulletFields);write(hit.weapon,hit.weaponFields);write(a.unit.pers,hit.pers);
               if(b!=null) {
                  // Keep the real projectile owner (including pets/mines).
                  // Player scope selects resources; it must not change the
                  // native damage formula by turning a mine into a player.
                  b.owner=hit.bulletOwner;b.weap=hit.weapon;
                  // Native armor and penetration mutate the projectile's
                  // damage. Carry that result to this projectile's later hit.
                  if(b.probiv>0 && piercing[b]!=null && Number(hit.bulletFields.damage)>0) {
                     amount*=Number(piercing[b])/Number(hit.bulletFields.damage);b.damage=Number(piercing[b]);
                  }
               }
               var dealt:Number=Number(host.access.scope.runRoom(a.context,hit.room,function():Number {
                  return target.damage(amount,int(hit.type),b,Boolean(hit.periodic));
               }));
               if(b!=null && b.probiv>0)piercing[b]=b.damage;
               ++applied;total+=dealt;
            }finally {write(b,old);write(hit.weapon,oldW);write(a.unit.pers,oldP);if(b!=null){b.owner=oldOwner;b.weap=oldWeapon;}}
         }
      }
      public function clear():void {entries=[];cursor=0;piercing=new Dictionary(true);}
      public function get pending():int{return entries.length-cursor;}
   }
}

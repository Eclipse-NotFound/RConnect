package fa {
    /** Blade damage is independent of the firearm's damage, ammo and on-hit effects. */
    public class BayonetCombat {
        public var impulse:BayonetImpulse=new BayonetImpulse();
        /** Native velocity is coordinates per logic step. Sample before damage/slow responses. */
        public function impact(owner:*,target:*,spec:Object):Object {
            var dx:Number=velocity(owner,"dx")-velocity(target,"dx"),dy:Number=velocity(owner,"dy")-velocity(target,"dy");
            var speed:Number=Math.sqrt(dx*dx+dy*dy);
            var rate:Number=setting(spec,"speedBonusPerUnit",4,20),cap:Number=setting(spec,"speedBonusCap",100,300);
            // Zero explicitly disables the bonus, including at extreme velocities.
            var bonus:Number=rate>0&&cap>0?Math.min(speed*rate,cap):0;
            return {relativeSpeed:speed,multiplier:1+bonus/100};
        }
        private function velocity(unit:*,key:String):Number {
            if(!unit||!unit.hasOwnProperty(key))return 0;
            var n:Number=Number(unit[key]);return isFinite(n)?n:0;
        }
        private function setting(spec:Object,key:String,fallback:Number,max:Number):Number {
            var value:*=spec?spec[key]:undefined,n:Number=Number(value);
            return value===null||value is Boolean||!isFinite(n)?fallback:Math.max(0,Math.min(max,n));
        }
        public function hit(w:*,gun:*,spec:Object,target:*,active:Boolean,x:Number,y:Number,BulletClass:Class):Object {
            var p:*=w.pers, owner:*=w.gg;
            var motion:Object=impact(owner,target,spec);
            var base:Number=active?spec.damage:spec.passive;
            var scale:Number=Number(p.weaponSkills[1])*Number(p.meleeDamMult)*Number(p.allDamMult);
            if(p.hasOwnProperty("acuteDam"))scale*=Number(p.acuteDam);
            // Same over-level scaling as native melee, using the blade's reference tier.
            scale*=1+Math.max(0,Number(p.getWeapLevel(1))-Number(spec.skillTier))*.1;
            var add:Number=p.hasOwnProperty("acuteDet")?Number(p.acuteDet):0;
            var damage:Number=(base+add)*scale*motion.multiplier;
            var token:*=new BulletClass(owner,x,y,null,false);
            token.weapId=String(spec.reference); // Never inherit a gun's ammoFire/dopEffect.
            token.tipDamage=1; // Unit.D_BLADE; 0 is a bullet, not a blade.
            token.damage=damage;
            token.pier=Number(active?spec.pier:spec.passivePier)+(p.hasOwnProperty("acutePier")?Number(p.acutePier):0);
            token.armorMult=1;
            if(active) {
                token.critCh=Math.max(0,Math.min(1,.1+Number(owner.critCh)+(p.hasOwnProperty("acuteCritch")?Number(p.acuteCritch):0)));
                token.critDamMult=Number(owner.critDamMult);
                token.critInvis=Number(owner.critInvis);
            }
            var before:Number=Number(target.hp);
            target.damage(damage,token.tipDamage,token,false);
            var push:Object=impulse.apply(owner,target,spec,active,motion.relativeSpeed,token);
            return {damage:damage,loss:before-Number(target.hp),pier:token.pier,active:active,
                relativeSpeed:motion.relativeSpeed,speedMultiplier:motion.multiplier,push:push};
        }
    }
}

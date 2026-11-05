package
{
   import flash.utils.Dictionary;

   // Read-only model of Unit.udarBullet / Unit.damage (host 1.02).
   // Only deferred hits advance this ledger; real HP, armor, RNG and ammo are untouched.
   public final class SandyDamagePredictor
   {
      private var defenses:Dictionary = new Dictionary();

      public function SandyDamagePredictor() { }
      public function reset():void { defenses = new Dictionary(); }
      private function probability(n:Number):Number { return Math.max(0, Math.min(1, n)); }

      public function hitChance(b:Object, u:Object):Number
      {
         var p:Number = b.miss > 0 ? probability(1 - b.miss) : 1;
         // Native hit gate short-circuits before dodge/accuracy in these cases.
         if (u.dexter <= 0 || (b.precision <= 0 && b.tipBullet == 0)) return p;
         if (b.tipBullet == 1) return p * probability(1 - u.dodge);
         if (b.tipBullet != 0) return 0;
         return p * probability(b.accuracy() / (u.dexter + u.dexterPlus + 0.05));
      }

      public function estimate(b:Object, u:Object, damage:Number, remainingHP:Number,
                               spread:Boolean, commit:Boolean = false):Number
      {
         if (u.invulner || damage <= 0 || !isFinite(damage)) return 0;
         var type:int = b.tipDamage;
         var p:Number = hitChance(b, u);
         if (p <= 0) return 0;
         var raw:Number = damage;
         if (type >= 0 && type < u.vulner.length) raw *= u.vulner[type];
         if (b.owner != null && b.owner.player && u.opt != null)
         {
            var pers:Object = b.owner.pers;
            if (u.opt.pony) raw *= pers.damPony;
            if (u.opt.zombie) raw *= pers.damZombie;
            if (u.opt.robot) raw *= pers.damRobot;
            if (u.opt.insect) raw *= pers.damInsect;
            if (u.opt.monster) raw *= pers.damMonster;
            if (u.opt.alicorn) raw *= pers.damAlicorn;
         }
         if (type == 9 && !u.stay && !u.inWater && u.isLaz == 0) raw *= 0.5;
         if (raw <= 0 || !isFinite(raw) || (type == 7 && u.sost != 1)) return 0;

         var state:Object = defenses[u];
         if (state == null) state = { armorHP: Number(u.armor_hp), quality: probability(u.armor_qual), shieldHP: Number(u.shithp) };
         var armorHP:Number = state.armorHP;
         var quality:Number = state.quality;
         var shieldHP:Number = state.shieldHP;
         var shieldArmor:Number = u.shitArmor;
         // turret3 creates this shield inside damage(), so no persistent field exposes it.
         var turret:Boolean = String(u.id).indexOf("turret3") == 0;
         if (turret)
         {
            shieldHP = 1000; shieldArmor = 25;
            if (b.weap != null && b.weap.tip == 1)
            {
               if ((u.X - b.weap.X) * u.storona > 25) shieldArmor = 0;
            }
            else if (b.dx * u.storona > 0) shieldArmor = 0;
         }
         var physical:Boolean = type == 0 || type == 1 || type == 2 || type == 4 || type == 10 || type == 14;
         var energy:Boolean = type == 3 || type == 5 || type == 6 || type == 9 || type == 11 || type == 18;
         var skin:Number = physical || energy ? u.skin : 0;
         var armor:Number = physical ? u.armor : (energy ? u.marmor : 0);
         var wearsArmor:Boolean = !u.player && armorHP > 0 && (u.armor > 0 || u.marmor > 0)
            && ((type <= 15 && type != 8 && type != 12 && type != 13) || type == 18);
         var crit:Number = probability(b.critCh);
         var sneak:Number = !u.doop && u.celUnit != b.owner ? probability(b.critInvis) : 0;
         var disintegrate:Number = type == 5 || type == 6 ? probability(b.desintegr) : 0;
         var allMult:Number = type != 12 && type != 13 && type != 100 ? u.allVulnerMult : 1;
         var total:Number = 0, armorAfter:Number = 0, qualityAfter:Number = 0, shieldAfter:Number = 0;
         // Fixed midpoint integration of the native 0.7..1.3 damage roll. Bounded work,
         // no RNG consumption; in testDam mode native damage has no spread either.
         var samples:int = spread ? 9 : 1;
         for (var i:int = 0; i < samples; i++)
         {
            var hit:Number = raw * (spread ? 0.7 + 0.6 * (i + 0.5) / samples : 1);
            var ah:Number = armorHP, aq:Number = quality;
            if (wearsArmor && (shieldHP <= 0 || hit > shieldArmor))
            {
               var wear:Number = hit - (shieldHP > 0 ? shieldArmor : 0);
               if (b.armorMult > 1) wear /= b.armorMult;
               if (type == 10) wear *= 4;
               else if (type == 4) wear *= 2;
               ah = Math.max(0, ah - wear);
               if (ah == 0) aq = 0; // Break removes armor on THIS hit, before reduction.
            }
            var baseDR:Number = skin + (shieldHP > 0 ? shieldArmor : 0);
            var bare:Number = Math.max(0, hit - Math.max(0, baseDR * b.armorMult - b.pier));
            var covered:Number = Math.max(0, hit - Math.max(0, (baseDR + armor) * b.armorMult - b.pier));
            // Average outcomes, not armor points: max(0, damage - E[armor]) is biased low.
            total += (1 - aq) * afterArmor(bare, crit, b.critDamMult, sneak, disintegrate, remainingHP)
                     + aq * afterArmor(covered, crit, b.critDamMult, sneak, disintegrate, remainingHP);
            armorAfter += ah;
            qualityAfter += aq;
            shieldAfter += Math.max(0, shieldHP - hit);
         }
         if (commit)
         {
            // Mean defense state for the next deferred hit. Misses spend no durability.
            state.armorHP = armorHP * (1 - p) + armorAfter / samples * p;
            state.quality = quality * (1 - p) + qualityAfter / samples * p;
            if (!turret) state.shieldHP = shieldHP * (1 - p) + shieldAfter / samples * p;
            defenses[u] = state;
         }
         return Math.max(0, total / samples * allMult * p);
      }

      private function afterArmor(hit:Number, crit:Number, multiplier:Number, sneak:Number,
                                  disintegrate:Number, hp:Number):Number
      {
         if (disintegrate <= 0) return hit * (1 + crit * (multiplier - 1)) * (1 + sneak);
         return (1 - crit) * ((1 - sneak) * disintegrated(hit, disintegrate, hp) + sneak * disintegrated(hit * 2, disintegrate, hp))
              + crit * ((1 - sneak) * disintegrated(hit * multiplier, disintegrate, hp) + sneak * disintegrated(hit * multiplier * 2, disintegrate, hp));
      }
      private function disintegrated(hit:Number, chance:Number, hp:Number):Number
      {
         return hit > 0 && hp <= hit * 10 ? hit * (1 + chance * 11) : hit;
      }
   }
}
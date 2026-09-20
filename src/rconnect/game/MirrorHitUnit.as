package rconnect.game
{
   import fe.unit.Unit;
   import fe.weapon.Bullet;

   /** Native collision/mitigation without native AI, death scripts or loot.
    *  Kept only in loc.units, never added to the loc.firstObj step chain. */
   public class MirrorHitUnit extends Unit
   {
      public static const DEFENSE:Array = ["maxhp","skin","armor","marmor","armor_hp",
         "armor_qual","shithp","shitArmor","allVulnerMult","vulner","dexter","dexterPlus",
         "dodge","invulner","transp","opt","mech","blood","mat","maxShok","showNumbs"];
      private var target:Object;
      private var inDamage:Boolean=false;
      private var feedback:HitFeedback = new HitFeedback();

      public function MirrorHitUnit(target:Object)
      {
         super(); this.target=target;
         var self:Object=this;
         self.id="rconnect_hit_"+String(target.id);
         self.doop=true; self.unres=true; self.npc=true; self.warn=0; self.xp=0;
         sync();
      }

      public function sync():void
      {
         if(inDamage) return;
         var self:Object=this;
         for each(var name:String in DEFENSE)
         {
            var value:*=GameBridge.probe(target,name);
            if(value!=null) self[name]=value is Array ? (value as Array).concat() : value;
         }
         for each(name in ["loc","X","Y","X1","X2","Y1","Y2","scX","scY","storona","fraction","hp","sost","trigDis"])
         {
            value=GameBridge.probe(target,name);
            if(value!=null) self[name]=value;
         }
         self.disabled=self.sost>=3;
      }

      override public function damage(amount:Number,type:int,bullet:Bullet=null,periodic:Boolean=false):Number
      {
         // Only the local character's attacks are authoritative client input.
         var self:Object=this;
         if(bullet!=null && GameBridge.probe(bullet,"owner")!==GameBridge.probe(self.loc,"gg")) return 0;
         sync();
         var before:Number=self.hp;
         var shieldBefore:Number=self.shithp;
         var show:Boolean=self.showNumbs;
         inDamage=true;
         var result:Number=0;
         // The native accumulator expires only in Unit.actions, which this receiver
         // deliberately never runs. Own number lifetime without enabling native AI.
         self.showNumbs=false;
         try { result=super.damage(amount,type,bullet,periodic); }
         finally
         {
            // Keep the real loss even if a native particle/UI callback throws.
            var loss:Number=Math.max(0,before-Number(self.hp));
            target.hp=Number(target.hp)-loss;
            target.armor_hp=self.armor_hp; target.armor_qual=self.armor_qual; target.shithp=self.shithp;
            self.showNumbs=show;
            if(show) feedback.show(target,loss,Math.max(0,shieldBefore-Number(self.shithp)));
            inDamage=false;
         }
         try { target.visDetails(); } catch(err:*) {}
         return result;
      }

      override public function die(type:int=0):*
      {
         // Host death snapshot is the sole owner of death/quest/loot outcomes.
      }

      public function dispose():void
      {
         var self:Object=this;
         var room:Object=GameBridge.probe(self,"loc");
         if(room!=null && room.units is Array)
         {
            var index:int=room.units.indexOf(this);
            if(index>=0) room.units.splice(index,1);
         }
         self.disabled=true;
      }
   }
}

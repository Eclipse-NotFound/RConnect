package {
   import fe.unit.UnitRaider;
   import rconnect.game.GameBridge;
   public class A22CollisionRaider extends UnitRaider {
      public static var observed:Function;
      public function A22CollisionRaider() {super("1",10,<unit weap="lmg"/>,null);}
      private function sample():Object {
         var s:Object={},u:Object=this;
         for each(var key:String in ["X","Y","dx","dy","t_throw","levit","hp","invulner","damWall","damWallSpeed","massa","knocked","aiNapr","levitaccel"])
            s[key]=GameBridge.probe(u,key);
         return s;
      }
      override public function damageWall(direction:int=0):* {
         var before:Object=sample();
         var result:*=super.damageWall(direction);
         if(observed!=null)observed("wall",this,before,sample(),{direction:direction});
         return result;
      }
      override public function attack():* {
         var before:Object=sample(),u:Object=this,other:Object=GameBridge.probe(u,"celUnit");
         var otherBefore:Object={};
         for each(var key:String in ["id","X","Y","dx","dy","massa","knocked","neujaz"])
            otherBefore[key]=GameBridge.probe(other,key);
         var result:*=super.attack();
         var after:Object=sample();
         if(observed!=null && (before.dx!=after.dx || before.dy!=after.dy))
            observed("attack-momentum",this,before,after,{before:otherBefore,collisionTip:GameBridge.probe(u,"collisionTip")});
         return result;
      }
      override public function control():* {
         var before:Object=sample(),result:*=super.control(),after:Object=sample();
         if(observed!=null && Number(before.levit)>0 && (before.dx!=after.dx || before.dy!=after.dy))
            observed("held-native-control",this,before,after,null);
         return result;
      }
      override public function step():* {
         var before:Object=sample(),result:*=super.step();
         if(observed!=null && Number(before.t_throw)>0)
            observed("native-step",this,before,sample(),null);
         return result;
      }
   }
}

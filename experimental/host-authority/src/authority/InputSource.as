package authority {
   public class InputSource {
      public var seq:int=0,action:int=0;
      public function frame(world:Object,session:String,player:int,room:String):Object {
         var c:Object=world.ctr,b:int=0,a:Array=[];
         if(c.keyLeft)b|=Commands.LEFT;if(c.keyRight)b|=Commands.RIGHT;if(c.keyJump)b|=Commands.JUMP;
         if(c.keyAttack)b|=Commands.FIRE;if(c.keySit)b|=Commands.SIT;if(c.keyRun)b|=Commands.RUN;
         if(c.keyReload){a.push({id:++action,type:"reload"});c.keyReload=false;}
         return {type:"input",session:session,player:player,room:room,epoch:1,weaponEpoch:1,
            seq:++seq,buttons:b,aimX:Number(world.celX),aimY:Number(world.celY),actions:a};
      }
   }
}

package authority {
   import flash.utils.Dictionary;
   /** B1's bounded native invocation scope. No permanent World.gg replacement.
    * These are synchronous calls only; objects retain their own owner/context. */
   public class NativeScope {
      private static const FIELDS:Array=["gg","pers","invent","ctr","sats","gui","loc","land","app","alicorn","hardInv","celX","celY","calcMass","calcMassW","checkLoot","t_battle","grafon","cam","visual","vfon","vscene"];
      private static const PENDING:Array=["calcMass","calcMassW","checkLoot","t_battle"];
      private static const LAND:Array=["loc","gg","locX","locY","locZ","prob","loc_t"];
      private var owners:Dictionary=new Dictionary(true);
      public var world:Object;
      public var roomServices:Function;
      private var appearance:Object;
      public var depth:int=0;
      public function NativeScope(world:Object,appearance:Object=null){this.world=world;this.appearance=appearance;}
      public function register(context:Object):void {owners[context.gg]=context;}
      public function unregister(context:Object):void {if(owners[context.gg]===context)delete owners[context.gg];}
      public function runRoom(context:Object,room:Object,operation:Function):* {
         var oldRoom:Object=context.loc,oldLand:Object=context.land;
         try {context.loc=room;context.land=room.land;return run(context,operation);}
         finally {context.loc=oldRoom;context.land=oldLand;}
      }
      private function capturePending(context:Object):void {
         for each(var name:String in PENDING)context[name]=world[name];
      }
      public function run(context:Object,operation:Function):* {
         var previous:Object={},name:String,room:Object=context.loc,roomPlayer:Object=room==null?null:room.gg;
         var returning:Object=owners[world.gg];
         // Capture the active owner before suspending it, including a nested
         // call. Its live flags may have changed since this context was entered.
         if(returning!=null)capturePending(returning);
         var oldAppearance:Object=appearance==null?null:AppearanceState.capture(appearance);
         var services:Object=roomServices==null || room==null?null:roomServices(room);
         var land:Object=services==null?null:room.land,priorLand:Object={};
         for each(name in FIELDS)previous[name]=world[name];
         if(land!=null)for each(name in LAND)priorLand[name]=land[name];
         ++depth;
         try {
            for each(name in FIELDS)if(context.hasOwnProperty(name))world[name]=context[name];
            if(services!=null) {
               for each(name in ["grafon","cam","visual","vfon","vscene"])world[name]=services[name];
               land.loc=room;land.gg=context.gg;land.locX=room.landX;land.locY=room.landY;land.locZ=room.landZ;
               land.prob=room.landProb;land.loc_t=context.transitionCooldown==null?0:context.transitionCooldown;
            }
            if(appearance!=null && context.appearance!=null)AppearanceState.apply(appearance,context.appearance);
            if(room!=null && context.gg!=null)room.gg=context.gg;
            return operation();
         } finally {
            if(context.gg!=null)capturePending(context);
            if(room!=null)room.gg=roomPlayer;
            if(oldAppearance!=null) {
               if(context.appearance!=null)context.appearance=AppearanceState.capture(appearance);
               AppearanceState.apply(appearance,oldAppearance);
            }
            for each(name in FIELDS)world[name]=previous[name];
            if(land!=null)for each(name in LAND)land[name]=priorLand[name];
            // A nested call can dirty the suspended player's inventory. Do not
            // lose that work by restoring the older primitive flag snapshot.
            if(returning!=null)for each(name in PENDING)world[name]=returning[name];
            --depth;
         }
      }
   }
}

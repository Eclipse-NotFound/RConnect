package authority {
   import flash.utils.Dictionary;
   /** B1's bounded native invocation scope. No permanent World.gg replacement.
    * These are synchronous calls only; objects retain their own owner/context. */
   public class NativeScope {
      private static const FIELDS:Array=["gg","pers","invent","ctr","sats","gui","loc","land","app","alicorn","hardInv","celX","celY","calcMass","calcMassW","checkLoot"];
      private static const PENDING:Array=["calcMass","calcMassW","checkLoot"];
      private var owners:Dictionary=new Dictionary(true);
      public var world:Object;
      private var appearance:Object;
      public var depth:int=0;
      public function NativeScope(world:Object,appearance:Object=null){this.world=world;this.appearance=appearance;}
      public function register(context:Object):void {owners[context.gg]=context;}
      public function unregister(context:Object):void {if(owners[context.gg]===context)delete owners[context.gg];}
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
         for each(name in FIELDS)previous[name]=world[name];
         ++depth;
         try {
            for each(name in FIELDS)if(context.hasOwnProperty(name))world[name]=context[name];
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
            // A nested call can dirty the suspended player's inventory. Do not
            // lose that work by restoring the older primitive flag snapshot.
            if(returning!=null)for each(name in PENDING)world[name]=returning[name];
            --depth;
         }
      }
   }
}

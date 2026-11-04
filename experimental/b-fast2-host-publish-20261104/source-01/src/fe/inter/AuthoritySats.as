package fe.inter {
   public final class AuthoritySats {
      public static function plan(queue:Array,keyFor:Function):Array {
         var result:Array=[];
         for each(var c:SatsCel in queue)result.push({target:c.un==null?0:keyFor(c.un.u),x:Object(c).X,y:Object(c).Y});
         return result;
      }
   }
}

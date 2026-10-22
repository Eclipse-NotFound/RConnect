package rconnect.game {
   import fe.serv.Item;

   /** Preserve the owner's item roll; Item's fourth constructor arg is variant,
    *  and its save() omits the damaged-container durability multiplier. */
   public final class GroundItemState {
      private static const EXTRA:Array=["multHP","shpun","imp","noref","nocheap","hardinv"];
      private static const SAVED:Array=["kol","sost","barter","lvl","trig"];

      public static function capture(item:Object):Object {
         if(item==null)return null;
         var data:Object=item.save();
         for each(var key:String in EXTRA)if(key in item)data[key]=item[key];
         return data;
      }

      public static function restore(data:Object,base:String=""):Item {
         var id:String=data!=null && data.id!=null?String(data.id):base;
         if(id==null || id=="")return null;
         var item:Object=new Item(data==null || data.tip==null?null:String(data.tip),id,
            data==null?1:int(data.kol),data==null?0:int(data.variant));
         if(data!=null) {
            for each(var key:String in SAVED)if(key in data)item[key]=data[key];
            for each(key in EXTRA)if(key in data)item[key]=data[key];
         }
         return item as Item;
      }
   }
}

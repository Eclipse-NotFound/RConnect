package authority {
   import flash.geom.ColorTransform;
   /** Native appearance clips read class statics while advancing their frames. */
   public class AppearanceState {
      private static const FIELDS:Array=["trFur","trHair","trHair1","trEye","trMagic","trBlack",
         "visHair1","fEye","fHair","ggArmorId","hideMane","transp"];
      public static function capture(type:Object,cloneColors:Boolean=false):Object {
         var result:Object={};
         for each(var name:String in FIELDS) {
            var value:*=type[name];
            if(cloneColors && value is ColorTransform) {
               var c:ColorTransform=value as ColorTransform;
               value=new ColorTransform(c.redMultiplier,c.greenMultiplier,c.blueMultiplier,c.alphaMultiplier,
                  c.redOffset,c.greenOffset,c.blueOffset,c.alphaOffset);
            }
            result[name]=value;
         }
         return result;
      }
      public static function apply(type:Object,state:Object):void {
         for each(var name:String in FIELDS)type[name]=state[name];
      }
   }
}

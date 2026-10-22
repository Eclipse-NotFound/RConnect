package rconnect.game {
 /** BitmapData exposes straight ARGB, but stores premultiplied channels.
  * A directly reused getPixel32 value can be rounded down a second time by
  * setPixel32. Return the setter input for the original observable channel.
  * Logical/wire colors are never changed; only the native write is adapted.
  */
 public final class NativeWallColor {
  private static function channel(c:int,a:int):int {
   var premult:int=int((c*a+254)/255);
   return int((premult*255+a-1)/a);
  }
  public static function setter(value:uint):uint {
   var a:int=value>>>24;
   if(a==255)return value;
   if(a==0)return 0;
   return uint(a<<24|channel(value>>>16&255,a)<<16|channel(value>>>8&255,a)<<8|channel(value&255,a));
  }
 }
}

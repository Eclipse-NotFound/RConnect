package rconnect.game {
 import flash.display.BitmapData;
 import flash.geom.Rectangle;
 public final class NativeWallColor {
  private static var inverse:Array=[];
  /** Preserve native straight ARGB exactly through its premultiplied storage.
   * Query this AIR runtime once per used alpha, rather than assuming a rounding
   * formula. At most 256 small tables; no cache of image pixels or room objects.
   */
  private static function table(a:int):Vector.<int> {
   var found:Vector.<int>=inverse[a] as Vector.<int>;
   if(found!=null)return found;
   found=new Vector.<int>(256,true);
   var values:Vector.<uint>=new Vector.<uint>(256,true),i:int;
   for(i=0;i<256;i++){found[i]=-1;values[i]=uint(a<<24|i<<16|i<<8|i);}
   var b:BitmapData=new BitmapData(256,1,true,0);
   try {
    b.setVector(b.rect,values);values=b.getVector(b.rect);
    for(i=0;i<256;i++)found[int(values[i]&255)]=i;
   }finally{b.dispose();}
   inverse[a]=found;return found;
  }
  private static function channel(c:int,lookup:Vector.<int>):int {
   // Malformed/non-native colors retain the old setter semantics.
   return lookup[c]<0?c:lookup[c];
  }
  public static function setter(value:uint):uint {
   var a:int=value>>>24;
   if(a==255)return value;
   if(a==0)return 0;
   var lookup:Vector.<int>=table(a);
   return uint(a<<24|channel(value>>>16&255,lookup)<<16|channel(value>>>8&255,lookup)<<8|channel(value&255,lookup));
  }
 }
}

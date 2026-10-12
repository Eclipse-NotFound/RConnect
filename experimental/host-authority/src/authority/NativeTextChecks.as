package authority {
   import flash.display.BitmapData;
   import flash.display.DisplayObject;
   import flash.display.MovieClip;
   import flash.geom.Matrix;
   import flash.text.TextField;
   /** Real authored damage-number text, including overflow and AIR scroll state. */
   public final class NativeTextChecks {
      public static function describe(t:TextField):Object {
         return {plain:t.text,html:t.htmlText,color:t.textColor,multiline:t.multiline,wrap:t.wordWrap,
            width:t.width,height:t.height,scrollH:t.scrollH,scrollV:t.scrollV,maxScrollH:t.maxScrollH,
            maxScrollV:t.maxScrollV,autoSize:t.autoSize,embed:t.embedFonts,antiAlias:t.antiAliasType,
            grid:t.gridFitType,sharpness:t.sharpness,thickness:t.thickness};
      }
      private static function bitmap(d:DisplayObject):BitmapData {
         var b:BitmapData=new BitmapData(180,80,true,0);b.draw(d,new Matrix(1,0,0,1,60,40));return b;
      }
      public static function run(a:NativeAccess,check:Function):void {
         var Type:Class=a.visualClass("visualNumb");
         for each(var words:String in ["78","1000000","-123456","MISS"]) {
            var original:MovieClip=new Type() as MovieClip,copy:MovieClip=new Type() as MovieClip;
            original.stop();copy.stop();original.numb.text=words;original.cacheAsBitmap=true;
            VisualPose.apply(copy,VisualPose.capture(original));
            var first:BitmapData=bitmap(original),second:BitmapData=bitmap(copy),difference:*=first.compare(second);
            check(difference===0,"authored native damage number preserves pixels including text overflow: "+words,
               {source:describe(original.numb),actual:describe(copy.numb)});
            if(difference is BitmapData)BitmapData(difference).dispose();
            first.dispose();second.dispose();VisualPose.dispose(original);VisualPose.dispose(copy);
         }
      }
   }
}

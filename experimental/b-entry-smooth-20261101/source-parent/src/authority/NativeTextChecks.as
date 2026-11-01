package authority {
   import flash.display.BitmapData;
   import flash.display.DisplayObject;
   import flash.display.MovieClip;
   import flash.geom.Matrix;
   import flash.text.TextField;
   import flash.text.TextFieldAutoSize;
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
         stability(a,check);
      }
      /** A confirmation import and the following transform-only redraw must
       * have the same final text position, including native autosize layouts. */
      public static function stability(a:NativeAccess,check:Function):void {
         for each(var mode:String in [TextFieldAutoSize.CENTER,TextFieldAutoSize.RIGHT]) {
            var source:TextField=new TextField(),target:TextField=new TextField();
            source.autoSize=target.autoSize=mode;source.multiline=target.multiline=false;
            source.text="initial";target.text="different width initially";
            var stable:Boolean=true,details:Object=null;
            for(var i:int=0;i<24;i++) {
               source.text=["78","1000000","MISS","Long NPC response",""][i%5];
               source.x=17+i*.25;source.y=-13+i*.125;
               var pose:Object=VisualPose.capture(source);
               VisualPose.apply(target,pose);
               var applied:Matrix=target.transform.matrix,expected:Matrix=source.transform.matrix;
               VisualPose.motion(target,pose);
               var motion:Matrix=target.transform.matrix;
               if(applied.tx!==expected.tx || applied.ty!==expected.ty || motion.tx!==applied.tx || motion.ty!==applied.ty) {
                  stable=false;if(details==null)details={mode:mode,iteration:i,expected:[expected.tx,expected.ty],
                     confirmed:[applied.tx,applied.ty],motion:[motion.tx,motion.ty]};
               }
            }
            check(stable,"text autosize import does not oscillate between confirmation and motion: "+mode,details);
            VisualPose.dispose(source);VisualPose.dispose(target);
         }
         for each(var symbol:String in ["visualNumb","visReplic","visReplic2"]) {
            var Type:Class=a.visualClass(symbol),original:MovieClip=new Type(),copy:MovieClip=new Type();
            original.stop();copy.stop();
            var text:TextField=symbol=="visualNumb"?original.numb:original.text.text;
            var exact:Boolean=true;
            for(i=0;i<12;i++) {
               text.text=i%2==0?"78":"NPC response";
               pose=VisualPose.capture(original);VisualPose.apply(copy,pose);
               var first:BitmapData=bitmap(copy);
               VisualPose.motion(copy,pose);
               var second:BitmapData=bitmap(copy),difference:*=first.compare(second);
               if(difference!==0)exact=false;
               if(difference is BitmapData)BitmapData(difference).dispose();
               first.dispose();second.dispose();
            }
            check(exact,"native number/speech confirmation and motion preserve identical pixels: "+symbol);
            VisualPose.dispose(original);VisualPose.dispose(copy);
         }
      }
   }
}

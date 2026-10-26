package {
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.MovieClip;
   import flash.display.Sprite;
   import flash.geom.Matrix;
   import flash.geom.Point;
   import flash.system.ApplicationDomain;
   import flash.text.TextField;
   import flash.text.TextFieldAutoSize;

   /** External regression for the actual native TextField coordinate contract.
    * The geometry stays fixed while alpha changes across two confirmations. */
   public final class BTextInterpolationChecks {
      public static function run(mod:Object,domain:ApplicationDomain,check:Function):void {
         var Pose:Object=domain.getDefinition("authority.VisualPose");
         var Tween:Object=domain.getDefinition("authority.PoseTween");
         var differentGetter:Boolean=false;
         for each(var symbol:String in ["visualNumb","visReplic","visReplic2"]) {
            var Type:Class=mod.access.visualClass(symbol),source:MovieClip=new Type(),target:MovieClip=new Type();
            source.gotoAndStop(symbol=="visualNumb"?4:1);target.stop();
            source.x=310;source.y=180;source.scaleX=source.scaleY=1.9512195121951224;
            var text:TextField=findText(source);
            if(text==null)throw new Error("Missing authored text in "+symbol);
            text.text=symbol=="visualNumb"?"78":"B native NPC speech";
            differentGetter=exercise(Pose,Tween,source,target,text,symbol,check) || differentGetter;
         }
         for each(var mode:String in [TextFieldAutoSize.CENTER,TextFieldAutoSize.RIGHT]) {
            var original:TextField=new TextField(),copy:TextField=new TextField();
            original.autoSize=copy.autoSize=mode;original.multiline=copy.multiline=true;
            original.text="Native autosize 78";original.x=310.25;original.y=180.4;
            differentGetter=exercise(Pose,Tween,original,copy,original,"autosize-"+mode,check) || differentGetter;
         }
         check(differentGetter,"text interpolation: real AIR fixture distinguishes TextField x/y from matrix translation");
      }
      private static function exercise(Pose:Object,Tween:Object,source:DisplayObject,target:DisplayObject,text:TextField,label:String,check:Function):Boolean {
         var board:Sprite=new Sprite();board.addChild(source);board.addChild(target);
         text.alpha=1;
         var a:Object=Pose.capture(source),before:Point=text.localToGlobal(new Point()),nativeMatrix:Matrix=text.transform.matrix;
         var gapX:Number=text.x-nativeMatrix.tx,gapY:Number=text.y-nativeMatrix.ty;
         text.alpha=.6;
         var b:Object=Pose.capture(source),after:Point=text.localToGlobal(new Point());
         check(before.equals(after),"text interpolation: alpha-only fixture leaves native geometry fixed: "+label);
         var worst:Number=0,first:Object=null,steps:int=0;
         for each(var fraction:Number in [0,.01,.25,.5,.9,.99,1]) {
            var recipe:Object=Tween.pose(a,b,fraction);
            Pose.apply(target,recipe);
            var actualText:TextField=findText(target),actual:Point=actualText.localToGlobal(new Point());
            var error:Number=Math.max(Math.abs(actual.x-before.x),Math.abs(actual.y-before.y));
            ++steps;worst=Math.max(worst,error);
            if(error>.11 && first==null)first={fraction:fraction,expected:[before.x,before.y],actual:[actual.x,actual.y],
               sourceGetter:[text.x,text.y],sourceMatrix:[nativeMatrix.tx,nativeMatrix.ty],pose:a,next:b,interpolated:recipe};
         }
         check(worst<=.11,"text interpolation: fixed native geometry does not drift through alpha tween: "+label,
            {steps:steps,maximumError:worst,getterMatrixDifference:[gapX,gapY],firstError:first});
         Pose.dispose(source);Pose.dispose(target);board.removeChildren();
         return Math.abs(gapX)>.1 || Math.abs(gapY)>.1;
      }
      private static function findText(display:DisplayObject):TextField {
         if(display is TextField)return display as TextField;
         var parent:DisplayObjectContainer=display as DisplayObjectContainer;
         if(parent!=null)for(var i:int=0;i<parent.numChildren;i++) {
            var text:TextField=findText(parent.getChildAt(i));if(text!=null)return text;
         }
         return null;
      }
   }
}

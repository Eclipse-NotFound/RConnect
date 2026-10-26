package authority {
   import flash.display.Bitmap;
   import flash.display.BitmapData;
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.MovieClip;
   import flash.display.Shape;
   import flash.filters.GlowFilter;
   import flash.geom.ColorTransform;
   import flash.geom.Matrix;
   import flash.geom.Rectangle;
   import flash.text.TextField;
   import flash.utils.getQualifiedClassName;
   import flash.utils.getTimer;
   /** Experimental checks only. No live world object is modified or stepped. */
   public final class VisualMotionChecks {
      private static function fixture():MovieClip {
         var root:MovieClip=new MotionCheckClip(),child:MovieClip=new MotionCheckClip();
         child.name="limb";child.x=18;root.addChild(child);return root;
      }
      private static function same(a:DisplayObject,b:DisplayObject):Boolean {
         if(!VisualPose.recipeEqual(VisualPose.capture(a),VisualPose.capture(b)))return false;
         var bounds:Rectangle=a.getBounds(a).union(b.getBounds(b));
         if(bounds.left < -250 || bounds.top < -250 || bounds.right > 250 || bounds.bottom > 250)
            throw new Error("Pixel fixture exceeds its uncropped comparison surface");
         var left:BitmapData=new BitmapData(512,512,true,0),right:BitmapData=new BitmapData(512,512,true,0);
         var difference:*,equal:Boolean=false;
         try {
            left.draw(a,new Matrix(1,0,0,1,256,256));right.draw(b,new Matrix(1,0,0,1,256,256));
            difference=left.compare(right);equal=difference===0;
         }finally {if(difference is BitmapData)BitmapData(difference).dispose();left.dispose();right.dispose();}
         return equal;
      }
      private static function pair(pose:Object,gold:DisplayObject,candidate:DisplayObject):Boolean {
         VisualPose.apply(gold,pose);
         var fast:Boolean=VisualPose.motionIfReady(candidate,pose);
         if(!fast)VisualPose.apply(candidate,pose);
         return fast;
      }
      public static function run(access:NativeAccess,check:Function):void {
         var oldResolve:Function=VisualPose.resolve;
         VisualPose.resolve=function(name:String):Class {
            return name=="authority::MotionCheckClip"?MotionCheckClip:access.visualClass(name);
         };
         try {
            var source:MovieClip=fixture(),gold:MovieClip=fixture(),candidate:MovieClip=fixture();
            var pose:Object=VisualPose.capture(source),fast:Boolean=pair(pose,gold,candidate);
            check(!fast && same(gold,candidate),"motion requires a completed initial full pose");
            var allFast:Boolean=true,allEqual:Boolean=true;
            for(var i:int=0;i<24;i++) {
               source.x=i*.25;source.y=-i*.125;source.rotation=i;
               source.alpha=1-i/48;source.getChildAt(0).rotation=-i*2;
               pose=VisualPose.capture(source);fast=pair(pose,gold,candidate);
               allFast=allFast && fast;allEqual=allEqual && same(gold,candidate);
            }
            check(allFast && allEqual,"existing stopped native trees use motion with identical pose and pixels");
            for each(var change:String in ["rootColor","childColor","rootFilter","childFilter","blend","cache","removedChild","replacementChild"]) {
               VisualPose.apply(gold,pose);VisualPose.apply(candidate,pose);
               mutate(gold,change);mutate(candidate,change);
               fast=pair(pose,gold,candidate);
               check(!fast && same(gold,candidate),"local discrete mutation forces complete restoration: "+change);
            }
            var added:MovieClip=new MotionCheckClip();added.name="managed";added.x=-25;source.addChild(added);
            pose=VisualPose.capture(source);pair(pose,gold,candidate);
            source.removeChild(added);pose=VisualPose.capture(source);fast=pair(pose,gold,candidate);
            check(!fast && same(gold,candidate),"obsolete managed child still receives full cleanup");
            VisualPose.dispose(source);VisualPose.dispose(gold);VisualPose.dispose(candidate);
            for each(var kind:String in ["text","vector","pixels"])conservative(kind,check);
            for each(var symbol:String in ["visualBullet","visualNumb","visReplic","visReplic2"])checkNative(access,symbol,check);
         }finally {VisualPose.resolve=oldResolve;}
      }
      private static function mutate(d:MovieClip,kind:String):void {
         var child:DisplayObject=d.getChildByName("limb");
         if(kind=="rootColor")d.transform.colorTransform=new ColorTransform(.5,1,1,1,30);
         else if(kind=="childColor")child.transform.colorTransform=new ColorTransform(1,.5,1,1,0,30);
         else if(kind=="rootFilter")d.filters=[new GlowFilter(0xFF0000,1,7,7)];
         else if(kind=="childFilter")child.filters=[new GlowFilter(0x00FF00,1,7,7)];
         else if(kind=="blend")d.blendMode="add";
         else if(kind=="cache")d.cacheAsBitmap=!d.cacheAsBitmap;
         else if(kind=="removedChild")d.removeChild(child);
         else if(kind=="replacementChild") {d.removeChild(child);var replacement:MovieClip=new MotionCheckClip();replacement.name="limb";d.addChild(replacement);}
      }
      private static function conservative(kind:String,check:Function):void {
         var source:MovieClip=fixture(),gold:MovieClip=fixture(),candidate:MovieClip=fixture();
         if(kind=="text"){var text:TextField=new TextField();text.text="No skipped text import";text.name="extra";source.addChild(text);}
         else if(kind=="vector"){var shape:Shape=new Shape();shape.graphics.beginFill(0xFF0000);shape.graphics.drawRect(0,0,8,8);shape.name="extra";source.addChild(shape);}
         else {var bitmap:Bitmap=new Bitmap(new BitmapData(8,8,true,0xFF00FF00));bitmap.name="extra";source.addChild(bitmap);}
         // Shape under an authored MovieClip is deliberately absent from the
         // native recipe; test its dynamic graphics as the root instead.
         if(kind=="vector") {
            var goldShape:Shape=new Shape(),candidateShape:Shape=new Shape();
            var vectorPose:Object=VisualPose.capture(shape);
            pair(vectorPose,goldShape,candidateShape);
            var fastVector:Boolean=pair(vectorPose,goldShape,candidateShape);
            check(!fastVector && same(goldShape,candidateShape),"dynamic graphics retain complete apply");
            VisualPose.dispose(goldShape);VisualPose.dispose(candidateShape);
         }else {
            var pose:Object=VisualPose.capture(source,0,kind=="pixels");pair(pose,gold,candidate);
            var fast:Boolean=pair(pose,gold,candidate);
            check(!fast && same(gold,candidate),"text/pixel subtree retains complete apply: "+kind);
         }
         VisualPose.dispose(source);VisualPose.dispose(gold);VisualPose.dispose(candidate);
         if(bitmap!=null && bitmap.bitmapData!=null)bitmap.bitmapData.dispose();
      }
      private static function checkNative(access:NativeAccess,symbol:String,check:Function):void {
         var Type:Class=access.visualClass(symbol),source:MovieClip=new Type(),gold:MovieClip=new Type(),candidate:MovieClip=new Type();
         source.stop();gold.stop();candidate.stop();
         var exact:Boolean=true,fastCount:uint=0;
         for(var i:int=0;i<12;i++) {
            source.x=i/4;source.y=-i/8;source.alpha=1-i/24;
            if(symbol=="visualNumb")source.numb.text=i%2==0?"78":"1000000";
            else if(symbol=="visReplic" || symbol=="visReplic2")source.text.text.text=i%2==0?"Short":"A longer native NPC response";
            var pose:Object=VisualPose.capture(source);
            if(pair(pose,gold,candidate))++fastCount;
            if(!same(gold,candidate))exact=false;
         }
         check(exact,"authored native tree keeps full-apply pixels: "+symbol,{fast:fastCount});
         if(source.totalFrames>1) {
            pose=VisualPose.capture(source);VisualPose.apply(gold,pose);VisualPose.apply(candidate,pose);
            gold.play();candidate.play();var fast:Boolean=pair(pose,gold,candidate);
            check(!fast && same(gold,candidate),"locally restarted native timeline is stopped again: "+symbol);
            gold.gotoAndStop(2);candidate.gotoAndStop(2);fast=pair(pose,gold,candidate);
            check(!fast && same(gold,candidate),"local native frame change receives full restore: "+symbol);
         }
         VisualPose.dispose(source);VisualPose.dispose(gold);VisualPose.dispose(candidate);
      }
      /** For the parent's real body/weapon/projectile probe. Capture only the
       * already observed source display; mutate neither world nor animation.
       * Returns alternating batch totals, not a claimed runtime speedup. */
      public static function benchmark(source:DisplayObject,resolve:Function,repetitions:int=250):Object {
         var oldResolve:Function=VisualPose.resolve;VisualPose.resolve=resolve;
         var gold:DisplayObject,candidate:DisplayObject,result:Object;
         try {
            var Type:Class=resolve(getQualifiedClassName(source));
            gold=new Type() as DisplayObject;candidate=new Type() as DisplayObject;
            var pose:Object=VisualPose.capture(source),rows:Array=[],motions:Array=[];
            for(var sample:int=0;sample<16;sample++) {
               var moving:Object=PoseTween.copy(pose);moving.x+=sample*.25;moving.y-=sample*.125;
               if(pose.m!=null){moving.m=pose.m.concat();moving.m[4]=moving.x;moving.m[5]=moving.y;}
               motions.push(moving);
            }
            VisualPose.apply(gold,pose);VisualPose.apply(candidate,pose);
            for(var warm:int=0;warm<20;warm++)pair(pose,gold,candidate);
            for(var round:int=0;round<8;round++) {
               var fullMS:int=0,guardedMS:int=0,fastCount:uint=0;
               for(var order:int=0;order<2;order++) {
                  var guarded:Boolean=(round%2==0?order==1:order==0),began:int=getTimer();
                  for(var i:int=0;i<repetitions;i++) {
                     moving=motions[i%motions.length];
                     if(guarded) {if(VisualPose.motionIfReady(candidate,moving))++fastCount;else VisualPose.apply(candidate,moving);}
                     else VisualPose.apply(gold,moving);
                  }
                  if(guarded)guardedMS=getTimer()-began;else fullMS=getTimer()-began;
               }
               rows.push({round:round,fullMs:fullMS,guardedMs:guardedMS,fast:fastCount,n:repetitions,equal:same(gold,candidate)});
            }
            result={symbol:getQualifiedClassName(source),rows:rows};
         }finally {VisualPose.dispose(gold);VisualPose.dispose(candidate);VisualPose.resolve=oldResolve;}
         return result;
      }
   }
}

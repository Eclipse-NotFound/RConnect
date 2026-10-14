package authority {
   import flash.display.*;
   import flash.geom.*;
   import flash.filters.*;
   import flash.text.TextField;
   import flash.utils.getTimer;
   /** Same-object, alternating-order comparison with the frozen B190 reader. */
   public final class PoseProfile {
      public static function run(access:NativeAccess,check:Function):void {
         var enabled:Boolean=Timing.enabled;Timing.enabled=false;
         try {transitions(check);measure(access,check);}finally {Timing.enabled=enabled;}
      }
      private static function transitions(check:Function):void {
         var root:Sprite=new Sprite(),limb:Sprite=new Sprite(),text:TextField=new TextField();
         var data:BitmapData=new BitmapData(12,12,true,0x8040ff20),bitmap:Bitmap=new Bitmap(data);
         root.addChild(limb);limb.addChild(text);limb.addChild(bitmap);
         text.name="number";bitmap.name="surface";
         var equal:Boolean=true,retained:Array=[],saved:Array=[],first:int=-1;
         for(var step:int=0;step<96;step++) {
            root.transform.matrix=new Matrix(step%2?-1:1,.125+step%3/4,.25-step%5/4,1+step%7/4,step%7,step%11);
            limb.transform.colorTransform=new ColorTransform(step%3/2,step%7/6,step%9/8,step%5/4,step%17,step%13,step%11,step%19);
            root.visible=step%9!=0;limb.visible=step%7!=0;root.alpha=step%6==0?0:1;
            limb.filters=step%4==0?[]:[new GlowFilter(0x20ff80,step%5/4,4,7,2,1,step%2==0)];
            if(step%11==0)limb.filters=[new ColorMatrixFilter([1,0,0,0,step,0,1,0,0,0,0,0,1,0,0,0,0,0,1,0]),new BlurFilter(3,5)];
            text.htmlText=step%2?"<b>108</b>":"<font color='#20ff80'>72</font>";
            bitmap.smoothing=step%2==0;bitmap.pixelSnapping=step%3==0?"always":"auto";
            data.fillRect(data.rect,uint(0x80000000+step*1000));
            limb.graphics.clear();limb.graphics.beginFill(0x40aaff);limb.graphics.drawRect(0,0,step%13+1,9);limb.graphics.endFill();
            if(bitmap.parent==null)limb.addChild(bitmap);
            if(step%2)limb.setChildIndex(bitmap,0);else limb.setChildIndex(text,0);
            if(step%5==0)limb.removeChild(bitmap);
            text.name="number"+(step%3);
            var pixels:Boolean=step%3!=0;
            var old:Object=PreviousPose190.capture(root,0,pixels),now:Object=VisualPose.capture(root,0,pixels);
            if(!VisualPose.recipeEqual(old,now)){equal=false;if(first<0)first=step;}
            if(step%8==0){retained.push(now);saved.push(copy(now));}
            // Capture without changing native state must retain the exact record.
            if(now!==VisualPose.capture(root,0,pixels)){equal=false;if(first<0)first=step;}
         }
         var immutable:Boolean=true;
         for(var i:int=0;i<retained.length;i++)if(!VisualPose.recipeEqual(retained[i],saved[i]))immutable=false;
         check(equal,"paired B190 pose capture preserves transforms, filters, visibility, child order, text and pixel modes",{steps:96,firstDifference:first});
         check(immutable,"paired pose changes leave all retained confirmations immutable",{retained:retained.length});
         VisualPose.dispose(root);data.dispose();
      }
      private static function copy(value:Object):Object {
         var bytes:flash.utils.ByteArray=new flash.utils.ByteArray();bytes.writeObject(value);bytes.position=0;return bytes.readObject();
      }
      private static function measure(access:NativeAccess,check:Function):void {
         var Type:Class=access.definition("fe.unit.UnitZombie"),values:Array=[],units:Array=[];
         for(var i:int=0;i<80;i++) {
            var u:Object=new Type("1",10,<unit tr="1" dig="0"/>,null);units.push(u);
            if(u.vis!=null)values.push(u.vis);
            if(u.hpbar!=null)values.push(u.hpbar);
         }
         check(values.length>=80,"paired pose benchmark uses real native enemy display objects",{objects:values.length});
         for each(var mode:String in ["stable","moving","alternating"]) {
            var beforeMs:Array=[],afterMs:Array=[],equal:Boolean=true;
            for each(var visual:DisplayObject in values){PreviousPose190.capture(visual);VisualPose.capture(visual);}
            for(var round:int=0;round<24;round++) {
               var old:Array=[],now:Array=[],began:int;
               if(round%2==0) {
                  began=getTimer();sample(values,mode,round,true,old);beforeMs.push(getTimer()-began);
                  began=getTimer();sample(values,mode,round,false,now);afterMs.push(getTimer()-began);
               }else {
                  began=getTimer();sample(values,mode,round,false,now);afterMs.push(getTimer()-began);
                  began=getTimer();sample(values,mode,round,true,old);beforeMs.push(getTimer()-began);
               }
               for(i=0;i<old.length;i++)if(!VisualPose.recipeEqual(old[i],now[i]))equal=false;
            }
            check(equal,"paired native enemy pose capture remains equal: "+mode);
            Log.write("pose-profile",{mode:mode,objects:values.length,callsPerChunk:values.length*4,chunks:24,
               previous:stats(beforeMs),current:stats(afterMs),previousChunks:beforeMs,currentChunks:afterMs,
               note:"Alternating same-object B190/current capture cost, not whole-game FPS."});
         }
         for each(visual in values)VisualPose.dispose(visual);
      }
      private static function sample(values:Array,mode:String,round:int,previous:Boolean,out:Array):void {
         for(var repeat:int=0;repeat<4;repeat++)for(var i:int=0;i<values.length;i++) {
            var visual:DisplayObject=values[i];
            if(mode=="moving" || mode=="alternating" && round%2==0){visual.x=i+round*4+repeat;visual.y=i%4+repeat;}
            out[i]=previous?PreviousPose190.capture(visual):VisualPose.capture(visual);
         }
      }
      private static function stats(values:Array):Object {
         var sorted:Array=values.concat();sorted.sort(Array.NUMERIC);var total:int=0;
         for each(var ms:int in values)total+=ms;
         return {totalMs:total,meanMs:total/values.length,p50Ms:sorted[int(sorted.length*.5)],p95Ms:sorted[int(sorted.length*.95)]};
      }
   }
}

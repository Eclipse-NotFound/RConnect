package authority {
 import flash.display.*;
 import flash.filters.GlowFilter;
 import flash.geom.ColorTransform;
 import flash.geom.Matrix;
 import flash.utils.getTimer;
 import flash.utils.ByteArray;
 /** Existing external micro runner entry; capture-only comparison on the SAME native object. */
 public final class VisualMotionChecks {
  private static function differences(a:*,b:*,path:String,nonfinite:Array,out:Array):void {
   if(a is ByteArray || b is ByteArray){if(!(a is ByteArray && b is ByteArray && PixelSurface.sameBytes(a,b)))out.push({path:path,a:"bytes",b:"different bytes"});return;}
   if(a is Number && b is Number && isNaN(a) && isNaN(b)){nonfinite.push(path);return;}
   if(a===b){if(a===0 && 1/a!==1/b)out.push({path:path,a:String(1/a),b:String(1/b)});return;}
   if(a==null || b==null || typeof a!="object" || typeof b!="object" || (a is Array)!=(b is Array)) {
    out.push({path:path,a:String(a),b:String(b)});return;
   }
   if(a is Array && a.length!=b.length)out.push({path:path+".length",a:a.length,b:b.length});
   for(var key:String in b) {
    if(!a.hasOwnProperty(key))out.push({path:path+"."+key,a:"missing",b:String(b[key])});
    else differences(a[key],b[key],path+"."+key,nonfinite,out);
   }
   for(key in a)if(!b.hasOwnProperty(key))out.push({path:path+"."+key,a:String(a[key]),b:"missing"});
  }
  public static function run(access:Object,check:Function):void {
   var fixture:ScalarFixture=new ScalarFixture(),before:Object,refBefore:Object,history:Array=[],refHistory:Array=[];
   var exact:Boolean=true,deltaExact:Boolean=true,immutable:Boolean=true;
   var saved:Array=[];
   for(var i:int=0;i<160;i++) {
    fixture.integer=i%7;fixture.unsigned=i*3;fixture.flag=i%2==0;
    fixture.number=i%8==0?NaN:i%8==1?Infinity:i%8==2?-Infinity:i%8==3?-0:i/3;
    fixture.text=i%3==0?null:i%3==1?"":"test"+i;
    fixture.anything=i%5==0?{}:i%5==1?null:i%5==2?false:i%5==3?i:"s";
    fixture.object=i%4==0?[]:i%4==1?i:i%4==2?"":true;
    var ref:Object=ReferenceNativeFields.capture(fixture),state:Object=NativeFields.capture(fixture);
    exact=exact && ReferenceVisualPose.recipeEqual(ref,state);
    if(before!=null) {
     var d:Object=NativeFields.delta(before,state),rd:Object=ReferenceNativeFields.delta(refBefore,ref);
     deltaExact=deltaExact && ((d==null)==(rd==null));
     if(d!=null && rd!=null)deltaExact=deltaExact && ReferenceVisualPose.recipeEqual(d.updates,rd.updates) && ReferenceVisualPose.recipeEqual(d.removed,rd.removed);
     // Another object's records, a non-immediate baseline and a reconstructed
     // equal-looking object must never borrow this exact-baseline optimization.
     deltaExact=deltaExact && NativeFields.delta({},state)==null;
     if(history.length>1)deltaExact=deltaExact && NativeFields.delta(history[history.length-2],state)==null;
    }
    history.push(state);refHistory.push(ref);saved.push(JSON.stringify(state));before=state;refBefore=ref;
    exact=exact && NativeFields.capture(fixture)===state && ReferenceNativeFields.capture(fixture)===ref;
   }
   for(i=0;i<history.length;i++)immutable=immutable && JSON.stringify(history[i])===saved[i];
   check(exact,"scalar capture and unchanged identity exactly match reference",{captures:320});
   check(deltaExact,"weak successor hints accept only exact previous scalar state",{transitions:159});
   check(immutable,"all retained scalar records remain immutable",{records:160});
   // Inspect retained transitions again after many later captures.
   var retained:Boolean=true;
   for(i=1;i<history.length;i++)retained=retained && NativeFields.delta(history[i-1],history[i])!=null;
   check(retained,"older retained adjacent scalar records keep their delta hint");
   var data:BitmapData=new BitmapData(16,16,true,0xff2468ac),b:Bitmap=new Bitmap(data),sprite:Sprite=new Sprite();sprite.addChild(b);
   exact=true;
   for(i=0;i<96;i++) {
    b.transform.matrix=new Matrix(1+i%3*.1,i%5*.1,-i%7*.1,i%2?-1:1,i-40,20-i);
    b.transform.colorTransform=new ColorTransform(1,i%4*.2,.7,1,i%9,0,0,0);
    b.alpha=i%8/7;b.visible=i%3!=0;b.smoothing=i%2==0;b.pixelSnapping=["auto","never","always"][i%3];
    b.cacheAsBitmap=i%2==0;b.blendMode=i%2?"normal":"add";b.filters=i%4==0?[new GlowFilter(0xff0000,.5,4,4)]:[];
    data.setPixel32(i%16,int(i/16),0xff000000+i*437);
    for each(var withPixels:Boolean in [false,true,false]) {
     ref=ReferenceVisualPose.capture(sprite,0,withPixels);state=VisualPose.capture(sprite,0,withPixels);
     exact=exact && ReferenceVisualPose.recipeEqual(ref,state);
    }
   }
   check(exact,"bitmap leaf colors, transforms, filters, pixels and hidden parents exactly match",{captures:288});
   sprite.removeChild(b);VisualPose.dispose(b);ReferenceVisualPose.dispose(b);data.dispose();
   var actor:Object=access.world.gg;
   var fieldRows:Array=[],repeats:int=500;
   for(var round:int=0;round<8;round++) {
    var refMs:int=0,fastMs:int=0,refFinal:Object,fastFinal:Object;
    for(var order:int=0;order<2;order++) {
     var reference:Boolean=(round+order)%2==0,started:int=getTimer();
     for(i=0;i<repeats;i++) {
      // X is restored before returning; no game step sees the artificial pose.
      var oldX:Number=actor.X;actor.X=oldX+(i%2==0?1:-1);
      if(reference)refFinal=ReferenceNativeFields.capture(actor);else fastFinal=NativeFields.capture(actor);
      actor.X=oldX;
     }
     if(reference)refMs=getTimer()-started;else fastMs=getTimer()-started;
    }
    fieldRows.push({referenceMs:refMs,candidateMs:fastMs,equal:ReferenceVisualPose.recipeEqual(refFinal,fastFinal)});
   }
   check(true,"native moving UnitPlayer scalar micro timing (not gameplay FPS)",{repeats:repeats,rows:fieldRows});
   FrameCloneChecks.run(actor,check);
  }
  public static function benchmark(display:DisplayObject,resolve:Function,repetitions:int):Object {
   var rows:Array=[],exact:Boolean=true;
   // Warm both independent captures of the same real display. No second
   // clone/auto-instance-name comparison and no native animation advancement.
   for(var warm:int=0;warm<40;warm++){ReferenceVisualPose.capture(display);VisualPose.capture(display);}
   for(var round:int=0;round<8;round++) {
    var referenceMs:int=0,candidateMs:int=0,ref:Object,fast:Object;
    for(var order:int=0;order<2;order++) {
     var reference:Boolean=(round+order)%2==0,started:int=getTimer();
     for(var i:int=0;i<repetitions;i++) {
      if(reference)ref=ReferenceVisualPose.capture(display);else fast=VisualPose.capture(display);
     }
     if(reference)referenceMs=getTimer()-started;else candidateMs=getTimer()-started;
    }
    // A just-created native weapon can still have NaN coordinates before its
    // first native animation step. Preserve and report matching NaNs explicitly;
    // numeric NaN !== NaN alone must not invent a difference between captures.
    var nonfinite:Array=[],diff:Array=[];differences(ref,fast,"pose",nonfinite,diff);
    exact=exact && diff.length==0;
    rows.push({referenceMs:referenceMs,candidateMs:candidateMs,equal:exact,identicalNonfinite:nonfinite,differences:diff});
   }
   return {repetitions:repetitions,rows:rows};
  }
 }
}

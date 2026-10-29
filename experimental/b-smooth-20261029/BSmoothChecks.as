package {
 import flash.system.ApplicationDomain;
 import flash.display.Sprite;
 import flash.display.MovieClip;
 import flash.display.BitmapData;
 import flash.geom.Matrix;
 import flash.geom.ColorTransform;
 import flash.filters.GlowFilter;
 import flash.text.TextField;
 import flash.utils.ByteArray;
 import flash.utils.getQualifiedClassName;
 public final class BSmoothChecks {
  private static function wire(v:Object):Object {var b:ByteArray=new ByteArray();b.writeObject(v);b.position=0;return b.readObject();}
  public static function run(domain:ApplicationDomain,check:Function):void {
   var V:Object=domain.getDefinition("authority.VisualPose");
   var P:Object=domain.getDefinition("authority.PoseTween");
   var F:Class=domain.getDefinition("authority.FrameDelta") as Class;
   var H:Object=domain.getDefinition("authority.HealthBarPose");
   BVisualReferenceChecks.bind(domain.getDefinition("authority.Timing"),domain.getDefinition("authority.PixelSurface"),domain.getDefinition("authority.VectorDraw"));
   BHealthReferenceChecks.bind(BVisualReferenceChecks);
   var root:Sprite=new Sprite(),limb:Sprite=new Sprite(),text:TextField=new TextField();
   limb.name="limb";text.name="label";limb.addChild(text);root.addChild(limb);text.text="100";
   var encoder:Object=new F(),decoder:Object=new F(),history:Array=[],frozen:Array=[];
   var previous:Object,valid:Boolean=true,immutable:Boolean=true,blend:Boolean=true,hints:int=0;
   var actual:Sprite=new Sprite(),reference:Sprite=new Sprite(),pictures:Boolean=true;
   for(var i:int=0;i<48;i++) {
    root.x=i%4==0?0:i*1.25;root.alpha=i%8==0?.5:1;root.visible=i%9!=0;
    limb.transform.matrix=new Matrix(i%3?-1:1,0.1,0.2,1,i%7,i%5);
    limb.rotation=i%2?42:-42;limb.visible=i%6!=0;
    text.text=String(100+i);text.textColor=i%2?0xff00ff:0x00ff00;
    root.filters=i%3==0?[new GlowFilter(0x00ffff,.6,4,4)]:[];
    root.transform.colorTransform=new ColorTransform(1,.8,1,root.alpha,i%4,0,0,0);
    limb.graphics.clear();if(i%2) {limb.graphics.beginFill(0x4488ff);limb.graphics.drawRect(0,0,i+1,3);limb.graphics.endFill();}
    if(i%5==0 && text.parent!=null)limb.removeChild(text);else if(text.parent==null)limb.addChild(text);
    var pose:Object=V.capture(root),frame:Object={session:"check",pose:pose};
    // Local renderer writes must be repaired even when the next packet reuses
    // the exact same recipe identity. Compare real output to the old renderer.
    V.apply(actual,pose);BVisualReferenceChecks.apply(reference,pose);
    actual.alpha=.13;actual.filters=[new GlowFilter(0xff0000,1,1,1)];
    actual.transform.colorTransform=new ColorTransform(.5,.4,.3,.2,2,3,4,5);
    actual.x+=13;V.apply(actual,pose);
    pictures=pictures && samePicture(actual,reference);
    if(previous!=null) {
     if(V.delta(previous,pose)!=null)hints++;
     for each(var fraction:Number in [0,.125,.5,.875,1])
      blend=blend && V.recipeEqual(P.pose(previous,pose,fraction),BSmoothReferenceChecks.pose(previous,pose,fraction));
    }
    var packet:Object=wire(encoder.encode(frame)),decoded:Object=decoder.decode(packet);
    valid=valid && V.recipeEqual(frame,decoded);
    for(var k:int=0;k<history.length;k++)immutable=immutable && V.recipeEqual(history[k],frozen[k]);
    history.push(decoded);frozen.push(wire(decoded));previous=pose;
   }
   check(hints>20,"smooth: actual capture provenance exercised",{hints:hints});
   check(valid,"smooth: encoded pose tuples preserve complete confirmed values");
   check(immutable,"smooth: later deltas never mutate buffered confirmations");
   check(blend,"smooth: pose interpolation equals frozen installed algorithm");
   check(pictures,"smooth: live display restoration equals frozen renderer across filters, text, geometry and visibility");
   V.dispose(root);V.dispose(actual);BVisualReferenceChecks.dispose(reference);
   var Bar:Class=domain.getDefinition("hpBar") as Class;
   var source:MovieClip=new Bar(),a:MovieClip=new Bar(),b:MovieClip=new Bar();
   var pixelsEqual:Boolean=true,modesEqual:Boolean=true,compact:int=0;
   for(i=0;i<20;i++) {
    source.x=70;source.y=30;source.visible=true;
    source.getChildByName("bar").scaleX=(i+1)/20;
    MovieClip(source.getChildByName("bar")).gotoAndStop(i+1);
    MovieClip(source.getChildByName("armor")).gotoAndStop(20-i);
    source.getChildByName("armor").visible=i%2==0;
    source.getChildByName("goldstar").visible=i%3==0;
    var state:Object=H.capture(source);if(state.kind!="full")compact++;
    var oldState:Object=BHealthReferenceChecks.capture(source);
    modesEqual=modesEqual && state.kind===oldState.kind;
    H.apply(a,state);BHealthReferenceChecks.apply(b,state);
    // Reuse the same immutable state and deliberately disturb the live copy.
    // Cached descriptions must still restore native state on every apply.
    a.getChildByName("bar").scaleX=.017;H.apply(a,state);
    var left:BitmapData=new BitmapData(160,60,true,0),right:BitmapData=new BitmapData(160,60,true,0);
    left.draw(a);right.draw(b);var difference:Object=left.compare(right);
    if(difference is BitmapData){pixelsEqual=false;BitmapData(difference).dispose();}else if(difference!==0)pixelsEqual=false;
    left.dispose();right.dispose();
   }
   check(modesEqual,"smooth: native health-bar fallback eligibility equals installed version",{compact:compact,structure:describe(source)});
   check(pixelsEqual,"smooth: native health-bar pictures equal frozen installed renderer across damage frames");
   V.dispose(source);V.dispose(a);V.dispose(b);
  }
  private static function describe(root:MovieClip):Object {
   var result:Object={cls:getQualifiedClassName(root),frames:root.totalFrames,frame:root.currentFrame,alpha:root.alpha,children:[]};
   for(var i:int=0;i<root.numChildren;i++) {
    var child:Object=root.getChildAt(i),row:Object={name:child.name,cls:getQualifiedClassName(child),filters:child.filters.length,blend:child.blendMode,
     mask:child.mask!=null,scroll:child.scrollRect!=null,scale9:child.scale9Grid!=null,slot:child.name in root && root[child.name]===child};
    if(child is MovieClip) {
     row.children=[];row.drawing=child.graphics.readGraphicsData(false).length;
     for(var j:int=0;j<child.numChildren;j++)row.children.push(getQualifiedClassName(child.getChildAt(j)));
    }
    result.children.push(row);
   }
   return result;
  }
  private static function samePicture(a:Sprite,b:Sprite):Boolean {
   var left:BitmapData=new BitmapData(220,140,true,0),right:BitmapData=new BitmapData(220,140,true,0);
   left.draw(a,new Matrix(1,0,0,1,65,65));right.draw(b,new Matrix(1,0,0,1,65,65));
   var difference:Object=left.compare(right),same:Boolean=difference===0;
   if(difference is BitmapData)BitmapData(difference).dispose();
   left.dispose();right.dispose();return same;
  }
 }
}

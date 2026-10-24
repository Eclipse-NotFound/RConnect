package {
   import flash.desktop.NativeApplication;
   import flash.display.BitmapData;
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.Shape;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.UncaughtErrorEvent;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.geom.Matrix;
   import rconnect.game.MirrorMasks;
   import rconnect.game.MirrorMasksReference;
   import rconnect.game.MirrorHitUnit;

   /** Real old/new MirrorMasks, separate display trees; synthetic ownership, not RV or game. */
   public final class MaskReferenceComponentDoc extends Sprite {
      private static const CASES:Array=["null-native","null-native-alias","detached-native",
         "self-held-native","unreferenced-native","native-other-owner","retired-alias-other-owner",
         "later-new-owner","inactive-self","release-restore","replaced-body-field",
         "standalone-release","forget-alias","copy-clean-new-owner"];
      private var assertions:Array=[],errors:Array=[],cases:Array=[];
      private var ran:Boolean=false,writing:Boolean=false;

      public function MaskReferenceComponentDoc() {
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,uncaught);
         if(stage!=null)arm();else addEventListener(Event.ADDED_TO_STAGE,added);
      }
      private function added(e:Event):void {removeEventListener(Event.ADDED_TO_STAGE,added);arm();}
      private function arm():void {addEventListener(Event.ENTER_FRAME,run);}
      private function check(ok:Boolean,label:String):void {assertions.push({passed:ok,label:label});}
      private function uncaught(e:UncaughtErrorEvent):void {
         errors.push("uncaught: "+String(e.error));check(false,"uncaught component exception");e.preventDefault();finish();
      }
      private function run(e:Event):void {
         if(ran)return;ran=true;removeEventListener(Event.ENTER_FRAME,run);
         for each(var id:String in CASES) {
            var old:Object=exercise(id,false),current:Object=exercise(id,true);
            var row:Object={caseId:id,old:old==null?null:old.report,current:current==null?null:current.report};
            if(old!=null && current!=null) {
               check(old.steps.length==current.steps.length,id+": same observation count");
               for(var i:int=0;i<Math.min(old.steps.length,current.steps.length);i++) {
                  var a:Object=old.steps[i],b:Object=current.steps[i];
                  check(a.label==b.label && JSON.stringify(a.state)==JSON.stringify(b.state),id+": ownership/visible/cache/tree equal "+a.label);
                  var difference:int=pixelDifference(a.image as BitmapData,b.image as BitmapData);
                  check(difference==0,id+": exact ARGB pixels equal "+a.label+" different="+difference);
                  a.image.dispose();b.image.dispose();
               }
            } else check(false,id+": both implementations completed");
            cases.push(row);
         }
         finish();
      }
      private function rectangle(name:String,color:uint,x:Number=8,y:Number=8):Shape {
         var v:Shape=new Shape();v.name=name;v.x=x;v.y=y;
         v.graphics.beginFill(color);v.graphics.drawRect(0,0,32,24);v.graphics.endFill();return v;
      }
      private function createFixtureMask(f:Object,name:String,reverse:Boolean=false):Shape {
         var data:BitmapData=new BitmapData(32,24,true,0);f.bitmaps.push(data);
         for(var y:int=0;y<24;y++)for(var x:int=0;x<32;x++)
            data.setPixel32(x,y,((x<16)!=reverse?0xFFFFFFFF:0x44FFFFFF));
         var s:Shape=new Shape();s.name=name;s.x=8;s.y=8;s.cacheAsBitmap=true;
         s.graphics.beginBitmapFill(data,new Matrix(),false,false);
         s.graphics.drawRect(0,0,32,24);s.graphics.endFill();f.layer.addChild(s);return s;
      }
      private function fixture(id:String):Object {
         var f:Object={id:id,root:new Sprite(),room:{id:id},active:true,bitmaps:[],steps:[],nodes:[]};
         f.root.name="fixture";addChild(f.root);
         var layers:Array=[];
         for(var i:int=0;i<4;i++){var layer:Sprite=new Sprite();layer.name="layer"+i;f.root.addChild(layer);layers.push(layer);}
         f.layer=layers[2];f.world={grafon:{visObjs:layers}};
         f.carrier=new MaskVisionCarrier();f.carrier.api={active:function(room:Object):Boolean{return room===f.room && f.active;}};
         f.root.addChild(f.carrier);
         f.view=rectangle("body",0x2266CC);f.layer.addChild(f.view);
         f.other=rectangle("other",0xCC6622,44,8);f.layer.addChild(f.other);
         f.nativeMask=createFixtureMask(f,"native");f.aliasMask=createFixtureMask(f,"alias",true);f.third=createFixtureMask(f,"later");
         // Unused fixture masks stay off-tree until explicitly involved.
         f.layer.removeChild(f.aliasMask);f.layer.removeChild(f.third);
         f.view.mask=f.nativeMask;f.view.cacheAsBitmap=true;
         f.body={vis:f.view,hpbar:null,loc:f.room};f.proxy=new MirrorHitUnit();
         f.proxy.body=f.body;f.proxy.vis=f.view;f.proxy.hpbar=null;
         f.nodes=[f.view,f.other,f.nativeMask,f.aliasMask,f.third];
         // Ordinary nested content makes actual recursive traversal nontrivial.
         var nest:Sprite=new Sprite();nest.name="nest";layers[1].addChild(nest);
         for(i=0;i<12;i++){var dot:Shape=rectangle("dot"+i,0x112233,80+i*2,40);nest.addChild(dot);}
         check(f.root.stage===stage && f.view.stage===stage,id+": fixture is attached to actual component stage");
         return f;
      }
      private function attachAlias(f:Object):void {
         if(f.aliasMask.parent==null)f.layer.addChild(f.aliasMask);
         f.view.mask=f.aliasMask;f.view.cacheAsBitmap=true;
      }
      private function setup(id:String,f:Object,sut:Object):void {
         if(id=="null-native" || id=="null-native-alias" || id=="forget-alias" || id=="copy-clean-new-owner") {
            f.view.mask=null;f.view.cacheAsBitmap=false;f.layer.removeChild(f.nativeMask);
         }
         if(id!="standalone-release")sut.register(f.body,f.proxy);
         if(id=="null-native-alias" || id=="detached-native" || id=="unreferenced-native"
            || id=="native-other-owner" || id=="retired-alias-other-owner" || id=="later-new-owner"
            || id=="forget-alias" || id=="copy-clean-new-owner")attachAlias(f);
         if(id=="detached-native")f.layer.removeChild(f.nativeMask);
         if(id=="native-other-owner") {f.other.mask=f.nativeMask;f.other.cacheAsBitmap=true;}
         sut.observe(f.room,f.world,f.root);
         if(id=="retired-alias-other-owner") {
            f.view.mask=null;f.other.mask=f.aliasMask;f.other.cacheAsBitmap=true;
         }
         if(id=="later-new-owner") {f.layer.addChild(f.third);f.view.mask=f.third;f.view.cacheAsBitmap=true;}
         if(id=="inactive-self")f.active=false;
         if(id=="release-restore" || id=="standalone-release")sut.release(f.view);
         if(id=="replaced-body-field") {
            f.replacement=rectangle("replacement",0x6633AA,44,32);f.layer.addChild(f.replacement);
            f.nodes.push(f.replacement);f.body.vis=f.replacement;
         }
      }
      private function label(v:DisplayObject):String {return v==null?"null":v.name;}
      private function nodeState(v:DisplayObject):Object {
         return {name:v.name,parent:label(v.parent),mask:label(v.mask),visible:v.visible,cache:v.cacheAsBitmap,
            x:v.x,y:v.y,a:v.alpha,onStage:v.stage!=null};
      }
      private function tree(v:DisplayObject):Array {
         var result:Array=[nodeState(v)],container:DisplayObjectContainer=v as DisplayObjectContainer;
         if(container!=null)for(var i:int=0;i<container.numChildren;i++)result=result.concat(tree(container.getChildAt(i)));
         return result;
      }
      private function observe(f:Object,name:String):void {
         var state:Object={bodyField:label(f.body.vis),nodes:[],tree:tree(f.root)};
         for each(var v:DisplayObject in f.nodes)state.nodes.push(nodeState(v));
         var bitmap:BitmapData=new BitmapData(128,80,true,0);bitmap.draw(f.root);
         var count:int=0,digest:uint=2166136261;
         for(var y:int=0;y<bitmap.height;y++)for(var x:int=0;x<bitmap.width;x++) {
            var pixel:uint=bitmap.getPixel32(x,y);if(pixel>>>24)count++;digest=uint((digest^pixel)*16777619);
         }
         f.steps.push({label:name,state:state,image:bitmap,summary:{label:name,state:state,pixelHash:digest,paintedPixels:count}});
         check(count>0,f.id+": rendered image is nonblank "+name);
      }
      private function pixelDifference(a:BitmapData,b:BitmapData):int {
         if(a.width!=b.width || a.height!=b.height)return -1;
         var count:int=0;
         for(var y:int=0;y<a.height;y++)for(var x:int=0;x<a.width;x++)if(a.getPixel32(x,y)!=b.getPixel32(x,y))count++;
         return count;
      }
      private function graphicsImage(s:Shape):BitmapData {
         var paint:Shape=new Shape();paint.graphics.copyFrom(s.graphics);
         var result:BitmapData=new BitmapData(32,24,true,0);result.draw(paint);return result;
      }
      private function expectCopy(f:Object,source:Shape,which:String):void {
         var actual:Shape=f.view.mask as Shape;
         check(actual!=null && actual!==source && actual.name=="RConnectRestoredMask" && actual.parent===f.layer,
            which+": independent attached mask copy");
         check(f.view.cacheAsBitmap,which+": copied mask keeps view bitmap cache");
         if(actual!=null) {
            var a:BitmapData=graphicsImage(actual),b:BitmapData=graphicsImage(source);
            check(pixelDifference(a,b)==0,which+": copied mask alpha/RGB equals its exact source");a.dispose();b.dispose();
         } else check(false,which+": copy pixels unavailable");
      }
      private function expected(id:String,f:Object,which:String):void {
         if(id=="null-native" || id=="inactive-self") {
            check(f.view.mask==null && !f.view.cacheAsBitmap,which+": no stale mask/cache");
         } else if(id=="null-native-alias" || id=="detached-native" || id=="forget-alias" || id=="copy-clean-new-owner") {
            expectCopy(f,f.aliasMask,which);check(!f.aliasMask.visible,which+": unreferenced retired alias hidden");
         } else if(id=="native-other-owner") {
            expectCopy(f,f.nativeMask,which);
            check(f.other.mask===f.nativeMask && f.nativeMask.visible && f.other.cacheAsBitmap,which+": other native owner is not robbed");
            check(!f.aliasMask.visible,which+": retired alias hidden after copy");
         } else if(id=="later-new-owner") {
            check(f.view.mask===f.third && f.third.parent===f.layer && f.third.visible && f.view.cacheAsBitmap,
               which+": later third-party owner/reference/cache preserved");
            check(!f.aliasMask.visible,which+": old unreferenced alias still retired");
         } else if(id=="replaced-body-field") {
            check(f.body.vis===f.replacement && f.replacement.mask==null && f.view.mask===f.nativeMask,
               which+": replaced body field not rebound to old view");
         } else {
            check(f.view.mask===f.nativeMask && f.nativeMask.visible && f.view.cacheAsBitmap,which+": exact historical native mask restored");
            if(id=="retired-alias-other-owner")check(f.other.mask===f.aliasMask && f.aliasMask.visible,
               which+": remaining-reference scan preserves retired mask's new owner");
            if(id=="unreferenced-native")check(!f.aliasMask.visible,which+": retired unused alias hidden");
         }
      }
      private function exercise(id:String,current:Boolean):Object {
         var f:Object=null,sut:Object=current?new MirrorMasks():new MirrorMasksReference();
         var which:String=id+(current?" new":" old"),result:Object=null;
         try {
            f=fixture(id);setup(id,f,sut);observe(f,"before");
            if(id=="forget-alias")sut.forget(f.body);else sut.restore(f.view);
            expected(id,f,which);observe(f,"restored");
            // restore removes its view record; a second call must not mutate the scene.
            sut.restore(f.view);observe(f,"repeat");
            check(JSON.stringify(f.steps[1].state)==JSON.stringify(f.steps[2].state),which+": repeat restore preserves ownership/visible/cache/tree");
            check(pixelDifference(f.steps[1].image,f.steps[2].image)==0,which+": repeat restore preserves exact pixels");
            if(id=="copy-clean-new-owner") {
               var copy:DisplayObject=f.view.mask;f.layer.addChild(f.third);f.view.mask=f.third;f.view.cacheAsBitmap=true;
               f.active=false;sut.clean(f.room,f.world,f.root);
               check(copy.parent==null && f.view.mask===f.third && f.view.cacheAsBitmap && f.third.visible,
                  which+": owned cleanup removes only old copy after renderer takeover");observe(f,"new-owner-clean");
            } else if(id=="null-native-alias" || id=="detached-native" || id=="native-other-owner" || id=="forget-alias") {
               copy=f.view.mask;f.active=false;sut.clean(f.room,f.world,f.root);
               check(copy.parent==null && f.view.mask==null && !f.view.cacheAsBitmap,
                  which+": active=false releases owned copy and cache");
               if(id=="native-other-owner")check(f.other.mask===f.nativeMask,which+": cleanup still preserves other owner");
               observe(f,"inactive-clean");
            }
            var summaries:Array=[];for each(var step:Object in f.steps)summaries.push(step.summary);
            result={steps:f.steps,report:{steps:summaries}};
         } catch(error:*) {
            errors.push(which+": "+String(error));check(false,which+": fixture/API exception "+String(error));
         } finally {
            if(f!=null) {
               try {
                  f.active=false;sut.reset();sut.clean(f.room,f.world,f.root);
                  if(f.root.parent!=null)f.root.parent.removeChild(f.root);
                  for each(var data:BitmapData in f.bitmaps){data.getPixel32(0,0);data.dispose();}
                  check(true,which+": source bitmap storage remained readable; fixture cleaned");
               } catch(cleanupError:*) {errors.push(which+" cleanup: "+String(cleanupError));check(false,which+": cleanup exception");}
            }
         }
         return result;
      }
      private function finish():void {
         if(writing)return;writing=true;
         var failed:int=0;for each(var a:Object in assertions)if(!a.passed)failed++;
         var result:Object={kind:"mirror-mask-reference-old-new-component",passed:failed==0,failed:failed,
            assertions:assertions,errors:errors,cases:cases,caseCount:cases.length,
            gameLoaded:false,realRVLoaded:false,syntheticVisionAPI:true,nativeMirrorHitUnitLoaded:false,
            performanceQualified:false,installed:false};
         var stream:FileStream=new FileStream();stream.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         stream.writeUTFBytes(JSON.stringify(result));stream.close();NativeApplication.nativeApplication.exit(result.passed?0:1);
      }
   }
}

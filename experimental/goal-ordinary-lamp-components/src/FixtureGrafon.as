package {
 import flash.display.Bitmap;
 import flash.display.BitmapData;
 import flash.display.Sprite;
 import flash.utils.Dictionary;
 /** Small pixel oracle; not a replacement implementation of native Grafon. */
 public dynamic class FixtureGrafon {
  public var loc:Object,sceneLarge:Boolean=false,sceneRedraws:int=10;
  public var visFront:Sprite=new Sprite(),visBack:Sprite=new Sprite();
  public var visBack2:Sprite=new Sprite(),visVoda:Sprite=new Sprite();
  public var ramT:Object={scaleY:-1},ramL:Object={scaleX:-1};
  public var failNext:Boolean=false;
  public function drawLoc(value:Object):void {paint(null);}
  public function paint(omit:Dictionary):void {
   if(failNext){failNext=false;throw new Error('injected paint failure');}
   var parents:Array=[visFront,visBack,visBack2,visVoda];
   for each(var parent:Sprite in parents){
    while(parent.numChildren){var old:Bitmap=parent.removeChildAt(0) as Bitmap;if(old)old.bitmapData.dispose();}
    var pixels:BitmapData=new BitmapData(6,4,true,0xff112233);
    for each(var bo:Object in loc.backobjs){
     if(omit!=null && omit[bo])continue;
     if(bo.vis!=null)pixels.setPixel32(bo.slot,1,bo.vis.color);
     if(bo.light!=null)pixels.setPixel32(bo.slot,2,bo.light.color);
     if(bo.erase!=null)pixels.setPixel32(bo.slot,3,0);
    }
    parent.addChild(new Bitmap(pixels));
   }
   sceneRedraws++;
  }
  public function pixels(index:int=0):BitmapData {
   return (Sprite([visFront,visBack,visBack2,visVoda][index]).getChildAt(0) as Bitmap).bitmapData;
  }
 }
}

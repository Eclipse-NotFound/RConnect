package fe.graph {
 import flash.display.BitmapData;
 import flash.geom.Rectangle;
 public class Grafon {
  public static var rconnectWallBridge:Function=null;
  public var loc:Object,sceneLarge:Boolean=true,rconnectRasterPending:Boolean=false;
  public var frontBmp:BitmapData,backBmp:BitmapData,backBmp2:BitmapData,vodaBmp:BitmapData;
  public var sceneX:int=0,sceneY:int=0,rectX:int=80,rectY:int=80;
  public var calls:int=0,throwDraw:Boolean=false,tint:uint=0;
  private var rconnectWallClips:Array=null,rconnectWallErrors:int=0;
  private var sceneScratch:Array,sceneChunks:Object={},sceneMarks:Array=[];
  private var sceneStamp:Array,sceneRasterizing:Boolean=false,sceneLastDirtyCount:int=0;
  public function Grafon(value:Object) {loc=value;value.grafon=this;sceneScratch=[new BitmapData(80,80,true,0),new BitmapData(1,1,true,0),new BitmapData(1,1,true,0),new BitmapData(1,1,true,0)];frontBmp=sceneScratch[0];backBmp=sceneScratch[1];backBmp2=sceneScratch[2];vodaBmp=sceneScratch[3];}
  public function add(x:int,y:int,w:int=80,h:int=80):Object {
   var s:Object={x:x,y:y,nativeBuffers:[new BitmapData(w,h,true,0xff555555),new BitmapData(1,1,true,0),new BitmapData(1,1,true,0),new BitmapData(1,1,true,0)],revision:0};
   sceneChunks[x+":"+y]=s;rectX=w;rectY=h;return s;
  }
  public function drop():void {for each(var s:Object in sceneChunks)for each(var b:BitmapData in s.nativeBuffers)b.dispose();sceneChunks={};}
  public function hit(area:Rectangle,color:uint):Object {sceneApply("decal",[area,color]);return sceneMarks[sceneMarks.length-1];}
  public function seed(area:Rectangle,color:uint):Object {var mark:Array=["decal",[area,color],[.1,.2],area];sceneMarks.push(mark);return mark;}
  public function historyCount():int{return sceneMarks.length;}
  public function baseClips(r:Rectangle,groups:Array):Array{return rconnectWallBaseClips(r,groups);}
  public function beforeToken(mark:Object,r:Rectangle):Object{return rconnectWallNotify("before",mark,r);}
  public function afterToken(mark:Object,r:Rectangle,token:Object):void{rconnectWallNotify("after",mark,r,token);}
  public function rebuild(bounds:Rectangle,clips:Array=null,color:uint=0):BitmapData {
   var saved:BitmapData=frontBmp,sx:int=sceneX,sy:int=sceneY;
   frontBmp=new BitmapData(bounds.width,bounds.height,true,0xff555555);sceneX=bounds.x;sceneY=bounds.y;rconnectWallClips=clips;tint=color;
   var b:BitmapData=frontBmp;
   try{sceneRestoreMarks();}finally{frontBmp=saved;sceneX=sx;sceneY=sy;rconnectWallClips=null;tint=0;}
   return b;
  }
  private function sceneCancelWarm(r:Rectangle=null):void{}
  private function sceneDecalBounds(args:Array,stamp:Array):Rectangle{return Rectangle(args[0]).clone();}
  private function sceneApplyCompactDecal(args:Array,r:Rectangle):void{draw(args,r);}
  private function sceneApplyRegionAction(kind:String,args:Array,r:Rectangle=null):void{draw(args,r);}
  private function draw(args:Array,r:Rectangle):void {
   calls++;var local:Rectangle=r.clone();local.offset(-sceneX,-sceneY);frontBmp.fillRect(local,tint?tint:uint(args[1]));
   if(throwDraw)throw new Error("fixture native paint failed");
  }
  // NATIVE_METHODS_HERE
 }
}

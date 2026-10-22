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
  public function sceneSurfaces() : Array
      {
         var result:Array = [];
         for each(var entry in this.sceneChunks)
         {
            result.push(entry);
         }
         return result;
      }
private function sceneApply(kind:String, args:Array) : void
      {
         var wallMark:Array = null;
         var wallToken:Object = null;
         var stamp:Array;
         var ox:int;
         var oy:int;
         var affected:Rectangle;
         var entry:Object;
         this.sceneLastDirtyCount = 0;
         if(kind == "decal" && args[0] == null && args[1] == null)
         {
            return;
         }
         stamp = kind == "decal" ? [Math.random(),Math.random()] : null;
         ox = this.sceneX;
         oy = this.sceneY;
         if(kind == "decal")
         {
            affected = this.sceneDecalBounds(args,stamp);
         }
         else if(kind == "paint")
         {
            affected = new Rectangle(Math.min(args[0],args[2]) - 50,Math.min(args[1],args[3]) - 50,Math.abs(args[2] - args[0]) + 100,Math.abs(args[3] - args[1]) + 100);
         }
         else if(kind == "gwall")
         {
            affected = new Rectangle(int(args[0]) * 40,int(args[1]) * 40,40,40);
         }
         else if(kind == "drawWater")
         {
            affected = new Rectangle(args[0].X * 40,args[0].Y * 40,40,80);
         }
         this.sceneCancelWarm(affected);
         if(kind == "decal" || kind == "paint" || kind == "gwall")
         {
            wallMark = [kind,args,stamp,affected];
            this.sceneMarks.push(wallMark);
            if(rconnectWallBridge != null)this.rconnectWallNotify("mark",wallMark,affected);
         }
         this.sceneRasterizing = true;
         this.sceneStamp = stamp;
         try
         {
            for each(entry in this.sceneChunks)
            {
               if(!(affected && !affected.intersects(new Rectangle(entry.x,entry.y,this.rectX,this.rectY))))
               {
                  this.frontBmp = entry.nativeBuffers[0];
                  this.backBmp = entry.nativeBuffers[1];
                  this.backBmp2 = entry.nativeBuffers[2];
                  this.vodaBmp = entry.nativeBuffers[3];
                  this.sceneX = entry.x;
                  this.sceneY = entry.y;
                  wallToken = rconnectWallBridge != null && wallMark != null ? this.rconnectWallNotify("before",wallMark,affected) : null;
                  try
                  {
                     if(kind == "decal")
                     {
                        this.sceneApplyCompactDecal(args,affected);
                     }
                     else
                     {
                        this.sceneApplyRegionAction(kind,args,affected);
                     }
                  }
                  finally {if(wallToken != null)this.rconnectWallNotify("after",wallMark,affected,wallToken);}
                  ++entry.revision;
                  ++this.sceneLastDirtyCount;
               }
            }
         }
         finally
         {
            this.frontBmp = this.sceneScratch[0];
            this.backBmp = this.sceneScratch[1];
            this.backBmp2 = this.sceneScratch[2];
            this.vodaBmp = this.sceneScratch[3];
            this.sceneX = ox;
            this.sceneY = oy;
            this.sceneRasterizing = false;
            this.sceneStamp = null;
         }
      }
private function sceneRestoreMarks() : void
      {
         var wallToken:Object;
         var item:Array;
         if(!this.sceneLarge)
         {
            return;
         }
         try
         {
            for each(item in this.sceneMarks)
            {
               this.sceneStamp = item[2];
               if(item[0] == "decal")
               {
                  if(item.length < 4 || !(item[3] is Rectangle))
                  {
                     item[3] = this.sceneDecalBounds(item[1],item[2]);
                  }
                  if(!Rectangle(item[3]).intersects(new Rectangle(this.sceneX,this.sceneY,this.rectX,this.rectY)))
                  {
                     continue;
                  }
               }
               wallToken = rconnectWallBridge != null ? this.rconnectWallNotify("before",item,item.length > 3 ? item[3] as Rectangle : null) : null;
               try {this.sceneApplyRegionAction(String(item[0]),item[1],item.length > 3 ? item[3] as Rectangle : null);}
               finally {if(wallToken != null)this.rconnectWallNotify("after",item,item.length > 3 ? item[3] as Rectangle : null,wallToken);}
            }
         }
         finally
         {
            this.sceneStamp = null;
         }
         if(rconnectWallBridge != null)this.rconnectWallNotify("raster");
      }
private function rconnectWallNotify(kind:String,mark:Object = null,affected:Rectangle = null,token:Object = null) : Object
      {
         if(rconnectWallBridge == null)return null;
         try {return rconnectWallBridge(kind,this,this.loc,this.frontBmp,this.sceneX,this.sceneY,affected,mark,token,this.rconnectWallClips);}
         catch(error:*) {if(this.rconnectWallErrors++ < 4)trace("RConnect wall bridge: " + error);}
         return null;
      }
private function rconnectWallBaseClips(bounds:Rectangle,groups:Array) : Array
      {
         var result:Array = [bounds];
         for each(var group:Object in groups)for each(var cut:Rectangle in group.clips)
         {
            var next:Array = [];
            for each(var rect:Rectangle in result)
            {
               var hit:Rectangle = rect.intersection(cut);
               if(hit.isEmpty()){next.push(rect);continue;}
               if(hit.top > rect.top)next.push(new Rectangle(rect.x,rect.y,rect.width,hit.top-rect.top));
               if(hit.bottom < rect.bottom)next.push(new Rectangle(rect.x,hit.bottom,rect.width,rect.bottom-hit.bottom));
               if(hit.left > rect.left)next.push(new Rectangle(rect.x,hit.y,hit.left-rect.left,hit.height));
               if(hit.right < rect.right)next.push(new Rectangle(hit.right,hit.y,rect.right-hit.right,hit.height));
            }
            result = next;
         }
         return result;
      }
 }
}

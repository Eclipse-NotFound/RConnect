package authority {
   import flash.display.Bitmap;
   import flash.display.BitmapData;
   import flash.display.MovieClip;
   import flash.geom.Point;
   import flash.geom.Rectangle;
   /** Display-only confirmed native particles and loose objects, by lifetime ID. */
   public final class SceneEffects {
      public var records:Object={},applications:uint=0;
      private var access:NativeAccess;
      public function SceneEffects(access:NativeAccess){this.access=access;}
      public function apply(states:Array):void {
         var live:Object={};
         for each(var s:Object in states) {
            live[s.key]=true;var rec:Object=records[s.key];
            if(rec==null) {
               var clip:MovieClip;
               if(s.atlas!=null) {
                  clip=new MovieClip();var data:BitmapData=new BitmapData(s.atlas.w,s.atlas.h,true,0);
                  var bmp:Bitmap=new Bitmap(data);bmp.x=-s.atlas.w/2;bmp.y=-s.atlas.h/2;clip.addChild(bmp);
                  rec={clip:clip,data:data};
               }else {var Type:Class=access.visualClass(s.clip);clip=new Type() as MovieClip;rec={clip:clip,data:null};}
               if(clip==null)throw new Error("Unsupported native visual effect: "+s.clip);
               records[s.key]=rec;
            }
            if(s.atlas!=null)rec.data.copyPixels(access.world.grafon.getSpriteList(s.atlas.atlas,1),
               new Rectangle(s.atlas.x,s.atlas.y,s.atlas.w,s.atlas.h),new Point());
            access.world.grafon.visObjs[int(s.layer)].addChild(rec.clip);VisualPose.apply(rec.clip,s.pose);++applications;
         }
         for(var id:String in records)if(!live[id])remove(id);
      }
      private function remove(id:String):void {
         var rec:Object=records[id];if(rec.clip.parent!=null)rec.clip.parent.removeChild(rec.clip);
         if(rec.data!=null)rec.data.dispose();delete records[id];
      }
      public function dispose():void {for(var id:String in records)remove(id);}
   }
}

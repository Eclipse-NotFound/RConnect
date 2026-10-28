package authority {
   import flash.display.Bitmap;
   import flash.display.BitmapData;
   import flash.display.MovieClip;
   import flash.display.DisplayObject;
   import flash.display.Sprite;
   import flash.display.Shape;
   import flash.geom.Point;
   import flash.geom.Rectangle;
   /** Display-only confirmed native particles and loose objects, by lifetime ID. */
   public final class SceneEffects {
      public var records:Object={},applications:uint=0;
      private var access:NativeAccess;
      private var decorations:DecorativeEffects=new DecorativeEffects();
      public function SceneEffects(access:NativeAccess){this.access=access;}
      public function apply(states:Array):void {
         var live:Object={};
         for each(var s:Object in states) {
            live[s.key]=true;var rec:Object=records[s.key];
            if(rec==null) {
               var clip:DisplayObject;
               if(s.atlas!=null) {
                  clip=new MovieClip();var data:BitmapData=new BitmapData(s.atlas.w,s.atlas.h,true,0);
                  var bmp:Bitmap=new Bitmap(data);bmp.x=-s.atlas.w/2;bmp.y=-s.atlas.h/2;MovieClip(clip).addChild(bmp);
                  rec={clip:clip,data:data};
               }else {
                  if(s.pose!=null && s.pose.vector!=null)clip=s.clip=="flash.display::Shape"?new Shape():new Sprite();
                  else {var Type:Class=access.visualClass(s.clip);clip=new Type() as DisplayObject;}
                  rec={clip:clip,data:null};
               }
               if(clip==null)throw new Error("Unsupported native visual effect: "+s.clip);
               records[s.key]=rec;
            }
            if(s.atlas!=null && rec.atlas!==s.atlas) {
               if(s.atlas.blank)rec.data.fillRect(rec.data.rect,0);
               else rec.data.copyPixels(access.world.grafon.getSpriteList(s.atlas.atlas,1),new Rectangle(s.atlas.x,s.atlas.y,s.atlas.w,s.atlas.h),new Point());
               rec.atlas=s.atlas;
            }
            if(s.name!=null)rec.clip.name=s.name;
            access.world.grafon.visObjs[int(s.layer)].addChild(rec.clip);
            var localPose:Object=SpeechScale.localPose(s.pose,Number(s.screenScale),Number(access.world.cam.scaleV));
            if(s.decor!=null)decorations.apply(rec.clip,localPose,s.decor);
            else {decorations.forget(rec.clip);VisualPose.apply(rec.clip,localPose);}
            ++applications;
            if(s.loot!=null && s.loot.fields!=null) {
               if(rec.pointer==null) {
                  var Obj:Class=access.definition("fe.Obj"),Interact:Class=access.definition("fe.serv.Interact");
                  rec.pointer=new Obj();rec.pointer.loc=access.world.loc;rec.pointer.inter=new Interact(rec.pointer);
               }
               NativeFields.apply(rec.pointer,s.loot.fields);NativeFields.apply(rec.pointer.inter,s.loot.inter);
               rec.pointer.vis=rec.clip as MovieClip;
               rec.pointerOffset={x:s.loot.x-s.pose.x,y:s.loot.y-s.pose.y};
            }else rec.pointer=null;
         }
         for(var id:String in records)if(!live[id])remove(id);
      }
      public function interpolate(states:Array):void {
         for each(var s:Object in states) {
            var rec:Object=records[s.key];
            if(rec==null)throw new Error("Interpolated effect has no confirmed lifetime");
            var localPose:Object=SpeechScale.localPose(s.pose,Number(s.screenScale),Number(access.world.cam.scaleV));
            if(s.decor!=null)decorations.motion(rec.clip,localPose,s.decor);
            else VisualPose.motion(rec.clip,localPose);
            if(rec.pointer!=null){rec.pointer.X=rec.clip.x+rec.pointerOffset.x;rec.pointer.Y=rec.clip.y+rec.pointerOffset.y;}
         }
      }
      private function remove(id:String):void {
         var rec:Object=records[id];if(rec.clip.parent!=null)rec.clip.parent.removeChild(rec.clip);
         decorations.forget(rec.clip);
         VisualPose.dispose(rec.clip);
         if(rec.data!=null)rec.data.dispose();delete records[id];
      }
      public function dispose():void {for(var id:String in records)remove(id);}
   }
}

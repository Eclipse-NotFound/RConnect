package rconnect.game {
   import flash.display.Bitmap;
   import flash.display.BitmapData;
   import flash.display.DisplayObjectContainer;
   import flash.display.MovieClip;
   import flash.utils.Dictionary;

   /** Refresh only SATS's copied body pixels. Keep its target identity, mouse
    * handlers, hover filter, labels, selection count and queued attacks intact. */
   public final class SatsTargetVisuals {
      private var seen:Dictionary=new Dictionary(true);

      public function sync(sats:Object,entry:Object,body:Object,snapshot:Object):Boolean {
         var target:DisplayObjectContainer=entry.du as DisplayObjectContainer;
         if(target==null||target.numChildren==0||body.vis==null)return false;
         var bitmap:Bitmap=target.getChildAt(0) as Bitmap;
         if(bitmap==null)return false;
         var pose:Object=snapshot==null?null:snapshot.pose;
         var blit:Object=pose==null?null:pose.blit,clip:Object=pose==null?null:pose.clip;
         var signature:String=[snapshot==null?null:snapshot.anim,body.storona,
            blit==null?null:blit.f,blit==null?null:blit.reverse,
            clip==null?null:clip.frame,body.vis.scaleX,body.vis.scaleY,body.vis.rotation,
            body.vis.width,body.vis.height].join("|");
         var previous:Object=seen[entry];
         if(previous!=null&&previous.signature==signature&&previous.visual===body.vis)return false;
         // Use the native color transform and bounds calculation. Swapping the
         // child BitmapData preserves the MovieClip used by Sats.setCel/mOver.
         var fresh:MovieClip=sats.drawUnit(body) as MovieClip;
         var source:Bitmap=fresh.getChildAt(0) as Bitmap;
         var old:BitmapData=bitmap.bitmapData;
         bitmap.bitmapData=source.bitmapData;source.bitmapData=null;
         bitmap.x=source.x;bitmap.y=source.y;
         target.scaleX=fresh.scaleX;target.scaleY=fresh.scaleY;target.rotation=fresh.rotation;
         if(old!=null)old.dispose();
         seen[entry]={signature:signature,visual:body.vis};
         return true;
      }
   }
}

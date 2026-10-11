package fe.graph {
   import flash.utils.Dictionary;
   public final class AuthorityParticle {
      private static var names:Dictionary=new Dictionary(true);
      public static function capture(value:Object,atlas:Object):Object {
         var part:Part=value as Part;
         if(part==null || part.blitData==null || part.blitRect==null)return null;
         var name:String=names[part.blitData];
         if(name==null)for(var key:String in atlas)if(atlas[key]===part.blitData){names[part.blitData]=name=key;break;}
         if(name==null)throw new Error("Particle atlas has no native identity");
         // Animated native particles may be captured after allocation but
         // before their first blit. A default atlas rectangle is not evidence
         // that the surface already contains that frame.
         return {atlas:name,x:part.blitRect.x,y:part.blitRect.y,w:part.blitRect.width,h:part.blitRect.height,
            blank:part.visData!=null && part.visData.getColorBoundsRect(0xFF000000,0,false).isEmpty()};
      }
   }
}

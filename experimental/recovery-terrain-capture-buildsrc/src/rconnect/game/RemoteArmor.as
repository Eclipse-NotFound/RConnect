package rconnect.game
{
   import flash.display.DisplayObjectContainer;
   import flash.display.MovieClip;
   import flash.utils.getQualifiedClassName;

   /** Native clothing frame scripts read the local player's globals on every new body frame. */
   public class RemoteArmor
   {
      private static var types:Object = {};
      public static function apply(node:DisplayObjectContainer, armor:String):void
      {
         if(node == null) return;
         var clip:MovieClip = node as MovieClip;
         if(clip != null)
         {
            var key:String = getQualifiedClassName(clip);
            var info:Object = types[key];
            if(info == null)
            {
               info = {frames:{},count:0};
               for each(var label:Object in clip.currentLabels)
               {
                  info.frames[label.name] = label.frame;
                  if(label.name=="pip" || label.name=="power" || label.name=="assault") info.count++;
               }
               types[key] = info;
            }
            if(info.count >= 2)
            {
               var frame:int = info.frames[armor] == null ? 1 : int(info.frames[armor]);
               if(clip.currentFrame != frame) clip.gotoAndStop(frame);
            }
         }
         // Query children after the frame change, as clothing can construct new parts.
         for(var i:int=0;i<node.numChildren;i++)
            apply(node.getChildAt(i) as DisplayObjectContainer,armor);
      }
   }
}

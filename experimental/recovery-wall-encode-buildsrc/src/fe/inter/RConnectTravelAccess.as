package fe.inter
{
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   public class RConnectTravelAccess
   {
      public static function blocked(page:Object,target:DisplayObject):Boolean
      {
         var p:PipPage=page as PipPage;
         if(p==null || p.vis==null || p.vis.butOk==null)return false;
         var button:DisplayObjectContainer=p.vis.butOk as DisplayObjectContainer;
         if(button==null || (target!==button && !button.contains(target)))return false;
         return (p is PipPageInfo && p.page2==3) || (p is PipPageInv && (p as PipPageInv).actCurrent=="retr");
      }
   }
}

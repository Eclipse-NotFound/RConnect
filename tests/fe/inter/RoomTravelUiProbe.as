package fe.inter {
   import flash.events.MouseEvent;
   public class RoomTravelUiProbe {
      public static function blocked(pip:Object,inventory:Boolean):Boolean {
         pip.onoff(inventory?2:3,inventory?1:3);
         var page:PipPage=pip.currentPage as PipPage;
         var oldPage:int=page.page2,oldAction:String=inventory?(page as PipPageInv).actCurrent:"";
         if(inventory)(page as PipPageInv).actCurrent="retr";else page.page2=3;
         var reached:Boolean=false;
         var listener:Function=function(e:MouseEvent):void {reached=true;};
         page.vis.butOk.addEventListener(MouseEvent.CLICK,listener);
         try {page.vis.butOk.dispatchEvent(new MouseEvent(MouseEvent.CLICK,true));}
         finally {
            page.vis.butOk.removeEventListener(MouseEvent.CLICK,listener);
            page.page2=oldPage;if(inventory)(page as PipPageInv).actCurrent=oldAction;
            pip.onoff(-1);
         }
         return !reached;
      }
   }
}

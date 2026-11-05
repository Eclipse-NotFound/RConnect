package
{
   import fe.*;
   import flash.display.MovieClip;
   import flash.display.StageAlign;
   import flash.events.Event;
   import flash.ui.ContextMenu;
   import flash.ui.ContextMenuItem;
   
   public class MainFE extends MovieClip
   {
      
      public var zastavka:MovieClip;
      
      internal var mainMenu:MainMenu;
      
      public function MainFE()
      {
         super();
         stage.scaleMode = "noScale";
         stage.align = StageAlign.TOP_LEFT;
         stage.color = 0;
         var _loc1_:ContextMenu = new ContextMenu();
         _loc1_.hideBuiltInItems();
         _loc1_.builtInItems.quality = true;
         contextMenu = _loc1_;
         _loc1_.customItems.push(new ContextMenuItem("Привет!",false,true,false));
         stop();
         addEventListener(Event.ENTER_FRAME,this.onEnterFrameLoader);
      }
      
      internal function onEnterFrameLoader(param1:Event) : *
      {
         var _loc2_:uint = loaderInfo.bytesLoaded;
         var _loc3_:uint = loaderInfo.bytesTotal;
         if(this.zastavka.alpha < 1)
         {
            this.zastavka.alpha += 0.05;
         }
         this.zastavka.progres.text = "Loading " + Math.round(_loc2_ / _loc3_ * 100) + "%";
         if(_loc2_ >= _loc3_)
         {
            this.zastavka.visible = false;
            removeEventListener(Event.ENTER_FRAME,this.onEnterFrameLoader);
            nextFrame();
            this.mainMenu = new MainMenu(this);
         }
      }
   }
}


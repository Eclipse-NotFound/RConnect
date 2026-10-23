package fixture {
   import flash.display.Sprite;
   import flash.display.MovieClip;
   import flash.text.TextField;
   /** The original asset's relevant public surface, including its raw marker. */
   public class LoadingArt extends Sprite {
      public var progres:TextField=new TextField();
      public var skill:MovieClip=new MovieClip();
      public var story:MovieClip=new MovieClip();
      public function LoadingArt() {
         progres.text="*gui_loading";progres.width=250;
         story.txt=new TextField();story.txt.htmlText="<i>Keep this story</i>";
         story.lmb=new MovieClip();story.addChild(story.txt);story.addChild(story.lmb);
         addChild(progres);addChild(skill);addChild(story);story.visible=false;
      }
   }
}

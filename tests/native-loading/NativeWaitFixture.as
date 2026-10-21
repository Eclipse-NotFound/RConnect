package {
   import flash.display.MovieClip;
   import flash.text.TextField;
   /** Component artwork only. The native asset is checked in the game run. */
   public dynamic class NativeWaitFixture extends MovieClip {
      public var skill:MovieClip=new MovieClip();
      public var progres:TextField=new TextField();
      public var story:MovieClip=new MovieClip();
      public function NativeWaitFixture() {
         skill.graphics.beginFill(0x44BB66);skill.graphics.drawRect(-20,-40,40,40);skill.graphics.endFill();
         progres.text="原版加载中";progres.textColor=0xFFFFFF;progres.x=-50;progres.width=120;
         story.txt=new TextField();story.lmb=new MovieClip();story.addChild(story.txt);story.addChild(story.lmb);
         story.visible=false;story.lmb.visible=false;
         addChild(skill);addChild(progres);addChild(story);
      }
   }
}

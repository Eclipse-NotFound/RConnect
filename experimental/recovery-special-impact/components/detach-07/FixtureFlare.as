package {
   import flash.display.MovieClip;
   /** Shape substitute, not the game's artwork or a native Part. */
   public class FixtureFlare extends MovieClip {
      public function FixtureFlare() {graphics.beginFill(0xffffff);graphics.drawRect(0,0,4,4);graphics.endFill();}
   }
}

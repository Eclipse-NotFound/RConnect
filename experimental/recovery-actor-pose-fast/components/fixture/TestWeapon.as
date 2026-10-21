package fixture {
   import flash.display.MovieClip;
   import flash.display.Sprite;
   public final class TestWeapon {
      public var id:String="gun",variant:int=0,X:Number=0,Y:Number=0,rot:Number=0;
      public var t_prep:int=0,t_reload:int=0,t_shoot:int=0;
      public var owner:Object,vis:MovieClip=new MovieClip(),layer:Sprite;
      public function TestWeapon(parent:Sprite) {layer=parent;layer.addChild(vis);}
      public function addVisual():void {Trace.note("add",id);layer.addChild(vis);}
      public function remVisual():void {Trace.note("remove",id);if(vis.parent!=null)vis.parent.removeChild(vis);}
      // Record the real caller's final state at the native animation boundary.
      // This fixture does not replace or approximate UnitPresentation.tick.
      public function animate():void {Trace.note("animate",id,X,Y,rot,t_prep,t_reload,t_shoot);}
   }
}

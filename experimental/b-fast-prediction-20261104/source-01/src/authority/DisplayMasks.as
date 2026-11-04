package authority {
   import flash.display.DisplayObject;
   import flash.utils.Dictionary;
   /** A mask stays local even if its owner leaves the layer before cleanup.
    * Weak identities neither retain dead units nor mistake ordinary Shapes
    * for masks. Owners need not currently have a display parent. */
   public final class DisplayMasks {
      private var known:Dictionary=new Dictionary(true);
      public function remember(owner:DisplayObject):void {
         if(owner!=null && owner.mask!=null)known[owner.mask]=true;
      }
      public function contains(display:DisplayObject):Boolean{return known[display]===true;}
      public function reset():void {known=new Dictionary(true);}
   }
}

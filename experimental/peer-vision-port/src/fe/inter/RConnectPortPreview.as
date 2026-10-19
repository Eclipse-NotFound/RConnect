package fe.inter {
   /** Reuses the real charged/ready/blocked marker and collision check. */
   public class RConnectPortPreview {
      public static function show(gui:Object,tile:Object):void {
         var nativeGui:GUI=gui as GUI;
         if(nativeGui==null || tile==null)return;
         var old:Number=Number(tile.visi);
         try {tile.visi=Math.max(old,.8);nativeGui.showPortCel();}
         finally {tile.visi=old;}
      }
   }
}

package rconnect.ui {
   import flash.geom.Rectangle;

   /** Stage coordinates only; never uses a player's world position. */
   public class HudLayout {
      public static function measure(sw:Number,sh:Number,scale:Number,collapsed:Boolean,
         dock:String,px:Number,py:Number,obstacles:Array):Object {
         scale=isFinite(scale)&&scale>0?scale:1;
         var width:Number=Math.min(280,Math.max(1,(sw-16)/scale));
         var left:Number=dock=="free"?px:dock.charAt(1)=="r"?sw-8-width*scale:8;
         left=Math.max(8,Math.min(left,sw-8-width*scale));
         var top:Number=8,bottom:Number=sh-8;
         for each(var r:Rectangle in obstacles) {
            if(r==null || r.right<=left || r.left>=left+width*scale)continue;
            if(r.top<sh/3)top=Math.max(top,r.bottom+8);
            if(r.bottom>sh*2/3)bottom=Math.min(bottom,r.top-8);
         }
         // Keep all controls reachable by scrolling, including when a corner
         // has too little free space to avoid every native widget.
         if(bottom-top<100*scale) {top=8;bottom=sh-8;}
         var height:Number=collapsed?36:Math.min(240,Math.max(100,(bottom-top)/scale));
         height=Math.min(height,Math.max(36,(sh-16)/scale));
         var y:Number=dock=="free"?py:dock.charAt(0)=="b"?bottom-height*scale:top;
         y=Math.max(8,Math.min(y,sh-8-height*scale));
         return {x:left,y:y,w:width,h:height,body:Math.max(16,height-84)};
      }
   }
}

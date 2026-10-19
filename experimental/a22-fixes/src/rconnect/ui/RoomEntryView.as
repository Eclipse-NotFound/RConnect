package rconnect.ui {
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.Sprite;
   import flash.display.Stage;
   import flash.geom.Point;
   import flash.geom.Rectangle;
   import flash.text.TextField;
   import flash.text.TextFormat;
   import modlocales.connect.RCLocale;

   /** Own only a loading cover, never native visibility, alpha or fade state.
    * Native redraws and visibility mods may keep working underneath. Menus,
    * errors, the HUD and disconnect controls retain their original layers. */
   public final class RoomEntryView {
      private var scene:Sprite=new Sprite(),sats:Sprite=new Sprite();
      private var label:TextField=new TextField();
      private var sceneBounds:Rectangle,satsBounds:Rectangle;
      public function RoomEntryView() {
         scene.name="rconnect-room-entry";sats.name="rconnect-room-entry-sats";
         scene.mouseEnabled=scene.mouseChildren=sats.mouseEnabled=sats.mouseChildren=false;
         label.defaultTextFormat=new TextFormat("_sans",16,0xD2DCCB,false,null,null,null,null,"center");
         label.selectable=false;label.mouseEnabled=false;label.multiline=label.wordWrap=true;
         scene.addChild(label);
      }
      public function clear():void {
         if(scene.parent!=null)scene.parent.removeChild(scene);
         if(sats.parent!=null)sats.parent.removeChild(sats);
      }
      public function show(world:Object,stage:Stage,status:String):void {
         var visual:DisplayObject=world.visual as DisplayObject;
         if(visual==null || visual.parent==null || stage==null){clear();return;}
         var parent:DisplayObjectContainer=visual.parent;
         if(scene.parent!==parent || parent.getChildIndex(scene)!=parent.getChildIndex(visual)+1) {
            if(scene.parent!=null)scene.parent.removeChild(scene);
            parent.addChildAt(scene,parent.getChildIndex(visual)+1);
            sceneBounds=null;
         }
         sceneBounds=paint(scene,parent,stage,sceneBounds);
         var text:String=RCLocale.text(status);
         if(label.text!=text)label.text=text;
         label.width=Math.max(1,sceneBounds.width-32);label.height=60;
         label.x=sceneBounds.x+16;label.y=sceneBounds.y+(sceneBounds.height-60)/2;
         var nativeSats:DisplayObjectContainer=world.vsats as DisplayObjectContainer;
         if(nativeSats!=null) {
            if(sats.parent!==nativeSats || nativeSats.getChildIndex(sats)!=nativeSats.numChildren-1) {
               nativeSats.addChild(sats);satsBounds=null;
            }
            satsBounds=paint(sats,nativeSats,stage,satsBounds);
         }else if(sats.parent!=null)sats.parent.removeChild(sats);
      }
      private function paint(cover:Sprite,parent:DisplayObjectContainer,stage:Stage,old:Rectangle):Rectangle {
         var corners:Array=[new Point(0,0),new Point(stage.stageWidth,0),
            new Point(0,stage.stageHeight),new Point(stage.stageWidth,stage.stageHeight)];
         var left:Number=Infinity,top:Number=Infinity,right:Number=-Infinity,bottom:Number=-Infinity;
         for each(var p:Point in corners) {
            p=parent.globalToLocal(p);left=Math.min(left,p.x);right=Math.max(right,p.x);
            top=Math.min(top,p.y);bottom=Math.max(bottom,p.y);
         }
         var rect:Rectangle=new Rectangle(left,top,right-left,bottom-top);
         if(old==null || !old.equals(rect)) {
            cover.graphics.clear();cover.graphics.beginFill(0x101510);
            cover.graphics.drawRect(rect.x,rect.y,rect.width,rect.height);cover.graphics.endFill();
         }
         return rect;
      }
   }
}

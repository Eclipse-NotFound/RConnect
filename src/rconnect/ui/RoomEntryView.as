package rconnect.ui {
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.MovieClip;
   import flash.display.Sprite;
   import flash.display.Stage;
   import flash.geom.Matrix;
   import flash.geom.Point;
   import flash.geom.Rectangle;

   /** Extend the game's loading artwork across the network barrier. Never call
    * setLoadScreen here: it also resets input, story and gameplay visibility.
    * The native instance remains entirely owned by World; two cheap instances
    * of its asset cover the scene and, when active, the separate SATS layer. */
   public final class RoomEntryView {
      private var scene:Sprite=new Sprite(),sats:Sprite=new Sprite();
      private var sceneBounds:Rectangle,satsBounds:Rectangle;
      private var source:DisplayObject,sceneWait:DisplayObject,satsWait:DisplayObject;
      public function RoomEntryView() {
         scene.name="rconnect-room-entry";sats.name="rconnect-room-entry-sats";
         scene.mouseEnabled=scene.mouseChildren=sats.mouseEnabled=sats.mouseChildren=false;
      }
      public function clear():void {
         if(scene.parent!=null)scene.parent.removeChild(scene);
         if(sats.parent!=null)sats.parent.removeChild(sats);
      }
      public function show(world:Object,stage:Stage,status:String):void {
         var visual:DisplayObject=world.visual as DisplayObject;
         if(visual==null || visual.parent==null || stage==null){clear();return;}
         var parent:DisplayObjectContainer=visual.parent;
         // Above native scene/fade, below menus, HUD, errors and mod controls.
         var anchor:DisplayObject=visual;
         for each(var n:String in ["vscene","vblack"]) {
            var d:DisplayObject=world[n] as DisplayObject;
            if(d!=null && d.parent===parent && parent.getChildIndex(d)>parent.getChildIndex(anchor))anchor=d;
         }
         if(scene.parent!==parent || parent.getChildIndex(scene)!=parent.getChildIndex(anchor)+1) {
            if(scene.parent!=null)scene.parent.removeChild(scene);
            parent.addChildAt(scene,parent.getChildIndex(anchor)+1);sceneBounds=null;
         }
         sceneBounds=paint(scene,parent,stage,sceneBounds);
         var original:DisplayObject=world.vwait as DisplayObject;
         if(original!==source) {
            source=original;
            sceneWait=replace(scene,sceneWait);
            if(satsWait!=null && satsWait.parent===sats)sats.removeChild(satsWait);
            satsWait=null;
         }
         var progressText:String=loadingText(world);
         sync(sceneWait,progressText);
         var nativeSats:DisplayObjectContainer=world.vsats as DisplayObjectContainer;
         // A second native asset is needed only while SATS is actually drawn.
         // Do not allocate or update an invisible copy during ordinary travel.
         if(nativeSats!=null && nativeSats.visible) {
            if(satsWait==null)satsWait=replace(sats,null);
            if(sats.parent!==nativeSats || nativeSats.getChildIndex(sats)!=nativeSats.numChildren-1) {
               nativeSats.addChild(sats);satsBounds=null;
            }
            satsBounds=paint(sats,nativeSats,stage,satsBounds);sync(satsWait,progressText);
         }else if(sats.parent!=null)sats.parent.removeChild(sats);
      }
      private function replace(cover:Sprite,old:DisplayObject):DisplayObject {
         if(old!=null && old.parent===cover)cover.removeChild(old);
         if(source==null)return null;
         var factory:Class=Object(source).constructor as Class;
         var view:DisplayObject=new factory() as DisplayObject;
         view.name="rconnect-native-loading";cover.addChild(view);return view;
      }
      private function loadingText(world:Object):String {
         if(source==null || !("progres" in source))return null;
         var text:String=String(Object(source).progres.text);
         // A join-only room barrier can precede native loading initialization.
         // Preserve every real progress message and never change native UI state.
         if(text!="*gui_loading")return text;
         try {
            var res:Object=world.main.loaderInfo.applicationDomain.getDefinition("fe.Res");
            var localized:String=res.guiText("loading");
            if(localized!=null && localized!="" && localized!="*gui_loading")return localized;
         }catch(error:*){}
         return text;
      }
      private function sync(view:DisplayObject,progressText:String):void {
         if(view==null || source==null || view.parent==null)return;
         var p:DisplayObjectContainer=view.parent;
         var a:Point=p.globalToLocal(source.localToGlobal(new Point()));
         var b:Point=p.globalToLocal(source.localToGlobal(new Point(1,0)));
         var c:Point=p.globalToLocal(source.localToGlobal(new Point(0,1)));
         view.transform.matrix=new Matrix(b.x-a.x,b.y-a.y,c.x-a.x,c.y-a.y,a.x,a.y);
         view.transform.colorTransform=source.transform.colorTransform;
         view.alpha=source.alpha;view.visible=true;
         // Mirror the native localized text, selected illustration and story
         // prompt. Do not roll a new random illustration or restart animation.
         frame(view,source);
         for each(var key:String in ["skill","progres","story"]) {
            if(!(key in source) || !(key in view))continue;
            var src:Object=Object(source)[key],dst:Object=Object(view)[key];
            dst.visible=src.visible;frame(dst,src);
            if(key=="progres" && dst.text!=progressText)dst.text=progressText;
            if(key=="story") {
               if(dst.txt.htmlText!=src.txt.htmlText)dst.txt.htmlText=src.txt.htmlText;
               dst.lmb.visible=src.lmb.visible;frame(dst.lmb,src.lmb);
            }
         }
      }
      private function frame(to:Object,from:Object):void {
         if(to is MovieClip && from is MovieClip) {
            var clip:MovieClip=to as MovieClip;
            if(clip.currentFrame!=from.currentFrame)clip.gotoAndStop(from.currentFrame);
            else clip.stop();
         }
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
            cover.graphics.clear();cover.graphics.beginFill(0);
            cover.graphics.drawRect(rect.x,rect.y,rect.width,rect.height);cover.graphics.endFill();
         }
         return rect;
      }
   }
}

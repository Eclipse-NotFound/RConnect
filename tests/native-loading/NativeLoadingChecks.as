package {
   import flash.display.*;
   import flash.geom.Point;
   import rconnect.ui.RoomEntryView;
   public final class NativeLoadingChecks {
      public static function run(check:Function,stage:Stage):void {
         var root:Sprite=new Sprite();stage.addChild(root);
         var w:Object={};
         for each(var key:String in ["vwait","vfon","visual","vscene","vblack","vpip","vsats","vgui","verror"]) {
            w[key]=key=="vwait"?new NativeWaitFixture():new Sprite();root.addChild(w[key]);
         }
         var native:NativeWaitFixture=w.vwait;native.x=320;native.y=200;native.visible=false;
         w.visual.graphics.beginFill(0xCC0000);w.visual.graphics.drawRect(0,0,640,400);
         w.vblack.graphics.beginFill(0);w.vblack.graphics.drawRect(0,0,640,400);
         w.vpip.visible=w.vsats.visible=false;
         var gate:RoomEntryView=new RoomEntryView();gate.show(w,stage,"房间交接中…");
         var cover:Sprite=root.getChildByName("rconnect-room-entry") as Sprite;
         var art:NativeWaitFixture=cover.getChildByName("rconnect-native-loading") as NativeWaitFixture;
         check(art!=null && art!==native,"native asset class supplies the loading view");
         check(cover.numChildren==1 && art.progres.text==native.progres.text,"only native illustration and localized loading text");
         check(native.parent===root && !native.visible && native.x==320,"native instance and ownership remain untouched");
         var image:BitmapData=new BitmapData(640,400,false,0);image.draw(root);
         check(image.getPixel(320,175)==0x44BB66,"native artwork stays visible above the opaque native fade");
         check(image.getPixel(50,50)==0,"pending scene has the original black loading background");
         w.vblack.visible=false;native.visible=true;gate.show(w,stage,"");
         check(native.visible && native.parent===root,"native loading retains its own visible state");
         native.visible=false;gate.show(w,stage,"");
         check(art.visible && !native.visible,"network wait keeps native artwork after native exit step 16");
         native.progres.text="Loading";gate.show(w,stage,"");
         check(art.progres.text=="Loading","language changes use native text");
         native.skill.visible=false;native.progres.visible=false;native.story.visible=true;
         native.story.txt.htmlText="<b>Story</b>";native.story.lmb.visible=true;gate.show(w,stage,"");
         check(art.story.visible && art.story.lmb.visible && !art.skill.visible && art.story.txt.text=="Story","native story and continue prompt survive");
         native.skill.visible=native.progres.visible=true;native.story.visible=false;
         w.vsats.graphics.beginFill(0xCC0000);w.vsats.graphics.drawRect(0,0,640,400);w.vsats.visible=true;
         gate.show(w,stage,"");image.fillRect(image.rect,0);image.draw(root);
         check(image.getPixel(320,175)==0x44BB66 && image.getPixel(50,50)==0,"SATS cannot leak a provisional room or hide loading artwork");
         root.scaleX=.75;root.scaleY=.8;root.x=20;root.y=15;
         w.vsats.x=11;w.vsats.y=7;w.vsats.scaleX=1.2;gate.show(w,stage,"");
         var satsArt:DisplayObject=Sprite(w.vsats.getChildByName("rconnect-room-entry-sats")).getChildByName("rconnect-native-loading");
         var actual:Point=satsArt.localToGlobal(new Point()),expected:Point=native.localToGlobal(new Point());
         check(Point.distance(actual,expected)<.01,"scaled SATS and root retain native loading position");
         root.scaleX=root.scaleY=1;root.x=root.y=0;w.vsats.visible=false;
         w.vpip.graphics.beginFill(0x3344DD);w.vpip.graphics.drawRect(0,0,640,400);w.vpip.visible=true;gate.show(w,stage,"");
         image.fillRect(image.rect,0);image.draw(root);check(image.getPixel(320,175)==0x3344DD,"menu remains operable over loading");
         w.verror.graphics.beginFill(0xEEAA00);w.verror.graphics.drawRect(0,0,640,400);image.draw(root);
         check(image.getPixel(320,175)==0xEEAA00,"native error layer remains visible");
         gate.clear();gate.clear();
         check(cover.parent==null && w.vsats.getChildByName("rconnect-room-entry-sats")==null,"release or disconnect removes all owned layers");
         check(native.parent===root && !native.visible && native.progres.text=="Loading","cleanup preserves native state");
         var replacement:NativeWaitFixture=new NativeWaitFixture();root.addChildAt(replacement,0);w.vwait=replacement;
         gate.show(w,stage,"");check(cover.numChildren==1 && cover.getChildAt(0)!==art,"world replacement discards the previous loading asset");
         gate.clear();stage.removeChild(root);image.dispose();
      }
   }
}

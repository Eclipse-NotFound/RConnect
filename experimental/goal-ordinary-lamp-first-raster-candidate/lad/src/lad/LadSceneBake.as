package lad {
    import flash.display.Bitmap;
    import flash.display.BitmapData;
    import flash.display.DisplayObjectContainer;
    import flash.geom.Rectangle;
    import flash.events.Event;
    import flash.utils.Dictionary;
    import flash.utils.getTimer;
    /** Two low-frequency native passes preserve pre-existing raster edits by pixel comparison. */
    public final class LadSceneBake {
        public static var lastMs:int=0;
        public static var preservedPixels:int=0;
        private static var pendingPreload:Dictionary=new Dictionary(true);
        public static function surfaces(g:*):Object {
            var result:Object={};
            if("sceneLarge" in g && g.sceneLarge && "sceneSurfaces" in g) {
                for each(var surface:Object in g.sceneSurfaces()) {
                    for(var n:int=0;n<4;n++) result[surface.cx+":"+surface.cy+":"+n]=surface.nativeBuffers[n];
                }
            } else {
                var parents:Array=[g.visFront,g.visBack,g.visBack2,g.visVoda];
                for(n=0;n<parents.length;n++) {
                    var parent:DisplayObjectContainer=parents[n];
                    for(var k:int=0;k<parent.numChildren;k++) {
                        var bmp:Bitmap=parent.getChildAt(k) as Bitmap;
                        if(bmp && bmp.bitmapData && bmp.name.indexOf("WallBlend")!=0) {
                            result["normal:"+n]=bmp.bitmapData;break;
                        }
                    }
                }
            }
            return result;
        }
        private static function capture(g:*):Object {
            var result:Object={},pixels:Number=0,current:Object=surfaces(g);
            for(var key:String in current) {
                var data:BitmapData=current[key];pixels+=data.width*data.height;
                if(pixels>24000000) {
                    dispose(result);throw new Error("background snapshot exceeds 24M pixels; safe conversion refused");
                }
                result[key]=data.clone();
            }
            return result;
        }
        private static function redraw(g:*,loc:*,camera:*):void {
            // Give independent overlay mods a frame to release the old chunk
            // generation before the host preloads the whole scene again.
            if("sceneLarge" in g && g.sceneLarge && "scenePreload" in g && (g.scenePreload || pendingPreload[g])
                && !("sceneSynchronousRedraw" in g && g.sceneSynchronousRedraw)) {
                if(!pendingPreload[g]) {
                    var state:Object={frames:3,listener:null};
                    state.listener=function(event:Event):void {
                        if(--state.frames>0) return;
                        g.visual.removeEventListener(Event.ENTER_FRAME,state.listener);
                        g.scenePreload=true;delete pendingPreload[g];
                    };
                    pendingPreload[g]=state;
                    g.visual.addEventListener(Event.ENTER_FRAME,state.listener,false,-10000);
                } else pendingPreload[g].frames=3;
                g.scenePreload=false;
            }
            g.drawLoc(loc);
            // drawLoc resets the native black borders. Reapply the current zoom
            // before sceneTick, without changing the player's zoom or position.
            camera.setZoom();
            if("sceneTick" in g) g.sceneTick();
            // A sceneTick may itself finish rasterizing a chunk and reset borders.
            if(g.ramT.scaleY>=0 || g.ramL.scaleX>=0) camera.setZoom();
        }
        public static function change(g:*,loc:*,mutation:Function,camera:*):void {
            // Large scenes already journal native decals/terrain edits and replay
            // them in drawLoc. Cloning every preloaded chunk would exceed RAM.
            if("sceneLarge" in g && g.sceneLarge && "sceneSave" in g) {
                var begin:int=getTimer();preservedPixels=0;
                mutation();redraw(g,loc,camera);lastMs=getTimer()-begin;
                LadLog.write("BAKE_LARGE native-history-replay ms="+lastMs);return;
            }
            var started:int=getTimer(),old:Object=capture(g),base:Object={};
            preservedPixels=0;
            try {
                redraw(g,loc,camera);base=capture(g);
                mutation();redraw(g,loc,camera);
                var current:Object=surfaces(g);
                for(var key:String in old) {
                    var before:BitmapData=old[key],clean:BitmapData=base[key],target:BitmapData=current[key];
                    if(!clean || !target || before.width!=clean.width || before.height!=clean.height
                        || target.width!=clean.width || target.height!=clean.height) continue;
                    var difference:*=before.compare(clean);
                    if(difference is BitmapData) {
                        var delta:BitmapData=difference;
                        var changed:Vector.<uint>=delta.getVector(delta.rect);
                        var original:Vector.<uint>=before.getVector(before.rect);
                        var output:Vector.<uint>=target.getVector(target.rect);
                        for(var i:int=0;i<changed.length;i++) if(changed[i]!=0) {output[i]=original[i];preservedPixels++;}
                        target.setVector(target.rect,output);delta.dispose();
                    }
                }
            } finally {dispose(old);dispose(base);lastMs=getTimer()-started;}
            LadLog.write("BAKE ms="+lastMs+" preserved="+preservedPixels);
        }
        private static function dispose(values:Object):void {
            for each(var data:BitmapData in values) data.dispose();
        }
    }
}

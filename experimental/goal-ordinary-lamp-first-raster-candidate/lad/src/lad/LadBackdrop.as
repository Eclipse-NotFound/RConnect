package lad {
    import flash.display.Bitmap;
    import flash.display.BitmapData;
    import flash.display.DisplayObjectContainer;
    import flash.geom.Matrix;
    import flash.geom.Rectangle;

    /** Borrows native alpha; never copies, redraws or owns the game's raster buffers. */
    public final class LadBackdrop {
        private var grafon:*;
        private var chunks:Object={};
        private var tracked:Array=[];
        private var normal:Array=[];
        private var pointers:Array=[];
        private var stamp:String="";
        private var revision:uint=0;
        private var side:int=320;
        private var large:Boolean=false;
        public function bind(value:*):void {clear();grafon=value;signature();}
        public function clear():void {
            grafon=null;chunks={};tracked=[];normal=[];pointers=[];stamp="";revision=0;large=false;
        }
        private static function read(o:*,key:String,fallback:*):* {return o && key in o?o[key]:fallback;}
        private function firstBitmap(layer:*):Bitmap {
            var container:DisplayObjectContainer=layer as DisplayObjectContainer;
            if(!container)return null;
            // Native raster is first; subsequent children can be cosmetic WB overlays.
            for(var i:int=0;i<container.numChildren;i++) {
                var bitmap:Bitmap=container.getChildAt(i) as Bitmap;
                if(bitmap && bitmap.bitmapData && bitmap.name.indexOf("WallBlend")!=0)return bitmap;
            }
            return null;
        }
        /** Structural tile edits are already in LadLightField's terrainHash.
         * Do not invalidate for scene revision alone: bullet decals increment it too. */
        public function signature():uint {
            var nextLarge:Boolean=Boolean(read(grafon,"sceneLarge",false));
            var next:String=[nextLarge,read(grafon,"sceneResident",0),read(grafon,"sceneEvictions",0)].join(":");
            var changed:Boolean=false;large=nextLarge;
            if(large) {
                for each(var record:Object in tracked) {
                    var buffers:Array=record.entry.nativeBuffers;
                    for(var i:int=0;i<3;i++) if(buffers[i]!==record.data[i]) {changed=true;record.data[i]=buffers[i];}
                }
            } else {
                var names:Array=["visFront","visBack","visBack2"];
                for(i=0;i<3;i++) {
                    var layer:*=read(grafon,names[i],null),bitmap:Bitmap=firstBitmap(layer);
                    var data:BitmapData=bitmap?bitmap.bitmapData:null;
                    if(pointers[i]!==data){changed=true;pointers[i]=data;}
                    if(bitmap)next+=":"+bitmap.alpha+":"+bitmap.transform.matrix.toString()+":"+layer.alpha+":"+layer.transform.matrix.toString();
                }
            }
            if(next!=stamp)changed=true;stamp=next;
            if(changed)++revision;
            return revision;
        }
        /** Called only when the cached environment raster actually needs rebuilding. */
        public function prepare(bounds:Rectangle):void {
            signature();chunks={};tracked=[];normal=[];
            if(!grafon)return;
            if(large && "sceneSurfaces" in grafon) {
                side=int(read(grafon,"sceneChunkSide",320));if(side<=0)side=320;
                for each(var entry:Object in grafon.sceneSurfaces()) {
                    var area:Rectangle=new Rectangle(entry.x+entry.gutter,entry.y+entry.gutter,entry.side,entry.side);
                    if(!area.intersects(bounds))continue;
                    chunks[entry.cx+":"+entry.cy]=entry;
                    tracked.push({entry:entry,data:[entry.nativeBuffers[0],entry.nativeBuffers[1],entry.nativeBuffers[2]]});
                }
                return;
            }
            var names:Array=["visFront","visBack","visBack2"];
            for(var i:int=0;i<3;i++) {
                var layer:*=read(grafon,names[i],null),bitmap:Bitmap=firstBitmap(layer);
                if(!bitmap){normal[i]=null;continue;}
                var matrix:Matrix=bitmap.transform.concatenatedMatrix.clone();
                var visual:*=read(grafon,"visual",null);
                if(visual) {var inverse:Matrix=visual.transform.concatenatedMatrix.clone();inverse.invert();matrix.concat(inverse);}
                matrix.invert();
                normal[i]={data:bitmap.bitmapData,matrix:matrix,alpha:bitmap.alpha*Number(read(layer,"alpha",1))};
            }
        }
        private function nativeAlpha(data:BitmapData,x:int,y:int):Number {
            if(!data || x<0 || y<0 || x>=data.width || y>=data.height)return 0;
            return (data.getPixel32(x,y)>>>24)/255;
        }
        private function alpha(index:int,x:Number,y:Number):Number {
            if(large) {
                var entry:Object=chunks[int(Math.floor(x/side))+":"+int(Math.floor(y/side))];
                if(!entry)return NaN; // Before-raster and not-yet-resident chunks are not transparent sky.
                return nativeAlpha(entry.nativeBuffers[index],int(Math.floor(x-entry.x)),int(Math.floor(y-entry.y)));
            }
            var record:Object=normal[index];if(!record)return NaN;
            var matrix:Matrix=record.matrix;
            return nativeAlpha(record.data,int(Math.floor(matrix.a*x+matrix.c*y+matrix.tx)),
                int(Math.floor(matrix.b*x+matrix.d*y+matrix.ty)))*record.alpha;
        }
        public function transmission(x:Number,y:Number):Number {
            var result:Number=1,available:Boolean=false;
            for(var i:int=0;i<3;i++) {
                var value:Number=alpha(i,x,y);
                if(isNaN(value))continue;
                available=true;result*=1-value;
            }
            return available?Math.max(0,Math.min(1,result)):NaN;
        }
        public function frontAlpha(x:Number,y:Number):Number {return alpha(0,x,y);}
        public function get allowsGeometryFallback():Boolean {return !large;}
    }
}

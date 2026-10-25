package lad {
    import fe.loc.Tile;
    import flash.display.Bitmap;
    import flash.display.BitmapData;
    import flash.display.BlendMode;
    import flash.display.GradientType;
    import flash.display.Sprite;
    import flash.geom.ColorTransform;
    import flash.geom.Matrix;
    import flash.geom.Point;
    import flash.geom.Rectangle;
    import flash.utils.getTimer;

    /** Viewport raster and gameplay samples use the same current illumination. */
    public final class LadLightField {
        public const cell:int = 12;
        public var bitmap:Bitmap = new Bitmap(null,"auto",true);
        public var data:BitmapData;
        public var bounds:Rectangle = new Rectangle();
        public var elapsedMs:int = 0;
        public var rebuilds:int = 0;
        public var trailRaster:LadTrailRaster=new LadTrailRaster();
        private var cache:Object = {};
        private var terrainHash:uint = 0;
        private var terrainRegion:String = "";
        private var loc:*;
        private var background:BitmapData;
        private var backgroundKey:String="";
        private var sceneBackground:BitmapData;
        private var sceneBackgroundKey:String="";
        public var sceneLightsCache:Boolean=true;
        public var sceneLightBuilds:int=0;
        private var previousView:Rectangle=new Rectangle();
        private var steadyViewFrames:int=0;
        private var materialHashes:Object={};
        // A scrolling viewport is not a terrain edit. Rooms retain the
        // same shadow geometry and a padded ambient raster until content changes.
        public var sceneCache:Boolean=true;
        private var usingSceneCache:Boolean=false;
        private var terrainCells:Array=[];
        private var backgroundBounds:Rectangle=new Rectangle();
        public function LadLightField() {
            bitmap.name = "LightAndDarknessIllumination";
            bitmap.blendMode = BlendMode.MULTIPLY;
            bitmap.scaleX = bitmap.scaleY = cell;
        }
        public function clear():void {
            trailRaster.clear();
            for each(var item:Object in cache) item.data.dispose();
            cache = {}; terrainHash = 0; terrainRegion = ""; loc = null;
            if(data) data.dispose(); data=null; bitmap.bitmapData=null;
            if(background) background.dispose();background=null;backgroundKey="";
            if(sceneBackground) sceneBackground.dispose();sceneBackground=null;sceneBackgroundKey="";
            previousView.setEmpty();steadyViewFrames=0;
            terrainCells=[];backgroundBounds.setEmpty();usingSceneCache=false;
            if(bitmap.parent) bitmap.parent.removeChild(bitmap);
        }
        public function render(location:*, view:Rectangle, lights:Array, ambient:Number,zones:Array=null,darkness:Number=1,environment:LadEnvironment=null):void {
            var started:int = getTimer();
            if(loc !== location) { clear(); loc = location; }
            var vx:int = Math.floor(view.x/cell)*cell-cell;
            var vy:int = Math.floor(view.y/cell)*cell-cell;
            var width:int = Math.ceil((view.right-vx)/cell)+2;
            var height:int = Math.ceil((view.bottom-vy)/cell)+2;
            if(data == null || data.width != width || data.height != height) {
                if(data) data.dispose(); data=new BitmapData(width,height,false,0);
                bitmap.bitmapData=data;
                // AIR resets smoothing when bitmapData is replaced; restore it on every resize.
                bitmap.smoothing=true;
            }
            bounds.setTo(vx,vy,width*cell,height*cell);
            steadyViewFrames=previousView.equals(bounds)?steadyViewFrames+1:0;
            previousView.copyFrom(bounds);
            bitmap.x=vx; bitmap.y=vy;
            var reuse:Boolean=sceneCache;
            if(reuse!=usingSceneCache) {
                clearGeometry();terrainCells=[];terrainHash=0;terrainRegion="";backgroundKey="";
                usingSceneCache=reuse;
            }
            var scan:Rectangle=view.clone(); scan.inflate(600,600);
            if(reuse) {
                // Include the ambient flood's seven-tile support and every
                // current light, even when its rays extend beyond the camera.
                if(background) {var ambientScan:Rectangle=backgroundBounds.clone();ambientScan.inflate(280,280);scan=scan.union(ambientScan);}
                for each(var activeLight:Object in lights)
                    if(!activeLight.trail && bounds.intersects(new Rectangle(activeLight.x-activeLight.radius,activeLight.y-activeLight.radius,activeLight.radius*2,activeLight.radius*2)))
                        scan=scan.union(new Rectangle(activeLight.x-activeLight.radius,activeLight.y-activeLight.radius,activeLight.radius*2,activeLight.radius*2));
                if(sceneTerrainChanged(scan)) {clearGeometry();++terrainHash;backgroundKey="";}
            } else {
            var left:int=Math.max(0,int(scan.left/40));
            var top:int=Math.max(0,int(scan.top/40));
            var right:int=Math.min(loc.spaceX-1,int(scan.right/40));
            var bottom:int=Math.min(loc.spaceY-1,int(scan.bottom/40));
            var hash:uint=2166136261;
            for(var x:int=left;x<=right;x++) for(var y:int=top;y<=bottom;y++) {
                hash ^= uint(Math.max(0,Math.min(255,Number(loc.space[x][y].opac)*255)));
                hash += (hash<<1)+(hash<<4)+(hash<<7)+(hash<<8)+(hash<<24);
                if(environment) {
                    var tile:*=loc.space[x][y];
                    var back:String=String(tile.back)+":"+(tile.fRear?String(tile.front):"");
                    if(!materialHashes.hasOwnProperty(back)) materialHashes[back]=LadAtmosphere.seed(back);
                    hash^=uint(materialHashes[back]);hash+=(hash<<1)+(hash<<4)+(hash<<7)+(hash<<8)+(hash<<24);
                    // Half-height and sloped surfaces can change without changing opacity.
                    hash^=uint(tile.phis*31+tile.zForm*131+tile.diagon*521+tile.phY1*8191);
                    hash+=(hash<<1)+(hash<<4)+(hash<<7)+(hash<<8)+(hash<<24);
                }
            }
            var region:String=[left,top,right,bottom].join(":");
            if(hash!=terrainHash || region!=terrainRegion) {
                for each(var old:Object in cache) old.data.dispose(); cache={};
                terrainHash=hash;terrainRegion=region;
            }
            }
            ambientBackground(ambient,zones,darkness,environment,reuse);
            var alive:Object={};
            var prefix:int=0;
            if(reuse && sceneLightsCache && steadyViewFrames>=2)while(prefix<lights.length && lights[prefix].staticScene && !lights[prefix].trail)++prefix;
            var base:BitmapData=prefix>1?stableBackground(lights,prefix,alive):background;
            if(prefix<=1)prefix=0;
            data.lock(); data.copyPixels(base,prefix>1?base.rect:new Rectangle((bounds.x-backgroundBounds.x)/cell,(bounds.y-backgroundBounds.y)/cell,data.width,data.height),new Point());
            for(var i:int=prefix;i<lights.length;++i) {
                var light:Object=lights[i];
                if(light.trail) continue;
                drawLight(data,bounds,light,alive);
            }
            for(var key:String in cache) if(!alive[key]) {cache[key].data.dispose();delete cache[key];}
            trailRaster.render(data,bounds,cell,loc,lights);
            data.unlock();elapsedMs=getTimer()-started;
        }
        private function clearGeometry():void {
            for each(var old:Object in cache) old.data.dispose();cache={};
            sceneBackgroundKey="";
        }
        private function stableBackground(lights:Array,count:int,alive:Object):BitmapData {
            var selected:Array=[],parts:Array=[backgroundKey,bounds.toString()];
            for(var i:int=0;i<count;++i) {
                var light:Object=lights[i];
                // Cache the same viewport-visible prefix, in its original order.
                // A newly visible light changes this key before cached pixels are used.
                if(!intersectsLight(bounds,light))continue;
                alive[String(light.id)]=true;selected.push(light);
                parts.push(light.id,light.x,light.y,light.radius,light.angle,light.cone,light.color,light.power);
            }
            var key:String=parts.join(":");
            if(sceneBackground && key==sceneBackgroundKey)return sceneBackground;
            if(sceneBackground)sceneBackground.dispose();
            // AIR's clipped SCREEN sampling differs when a draw target is padded.
            // Keep the exact viewport target and transform of the uncached path.
            // Only cache after the view settles, avoiding allocations while scrolling.
            sceneBackground=new BitmapData(data.width,data.height,false,0);sceneBackground.lock();
            sceneBackground.copyPixels(background,new Rectangle((bounds.x-backgroundBounds.x)/cell,(bounds.y-backgroundBounds.y)/cell,data.width,data.height),new Point());
            for each(light in selected)drawLight(sceneBackground,bounds,light,alive);
            sceneBackground.unlock();sceneBackgroundKey=key;++sceneLightBuilds;
            return sceneBackground;
        }
        private function intersectsLight(rect:Rectangle,light:Object):Boolean {
            return rect.intersects(new Rectangle(light.x-light.radius,light.y-light.radius,light.radius*2,light.radius*2));
        }
        private function drawLight(target:BitmapData,area:Rectangle,light:Object,alive:Object):void {
            if(!intersectsLight(area,light))return;
            var identity:String=String(light.id);alive[identity]=true;
            // A momentary blackout retains its shadow geometry for the next lit frame.
            if(light.power<=0)return;
            var signature:String=[int(light.x/4),int(light.y/4),light.radius,int(light.angle*90/Math.PI),light.cone].join(":");
            var entry:Object=cache[identity];
            if(entry==null || entry.key!=signature) {
                if(entry)entry.data.dispose();
                entry={key:signature,data:makeLight(light)};cache[identity]=entry;rebuilds++;
            }
            var color:uint=uint(light.color);
            var transform:ColorTransform=new ColorTransform(((color>>16)&255)/255*light.power,
                ((color>>8)&255)/255*light.power,(color&255)/255*light.power,1);
            var matrix:Matrix=new Matrix(1,0,0,1,(light.x-light.radius-area.x)/cell,(light.y-light.radius-area.y)/cell);
            target.draw(entry.data,matrix,transform,BlendMode.SCREEN,null,true);
        }
        private function sceneTerrainChanged(scan:Rectangle):Boolean {
            var left:int=Math.max(0,Math.floor(scan.left/40)),top:int=Math.max(0,Math.floor(scan.top/40));
            var right:int=Math.min(loc.spaceX-1,Math.floor(scan.right/40)),bottom:int=Math.min(loc.spaceY-1,Math.floor(scan.bottom/40));
            var changed:Boolean=false;
            for(var x:int=left;x<=right;++x) {
                var column:Array=terrainCells[x];if(!column){column=[];terrainCells[x]=column;}
                var tiles:Array=loc.space[x];
                for(var y:int=top;y<=bottom;++y) {
                    var tile:Tile=tiles[y],old:LadTileState=column[y];
                    var opacity:Number=tile.opac,back:String=tile.back,rear:Boolean=tile.fRear,front:String=rear?tile.front:"";
                    var physical:int=tile.phis,shape:int=tile.zForm,diagonal:int=tile.diagon,topEdge:Number=tile.phY1;
                    if(!old) column[y]=new LadTileState(opacity,back,rear,front,physical,shape,diagonal,topEdge);
                    else if(old.opacity!=opacity || old.back!=back || old.rear!=rear || old.front!=front
                        || old.physical!=physical || old.shape!=shape || old.diagonal!=diagonal || old.top!=topEdge) {
                        changed=true;old.opacity=opacity;old.back=back;old.rear=rear;old.front=front;
                        old.physical=physical;old.shape=shape;old.diagonal=diagonal;old.top=topEdge;
                    }
                }
            }
            return changed;
        }
        private function ambientBackground(ambient:Number,zones:Array,darkness:Number,environment:LadEnvironment,reuse:Boolean):void {
            var signature:String=[ambient,darkness,JSON.stringify(zones),environment?environment.signature()+":"+terrainHash:""].join(":");
            if(signature==backgroundKey && background && (reuse?backgroundBounds.containsRect(bounds):backgroundBounds.equals(bounds))) return;
            if(background) background.dispose();
            backgroundBounds=bounds.clone();if(reuse)backgroundBounds.inflate(240,240);
            var paintBounds:Rectangle=backgroundBounds;
            var shade:int=Math.max(0,Math.min(255,int(ambient*255)));
            background=environment?environment.paint(paintBounds,cell,ambient/0.14):new BitmapData(Math.round(paintBounds.width/cell),Math.round(paintBounds.height/cell),false,(shade<<16)|(shade<<8)|shade);
            var original:BitmapData=zones && zones.length && darkness>0?background.clone():null;
            if(zones && darkness>0) for each(var zone:Object in zones) {
                var rect:Rectangle=new Rectangle(zone.x,zone.y,zone.width,zone.height);
                if(!paintBounds.intersects(rect)) continue;
                var left:int=Math.max(0,int((rect.left-paintBounds.x)/cell));
                var top:int=Math.max(0,int((rect.top-paintBounds.y)/cell));
                var right:int=Math.min(background.width,Math.ceil((rect.right-paintBounds.x)/cell));
                var bottom:int=Math.min(background.height,Math.ceil((rect.bottom-paintBounds.y)/cell));
                for(var x:int=left;x<right;x++) for(var y:int=top;y<bottom;y++) {
                    var wx:Number=paintBounds.x+(x+0.5)*cell,wy:Number=paintBounds.y+(y+0.5)*cell;
                    var edge:Number=Math.min(wx-rect.left,rect.right-wx,wy-rect.top,rect.bottom-wy);
                    if(edge<0) continue;
                    var weight:Number=zone.feather>0?Math.min(1,edge/zone.feather):1;
                    weight=weight*weight*(3-2*weight);
                    var value:int=Math.min(background.getPixel(x,y)&255,int((original.getPixel(x,y)&255)*(1-darkness*weight*(1-zone.factor))));
                    background.setPixel(x,y,(value<<16)|(value<<8)|value);
                }
            }
            if(original) original.dispose();
            backgroundKey=signature;
        }
        private function makeLight(light:Object):BitmapData {
            var radius:Number=Number(light.radius);
            var side:int=Math.ceil(radius*2/cell)+1;
            var root:Sprite=new Sprite(),glow:Sprite=new Sprite(),mask:Sprite=new Sprite();
            var matrix:Matrix=new Matrix(); matrix.createGradientBox(radius*2/cell,radius*2/cell);
            glow.graphics.beginGradientFill(GradientType.RADIAL,[0xFFFFFF,0xFFFFFF,0],[1,1,1],[0,45,255],matrix);
            glow.graphics.drawRect(0,0,side,side);glow.graphics.endFill();
            mask.graphics.beginFill(0xFFFFFF);
            var cone:Number=Number(light.cone),center:Number=Number(light.angle);
            var full:Boolean=cone>=Math.PI*2-0.01;
            var start:Number=full?0:center-cone/2;
            var count:int=light.transient?64:Math.max(24,Math.ceil(cone/(Math.PI/90)));
            if(!full) mask.graphics.moveTo(radius/cell,radius/cell);
            for(var i:int=0;i<=count;i++) {
                var angle:Number=start+cone*i/count;
                var distance:Number=traceRay(light.x,light.y,Math.cos(angle),Math.sin(angle),radius);
                var px:Number=(radius+Math.cos(angle)*distance)/cell;
                var py:Number=(radius+Math.sin(angle)*distance)/cell;
                if(i==0 && full) mask.graphics.moveTo(px,py);else mask.graphics.lineTo(px,py);
            }
            if(!full) mask.graphics.lineTo(radius/cell,radius/cell);
            mask.graphics.endFill();root.addChild(glow);root.addChild(mask);glow.mask=mask;
            var result:BitmapData=new BitmapData(side,side,false,0);
            result.draw(root);return result;
        }
        public function traceRay(sx:Number,sy:Number,dx:Number,dy:Number,radius:Number):Number {
            var cx:int=Math.floor(sx/40),cy:int=Math.floor(sy/40);
            var stepX:int=dx<0?-1:1,stepY:int=dy<0?-1:1;
            var nextX:Number=Math.abs(dx)<0.00001?1e20:((cx+(stepX>0?1:0))*40-sx)/dx;
            var nextY:Number=Math.abs(dy)<0.00001?1e20:((cy+(stepY>0?1:0))*40-sy)/dy;
            var deltaX:Number=Math.abs(dx)<0.00001?1e20:Math.abs(40/dx);
            var deltaY:Number=Math.abs(dy)<0.00001?1e20:Math.abs(40/dy);
            var distance:Number=0,opacity:Number=0;
            while(distance<radius) {
                if(nextX<nextY) {distance=nextX;nextX+=deltaX;cx+=stepX;}
                else {distance=nextY;nextY+=deltaY;cy+=stepY;}
                if(distance>=radius) break;
                if(cx<0||cy<0||cx>=loc.spaceX||cy>=loc.spaceY) return Math.max(0,distance);
                opacity+=Math.max(0,Number(loc.space[cx][cy].opac));
                if(opacity>=0.99) return Math.max(0,distance-1);
            }
            return radius;
        }
        public function sample(x:Number,y:Number):Number {
            if(data==null || !bounds.contains(x,y)) return 1;
            var value:uint=data.getPixel(Math.min(data.width-1,Math.max(0,int((x-bounds.x)/cell))),
                Math.min(data.height-1,Math.max(0,int((y-bounds.y)/cell))));
            return Math.max((value>>16)&255,(value>>8)&255,value&255)/255;
        }
    }
}

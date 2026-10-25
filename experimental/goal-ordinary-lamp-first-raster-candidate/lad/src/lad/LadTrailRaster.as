package lad {
    import flash.display.BitmapData;
    import flash.geom.Rectangle;

    /** One reusable CPU raster for all transient ribbons. No per-bullet bitmaps,
     * display objects, shadow fans or cache invalidation by changing positions. */
    public final class LadTrailRaster {
        public static const MAX_VISITS:int=65536;
        public var visits:int=0;
        public var rays:int=0;
        public var painted:int=0;
        public var limited:Boolean=false;
        private var colors:Vector.<uint>=new Vector.<uint>();
        private var stamps:Vector.<uint>=new Vector.<uint>();
        private var touched:Vector.<int>=new Vector.<int>();
        private var epoch:uint=0;
        public function clear():void {colors.length=stamps.length=touched.length=0;epoch=0;}
        public function render(target:BitmapData,bounds:Rectangle,cell:int,loc:*,lights:Array):void {
            visits=rays=painted=0;limited=false;touched.length=0;
            var width:int=target.width,height:int=target.height,size:int=width*height;
            if(colors.length!=size){colors.length=stamps.length=size;}
            if(++epoch==0){for(var z:int=0;z<size;++z)stamps[z]=0;epoch=1;}
            var segments:int=0;
            for each(var light:Object in lights) {
                if(!light.trail || light.power<=0)continue;
                var color:uint=uint(light.color),red:int=color>>16&255,green:int=color>>8&255,blue:int=color&255;
                for each(var s:Object in light.trail) {
                    if(++segments>96 || visits>=MAX_VISITS){limited=true;break;}
                    var ax:Number=s.ax,ay:Number=s.ay,bx:Number=s.bx,by:Number=s.by,radius:Number=s.width;
                    var dx:Number=bx-ax,dy:Number=by-ay,len2:Number=dx*dx+dy*dy;
                    if(!isFinite(len2) || !isFinite(radius) || radius<=0 || radius>120)continue;
                    var top:int=Math.max(0,Math.floor((Math.min(ay,by)-radius-bounds.y)/cell));
                    var bottom:int=Math.min(height-1,Math.ceil((Math.max(ay,by)+radius-bounds.y)/cell));
                    for(var py:int=top;py<=bottom && visits<MAX_VISITS;++py) {
                        var wy:Number=bounds.y+(py+0.5)*cell;
                        // Bound each scanline to the ribbon, not its diagonal AABB.
                        var low:Number=0,high:Number=1;
                        if(Math.abs(dy)>0.001) {
                            var t0:Number=(wy-radius-ay)/dy,t1:Number=(wy+radius-ay)/dy;
                            low=Math.max(0,Math.min(t0,t1));high=Math.min(1,Math.max(t0,t1));
                            if(low>high)continue;
                        }
                        var x0:Number=ax+dx*low,x1:Number=ax+dx*high;
                        var left:int=Math.max(0,Math.floor((Math.min(x0,x1)-radius-bounds.x)/cell));
                        var right:int=Math.min(width-1,Math.ceil((Math.max(x0,x1)+radius-bounds.x)/cell));
                        for(var px:int=left;px<=right && visits<MAX_VISITS;++px) {
                            ++visits;
                            var wx:Number=bounds.x+(px+0.5)*cell;
                            var t:Number=len2>0.001?Math.max(0,Math.min(1,((wx-ax)*dx+(wy-ay)*dy)/len2)):1;
                            var sx:Number=ax+t*dx,sy:Number=ay+t*dy;
                            var longitudinal:Number=s.tail+(s.head-s.tail)*t;
                            var spread:Number=radius*(0.65+0.35*longitudinal);
                            var q:Number=1-((wx-sx)*(wx-sx)+(wy-sy)*(wy-sy))/(spread*spread);
                            if(q<=0)continue;
                            var strength:Number=Math.min(1,q*q*longitudinal*light.power);
                            if(strength<0.006 || !visible(loc,sx,sy,wx,wy))continue;
                            var index:int=py*width+px,old:uint=stamps[index]==epoch?colors[index]:0;
                            if(stamps[index]!=epoch){stamps[index]=epoch;touched.push(index);}
                            // Same-colour overlap takes the brighter ribbon. A shotgun
                            // volley cannot multiply a tiny area to an opaque white patch.
                            colors[index]=(Math.max(old>>16&255,int(red*strength))<<16)|
                                (Math.max(old>>8&255,int(green*strength))<<8)|Math.max(old&255,int(blue*strength));
                        }
                    }
                }
            }
            limited=limited || visits>=MAX_VISITS;
            for each(index in touched) {
                px=index%width;py=int(index/width);old=target.getPixel(px,py);color=colors[index];
                target.setPixel(px,py,((255-int((255-(old>>16&255))*(255-(color>>16&255))/255))<<16)|
                    ((255-int((255-(old>>8&255))*(255-(color>>8&255))/255))<<8)|(255-int((255-(old&255))*(255-(color&255))/255)));
            }
            painted=touched.length;
        }
        private function visible(loc:*,sx:Number,sy:Number,x:Number,y:Number):Boolean {
            ++rays;
            var cx:int=Math.floor(sx/40),cy:int=Math.floor(sy/40),ex:int=Math.floor(x/40),ey:int=Math.floor(y/40);
            if(cx<0 || cy<0 || ex<0 || ey<0 || cx>=loc.spaceX || cy>=loc.spaceY || ex>=loc.spaceX || ey>=loc.spaceY)return false;
            if(Number(loc.space[cx][cy].opac)>=0.99 || Number(loc.space[ex][ey].opac)>=0.99)return false;
            if(cx==ex && cy==ey)return true;
            var dx:Number=x-sx,dy:Number=y-sy,stepX:int=dx<0?-1:1,stepY:int=dy<0?-1:1;
            var nx:Number=Math.abs(dx)<0.00001?1e20:((cx+(stepX>0?1:0))*40-sx)/dx;
            var ny:Number=Math.abs(dy)<0.00001?1e20:((cy+(stepY>0?1:0))*40-sy)/dy;
            var tx:Number=Math.abs(dx)<0.00001?1e20:Math.abs(40/dx),ty:Number=Math.abs(dy)<0.00001?1e20:Math.abs(40/dy),opacity:Number=0;
            while(cx!=ex || cy!=ey) {
                // At a corner check both touching cells: no diagonal wall leak.
                if(Math.abs(nx-ny)<0.000001) {
                    if(cx+stepX<0 || cx+stepX>=loc.spaceX || cy+stepY<0 || cy+stepY>=loc.spaceY)return false;
                    if(Number(loc.space[cx+stepX][cy].opac)>=0.99 || Number(loc.space[cx][cy+stepY].opac)>=0.99)return false;
                    nx+=tx;ny+=ty;cx+=stepX;cy+=stepY;
                } else if(nx<ny){nx+=tx;cx+=stepX;}else{ny+=ty;cy+=stepY;}
                if(cx<0 || cy<0 || cx>=loc.spaceX || cy>=loc.spaceY)return false;
                opacity+=Math.max(0,Number(loc.space[cx][cy].opac));if(opacity>=0.99)return false;
            }
            return true;
        }
    }
}

package lad {
    import flash.display.BitmapData;
    import flash.geom.Matrix;
    import flash.geom.Rectangle;

    /** Native backdrop geometry supplies ambient light; fixtures remain independent, destructible lights. */
    public final class LadEnvironment {
        public var regions:Array=[];
        public var openings:Array=[];
        public var protectedPoints:Array=[];
        public var brightness:LadLightingPreferences=new LadLightingPreferences();
        private var loc:*;
        private var identity:String;
        private var land:String;
        private var fallback:Object;
        private var lastSignature:String="";
        private var backdrop:LadBackdrop=new LadBackdrop();
        private var backgroundName:String="";
        private var apertureSeeds:Object={};
        private var legacyApertures:Object={};
        private var apertureRecords:Array=[];
        private var openingKey:String="";
        private var openingContext:String="";
        private static const WINDOWS:Object={fwindow:true,bwindow:true,swindow:true,cwindow:true,awindow:true,enclwindow:true};
        private static const OUTSIDE_FONS:Object={fonRuins:true,fonDarkClouds:true,fonCanter:true,fonWay:true,fonEnclave:true,fonClear:true,fonFire:true,fonFinalb:true};
        public function clear():void {
            loc=null;regions=[];openings=[];protectedPoints=[];fallback=null;lastSignature="";
            backdrop.clear();backgroundName="";apertureSeeds={};legacyApertures={};apertureRecords=[];openingKey="";openingContext="";
        }
        public function bind(location:*,grafon:*,key:String):void {
            clear();loc=location;identity=key;land=String(loc.land.act.id);
            backdrop.bind(grafon);backgroundName=String(read(loc.land.act,"fon",""));
            fallback={bounds:new Rectangle(0,0,loc.spaceX*40,loc.spaceY*40),style:loc};
            if(grafon && "sceneRegionSlices" in grafon) {
                var slices:Array=grafon.sceneRegionSlices(loc,fallback.bounds);
                for each(var slice:Object in slices) regions.push({bounds:slice.bounds.clone(),style:slice.style});
            }
            if(!regions.length) regions.push(fallback);
            collectProtection();openingContext=contextSignature();collectWindows();
        }
        public function regionAt(x:Number,y:Number):Object {
            for each(var region:Object in regions) if(region.bounds.contains(x,y)) return region;
            return fallback;
        }
        private static function read(o:*,key:String,otherwise:*):* {return o && key in o?o[key]:otherwise;}
        private function outsideContext(style:*):Boolean {
            if(String(read(style,"backwall",""))=="sky" || Number(read(style,"backform",0))>0)return true;
            return OUTSIDE_FONS.hasOwnProperty(backgroundName);
        }
        private function geometricSky(r:Object,x:Number,y:Number):Boolean {
            var s:*=r.style;
            if(String(read(s,"backwall",""))=="sky")return true;
            var origin:Rectangle=read(s,"bounds",r.bounds) as Rectangle;
            var lx:Number=x-origin.x,ly:Number=y-origin.y,form:int=int(read(s,"backform",0));
            return form==1?lx>=430 && lx<1490:form==2?ly<650:form==3?ly<970:false;
        }
        public function profile(x:Number,y:Number):Object {
            var region:Object=regionAt(x,y),s:*=region.style;
            if(region.profile) return region.profile;
            var safe:Boolean=Boolean(read(s,"homeStable",false)) || Boolean(read(loc,"base",false)) || String(read(loc.land.act,"tip",""))=="base";
            var abandoned:Boolean=/begin|sewer|covert|grave|pis|raiders|mane|canter|workshop|minst|hql/.test(land);
            var maintained:Boolean=/stable|encl|mbase|bunker|comm/.test(land);
            var outage:Boolean=Number(read(loc,"lightOn",0))<0 || String(read(s,"color",""))=="black";
            var kind:String=safe?"safe":outage?"outage":abandoned?"abandoned":maintained?"maintained":"interior";
            var daylight:Boolean=Number(read(s,"backform",0))>0 || String(read(s,"backwall",""))=="sky"
                || (Boolean(read(s,"transpFon",false)) && outsideContext(s));
            var underground:Boolean=/begin|sewer|covert|grave|pis/.test(land);
            var brightnessKey:String=safe?"safe":outage?"outage":underground?"underground":kind;
            var base:Number=brightness.getLevel(brightnessKey);
            region.profile={kind:kind,ambient:base,safe:safe,abandoned:abandoned || outage,
                brightnessKey:brightnessKey,
                faults:safe?0:outage?35:abandoned?24:maintained?6:12,
                daylight:daylight,region:region};
            return region.profile;
        }
        /** A sky backdrop can sit behind interior masonry. Native backform uses local room coordinates. */
        public function skyAt(tx:int,ty:int):Boolean {
            return skyTransmission(tx,ty)>0.001;
        }
        private function skyTransmission(tx:int,ty:int):Number {
            if(!loc || tx<0 || ty<0 || tx>=loc.spaceX || ty>=loc.spaceY) return 0;
            var tile:*=loc.space[tx][ty];
            if(Number(tile.opac)>=0.99 || String(read(tile,"back",""))!="" || (Boolean(read(tile,"fRear",false)) && String(read(tile,"front",""))!="")) return 0;
            var x:Number=tx*40+20,y:Number=ty*40+20,r:Object=regionAt(x,y),s:*=r.style;
            var direct:Boolean=geometricSky(r,x,y),key:String=tx+":"+ty;
            var aperture:Number=Number(apertureSeeds[key]);if(isNaN(aperture))aperture=0;
            var transparent:Boolean=Boolean(read(s,"transpFon",false)) && outsideContext(s);
            if(!direct && (!transparent && aperture<=0 || Number(legacyApertures[key])>0))return 0;
            // Nine actual raster samples preserve partially transparent glass and avoid seeding a whole room.
            var total:Number=0,available:int=0;
            for(var ox:int=6;ox<=34;ox+=14)for(var oy:int=6;oy<=34;oy+=14) {
                var value:Number=backdrop.transmission(tx*40+ox,ty*40+oy);
                if(!isNaN(value)){total+=value;available++;}
            }
            if(available)return total/available;
            // No raster is common in synthetic checks and beforeSceneRaster. Only explicit geometry
            // or an authored aperture has a fallback; missing transparent chunks never become sources.
            return backdrop.allowsGeometryFallback?(direct?1:aperture):0;
        }
        /** Room policy, separate from raster residency so scene scrolling never regenerates all dark pockets. */
        public function contextSignature():String {
            if(loc)backgroundName=String(read(loc.land.act,"fon",""));
            var parts:Array=[land,read(loc,"lightOn",0),read(loc,"base",false),backgroundName,brightness.signature()];
            for each(var r:Object in regions) parts.push(r.bounds,read(r.style,"backwall",""),read(r.style,"backform",0),read(r.style,"transpFon",false),read(r.style,"color",""),read(r.style,"darkness",0),read(r.style,"homeStable",false));
            var key:String=parts.join(":");
            if(key!=lastSignature) {for each(r in regions) r.profile=null;if(fallback)fallback.profile=null;lastSignature=key;}
            return key;
        }
        private function refreshOpenings():String {
            var context:String=contextSignature();
            if(context!=openingContext || apertureSignature()!=openingKey) {collectWindows();openingContext=context;}
            return context;
        }
        public function signature():String {
            return refreshOpenings()+":"+backdrop.signature()+":"+openingKey;
        }
        /** Tile flood gives sky openings a short diffuse spill, stopped by current opaque walls/doors. */
        public function paint(bounds:Rectangle,cell:int,multiplier:Number):BitmapData {
            var left:int=Math.min(loc.spaceX,Math.max(0,Math.floor(bounds.left/40)-7)),top:int=Math.min(loc.spaceY,Math.max(0,Math.floor(bounds.top/40)-7));
            var right:int=Math.max(left,Math.min(loc.spaceX,Math.ceil(bounds.right/40)+7)),bottom:int=Math.max(top,Math.min(loc.spaceY,Math.ceil(bounds.bottom/40)+7));
            var width:int=right-left,height:int=bottom-top,n:int=width*height;
            var base:Vector.<Number>=new Vector.<Number>(n,true),sky:Vector.<Number>=new Vector.<Number>(n,true);
            var source:Vector.<Number>=new Vector.<Number>(n,true);
            var faceLeft:Vector.<Number>=new Vector.<Number>(n,true),faceRight:Vector.<Number>=new Vector.<Number>(n,true);
            var faceTop:Vector.<Number>=new Vector.<Number>(n,true),faceBottom:Vector.<Number>=new Vector.<Number>(n,true);
            var blocked:Vector.<Boolean>=new Vector.<Boolean>(n,true),solid:Vector.<Boolean>=new Vector.<Boolean>(n,true);
            var topEdge:Vector.<Number>=new Vector.<Number>(n,true),queue:Array=[],i:int,x:int,y:int;
            var daylight:Number=brightness.getLevel("outdoor");
            backdrop.prepare(new Rectangle(left*40,top*40,width*40,height*40));
            for(y=0;y<height;y++) for(x=0;x<width;x++) {
                i=y*width+x;var p:Object=profile((left+x)*40+20,(top+y)*40+20);
                var tile:*=loc.space[left+x][top+y];
                base[i]=p.ambient;blocked[i]=Number(tile.opac)>=0.99;solid[i]=Number(read(tile,"phis",0))>0 || blocked[i];
                topEdge[i]=Math.max(0,Math.min(40,Number(read(tile,"phY1",(top+y)*40))-(top+y)*40));
                var transmission:Number=skyTransmission(left+x,top+y);
                source[i]=transmission;
                if(transmission>0.001) {
                    base[i]=Math.min(base[i],daylight);
                    sky[i]=base[i]+(daylight-base[i])*transmission;queue.push(i);
                }
            }
            var cursor:int=0;
            while(cursor<queue.length) {
                // Keep the flood inside the existing seven-tile cache support even at full daylight.
                i=int(queue[cursor++]);var v:Number=sky[i]-0.11;
                if(v<=0.28) continue;
                x=i%width;y=int(i/width);
                var neighbors:Array=[];if(x>0)neighbors.push(i-1);if(x+1<width)neighbors.push(i+1);if(y>0)neighbors.push(i-width);if(y+1<height)neighbors.push(i+width);
                for each(var j:int in neighbors) if(!blocked[j] && sky[j]+0.001<v) {sky[j]=v;queue.push(j);}
            }
            // An opaque tile receives at its exposed faces but can never transmit that light onward.
            for(y=0;y<height;y++)for(x=0;x<width;x++) {
                i=y*width+x;if(!solid[i])continue;
                if(x>0 && !blocked[i-1])faceLeft[i]=sky[i-1];
                if(x+1<width && !blocked[i+1])faceRight[i]=sky[i+1];
                if(y>0 && !blocked[i-width])faceTop[i]=sky[i-width];
                if(y+1<height && !blocked[i+width])faceBottom[i]=sky[i+width];
            }
            var output:BitmapData=new BitmapData(Math.round(bounds.width/cell),Math.round(bounds.height/cell),false,0);
            output.lock();
            for(x=0;x<output.width;x++) for(y=0;y<output.height;y++) {
                var wx:Number=bounds.x+(x+0.5)*cell,wy:Number=bounds.y+(y+0.5)*cell;
                var tx:int=Math.floor(wx/40)-left,ty:int=Math.floor(wy/40)-top;
                // The tile pass already resolved its room profile. Only pixels
                // outside the location need the fallback region lookup.
                if(tx>=0 && ty>=0 && tx<width && ty<height) {
                    i=ty*width+tx;v=Math.max(base[i],sky[i]);
                    if(source[i]>0.001) {
                        // A narrow hole contributes proportionally to diffuse transport, but the
                        // visible sky inside that hole retains its own pixel-level transmission.
                        var directAlpha:Number=backdrop.transmission(wx,wy);
                        if(!isNaN(directAlpha))v=Math.max(v,base[i]+(daylight-base[i])*directAlpha);
                    }
                    if(solid[i]) {
                        var dx:Number=wx-(left+tx)*40,dy:Number=wy-(top+ty)*40;
                        var surfaceTop:Number=topEdge[i];tile=loc.space[left+tx][top+ty];
                        if(Number(read(tile,"diagon",0))!=0 && "getMaxY" in tile)
                            surfaceTop=Math.max(0,Math.min(40,Number(tile.getMaxY(wx))-(top+ty)*40));
                        var received:Number=Math.max(surface(base[i],faceLeft[i],dx),surface(base[i],faceRight[i],40-dx),
                            surface(base[i],faceTop[i],dy-surfaceTop),surface(base[i],faceBottom[i],40-dy));
                        var alpha:Number=backdrop.frontAlpha(wx,wy);
                        if(dy>=surfaceTop)v=Math.max(v,isNaN(alpha)?received:base[i]+(received-base[i])*alpha);
                    }
                }
                else v=profile(wx,wy).ambient;
                var shade:int=Math.max(0,Math.min(255,int(v*multiplier*255)));
                output.setPixel(x,y,(shade<<16)|(shade<<8)|shade);
            }
            output.unlock();return output;
        }
        private static function surface(base:Number,light:Number,distance:Number):Number {
            // Stop before the rear six pixels so 12px bilinear sampling cannot carry light through a thin wall.
            var amount:Number=Math.max(0,Math.min(1,1-distance/34));
            amount=amount*amount*(3-2*amount);
            return base+Math.max(0,light-base)*amount;
        }
        private function apertureSignature():String {
            var parts:Array=[read(read(loc,"backobjs",null),"length",0)];
            for each(var record:Object in apertureRecords)parts.push(record.bo.frame,record.bo.alpha,record.bo.scX,record.bo.scY,record.bo.X,record.bo.Y);
            return parts.join(":");
        }
        private function collectWindows():void {
            openings=[];apertureSeeds={};legacyApertures={};apertureRecords=[];
            for each(var bo:* in loc.backobjs) {
                // stwindow is an internal observation window. No unconditional daylight from it.
                var id:String=String(bo.id),legacy:Boolean=Boolean(WINDOWS[id]);
                var added:Boolean=id=="enil" || /^(c?hole)[0-9]*$/.test(id);
                if((!legacy && !added) || !bo.erase) continue;
                apertureRecords.push({bo:bo});
                if(Number(bo.alpha)<=0)continue;
                var p:Object=profile(bo.X,bo.Y);
                var exterior:Boolean=legacy?(p.daylight || outsideContext(p.region.style) || /surf|mane|mtn|canter|encl|plant|nio|rbl|workshop/.test(land))
                    :outsideContext(p.region.style);
                if(!exterior) continue;
                var r:Rectangle=bo.erase.getBounds(bo.erase);
                if(r.isEmpty()) continue;
                var area:Rectangle=new Rectangle(bo.X+Math.min(r.left*bo.scX,r.right*bo.scX),bo.Y+Math.min(r.top*bo.scY,r.bottom*bo.scY),Math.abs(r.width*bo.scX),Math.abs(r.height*bo.scY));
                if(area.width>4000 || area.height>4000) continue;
                // Inspect the actual aperture alpha, not the painted frame's bounding box.
                var mask:BitmapData=new BitmapData(Math.max(1,Math.ceil(area.width/40)),Math.max(1,Math.ceil(area.height/40)),true,0);
                mask.draw(bo.erase,new Matrix(bo.scX/40,0,0,bo.scY/40,(bo.X-area.x)/40,(bo.Y-area.y)/40));
                var points:Array=[];
                for(var x:int=0;x<mask.width;x++) for(var y:int=0;y<mask.height;y++) {
                    var rawAlpha:Number=(mask.getPixel32(x,y)>>>24)/255;
                    var alpha:Number=rawAlpha*Number(bo.alpha);
                    if(alpha<=0.02)continue;
                    var sample:Object={x:area.x+(x+0.5)*40,y:area.y+(y+0.5)*40};
                    var cellKey:String=int(Math.floor(sample.x/40))+":"+int(Math.floor(sample.y/40));
                    var previous:Number=Number(legacy?legacyApertures[cellKey]:apertureSeeds[cellKey]);
                    if(isNaN(previous))previous=0;
                    if(legacy)legacyApertures[cellKey]=Math.max(previous,alpha);
                    else apertureSeeds[cellKey]=Math.max(previous,alpha);
                    if((legacy?rawAlpha:alpha)>80/255)points.push(sample);
                }
                mask.dispose();
                // Several separated samples make a broad window; hard ceiling bounds huge decorative objects.
                for(var k:int=0;k<Math.min(4,points.length);k++) {
                    var q:Object=points[int((k+0.5)*points.length/Math.min(4,points.length))];
                    openings.push({id:"window:"+bo.id+":"+bo.X+":"+bo.Y+":"+k,x:q.x,y:q.y,radius:260,color:0xddeaff,power:0.5,angle:0,cone:Math.PI*2,staticScene:true,environmentOnly:!legacy});
                }
            }
            openingKey=apertureSignature();
        }
        public function lights(view:Rectangle):Array {
            // Runtime gathers sources before Field asks for its cache key. Refresh here as well
            // so an authored window changing frame/alpha/position never emits one stale frame.
            refreshOpenings();
            var eligible:Array=[],result:Array=[],cx:Number=view.x+view.width/2,cy:Number=view.y+view.height/2;
            for each(var light:Object in openings) {
                if(light.environmentOnly)continue;
                if(!view.intersects(new Rectangle(light.x-light.radius,light.y-light.radius,light.radius*2,light.radius*2))) continue;
                var tx:int=Math.floor(light.x/40),ty:int=Math.floor(light.y/40);
                if(tx<0 || ty<0 || tx>=loc.spaceX || ty>=loc.spaceY || loc.space[tx][ty].opac>=0.99) continue;
                eligible.push({light:light,d:(light.x-cx)*(light.x-cx)+(light.y-cy)*(light.y-cy)});
            }
            eligible.sortOn(["d"],[Array.NUMERIC]);
            for(var i:int=0;i<Math.min(24,eligible.length);i++)result.push(eligible[i].light);
            return result;
        }
        private function collectProtection():void {
            for each(var spawn:Object in read(loc,"spawnPoints",[])) protectedPoints.push({x:Number(spawn.x)*40,y:Number(spawn.y)*40,radius:240});
            for each(var act:* in read(loc,"acts",[])) if(act && "X" in act && "Y" in act) protectedPoints.push({x:Number(act.X),y:Number(act.Y),radius:200});
            for(var object:*=read(loc,"firstObj",null);object;object=object.nobj) if("inter" in object && object.inter && "X" in object && "Y" in object) {
                var inter:*=object.inter;
                // Ordinary loot can occupy a dark alcove. Protect doors, consoles,
                // controls and scripted interactions instead of every loot container.
                if(read(inter,"door",0) || read(inter,"prob",null) || read(inter,"cons",null) || read(inter,"knop",0)
                    || read(inter,"scrAct",null) || read(inter,"scrTouch",null) || read(object,"id","")=="exit")
                    protectedPoints.push({x:Number(object.X),y:Number(object.Y),radius:160});
            }
            // Only authored entry/interaction anchors: a saved player's current position must not reroll pockets.
        }
        public function protectedAt(x:Number,y:Number):Boolean {
            for each(var p:Object in protectedPoints) if(Math.abs(x-p.x)<p.radius+120 && Math.abs(y-p.y)<p.radius+80)return true;
            return false;
        }
        public function pockets():Array {
            var result:Array=[];
            for(var x:int=3;x<loc.spaceX-3;x+=4) for(var y:int=3;y<loc.spaceY-1;y++) {
                var wx:Number=x*40+20,wy:Number=y*40+20,p:Object=profile(wx,wy);
                if(p.safe || !p.abandoned || p.daylight || protectedAt(wx,wy) || result.length>=64)continue;
                if(loc.space[x][y].phis!=0 || loc.space[x][y+1].phis==0 || loc.space[x][y-1].phis!=0)continue;
                var roof:Boolean=false,side:Boolean=false;
                for(var d:int=1;d<=3;d++) {if(loc.space[x][y-d].opac>=0.99)roof=true;if(loc.space[x-d][y].opac>=0.99 || loc.space[x+d][y].opac>=0.99)side=true;}
                if(!roof || !side || LadAtmosphere.seed(identity+":"+x+":"+y)%100>=35)continue;
                var rect:Rectangle=new Rectangle(wx-120,wy-120,240,160);
                if(!p.region.bounds.containsRect(rect))continue;
                var overlap:Boolean=false;
                for each(var old:Object in result) if(rect.intersects(new Rectangle(old.x-80,old.y-80,old.width+160,old.height+160)))overlap=true;
                if(!overlap)result.push({x:rect.x,y:rect.y,width:rect.width,height:rect.height,feather:60,factor:0.4,automatic:true});
            }
            return result;
        }
    }
}

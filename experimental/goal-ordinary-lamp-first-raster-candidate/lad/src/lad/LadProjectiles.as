package lad {
    import flash.geom.Rectangle;
    import flash.utils.Dictionary;
    import flash.utils.getDefinitionByName;

    /** Observes native objects without changing their lifetime, damage or display. */
    public final class LadProjectiles {
        public static const MAX_TRACKED:int=192;
        public static const MAX_PULSES:int=96;
        public static const MAX_LIGHTS:int=24;
        public var clock:Number=0;
        public var captured:int=0;
        public var dropped:int=0;
        public var scanCount:int=0;
        private var world:*,loc:*;
        private var records:Array=[];
        private var known:Dictionary=new Dictionary(true);
        private var pulses:Array=[];
        private var pulseById:Object={};
        private var evict:int=0;
        private var serial:int=0;
        private var emitters:Class;
        private var grafon:Class;
        private var bulletClass:Class;
        private var view:Rectangle;
        public function LadProjectiles() {}
        public function bind(w:*,location:*):void {
            if(loc===location) return;
            clear();world=w;loc=location;
            bulletClass=getDefinitionByName("fe.weapon.Bullet") as Class;
            emitters=getDefinitionByName("fe.graph.Emitter") as Class;
            grafon=getDefinitionByName("fe.graph.Grafon") as Class;
        }
        public function clear():void {
            records=[];pulses=[];pulseById={};evict=0;known=new Dictionary(true);loc=null;world=null;clock=0;view=null;
        }
        public function setView(value:Rectangle):void {view=value.clone();}
        public function get trackedCount():int {return records.length;}
        public function get pulseCount():int {return pulses.length;}
        public function observe(o:*):void {
            if(!loc || !o || o.loc!==loc || !o.vis || known[o]) return;
            var bullet:Boolean=o is bulletClass;
            if(!bullet && !("blitData" in o && "mliv" in o)) return;
            known[o]=true;
            // Part is fully initialized before addObj; negative cache prevents a
            // shower of smoke/blood/shells from being reclassified every tick.
            if(!bullet && partProfile(o)==null) return;
            if(records.length>=MAX_TRACKED) {dropped++;return;}
            // Bullet constructor has not yet received Weapon.setBullet fields here.
            records.push({o:o,id:++serial,bullet:bullet,p:null,started:false,hit:false,
                x:Number(o.X),y:Number(o.Y),path:[],lastTick:-1});captured++;
        }
        private function partProfile(o:*):Object {
            if(!emitters || !grafon) return null;
            for each(var id:String in LadProjectileProfiles.EMITTER_IDS) {
                var emitter:*=emitters["arr"][id];
                if(!emitter) continue;
                if((o.vClass && emitter.visClass===o.vClass) ||
                    (o.blitData && emitter.blit && grafon["spriteLists"][emitter.blit]===o.blitData))
                    {
                        // These native emitters share a sprite sheet. Preserve
                        // their public blend/scale clues without replaying emit.
                        if(id=="expl") {
                            if(o.vis.blendMode=="screen") id="fireexpl";
                            else if(Math.abs(o.vis.scaleX)>=1.5) id="ttexpl";
                        } else if(id=="plaexpl" && Math.abs(o.vis.scaleX)>=1.5) id="ttplaexpl";
                        return LadProjectileProfiles.emitter(id);
                    }
            }
            return null;
        }
        public function advance():void {
            if(!loc) return;
            clock+=1/30;
            for(var i:int=pulses.length-1;i>=0;i--) if(pulses[i].until<=clock) {delete pulseById[pulses[i].id];pulses.splice(i,1);}
            // Fallback discovers objects already present when the mod/scene was enabled.
            var object:*=loc.firstObj;scanCount=0;
            while(object && scanCount<2048) {observe(object);object=object.nobj;scanCount++;}
            capture();
        }
        public function capture():Boolean {
            if(!loc) return false;
            var changed:Boolean=false;
            for(var i:int=records.length-1;i>=0;i--) {
                var r:Object=records[i],o:*=r.o;
                if(o.loc!==loc) {records.splice(i,1);continue;}
                if(!r.started) {
                    r.p=r.bullet?LadProjectileProfiles.bullet(o):partProfile(o);
                    r.started=true;
                    if(!r.p) {records.splice(i,1);continue;}
                    if(!r.bullet) {
                        if(o.otklad>0) {if(!o.in_chain) records.splice(i,1);else r.started=false;continue;}
                        flash(Number(o.X),Number(o.Y),r.p.radius,r.p.power,r.p.color,r.p.life,"blast");
                        records.splice(i,1);changed=true;continue;
                    }
                    if(r.p.muzzle && !o.isExpl) {
                        flash(Number(o.begx),Number(o.begy),Math.min(110,r.p.radius+25),r.p.power,r.p.color,0.07,"muzzle");
                        changed=true;
                    }
                }
                var p:Object=r.p;
                var x:Number=Number(o.X),y:Number=Number(o.Y);
                var moved:Boolean=Math.abs(x-r.x)+Math.abs(y-r.y)>0.5;
                var tick:int=int(clock*30+0.5);
                if(p.flight && (moved || r.lastTick!=tick) && !o.isExpl && (!o.babah || !r.hit)) {
                    var sx:Number=p.beam?Number(o.begx):r.x;
                    var sy:Number=p.beam?Number(o.begy):r.y;
                    trail(r,sx,sy,x,y,p);
                    changed=true;
                }
                if(!r.hit && (o.isExpl || o.babah)) {
                    r.hit=true;
                    if(o.isExpl) {
                        // Visible parent gives a fallback when native particles are disabled.
                        // Gas/acid and weapon-specific no-light explosions remain dark.
                        var explosion:Object=explosionProfile(o,p);
                        if(explosion) {
                            var size:Number=Math.min(360,Math.max(explosion.radius,Number(o.explRadius)*1.25));
                            impact(x,y,r.x,r.y,size,explosion.power,explosion.color,explosion.life,"blast");changed=true;
                        }
                    } else if(o.tilehit || (o.parr && o.parr.length>0)) {
                        impact(x,y,r.x,r.y,p.impact,p.power,p.color,p.life,"impact");changed=true;
                    }
                }
                r.x=x;r.y=y;r.lastTick=tick;
                if(!o.in_chain || o.liv<=0 || o.off || r.hit) records.splice(i,1);
            }
            return changed;
        }
        private function explosionProfile(o:*,fallback:Object):Object {
            var visual:String=o.weap?String(o.weap.visexpl):"";
            if(visual=="sparkle") visual=Number(o.inWater)>0?"explw":"sparkleexpl";
            if(visual && visual!="null" && visual!="undefined") return LadProjectileProfiles.emitter(visual);
            var damage:int=int(o.tipDamage);
            if([3,4,6,8,10,11,15].indexOf(damage)<0) return null;
            if(damage==3 && Number(o.inWater)>0) return null;
            var id:String=damage==3?"fireexpl":damage==6?"plaexpl":damage==8?"impexpl":damage==10?"acidexpl":damage==11?"iceexpl":damage==15?"balefire":Number(o.inWater)>0?"explw":"expl";
            return LadProjectileProfiles.emitter(id);
        }
        private function trail(record:Object,sx:Number,sy:Number,x:Number,y:Number,p:Object):void {
            var dx:Number=x-sx,dy:Number=y-sy,length:Number=Math.sqrt(dx*dx+dy*dy);
            if(!isFinite(length)) return;
            var path:Array=record.path;
            if(p.beam) path=[{x:sx,y:sy},{x:x,y:y}];
            else {
                if(path.length==0)path.push({x:sx,y:sy});
                var last:Object=path[path.length-1];
                if(Math.abs(x-last.x)+Math.abs(y-last.y)>0.5) {
                    // Coalesce straight motion, retain bends of homing/ballistic shots.
                    if(path.length>1) {
                        var prev:Object=path[path.length-2];
                        var ux:Number=last.x-prev.x,uy:Number=last.y-prev.y,vx:Number=x-last.x,vy:Number=y-last.y;
                        var product:Number=Math.sqrt((ux*ux+uy*uy)*(vx*vx+vy*vy));
                        if(product>0 && (ux*vx+uy*vy)/product>0.997)path.pop();
                    }
                    path.push({x:x,y:y});
                }
                while(path.length>12)path.shift();
            }
            var desired:Number=p.shape=="streak"?Math.min(p.length,Math.max(88,Number(record.o.vel)*0.88)):p.length;
            var segments:Array=[],remaining:Number=p.beam?1e12:desired,skip:Number=p.rear,walked:Number=0;
            var minX:Number=1e20,minY:Number=1e20,maxX:Number=-1e20,maxY:Number=-1e20;
            for(var n:int=path.length-1;n>0 && remaining>0 && segments.length<4;n--) {
                var a:Object=path[n-1],b:Object=path[n];dx=b.x-a.x;dy=b.y-a.y;length=Math.sqrt(dx*dx+dy*dy);
                if(length<0.01)continue;
                if(skip>=length){skip-=length;continue;}
                var end:Number=1-skip/length,start:Number=Math.max(0,end-remaining/length);skip=0;
                var ax:Number=a.x+dx*start,ay:Number=a.y+dy*start,bx:Number=a.x+dx*end,by:Number=a.y+dy*end;
                var used:Number=(end-start)*length;
                var tail:Number=p.beam?1:Math.max(p.taper,1-(walked+used)/desired*(1-p.taper));
                var head:Number=p.beam?1:Math.max(p.taper,1-walked/desired*(1-p.taper));
                remaining-=used;walked+=used;
                // Most short paths are wholly visible. Avoid allocating a clipped
                // rectangle and slab arrays for every pellet on every simulation step.
                if(view && (Math.min(ax,bx)<Math.max(0.01,view.left-p.width) || Math.max(ax,bx)>Math.min(loc.spaceX*40-0.01,view.right+p.width) ||
                    Math.min(ay,by)<Math.max(0.01,view.top-p.width) || Math.max(ay,by)>Math.min(loc.spaceY*40-0.01,view.bottom+p.width))) {
                    var clipped:Array=clip(ax,ay,bx-ax,by-ay,p.width);
                    if(!clipped)continue;
                    var oldTail:Number=tail;
                    tail=oldTail+(head-oldTail)*clipped[0];head=oldTail+(head-oldTail)*clipped[1];
                    dx=bx-ax;dy=by-ay;bx=ax+dx*clipped[1];by=ay+dy*clipped[1];ax+=dx*clipped[0];ay+=dy*clipped[0];
                }
                // Clip at the first solid tile, including a last endpoint inside a wall.
                // An already penetrating projectile can illuminate again on its next clear segment.
                var safe:Number=clearFraction(ax,ay,bx,by);
                if(safe<=0)continue;
                bx=ax+(bx-ax)*safe;by=ay+(by-ay)*safe;head=tail+(head-tail)*safe;
                segments.push({ax:ax,ay:ay,bx:bx,by:by,width:p.width,tail:tail,head:head});
                minX=Math.min(minX,ax,bx);minY=Math.min(minY,ay,by);maxX=Math.max(maxX,ax,bx);maxY=Math.max(maxY,ay,by);
            }
            // Stationary glowing orbs keep a compact head; no invented direction/flight path.
            if(segments.length==0 && length<0.5 && free(x,y) && p.shape!="streak" && p.shape!="exhaust" && !p.beam) {
                segments.push({ax:x,ay:y,bx:x,by:y,width:p.width,tail:1,head:1});minX=maxX=x;minY=maxY=y;
            }
            if(segments.length==0)return;
            var id:String="trail:"+record.id;
            var value:Object=allocate(id);value.x=(minX+maxX)/2;value.y=(minY+maxY)/2;
            value.radius=Math.max(maxX-minX,maxY-minY)/2+p.width;
            value.power=p.power*(p.beam?0.8:0.65);value.color=p.color;value.born=clock;value.life=p.tail;value.until=clock+p.tail;
            value.trail=segments;value.width=p.width;
            if(!value.rect)value.rect=new Rectangle();
            value.rect.setTo(minX-p.width,minY-p.width,maxX-minX+2*p.width,maxY-minY+2*p.width);
        }
        private function clearFraction(ax:Number,ay:Number,bx:Number,by:Number):Number {
            if(!free(ax,ay))return 0;
            var dx:Number=bx-ax,dy:Number=by-ay;
            var cx:int=Math.floor(ax/40),cy:int=Math.floor(ay/40),stepX:int=dx<0?-1:1,stepY:int=dy<0?-1:1;
            var nx:Number=Math.abs(dx)<0.00001?1e20:((cx+(stepX>0?1:0))*40-ax)/dx;
            var ny:Number=Math.abs(dy)<0.00001?1e20:((cy+(stepY>0?1:0))*40-ay)/dy;
            var tx:Number=Math.abs(dx)<0.00001?1e20:Math.abs(40/dx),ty:Number=Math.abs(dy)<0.00001?1e20:Math.abs(40/dy),t:Number=0;
            while(Math.min(nx,ny)<1) {
                if(nx<ny){t=nx;nx+=tx;cx+=stepX;}else{t=ny;ny+=ty;cy+=stepY;}
                if(cx<0||cy<0||cx>=loc.spaceX||cy>=loc.spaceY||Number(loc.space[cx][cy].opac)>=0.99)return Math.max(0,t-0.001);
            }
            return 1;
        }
        private function clip(sx:Number,sy:Number,dx:Number,dy:Number,radius:Number):Array {
            var rect:Rectangle=view.clone();rect.inflate(radius,radius);
            rect=rect.intersection(new Rectangle(0.01,0.01,loc.spaceX*40-0.02,loc.spaceY*40-0.02));
            if(rect.isEmpty())return null;
            var start:Number=0,end:Number=1;
            var origins:Array=[sx,sy],deltas:Array=[dx,dy],low:Array=[rect.left,rect.top],high:Array=[rect.right,rect.bottom];
            for(var i:int=0;i<2;i++) {
                if(Math.abs(deltas[i])<0.00001) {if(origins[i]<low[i] || origins[i]>high[i]) return null;}
                else {
                    var a:Number=(low[i]-origins[i])/deltas[i],b:Number=(high[i]-origins[i])/deltas[i];
                    start=Math.max(start,Math.min(a,b));end=Math.min(end,Math.max(a,b));
                    if(start>end) return null;
                }
            }
            return [start,end];
        }
        private function free(x:Number,y:Number):Boolean {
            if(!isFinite(x) || !isFinite(y)) return false;
            var tx:int=Math.floor(x/40),ty:int=Math.floor(y/40);
            return tx>=0 && ty>=0 && tx<loc.spaceX && ty<loc.spaceY && Number(loc.space[tx][ty].opac)<0.99;
        }
        private function impact(x:Number,y:Number,previousX:Number,previousY:Number,radius:Number,power:Number,color:uint,life:Number,kind:String):void {
            // Native collision endpoints can be inside a wall; never start a light there.
            if(!free(x,y)) {
                var dx:Number=previousX-x,dy:Number=previousY-y,len:Number=Math.sqrt(dx*dx+dy*dy);
                if(len<=0 || !isFinite(len)) return;
                for(var n:int=1;n<=20;n++) {
                    var t:Number=Math.min(len,n*4)/len;
                    if(free(x+dx*t,y+dy*t)) {x+=dx*t;y+=dy*t;break;}
                }
            }
            flash(x,y,radius,power,color,life,kind);
        }
        private function flash(x:Number,y:Number,radius:Number,power:Number,color:uint,life:Number,kind:String):void {
            if(!free(x,y) || radius<=0) return;
            // A shotgun volley and an explosion's particle cluster share one local flash.
            var id:String=kind+":"+int(x/80)+":"+int(y/80);
            if(kind=="blast") for each(var old:Object in pulses) {
                if(old.id.indexOf("blast:")==0 && old.until>clock && Math.abs(old.x-x)<=70 && Math.abs(old.y-y)<=70) {id=old.id;break;}
            }
            put(id,x,y,radius,power,color,life);
        }
        private function put(id:String,x:Number,y:Number,radius:Number,power:Number,color:uint,life:Number):void {
            if(!isFinite(radius) || !isFinite(power) || life<=0) return;
            var value:Object=pulseById[id];
            if(!value) value=allocate(id);
            else if(id.indexOf("blast:")==0 && value.until>clock) {
                // The same detonation can emit a generic flash plus a coloured
                // special effect. The stronger/larger effect owns its colour.
                if(value.power>power || (value.power==power && value.radius>radius)) color=value.color;
                radius=Math.max(radius,value.radius);power=Math.max(power,value.power);
                life=Math.max(life,value.until-clock);
            }
            value.x=x;value.y=y;value.radius=Math.min(360,Math.max(1,radius));
            value.power=Math.min(1.1,Math.max(0,power));value.color=color;
            value.born=clock;value.life=life;value.until=clock+life;
        }
        private function allocate(id:String):Object {
            var value:Object=pulseById[id];if(value)return value;
            value={id:id};
            if(pulses.length>=MAX_PULSES){var slot:int=evict++%MAX_PULSES,old:Object=pulses[slot];delete pulseById[old.id];pulses[slot]=value;dropped++;}
            else pulses.push(value);
            pulseById[id]=value;return value;
        }
        public static function signature(lights:Array):String {
            var visible:Array=[];
            for each(var light:Object in lights)if(light.transient)visible.push(light);
            // Exact inputs, including ordered trail segments and brightness.
            // Offscreen activity and unsuccessful clipped trails cannot dirty the view.
            return JSON.stringify(visible);
        }
        public function lights(view:Rectangle,brightness:Number=1):Array {
            var result:Array=[];
            for each(var p:Object in pulses) {
                if(p.until<=clock || !view.intersects(p.rect?p.rect:new Rectangle(p.x-p.radius,p.y-p.radius,2*p.radius,2*p.radius))) continue;
                var remaining:Number=Math.max(0,Math.min(1,(p.until-clock)/p.life));
                var power:Number=p.power*remaining*remaining*brightness;
                result.push({id:"projectile:"+p.id,x:p.x,y:p.y,radius:p.radius,color:p.color,power:power,angle:0,cone:Math.PI*2,transient:true,trail:p.trail,width:p.width});
            }
            if(result.length>MAX_LIGHTS) {
                var cx:Number=view.x+view.width/2,cy:Number=view.y+view.height/2;
                result.sort(function(a:Object,b:Object):Number {
                    var ar:Number=a.power*a.radius/(80+Math.abs(a.x-cx)+Math.abs(a.y-cy));
                    var br:Number=b.power*b.radius/(80+Math.abs(b.x-cx)+Math.abs(b.y-cy));
                    return br-ar;
                });
                result.length=MAX_LIGHTS;
            }
            return result;
        }
    }
}

package fa {
    /** Consecutive native gun poses -> bounded swept blade segments, in world coordinates. */
    public class BladeSweep {
        private var previous:Object;
        public function reset():void {previous=null;}
        public function advance(s:Object):Array {
            var rays:Array=[],old:Object=previous;
            if(!valid(s)||s.blocked){reset();return rays;}
            // Copy scalar fields: later gun movement must not mutate our previous pose.
            previous={gun:s.gun,loc:s.loc,tick:s.tick,x:s.x,y:s.y,px:s.px,py:s.py,angle:s.angle,length:s.length};
            if(!old||old.gun!==s.gun||old.loc!==s.loc||s.tick!=old.tick+1||s.length!=old.length)return rays;
            var dx:Number=s.px-old.px,dy:Number=s.py-old.py,travel:Number=Math.sqrt(dx*dx+dy*dy);
            if(travel>120)return rays; // Teleport / discontinuity, never a map-spanning slash.
            var turn:Number=s.angle-old.angle;
            while(turn>Math.PI)turn-=Math.PI*2;
            while(turn<-Math.PI)turn+=Math.PI*2;
            var c:Number=Math.cos(old.angle),sn:Number=Math.sin(old.angle);
            var ox:Number=(old.x-old.px)*c+(old.y-old.py)*sn,oy:Number=-(old.x-old.px)*sn+(old.y-old.py)*c;
            c=Math.cos(s.angle);sn=Math.sin(s.angle);
            var nx:Number=(s.x-s.px)*c+(s.y-s.py)*sn,ny:Number=-(s.x-s.px)*sn+(s.y-s.py)*c;
            var radius:Number=Math.max(Math.sqrt(ox*ox+oy*oy),Math.sqrt(nx*nx+ny*ny))+s.length;
            // Ignore aim jitter and pure player translation. Normal contact still handles those.
            if(Math.abs(turn)<Math.PI/90||radius*Math.abs(turn)<3)return rays;
            var change:Number=Math.sqrt((nx-ox)*(nx-ox)+(ny-oy)*(ny-oy));
            var steps:int=Math.ceil((travel+change+radius*Math.abs(turn))/3);
            if(steps>256)return rays;
            for(var i:int=0;i<=steps;i++) {
                var t:Number=i/steps,a:Number=old.angle+turn*t;
                c=Math.cos(a);sn=Math.sin(a);
                var ux:Number=ox+(nx-ox)*t,uy:Number=oy+(ny-oy)*t;
                var x:Number=old.px+dx*t+ux*c-uy*sn,y:Number=old.py+dy*t+ux*sn+uy*c;
                rays.push({x:x,y:y,ex:x+c*s.length,ey:y+sn*s.length,px:old.px+dx*t,py:old.py+dy*t});
            }
            return rays;
        }
        private function valid(s:Object):Boolean {
            if(!s||!s.gun||!s.loc||!isFinite(Number(s.tick))||!(s.length>0&&s.length<=100))return false;
            for each(var k:String in ["x","y","px","py","angle"])if(!isFinite(Number(s[k])))return false;
            return Math.abs(s.angle)<=Math.PI*4;
        }
        public function intersects(rays:Array,x1:Number,y1:Number,x2:Number,y2:Number,clear:Function):Boolean {
            for each(var r:Object in rays) {
                // At most three pixels between samples: half-spacing thickness closes the gaps.
                if(!segmentBox(r.x,r.y,r.ex,r.ey,x1-1.5,y1-1.5,x2+1.5,y2+1.5))continue;
                // Check the gun-to-tip line too: the muzzle itself must not sweep through a wall.
                if(clear(r.px,r.py,r.ex,r.ey))return true;
            }
            return false;
        }
        public static function segmentBox(x:Number,y:Number,ex:Number,ey:Number,x1:Number,y1:Number,x2:Number,y2:Number):Boolean {
            var lo:Number=0,hi:Number=1,dx:Number=ex-x,dy:Number=ey-y,p:Array=[-dx,dx,-dy,dy],q:Array=[x-x1,x2-x,y-y1,y2-y];
            for(var i:int=0;i<4;i++) {
                if(Math.abs(p[i])<.0001){if(q[i]<0)return false;}
                else {var t:Number=q[i]/p[i];if(p[i]<0)lo=Math.max(lo,t);else hi=Math.min(hi,t);if(lo>hi)return false;}
            }
            return true;
        }
    }
}

package fa {
    /** A single native impulse followed by short recovery; never writes position or throw state. */
    public class BayonetImpulse {
        public function apply(owner:*,target:*,spec:Object,active:Boolean,speed:Number,token:*):Object {
            var out:Object={applied:false,steps:0,nx:0,ny:0,stop:0,kick:0,multiplier:1};
            var strength:Number=value(spec,"impactStrength",100,300)/100;
            if(strength<=0||target.invulner||target.fixed||target.sost>=3||protectedMotion(target))return out;
            var mass:Number=Number(target.massa),resistance:Number=Number(target.knocked);
            if(!isFinite(mass)||mass<=0||!isFinite(resistance)||resistance<=0)return out;
            var response:Number=Math.min(3,resistance/mass);
            var nx:Number=Number(target.X)-Number(owner.X),ny:Number=0;
            if(target.isFly)ny=(Number(target.Y)-Number(target.scY)*.5)-(Number(owner.Y)-Number(owner.scY)*.5);
            var length:Number=Math.sqrt(nx*nx+ny*ny);
            if(length<.001){nx=Number(owner.storona)<0?-1:1;ny=0;}else {nx/=length;ny/=length;}
            var multiplier:Number=1+Math.min(Math.max(0,speed)*value(spec,"impactSpeedBonus",6,20)/100,1.5);
            var mode:Number=active?1:.75;
            var stop:Number=Math.min(1,.8*multiplier*response*strength);
            var incoming:Number=Number(target.dx)*nx+Number(target.dy)*ny;
            if(incoming<0){target.dx-=incoming*nx*stop;target.dy-=incoming*ny*stop;}
            var beforeX:Number=Number(target.dx),beforeY:Number=Number(target.dy);
            token.knockx=nx;token.knocky=target.isFly?ny:-.12;
            token.otbros=(spec.motion=="thrust"?8:5)*mode*multiplier*strength;
            // Preserve the engine's mass, knock resistance and small random variation.
            target.otbros(token);
            var kx:Number=Number(target.dx)-beforeX,ky:Number=Number(target.dy)-beforeY;
            var kick:Number=Math.sqrt(kx*kx+ky*ky);
            if(kick>24){kx*=24/kick;ky*=24/kick;target.dx=beforeX+kx;target.dy=beforeY+ky;kick=24;}
            var steps:int=Math.min(24,Math.round(value(spec,"impactRecovery",8,30)*mode*multiplier*Math.min(1,response)));
            if(steps>0)target.stun=Math.max(Number(target.stun),steps);
            return {applied:true,steps:steps,nx:nx,ny:ny,stop:stop,kick:kick,multiplier:multiplier};
        }
        public function protectedMotion(target:*):Boolean {return Number(target.levit)>0||Number(target.t_throw)>0;}
        public function recover(target:*,impact:Object):void {
            if(!impact||!impact.applied||target.invulner||target.fixed||Number(target.knocked)<=0||protectedMotion(target))return;
            // Only resist renewed motion into the blade. Let the outgoing impulse and gravity run.
            var inward:Number=Number(target.dx)*impact.nx+Number(target.dy)*impact.ny;
            if(inward<0){target.dx-=inward*impact.nx*impact.stop;target.dy-=inward*impact.ny*impact.stop;}
        }
        private function value(spec:Object,key:String,fallback:Number,max:Number):Number {
            var raw:*=spec?spec[key]:undefined,n:Number=Number(raw);
            return raw===null||raw is Boolean||!isFinite(n)?fallback:Math.max(0,Math.min(max,n));
        }
    }
}

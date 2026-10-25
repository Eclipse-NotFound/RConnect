package lad {
    import flash.display.MovieClip;
    import flash.display.Sprite;
    import flash.geom.Rectangle;
    import flash.geom.ColorTransform;
    public final class LadLampCatalog {
        private static const TYPES:Object={
            light1:{radius:300,color:0xffe4b3},stlight1:{radius:310,color:0xfff0cc},
            light2:{radius:370,color:0xffefd4},light3:{radius:340,color:0xffe6c0},
            stlight3:{radius:350,color:0xe0efff},light4:{radius:390,color:0xffe1a1},
            stlight4:{radius:390,color:0xd5e8ff},light5:{radius:190,color:0xff5a3f},
            light6:{radius:320,color:0xffedc4},light7:{radius:360,color:0xd0e7ff}
        };
        public static function isLamp(id:String):Boolean {return TYPES.hasOwnProperty(id);}
        public static function discover(loc:*,g:*,saved:Object,atmosphere:LadAtmosphere,roomKey:String,environment:LadEnvironment=null):Array {
            var result:Array=[],duplicates:Object={};
            for each(var bo:* in loc.backobjs) {
                if(!isLamp(String(bo.id)) || bo.vis==null) continue;
                var stem:String=[bo.id,Number(bo.X).toFixed(2),Number(bo.Y).toFixed(2),bo.scX,bo.scY].join(":");
                var ordinal:int=int(duplicates[stem]);duplicates[stem]=ordinal+1;
                var key:String=stem+":"+ordinal;
                var clip:MovieClip=g.getObj("back_"+bo.id+"_t",1) as MovieClip;
                if(!clip) continue;
                clip.gotoAndStop(bo.frame);
                var r:Rectangle=clip.getBounds(clip);
                var x1:Number=bo.X+Math.min(r.left*bo.scX,r.right*bo.scX);
                var x2:Number=bo.X+Math.max(r.left*bo.scX,r.right*bo.scX);
                var y1:Number=bo.Y+Math.min(r.top*bo.scY,r.bottom*bo.scY);
                var y2:Number=bo.Y+Math.max(r.top*bo.scY,r.bottom*bo.scY);
                var state:Object=saved[key];
                if(state==null) {
                    state={hp:40,on:bo.frame==(bo.frameOn>0?bo.frameOn:1)};saved[key]=state;
                }
                if(!isFinite(Number(state.hp))) throw new Error("invalid saved fixture HP: "+key);
                state.hp=Math.max(0,Math.min(40,Number(state.hp)));
                state.atmosphere=atmosphere.style(state.atmosphere,roomKey+"#"+key,String(bo.id),String(loc.land.act.id),String(loc.id),environment?environment.profile((x1+x2)/2,(y1+y2)/2):null);
                var visual:Sprite=new Sprite();visual.mouseEnabled=false;visual.mouseChildren=false;
                visual.x=bo.X;visual.y=bo.Y;clip.scaleX=bo.scX;clip.scaleY=bo.scY;visual.addChild(clip);
                var model:Object=TYPES[bo.id];
                var lamp:Object={key:key,type:String(bo.id),bo:bo,state:state,holder:visual,clip:clip,
                    originalVis:bo.vis,originalLight:bo.light,originalErase:bo.erase,
                    onFrame:Math.max(1,int(bo.frameOn)),offFrame:int(bo.frameOff),nativeFrame:int(bo.frame),
                    bounds:new Rectangle(x1,y1,Math.max(8,x2-x1),Math.max(8,y2-y1)),
                    x:(x1+x2)/2,y:(y1+y2)/2,radius:model.radius,color:model.color,
                    proxy:null,visualState:"",powered:loc.lightOn!=-1,
                    phase:(LadAtmosphere.seed(roomKey+"#"+key)%10000)/10000,power:0};
                result.push(lamp);
            }
            return result;
        }
        public static function strip(lamps:Array):void {
            for each(var lamp:Object in lamps) {lamp.bo.vis=null;lamp.bo.light=null;lamp.bo.erase=null;}
        }
        public static function restore(lamps:Array):void {
            for each(var lamp:Object in lamps) {
                lamp.bo.vis=lamp.originalVis;lamp.bo.light=lamp.originalLight;lamp.bo.erase=lamp.originalErase;
                if(lamp.bo.vis) lamp.bo.vis.gotoAndStop(lamp.bo.frame);
                if(lamp.bo.light) lamp.bo.light.gotoAndStop(lamp.bo.frame);
                if(lamp.bo.erase) lamp.bo.erase.gotoAndStop(lamp.bo.frame);
            }
        }
        public static function visual(lamp:Object):void {
            var level:Number=Math.min(1,Math.max(0,Number(lamp.power)));
            var lit:Boolean=level>0.06;
            var signature:String=[lit,lamp.state.hp<=0,int(level*24)].join(":");
            if(signature==lamp.visualState) return;lamp.visualState=signature;
            var off:int=lamp.offFrame>0?lamp.offFrame:Math.min(2,lamp.clip.totalFrames);
            lamp.clip.gotoAndStop(lit?lamp.onFrame:off);
            // Several native off frames still contain white pixels/glow. Make
            // the glass visibly unlit even when the asset lacks a dark frame.
            var tint:Number=lit?0.28+0.72*level:0.28;
            lamp.clip.transform.colorTransform=new ColorTransform(tint,tint,tint);
            lamp.clip.alpha=lamp.state.hp<=0?0.48:1;
            lamp.holder.graphics.clear();
            if(lamp.state.hp<=0) {
                var r:Rectangle=lamp.bounds;
                lamp.holder.graphics.lineStyle(1,0x35302c,0.9);
                lamp.holder.graphics.moveTo(r.left-lamp.bo.X+3,r.top-lamp.bo.Y+2);
                lamp.holder.graphics.lineTo(r.right-lamp.bo.X-3,r.bottom-lamp.bo.Y-2);
            }
        }
    }
}

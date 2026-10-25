package lad {
    import flash.display.DisplayObject;
    import flash.display.DisplayObjectContainer;
    import flash.display.MovieClip;
    import flash.geom.Point;
    import flash.geom.Rectangle;
    import flash.utils.Dictionary;
    import flash.utils.getQualifiedClassName;

    /** Native indicator spill only: never change a unit, timeline, or AI state. */
    public final class LadMachineLights {
        private var identities:Dictionary=new Dictionary(true);
        private var serial:uint=0;
        private var location:*;
        public function clear():void {identities=new Dictionary(true);location=null;serial=0;}
        public function lights(loc:*,visual:DisplayObjectContainer,view:Rectangle):Array {
            if(loc!==location) {clear();location=loc;}
            var result:Array=[];
            if(!loc || !visual || !view) return result;
            for each(var unit:* in loc.units) {
                if(!unit || unit.loc!==loc || unit.disabled || unit.sost>=3 || unit.hp<=0) continue;
                var identity:Object=identities[unit];
                if(identity==null) {
                    var type:String=getQualifiedClassName(unit),kind:String="";
                    if(type=="fe.unit::UnitTurret") kind="turret";
                    else if(type=="fe.unit::UnitMsp") kind="spider";
                    else if(type=="fe.unit::UnitThunderTurret") kind="thunder";
                    identity={kind:kind,id:"machine-"+(++serial)};identities[unit]=identity;
                }
                if(!identity.kind) continue;
                var vis:DisplayObjectContainer=unit.vis as DisplayObjectContainer;
                if(!vis || !visibleIn(vis,visual)) continue;
                // Reject distant units before traversing their indicator artwork.
                if(unit.X<view.left-240 || unit.X>view.right+240 || unit.Y<view.top-240 || unit.Y>view.bottom+240) continue;
                var osn:MovieClip=vis.getChildByName("osn") as MovieClip;
                if(!osn) continue;
                var source:DisplayObject,color:uint,radius:Number,power:Number;
                if(identity.kind=="turret") {
                    // Retraction leaves stale light properties on some native clips.
                    // Only use an actual child on the fully extended timeline frame.
                    if(osn.currentFrame!=1) continue;
                    var indicator:MovieClip=osn.getChildByName("light") as MovieClip;
                    if(!indicator || indicator.currentFrame<2 || indicator.currentFrame>5) continue;
                    var frame:int=indicator.currentFrame;
                    color=frame==2?0xffdf55:frame==4?0xff5246:0xffad48;
                    radius=frame==2?72:frame==4?100:86;
                    power=frame==2?0.42:frame==4?0.58:0.48;
                    source=indicator;
                } else if(identity.kind=="spider") {
                    // Native stay frame has no lit bulb. Wake is yellow; walk/jump red.
                    if(osn.currentFrame<2 || osn.currentFrame>4 || osn.numChildren==0) continue;
                    var body:DisplayObjectContainer=osn.getChildAt(0) as DisplayObjectContainer;
                    source=spiderBulb(body);
                    color=osn.currentFrame==2?0xffdc3e:0xff5546;
                    radius=osn.currentFrame==2?62:78;
                    power=osn.currentFrame==2?0.46:0.54;
                } else {
                    // Thunderhead mounts have no bulb; only their enabled blue force field emits.
                    source=osn.getChildByName("pole");color=0x78baff;radius=120;power=0.32;
                }
                if(!source || !visibleIn(source,visual)) continue;
                var bounds:Rectangle=source.getBounds(source);
                if(bounds.isEmpty()) continue;
                var point:Point=visual.globalToLocal(source.localToGlobal(new Point(bounds.x+bounds.width/2,bounds.y+bounds.height/2)));
                if(!isFinite(point.x) || !isFinite(point.y) || point.x+radius<view.left || point.x-radius>view.right || point.y+radius<view.top || point.y-radius>view.bottom) continue;
                var dx:Number=point.x-(view.x+view.width/2),dy:Number=point.y-(view.y+view.height/2);
                result.push({id:identity.id,x:point.x,y:point.y,radius:radius,color:color,power:power,
                    angle:0,cone:Math.PI*2,transient:true,distance:dx*dx+dy*dy});
            }
            // Bound shadow work in rooms filled with machines; keep nearest visible sources.
            if(result.length>32) {result.sortOn("distance",Array.NUMERIC);result.length=32;}
            return result;
        }
        private function spiderBulb(body:DisplayObjectContainer):DisplayObject {
            if(!body) return null;
            // The unnamed halo is a 29.8 x 29.8 shape (wake) or clip (walk/jump).
            // Its live bounds follow the eight-frame leg/body animation, flip and mounting rotation.
            for(var i:int=body.numChildren-1;i>=0;i--) {
                var child:DisplayObject=body.getChildAt(i),b:Rectangle=child.getBounds(child);
                if(b.width>29 && b.width<30.5 && b.height>29 && b.height<30.5) return child;
            }
            return null;
        }
        private function visibleIn(child:DisplayObject,ancestor:DisplayObject):Boolean {
            var current:DisplayObject=child;
            while(current && current!==ancestor) {
                if(!current.visible || current.alpha<=0) return false;
                current=current.parent;
            }
            return current===ancestor;
        }
    }
}

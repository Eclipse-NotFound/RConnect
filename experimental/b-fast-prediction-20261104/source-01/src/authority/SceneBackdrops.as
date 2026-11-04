package authority {
   import flash.display.DisplayObject;
   import flash.display.MovieClip;
   import flash.geom.ColorTransform;
   import flash.utils.Dictionary;
   import flash.utils.getQualifiedClassName;
   /** Authored BackObj decorations are baked by drawLoc, not world-layer Pt's.
    * Cache their immutable description for the native raster epoch. */
   public final class SceneBackdrops {
      private static const FIELDS:Array=["id","X","Y","scX","scY","frame","frameOn","frameOff","blend","alpha","sloy","er"];
      private static const PARTS:Array=["vis","erase","light"];
      private var access:NativeAccess;
      private var captured:Dictionary=new Dictionary(true);
      private var received:Object;
      private var native:Array=[];
      public function SceneBackdrops(access:NativeAccess){this.access=access;}
      public function capture(room:Object,epoch:uint):Object {
         var old:Object=captured[room];
         if(old!=null && old.epoch===epoch)return old.state;
         var state:Object={items:[],tint:color(room.cTransform),fonTint:color(room.cTransformFon)};
         for each(var object:Object in room.backobjs) {
            var item:Object={fields:{},parts:{}};
            for each(var name:String in FIELDS)item.fields[name]=object[name];
            for each(name in PARTS) {
               var display:DisplayObject=object[name] as DisplayObject;
               item.parts[name]=display==null?null:{clip:getQualifiedClassName(display),pose:VisualPose.capture(display)};
            }
            state.items.push(item);
         }
         captured[room]={epoch:epoch,state:state};return state;
      }
      /** Reconstruct native typed BackObjs before Grafon.drawLoc consumes them.
       * The constructor chooses the correct background resource domain; every
       * random placement/frame is then replaced by the host's final values. */
      public function apply(room:Object,state:Object):Boolean {
         if(state==null)return false;
         if(received===state && room.backobjs===native)return false;
         var next:Array=[],Type:Class=access.definition("fe.graph.BackObj");
         for(var i:int=0;i<state.items.length;i++) {
            var item:Object=state.items[i],object:Object=i<native.length?native[i]:null;
            if(object==null || object.id!==item.fields.id) {
               if(object!=null)release(object);
               var placement:XML=<back/>;placement.@fr=item.fields.frame;
               object=new Type(room,item.fields.id,item.fields.X,item.fields.Y,placement);
            }
            for each(var name:String in FIELDS)object[name]=item.fields[name];
            for each(name in PARTS) {
               var part:Object=item.parts[name],display:DisplayObject=object[name] as DisplayObject;
               if(part==null) {
                  if(display!=null)VisualPose.dispose(display);
                  object[name]=null;
               }else {
                  if(display==null || getQualifiedClassName(display)!==part.clip) {
                     if(display!=null)VisualPose.dispose(display);
                     var Clip:Class=access.visualClass(part.clip);display=new Clip() as MovieClip;
                     if(display==null)throw new Error("Unsupported native background symbol: "+part.clip);
                     object[name]=display;
                  }
                  VisualPose.apply(display,part.pose);
               }
            }
            next.push(object);
         }
         for(i=state.items.length;i<native.length;i++)release(native[i]);
         native=next;room.backobjs=native;
         room.cTransform=transform(state.tint);room.cTransformFon=transform(state.fonTint);
         received=state;return true;
      }
      private static function color(c:Object):Array {return c==null?null:[c.redMultiplier,c.greenMultiplier,c.blueMultiplier,c.alphaMultiplier,c.redOffset,c.greenOffset,c.blueOffset,c.alphaOffset];}
      private static function transform(c:Array):ColorTransform {return c==null?null:new ColorTransform(c[0],c[1],c[2],c[3],c[4],c[5],c[6],c[7]);}
      private static function release(object:Object):void {for each(var name:String in PARTS)if(object[name]!=null)VisualPose.dispose(object[name]);}
      public function dispose():void {for each(var object:Object in native)release(object);native=[];received=null;captured=new Dictionary(true);}
   }
}

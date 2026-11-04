package authority {
   import flash.display.Sprite;
   import flash.display.Shape;
   import flash.display.MovieClip;
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.Graphics;
   import flash.display.BitmapData;
   import flash.display.GradientType;
   import flash.geom.Matrix;
   import flash.geom.Rectangle;
   /** Actual AIR raster comparison after transport through the scene stream. */
   public final class VectorProbe extends Probe {
      private var begin:int=-1,tick:int=0,phase:int=-1,drawn:DisplayObject,texture:BitmapData;
      private var expected:Object={},matched:Object={},received:int=0;
      private var controlBitmaps:Array=[];
      private var viewMask:Shape,maskOwner:Sprite,receivedMask:Boolean=false;
      public function VectorProbe(a:NativeAccess,h:Boolean){super(a,h);}
      override public function message(value:Object):void {
         if(host && begin<0 && value.type=="input" && value.player==1 && value.probeStart is Number)begin=int(value.probeStart);
         if(!host && value.type=="vector-reference"){expected[String(value.hash)]=value.phase;++received;}
      }
      override public function input(frame:Object,session:HostSession):Object {
         frame.buttons=0;frame.actions=[];
         if(!host && begin>=0)frame.probeStart=begin;return frame;
      }
      private function hash(clip:DisplayObject):uint {
         var bitmap:BitmapData=new BitmapData(160,100,true,0);bitmap.draw(clip);
         var value:uint=2166136261;
         for each(var pixel:uint in bitmap.getVector(bitmap.rect))value=uint((value^pixel)*16777619);
         bitmap.dispose();return value;
      }
      private function paint(index:int):void {
         if(index>=4) {
            var parent:DisplayObjectContainer=drawn.parent,x:Number=drawn.x,y:Number=drawn.y;
            parent.removeChild(drawn);drawn=index==4?new MovieClip():new Shape();
            drawn.name="B-vector-fixture";drawn.x=x;drawn.y=y;parent.addChild(drawn);
         }
         var g:Graphics=drawn is Shape?Shape(drawn).graphics:Sprite(drawn).graphics;
         var container:DisplayObjectContainer=drawn as DisplayObjectContainer;
         g.clear();if(container!=null)while(container.numChildren>0)container.removeChildAt(0);
         if(index==0) {
            g.lineStyle(3,0xF84351,.25);g.moveTo(8,12);g.lineTo(140,80);
            g.lineStyle(1,0xFFBAC1,.95);g.moveTo(8,12);g.curveTo(90,2,140,80);
            g.lineStyle();g.beginFill(0xFFF1F1,.7);g.drawCircle(140,80,4);g.endFill();
         } else if(index==1) {
            var m:Matrix=new Matrix();m.createGradientBox(130,70,.4,8,8);
            g.beginGradientFill(GradientType.LINEAR,[0x00FFFF,0x5000FF],[.8,.1],[0,255],m);
            g.drawRoundRect(8,8,130,70,12);g.endFill();
            var child:Shape=new Shape();child.name="runtime-child";child.graphics.beginFill(0xF5CA48,.9);child.graphics.drawCircle(24,24,12);child.graphics.endFill();container.addChild(child);
         } else if(index==2) {
            texture=new BitmapData(4,4,true,0xFFFF8844);texture.setPixel32(0,0,0);texture.setPixel32(2,2,0xFF44AAFF);
            g.beginBitmapFill(texture,new Matrix(12,0,0,12,0,0),true,true);
            g.drawTriangles(new <Number>[10,10,140,15,80,80],new <int>[0,1,2],new <Number>[0,0,1,0,.5,1]);g.endFill();
         } else if(index>=4) {
            g.beginFill(index==4?0xAAFF20:0x2040FF,.6);g.drawEllipse(10,8,130,78);g.endFill();
         }
      }
      private function difference(source:DisplayObject,target:DisplayObject):Object {
         var a:BitmapData=new BitmapData(160,100,true,0),b:BitmapData=new BitmapData(160,100,true,0);
         a.draw(source);b.draw(target);var mismatches:int=0,maximum:int=0,first:Array=[];
         for(var y:int=0;y<100;y++)for(var x:int=0;x<160;x++) {
            var left:uint=a.getPixel32(x,y),right:uint=b.getPixel32(x,y);
            if(left!=right){++mismatches;if(first.length<6)first.push({x:x,y:y,left:left.toString(16),right:right.toString(16)});}
            for(var shift:int=0;shift<=24;shift+=8)maximum=Math.max(maximum,Math.abs(((left>>>shift)&255)-((right>>>shift)&255)));
         }
         a.dispose();b.dispose();return {mismatches:mismatches,maxChannelDelta:maximum,first:first};
      }
      // Independent, in-process AIR bitmap rendering control: no VectorDraw,
      // bytes, channel conversion, transport, or VisualPose reconstruction.
      private function rasterControl(original:DisplayObject):Sprite {
         var result:Sprite=new Sprite(),g:Graphics=original is Shape?Shape(original).graphics:Sprite(original).graphics;
         var geometry:Shape=new Shape();geometry.graphics.copyFrom(g);
         var bounds:Rectangle=geometry.getBounds(geometry);
         if(bounds.width>0 && bounds.height>0) {
            var x:int=Math.floor(bounds.x),y:int=Math.floor(bounds.y);
            var bitmap:BitmapData=new BitmapData(Math.ceil(bounds.right)-x,Math.ceil(bounds.bottom)-y,true,0);
            bitmap.draw(geometry,new Matrix(1,0,0,1,-x,-y));controlBitmaps.push(bitmap);
            result.graphics.beginBitmapFill(bitmap,new Matrix(1,0,0,1,x,y),false,true);
            result.graphics.drawRect(x,y,bitmap.width,bitmap.height);result.graphics.endFill();
         }
         var parent:DisplayObjectContainer=original as DisplayObjectContainer;
         if(parent!=null)for(var i:int=0;i<parent.numChildren;i++)result.addChild(rasterControl(parent.getChildAt(i)));
         result.transform.matrix=original.transform.matrix;return result;
      }
      override public function observe(session:HostSession,replica:ClientReplica):void {
         if(finished)return;
         if(!host) {
            if(replica==null || replica.lastFrame==null)return;
            if(begin<0)begin=replica.lastFrame.tick;tick=replica.lastFrame.tick-begin;
            var visible:Boolean=false;
            for each(var rec:Object in replica.scene.effects.records) {
               if(rec.clip.name=="B-local-view-mask")receivedMask=true;
               if(rec.clip.name=="B-vector-fixture") {
                  visible=true;var digest:String=String(hash(rec.clip));
                  if(expected.hasOwnProperty(digest))matched[expected[digest]]=true;
               }
            }
            if(tick>315) {
               for(var i:int=0;i<6;i++)check(matched[i]===true,"confirmed vector drawing matches native source pixels phase "+i,{references:received});
               check(!visible,"removed runtime vector effect leaves no client ghost");
               check(!receivedMask,"local visibility masks are never reproduced as visible world effects");
               finish();
            }
            return;
         }
         if(session==null || !session.active)return;
         if(drawn==null) {
            VisualPose.resolve=access.visualClass;
            drawn=new Sprite();drawn.name="B-vector-fixture";drawn.x=access.world.gg.X;drawn.y=access.world.gg.Y-100;
            session.runtime.rooms.services(access.world.loc).grafon.visObjs[2].addChild(drawn);
            maskOwner=new Sprite();viewMask=new Shape();viewMask.name="B-local-view-mask";
            viewMask.graphics.beginFill(0xffffff);viewMask.graphics.drawRect(0,0,40,40);viewMask.graphics.endFill();
            drawn.parent.addChild(maskOwner);drawn.parent.addChild(viewMask);maskOwner.mask=viewMask;
         }
         if(begin<0)return;tick=session.runtime.tick-begin;
         var next:int=Math.min(6,int(tick/45));
         if(next!=phase) {
            phase=next;
            if(phase<6) {
               paint(phase);var copy:Sprite=new Sprite();VisualPose.apply(copy,VisualPose.capture(drawn));
               var control:Sprite=rasterControl(drawn);
               check(hash(control)==hash(copy),"runtime drawing transport matches an independent native raster control phase "+phase,{source:hash(drawn),control:hash(control),replica:hash(copy)});
               Log.write("vector-diagnostic",{phase:phase,transport:difference(control,copy),nativeRasterization:difference(drawn,control),sourceBounds:String(drawn.getBounds(drawn)),replicaBounds:String(copy.getBounds(copy))});
               VisualPose.dispose(copy);
               session.link.send({type:"vector-reference",phase:phase,hash:hash(control)});
               for each(var bitmap:BitmapData in controlBitmaps)bitmap.dispose();controlBitmaps=[];
            }else {
               drawn.parent.removeChild(drawn);maskOwner.mask=null;maskOwner.parent.removeChild(maskOwner);viewMask.parent.removeChild(viewMask);
               if(texture!=null)texture.dispose();
            }
         }
         if(tick>330)finish();
      }
   }
}

package authority {
   import flash.display.Sprite;
   import flash.display.Shape;
   import flash.display.DisplayObject;
   import flash.display.BitmapData;
   import flash.display.GradientType;
   import flash.geom.Matrix;
   /** Actual AIR raster comparison after transport through the scene stream. */
   public final class VectorProbe extends Probe {
      private var begin:int=-1,tick:int=0,phase:int=-1,drawn:Sprite,texture:BitmapData;
      private var expected:Object={},matched:Object={},received:int=0;
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
         drawn.graphics.clear();while(drawn.numChildren>0)drawn.removeChildAt(0);
         if(index==0) {
            drawn.graphics.lineStyle(3,0xF84351,.25);drawn.graphics.moveTo(8,12);drawn.graphics.lineTo(140,80);
            drawn.graphics.lineStyle(1,0xFFBAC1,.95);drawn.graphics.moveTo(8,12);drawn.graphics.curveTo(90,2,140,80);
            drawn.graphics.lineStyle();drawn.graphics.beginFill(0xFFF1F1,.7);drawn.graphics.drawCircle(140,80,4);drawn.graphics.endFill();
         } else if(index==1) {
            var m:Matrix=new Matrix();m.createGradientBox(130,70,.4,8,8);
            drawn.graphics.beginGradientFill(GradientType.LINEAR,[0x00FFFF,0x5000FF],[.8,.1],[0,255],m);
            drawn.graphics.drawRoundRect(8,8,130,70,12);drawn.graphics.endFill();
            var child:Shape=new Shape();child.name="runtime-child";child.graphics.beginFill(0xF5CA48,.9);child.graphics.drawCircle(24,24,12);child.graphics.endFill();drawn.addChild(child);
         } else if(index==2) {
            texture=new BitmapData(4,4,true,0xFFFF8844);texture.setPixel32(0,0,0);texture.setPixel32(2,2,0xFF44AAFF);
            drawn.graphics.beginBitmapFill(texture,new Matrix(12,0,0,12,0,0),true,true);
            drawn.graphics.drawTriangles(new <Number>[10,10,140,15,80,80],new <int>[0,1,2],new <Number>[0,0,1,0,.5,1]);drawn.graphics.endFill();
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
      override public function observe(session:HostSession,replica:ClientReplica):void {
         if(finished)return;
         if(!host) {
            if(replica==null || replica.lastFrame==null)return;
            if(begin<0)begin=replica.lastFrame.tick;tick=replica.lastFrame.tick-begin;
            var visible:Boolean=false;
            for each(var rec:Object in replica.scene.effects.records)if(rec.clip.name=="B-vector-fixture") {
               visible=true;var digest:String=String(hash(rec.clip));
               if(expected.hasOwnProperty(digest))matched[expected[digest]]=true;
            }
            if(tick>225) {
               for(var i:int=0;i<4;i++)check(matched[i]===true,"confirmed vector drawing matches native source pixels phase "+i,{references:received});
               check(!visible,"removed runtime vector effect leaves no client ghost");finish();
            }
            return;
         }
         if(session==null || !session.active)return;
         if(drawn==null) {
            VisualPose.resolve=access.visualClass;
            drawn=new Sprite();drawn.name="B-vector-fixture";drawn.x=access.world.gg.X;drawn.y=access.world.gg.Y-100;
            session.runtime.rooms.services(access.world.loc).grafon.visObjs[2].addChild(drawn);
         }
         if(begin<0)return;tick=session.runtime.tick-begin;
         var next:int=Math.min(4,int(tick/45));
         if(next!=phase) {
            phase=next;
            if(phase<4) {
               paint(phase);var copy:Sprite=new Sprite();VisualPose.apply(copy,VisualPose.capture(drawn));
               check(hash(drawn)==hash(copy),"drawing-command round trip matches source pixels phase "+phase,{source:hash(drawn),replica:hash(copy)});
               Log.write("vector-diagnostic",{phase:phase,difference:difference(drawn,copy),sourceBounds:String(drawn.getBounds(drawn)),replicaBounds:String(copy.getBounds(copy))});
               VisualPose.dispose(copy);
               session.link.send({type:"vector-reference",phase:phase,hash:hash(drawn)});
            }else {drawn.parent.removeChild(drawn);if(texture!=null)texture.dispose();}
         }
         if(tick>240)finish();
      }
   }
}

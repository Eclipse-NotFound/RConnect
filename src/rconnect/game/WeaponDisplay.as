package rconnect.game {
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.MovieClip;
   import flash.geom.Matrix;
   import flash.geom.Point;
   import flash.utils.Dictionary;

   /** Native display poses in world-layer coordinates. Gun flipping and its
    * recoil belong to the weapon; the pony's facing is a separate transform. */
   public class WeaponDisplay {
      private var animations:Dictionary=new Dictionary(true);

      public static function capture(u:Object,w:Object):Object {
         var v:DisplayObject=GameBridge.probe(w,"vis") as DisplayObject;
         var body:DisplayObject=GameBridge.probe(u,"vis") as DisplayObject;
         var layer:DisplayObjectContainer=body==null?null:body.parent;
         if(v==null || v.parent==null || layer==null)return null;
         var p:Point=layer.globalToLocal(v.localToGlobal(new Point()));
         var a:Point=layer.globalToLocal(v.localToGlobal(new Point(1,0))).subtract(p);
         var b:Point=layer.globalToLocal(v.localToGlobal(new Point(0,1))).subtract(p);
         var sx:Number=Math.sqrt(a.x*a.x+a.y*a.y);
         if(sx<.0001)return null;
         return {x:p.x-Number(u.X),y:p.y-Number(u.Y),r:Math.atan2(a.y,a.x),
            sx:sx,sy:(a.x*b.y-a.y*b.x)/sx,
            frame:v is MovieClip?MovieClip(v).currentFrame:1,
            label:v is MovieClip?MovieClip(v).currentLabel:""};
      }

      /** Position/angle blend along the avatar's existing source-time cursor.
       * Reflection stays discrete so crossing vertical never flattens the gun. */
      public static function interpolate(first:Array,last:Array,t:Number):Array {
         if(first==null || last==null)return first;
         var result:Array=[];
         for each(var a:Object in first) {
            var pose:Object=a.display,b:Object=null;
            for each(var next:Object in last)
               if(a.slot==next.slot && a.id==next.id && a.variant==next.variant && a.stream==next.stream){b=next;break;}
            if(pose==null || b==null || b.display==null){result.push(a);continue;}
            var copy:Object={};for(var k:String in a)copy[k]=a[k];
            var p:Object={};for(k in pose)p[k]=pose[k];
            var angle:Number=Number(b.display.r)-Number(pose.r);
            while(angle>Math.PI)angle-=Math.PI*2;
            while(angle<-Math.PI)angle+=Math.PI*2;
            p.x=pose.x+(b.display.x-pose.x)*t;p.y=pose.y+(b.display.y-pose.y)*t;
            p.r=pose.r+angle*t;copy.display=p;result.push(copy);
         }
         return result;
      }

      public function apply(u:Object,w:Object,s:Object,now:int):void {
         var v:DisplayObject=GameBridge.probe(w,"vis") as DisplayObject;
         var body:DisplayObject=GameBridge.probe(u,"vis") as DisplayObject;
         if(v==null || body==null || body.parent==null || v.parent!==body || s.display==null)return;
         var p:Object=s.display,cos:Number=Math.cos(p.r),sin:Number=Math.sin(p.r);
         var world:Matrix=new Matrix(cos*p.sx,sin*p.sx,-sin*p.sy,cos*p.sy,Number(u.X)+p.x,Number(u.Y)+p.y);
         var local:Matrix=body.transform.matrix.clone();local.invert();world.concat(local);
         v.transform.matrix=world;
         w.X=Number(u.X)+Number(s.ox);w.Y=Number(u.Y)+Number(s.oy);w.rot=Number(s.rot);
         var rec:Object=animations[w];
         if(rec==null || rec.stream!=s.stream)rec=animations[w]={stream:s.stream,shots:int(s.shots),queue:0,next:now,reload:0};
         var delta:int=int(s.shots)-int(rec.shots);
         if(delta>0)rec.queue=Math.min(8,int(rec.queue)+delta);
         rec.shots=int(s.shots);
         if(int(s.reload)>0 && int(rec.reload)<=0)play(v as MovieClip,"reload");
         rec.reload=int(s.reload);
         if(rec.queue>0 && now>=int(rec.next)) {
            rec.queue--;rec.next=now+Math.max(16,Math.min(250,Number(s.cadence)));
            play(v as MovieClip,"shoot");
         }
      }

      private function play(v:MovieClip,label:String):void {
         if(v==null)return;
         for each(var l:Object in v.currentLabels)if(l.name==label){v.gotoAndPlay(label);return;}
      }
      public function forget(w:Object):void {if(w!=null)delete animations[w];}
   }
}

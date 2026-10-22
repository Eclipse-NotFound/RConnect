package rconnect.game { public final class WeaponDisplay {
      public static function interpolate(first:Array,last:Array,t:Number):Array {
         if(first==null || last==null)return first;
         var result:Array=[];
         for each(var a:Object in first) {
            var pose:Object=a.display,b:Object=null;
            for each(var next:Object in last)
               if(a.slot==next.slot && a.id==next.id && a.variant==next.variant && a.stream==next.stream){b=next;break;}
            if(pose==null || b==null || b.display==null){result.push(a);continue;}
            var copy:Object={};for(var k:String in a)copy[k]=a[k];
            // The later packet contains the native frames between a and b;
            // select from that history with the same avatar source cursor.
            copy.melee=b.melee;
            var p:Object={};for(k in pose)p[k]=pose[k];
            var angle:Number=Number(b.display.r)-Number(pose.r);
            while(angle>Math.PI)angle-=Math.PI*2;
            while(angle<-Math.PI)angle+=Math.PI*2;
            p.x=pose.x+(b.display.x-pose.x)*t;p.y=pose.y+(b.display.y-pose.y)*t;
            p.r=pose.r+angle*t;copy.display=p;result.push(copy);
         }
         return result;
      }
}}

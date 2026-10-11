package authority {
   /** Interpolate confirmed transforms only. Discrete native actions stay at A. */
   public final class PoseTween {
      public static function copy(value:Object):Object {var out:Object={};for(var k:String in value)out[k]=value[k];return out;}
      private static function lerp(a:Number,b:Number,t:Number):Number{return a+(b-a)*t;}
      private static function angle(a:Number,b:Number,t:Number):Number{return a+(((b-a+540)%360)-180)*t;}
      public static function pose(a:Object,b:Object,t:Number):Object {
         if(a==null || b==null || a.v!==b.v)return a;
         var out:Object=copy(a);
         for each(var k:String in ["x","y","a"])out[k]=lerp(a[k],b[k],t);
         if(a.sx*b.sx>=0 && a.sy*b.sy>=0){out.sx=lerp(a.sx,b.sx,t);out.sy=lerp(a.sy,b.sy,t);out.r=angle(a.r,b.r,t);}
         if(a.f===b.f && a.children!=null && b.children!=null) {
            out.children=[];
            for(var i:int=0;i<a.children.length;i++) {
               var c:Object=a.children[i],d:Object=i<b.children.length?b.children[i]:null,r:Object=c;
               if(d!=null && c.i==d.i && c.cls==d.cls) {r=copy(c);r.s=pose(c.s,d.s,t);}
               out.children.push(r);
            }
         }
         return out;
      }
      private static function close(a:Object,b:Object,x:String,y:String):Boolean {
         return isFinite(a[x]) && isFinite(b[x]) && isFinite(a[y]) && isFinite(b[y]) &&
            Math.abs(a[x]-b[x])<160 && Math.abs(a[y]-b[y])<160;
      }
      private static function fields(a:Object,b:Object,t:Number):Object {
         var out:Object=copy(a);
         for each(var k:String in ["X","Y","X1","X2","Y1","Y2","eyeX","eyeY","celX","celY"])
            if(a[k] is Number && b[k] is Number)out[k]=lerp(a[k],b[k],t);
         return out;
      }
      private static function keyed(list:Array,key:String):Object {var out:Object={};for each(var o:Object in list)out[o[key]]=o;return out;}
      public static function frame(a:Object,b:Object,t:Number):Object {
         if(b==null || t<=0 || a.room!==b.room || a.pauseEpoch!=b.pauseEpoch)return a;
         var out:Object=copy(a);out.players=[];out.projectiles=[];
         for(var i:int=0;i<a.players.length;i++) {
            var p:Object=a.players[i],q:Object=b.players[i],r:Object=p;
            if(q!=null && p.epoch==q.epoch && p.roomEpoch==q.roomEpoch && close(p,q,"x","y")) {
               r=copy(p);r.x=lerp(p.x,q.x,t);r.y=lerp(p.y,q.y,t);r.native=fields(p.native,q.native,t);
               r.visual=pose(p.visual,q.visual,t);
               if(p.weapon!=null && q.weapon!=null && p.weaponEpoch==q.weaponEpoch && p.weapon.id==q.weapon.id) {
                  r.weapon=copy(p.weapon);r.weapon.visual=pose(p.weapon.visual,q.weapon.visual,t);
               }
            }
            out.players.push(r);
         }
         var targets:Object=keyed(b.projectiles,"id");
         for each(p in a.projectiles) {
            q=targets[p.id];r=p;
            if(q!=null && p.room==q.room && close(p,q,"x","y")) {
               r=copy(p);r.x=lerp(p.x,q.x,t);r.y=lerp(p.y,q.y,t);r.rotation=angle(p.rotation,q.rotation,t);
               if(p.visual!=null && q.visual!=null)r.visual=pose(p.visual,q.visual,t);
            }
            out.projectiles.push(r);
         }
         if(a.scene!=null && b.scene!=null && a.scene.key==b.scene.key) {
            out.scene=copy(a.scene);
            for each(var list:String in ["units","objects","effects"]) {
               out.scene[list]=[];targets=keyed(b.scene[list],"key");
               for each(p in a.scene[list]) {
                  q=targets[p.key];r=p;
                  if(q!=null && p.pose!=null && q.pose!=null && close(p.pose,q.pose,"x","y")) {
                     r=copy(p);r.pose=pose(p.pose,q.pose,t);
                     if(p.fields!=null && q.fields!=null && close(p.fields,q.fields,"X","Y"))r.fields=fields(p.fields,q.fields,t);
                     if(p.weapons!=null) {
                        r.weapons=[];
                        for(i=0;i<p.weapons.length;i++) {
                           var gun:Object=p.weapons[i],other:Object=i<q.weapons.length?q.weapons[i]:null,g:Object=gun;
                           if(other!=null && gun.id==other.id && gun.variant==other.variant){g=copy(gun);g.pose=pose(gun.pose,other.pose,t);}
                           r.weapons.push(g);
                        }
                     }
                  }
                  out.scene[list].push(r);
               }
            }
         }
         return out;
      }
   }
}

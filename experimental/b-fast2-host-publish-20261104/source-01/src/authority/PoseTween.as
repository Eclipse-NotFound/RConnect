package authority {
   import flash.utils.Dictionary;
   /** Interpolate confirmed transforms only. Discrete native actions stay at A. */
   public final class PoseTween {
      // FrameDelta returns immutable confirmation branches. Index only their
      // array identity, never a mutable native entity or display tree. Values
      // contain records, not their parent array, so old frames remain collectible.
      private static var indices:Dictionary=new Dictionary(true);
      public static function copy(value:Object):Object {var out:Object={};for(var k:String in value)out[k]=value[k];return out;}
      private static function lerp(a:Number,b:Number,t:Number):Number{return a+(b-a)*t;}
      private static function angle(a:Number,b:Number,t:Number):Number{return a+(((b-a+540)%360)-180)*t;}
      public static function pose(a:Object,b:Object,t:Number):Object {
         if(a===b || a==null || b==null || a.v!==b.v)return a;
         // A changed animation frame/color is discrete, not evidence that its
         // geometry moved. Preserve unchanged recipes and child arrays instead
         // of allocating a second display tree on every screen frame.
         var stable:Boolean=a.x===b.x && a.y===b.y && a.a===b.a && a.sx===b.sx && a.sy===b.sy && a.r===b.r;
         if(stable && a.m!==b.m && a.m!=null && b.m!=null)
            for(var mi:int=0;mi<6;mi++)if(a.m[mi]!==b.m[mi]){stable=false;break;}
         if(stable) {
            var children:Array=a.children,changed:Array=null;
            if(a.f===b.f && children!=null && b.children!=null && children!==b.children) {
               for(var ci:int=0;ci<children.length;ci++) {
                  var left:Object=children[ci],right:Object=ci<b.children.length?b.children[ci]:null,childPose:Object=left.s;
                  if(right!=null && left.i==right.i && left.cls==right.cls)childPose=pose(left.s,right.s,t);
                  if(childPose!==left.s) {
                     if(changed==null)changed=children.slice(0,ci);
                     var childRecord:Object=copy(left);childRecord.s=childPose;changed.push(childRecord);
                  }else if(changed!=null)changed.push(left);
               }
            }
            if(changed==null)return a;
            var fixed:Object=copy(a);fixed.children=changed;return fixed;
         }
         var out:Object=copy(a);
         for each(var k:String in ["x","y","a"])out[k]=lerp(a[k],b[k],t);
         if(a.sx*b.sx>=0 && a.sy*b.sy>=0){out.sx=lerp(a.sx,b.sx,t);out.sy=lerp(a.sy,b.sy,t);out.r=angle(a.r,b.r,t);}
         if(a.m!=null && b.m!=null) {
            out.m=a.m.concat();out.m[4]=lerp(a.m[4],b.m[4],t);
            out.m[5]=lerp(a.m[5],b.m[5],t);
            // Blend each affine basis independently, preserving authored skew.
            // Native reflection/frame switches remain discrete, never collapse
            // a weapon through zero size to turn it to the opposite direction.
            if(a.sx*b.sx>=0 && a.sy*b.sy>=0)for(var axis:int=0;axis<4;axis+=2) {
               if(a.m[axis]===b.m[axis] && a.m[axis+1]===b.m[axis+1])continue;
               var ar:Number=Math.sqrt(a.m[axis]*a.m[axis]+a.m[axis+1]*a.m[axis+1]);
               var br:Number=Math.sqrt(b.m[axis]*b.m[axis]+b.m[axis+1]*b.m[axis+1]);
               var rotation:Number=angle(Math.atan2(a.m[axis+1],a.m[axis])*180/Math.PI,Math.atan2(b.m[axis+1],b.m[axis])*180/Math.PI,t)*Math.PI/180;
               var radius:Number=lerp(ar,br,t);out.m[axis]=Math.cos(rotation)*radius;out.m[axis+1]=Math.sin(rotation)*radius;
            }
         }
         if(a.f===b.f && a.children!=null && b.children!=null && a.children!==b.children) {
            out.children=[];
            for(var i:int=0;i<a.children.length;i++) {
               var c:Object=a.children[i],d:Object=i<b.children.length?b.children[i]:null,r:Object=c;
               if(d!=null && c.i==d.i && c.cls==d.cls) {
                  var blended:Object=pose(c.s,d.s,t);
                  if(blended!==c.s){r=copy(c);r.s=blended;}
               }
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
         if(a===b)return a;
         var moving:Boolean=false;
         for each(var field:String in NativeFields.MOTION)
            if(a[field] is Number && b[field] is Number && a[field]!==b[field]){moving=true;break;}
         if(!moving)return a;
         var out:Object=copy(a);
         for each(var k:String in NativeFields.MOTION)
            if(a[k] is Number && b[k] is Number)out[k]=lerp(a[k],b[k],t);
         return out;
      }
      private static function keyed(list:Array,key:String):Object {
         var byKey:Object=list==null?null:indices[list],out:Object=byKey==null?null:byKey[key];
         if(out!=null)return out;
         out={};for each(var o:Object in list)out[o[key]]=o;
         if(list!=null) {
            if(byKey==null){byKey={};indices[list]=byKey;}
            byKey[key]=out;
         }
         return out;
      }
      /** Only changed/fallback decorative templates need child interpolation.
       * Expand them locally using the current root, never the template's old
       * root position. The ordinary wire snapshot stays compact. */
      private static function effectPose(state:Object):Object {
         if(state.decor==null)return state.pose;
         var out:Object=copy(state.pose);
         if(out.v && out.a>0)out.children=state.decor.recipe.children;
         return out;
      }
      public static function frame(a:Object,b:Object,t:Number):Object {
         if(b==null || t<=0 || a.room!==b.room || a.pauseEpoch!=b.pauseEpoch)return a;
         if(a.timeControl!=null && b.timeControl!=null &&
            (a.timeControl.phase!==b.timeControl.phase || a.timeControl.cycle!==b.timeControl.cycle))return a;
         var out:Object=copy(a);out.players=[];out.projectiles=[];
         for(var i:int=0;i<a.players.length;i++) {
            var p:Object=a.players[i],q:Object=b.players[i],r:Object=p;
            if(q!=null && p.epoch==q.epoch && p.roomEpoch==q.roomEpoch && p.positionEpoch==q.positionEpoch && close(p,q,"x","y")) {
               r=copy(p);r.x=lerp(p.x,q.x,t);r.y=lerp(p.y,q.y,t);r.native=fields(p.native,q.native,t);
               r.visual=pose(p.visual,q.visual,t);
               if(p.held!=null && q.held!=null && p.held.key==q.held.key && p.held.positionEpoch==q.held.positionEpoch && close(p.held,q.held,"X","Y")) {
                  r.held=copy(p.held);r.held.X=lerp(p.held.X,q.held.X,t);r.held.Y=lerp(p.held.Y,q.held.Y,t);
               }
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
                  if(q!=null && p.positionEpoch==q.positionEpoch && p.pose!=null && q.pose!=null && close(p.pose,q.pose,"x","y")) {
                     r=copy(p);
                     if(list=="effects" && (p.decor!=null || q.decor!=null) &&
                        (p.decor==null || q.decor==null || p.decor.recipe!==q.decor.recipe))
                        r.pose=pose(effectPose(p),effectPose(q),t);
                     else r.pose=pose(p.pose,q.pose,t);
                     if(p.healthBar!=null && q.healthBar!=null)r.healthBar=HealthBarPose.tween(p.healthBar,q.healthBar,t);
                     if(list=="objects" && p.shadow!=null && q.shadow!=null && p.shadow.clip===q.shadow.clip) {
                        r.shadow=copy(p.shadow);r.shadow.pose=pose(p.shadow.pose,q.shadow.pose,t);
                     }
                     var pm:Object=NativeFields.motionOf(p),qm:Object=NativeFields.motionOf(q);
                     if(pm!=null && qm!=null && close(pm,qm,"X","Y")) {
                        r.fields=fields(pm,qm,t);delete r.fieldsDelta;
                     }
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

package authority {
   /** The side-effect-free, flat-ground subset of UnitPlayer.forces/control/run.
    * The host supplies both coefficients and a checked 24 px corridor. Other
    * movement, combat, platforms and uncertain terrain use confirmation only. */
   public final class GroundMotion {
      public static function capture(g:Object):Object {
         if(!(g is AuthorityPlayer) || AuthorityPlayer(g).predictionBlocked)return null;
         if(g==null || g.hp<=0 || g.sost!=1 || g.disabled || !g.ggControl || !g.stay || Math.abs(g.dy)>.01 ||
            g.work!="" || g.t_work>0 || g.teleObj!=null || g.stayOsn!=null || g.loc.sky || g.loc.quake ||
            g.isFly || g.isPlav || g.inWater || g.isSit || g.isLaz || g.levit || g.stun ||
            g.isFetter || g.autoAttack || g.runForever || g.isRun || g.zaput || g.cryst ||
            g.t_throw>0 || g.dash_t>0 || g.kdash_t>0 || g.t_emerg>0 || g.rat || g.fixed)return null;
         var gun:Object=g.currentWeapon;
         if(gun!=null && (gun.t_attack>0 || gun.t_reload>0 || gun.t_prep>0))return null;
         var room:Object=g.loc,left:Number=g.X-24,right:Number=g.X+24,half:Number=g.scX/2;
         var floor:int=Math.round(g.Y/40),top:int=Math.floor((g.Y-g.scY)/40);
         if(Math.abs(g.Y-floor*40)>1.01 || left-half<40 || right+half>=room.limX-40 || top<1 || floor>=room.spaceY-1)return null;
         for(var x:int=Math.floor((left-half)/40);x<=Math.floor((right+half)/40);x++) {
            var tile:Object=room.space[x][floor];
            if(tile.phis!=1 || tile.diagon || tile.stair || tile.zForm || tile.water || tile.door!=null || tile.trap!=null)return null;
            for(var y:int=top;y<floor;y++) {
               tile=room.space[x][y];
               if(tile.phis!=0 || tile.shelf || tile.water || tile.diagon || tile.stair || tile.grav!=1 || tile.door!=null || tile.trap!=null)return null;
            }
         }
         // Box/platform contacts can change a native step without changing tiles.
         var o:Object=room.firstObj,count:int=0;
         while(o!=null && ++count<=10000) {
            if(o!==g && NativeAccess.get(o,"mater",false) &&
               Number(o.X2)>=left-half && Number(o.X1)<=right+half && Number(o.Y2)>=g.Y-g.scY && Number(o.Y1)<=g.Y+1)return null;
            o=o.nobj;
         }
         if(count>10000)return null;
         return {x:g.X,dx:g.dx,walk:g.walk,max:g.maxSpeed,speed:g.walkSpeed,
            accel:g.accel*g.pers.accelMult,brake:g.brake,friction:g.tormoz,left:left,right:right};
      }
      public static function advance(state:Object,buttons:int):Object {
         if(state==null || (buttons&~(Commands.LEFT|Commands.RIGHT))!=0)return null;
         var s:Object=PoseTween.copy(state),v:Number=s.dx,b:Number=s.brake;
         if(s.walk<0){if(v < -s.max)v+=b;}
         else if(s.walk>0){if(v>s.max)v-=b;}
         else if(v>-b && v<b)v=0;
         else if(v>0)v-=b;else if(v<0)v+=b;
         v*=s.friction;
         s.walk=(buttons&3)==Commands.LEFT?-1:(buttons&3)==Commands.RIGHT?1:0;
         if(s.walk<0 && v>-s.speed)v=Math.max(-s.speed,v-s.accel);
         if(s.walk>0 && v<s.speed)v=Math.min(s.speed,v+s.accel);
         s.max=s.speed;s.dx=v;s.x+=v;
         if(s.x<s.left || s.x>s.right)return null;
         return s;
      }
   }
}

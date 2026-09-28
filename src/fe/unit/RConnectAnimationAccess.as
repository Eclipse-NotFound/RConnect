package fe.unit {
   import flash.display.MovieClip;
   /** Small presentation-only view of native state. No AI or combat steps. */
   public class RConnectAnimationAccess {
      public static function capture(unit:Unit):Object {
         if(unit==null)return null;
         var u:Object=unit,s:Object={ai:unit.aiState},a:Object;
         // TurretDisplay owns native unfold/retract transitions; a generic
         // stopped-frame correction would cut those transitions short.
         if(unit is UnitTurret)return s;
         if(u.blitData!=null && unit.anims!=null && (a=unit.anims[u.animState])!=null)
            s.blit={f:a.f,df:a.df,st:a.st,stab:a.stab};
         var osn:Object=u.vis==null || !("osn" in u.vis)?null:u.vis["osn"];
         if(osn is MovieClip)s.clip={frame:osn.currentFrame,playing:osn.isPlaying};
         return s;
      }
      public static function receive(unit:Unit,pose:Object,anim:String,previous:Object=null):void {
         if(pose==null || unit==null)return;
         var u:Object=unit,a:Object;
         unit.aiState=int(pose.ai);
         if(pose.blit!=null && unit.anims!=null && (a=unit.anims[anim])!=null) {
            var changed:Boolean=u.animState!=anim || previous==null;
            // A repeated non-looping attack may restart without changing its label.
            var restart:Boolean=!a.replay && previous!=null && previous.blit!=null
               && Number(pose.blit.f)+1<Number(previous.blit.f);
            if(changed || restart)a.restart();
            if(changed || restart || pose.blit.stab || pose.blit.st)a.f=Number(pose.blit.f);
            a.df=Number(pose.blit.df);a.st=pose.blit.st;a.stab=pose.blit.stab;
            u.animState=u.animState2=anim;
         }
         if(pose.clip!=null && u.vis!=null) {
            var osn:Object="osn" in u.vis?u.vis["osn"]:null;
            if(osn is MovieClip) {
               var frame:int=int(pose.clip.frame);
               var continuous:Boolean=u.animState==anim && pose.clip.playing && previous!=null && previous.clip!=null && previous.clip.playing;
               if(!continuous && (osn.currentFrame!=frame || osn.isPlaying!=pose.clip.playing)) {
                  if(pose.clip.playing)osn.gotoAndPlay(frame);else osn.gotoAndStop(frame);
               }
               u.animState=anim;
            }
         }
      }
      public static function tick(unit:Unit,pose:Object):Boolean {
         if(pose==null)return false;
         var u:Object=unit,a:Object;
         if(pose.blit!=null && unit.anims!=null && (a=unit.anims[u.animState])!=null) {
            u.blit(a.id,int(a.f));a.step();return true;
         }
         // MovieClip child timelines advance on the stage. Re-running animate()
         // would select a pose from stale local AI counters and restart the clip.
         return pose.clip!=null;
      }
   }
}

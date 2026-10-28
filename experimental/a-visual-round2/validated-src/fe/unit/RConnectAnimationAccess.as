package fe.unit {
   import flash.display.MovieClip;
   import flash.utils.Dictionary;
   /** Small presentation-only view of native state. No AI or combat steps. */
   public class RConnectAnimationAccess {
      private static var painted:Dictionary=new Dictionary(true);
      private static var observed:Dictionary=new Dictionary(true);
      private static var receivedClips:Dictionary=new Dictionary(true);
      private static var pausedClips:Dictionary=new Dictionary(true);
      public static function reset():void {painted=new Dictionary(true);observed=new Dictionary(true);receivedClips=new Dictionary(true);pausedClips=new Dictionary(true);}
      /** Authored clips can auto-advance while AIR reports isPlaying=false.
       * Observe actual frame changes before deciding a body is a stopped pose.
       * Label changes alone are pose selections, not continuous playback. */
      public static function observe(unit:Unit):void {
         if(unit==null)return;
         var u:Object=unit,osn:MovieClip=u.vis==null || !("osn" in u.vis)?null:u.vis["osn"] as MovieClip;
         if(osn==null || unit is UnitTurret)return;
         var rec:Object=observed[unit];
         if(rec==null || rec.clip!==osn)rec=observed[unit]={clip:osn,frame:osn.currentFrame,label:osn.currentLabel,run:0,samples:0};
         rec.run=osn.currentFrame!=rec.frame && osn.currentLabel==rec.label?int(rec.run)+1:0;
         rec.samples++;
         rec.frame=osn.currentFrame;rec.label=osn.currentLabel;
      }
      public static function effects(unit:Unit):void {
         if(unit is UnitAlicorn) {
            var a:UnitAlicorn=unit as UnitAlicorn,u:Object=unit;
            if(a.visshit!=null && a.visshit.visible!=(Number(u.shithp)>0)) {
               a.visshit.visible=Number(u.shithp)>0;
               if(a.visshit.visible)a.visshit.gotoAndPlay(1);else a.visshit.gotoAndStop(1);
            }
         }
      }
      public static function capture(unit:Unit):Object {
         if(unit==null)return null;
         var u:Object=unit,s:Object={ai:unit.aiState},a:Object;
         // TurretDisplay owns native unfold/retract transitions; a generic
         // stopped-frame correction would cut those transitions short.
         if(unit is UnitTurret)return s;
         if(u.blitData!=null && unit.anims!=null && (a=unit.anims[u.animState])!=null)
            s.blit={f:a.f,df:a.df,st:a.st,stab:a.stab,first:a.firstf,length:a.maxf,ret:a.retf,loop:a.replay,
               reverse:unit is UnitMerc && u.animState=="walk" && unit.aiNapr*Number(u.storona)<0};
         var osn:Object=u.vis==null || !("osn" in u.vis)?null:u.vis["osn"];
         if(osn is MovieClip) {
            var rec:Object=observed[unit];
            // A checkpoint can be captured immediately after construction,
            // before any frame observation. AIR reports false even for native
            // implicit autoplay. Unknown is not a request to stop that clip.
            var known:Boolean=osn.isPlaying || (rec!=null && rec.clip===osn && int(rec.samples)>=3);
            s.clip={frame:osn.currentFrame,known:known,
               playing:osn.isPlaying || (rec!=null && rec.clip===osn && int(rec.run)>=2)};
         }
         return s;
      }
      public static function receive(unit:Unit,pose:Object,anim:String,previous:Object=null,clocked:Boolean=false,paused:Boolean=false):void {
         if(pose==null || unit==null)return;
         var u:Object=unit,a:Object;
         unit.aiState=int(pose.ai);
         if(pose.blit!=null && unit.anims!=null && (a=unit.anims[anim])!=null) {
            var changed:Boolean=u.animState!=anim || previous==null;
            // A repeated non-looping attack may restart without changing its label.
            var restart:Boolean=!a.replay && previous!=null && previous.blit!=null
               && Number(pose.blit.f)+1<Number(previous.blit.f);
            if(changed || restart)a.restart();
            if(clocked || changed || restart || pose.blit.stab || pose.blit.st)a.f=Number(pose.blit.f);
            a.df=Number(pose.blit.df);a.st=pose.blit.st;a.stab=pose.blit.stab;
            u.animState=u.animState2=anim;
         }
         if(pose.clip!=null && pose.clip.known!==false && u.vis!=null) {
            var osn:Object="osn" in u.vis?u.vis["osn"]:null;
            if(osn is MovieClip) {
               var frame:int=int(pose.clip.frame);
               var continuous:Boolean=!paused && !pausedClips[unit] && receivedClips[unit]===osn && u.animState==anim && pose.clip.playing && previous!=null && previous.clip!=null && previous.clip.playing;
               // isPlaying also cannot identify an implicit autoplay clip on
               // receipt. Apply explicit start/stop transitions even at the same
               // frame; don't let a fresh child inherit the previous child's mode.
               if(!continuous && (paused || pausedClips[unit] || pose.clip.playing || receivedClips[unit]!==osn || previous==null || previous.clip==null
                  || previous.clip.playing || osn.currentFrame!=frame)) {
                  if(!paused && pose.clip.playing)osn.gotoAndPlay(frame);else osn.gotoAndStop(frame);
               }
               pausedClips[unit]=paused;
               receivedClips[unit]=osn;
               u.animState=anim;
            }
         }
      }
      public static function tick(unit:Unit,pose:Object,advance:Boolean=true):Boolean {
         if(pose==null)return false;
         var u:Object=unit,a:Object;
         if(pose.blit!=null && unit.anims!=null && (a=unit.anims[u.animState])!=null) {
            var frame:int=pose.blit.reverse?int(a.maxf-a.f-1):int(a.f),last:Object=painted[unit];
            if(last==null || last.id!=a.id || last.frame!=frame || last.data!==unit.visData) {
               u.blit(a.id,frame);painted[unit]={id:a.id,frame:frame,data:unit.visData};
            }
            if(advance)a.step();
            // Native Merc.animate skips blit when the host already stopped the
            // pose, leaving a fresh mirror bitmap empty. Paint even that first
            // stopped frame, then place its separate arm as native animate does.
            if(unit is UnitMerc) {
               var merc:UnitMerc=unit as UnitMerc,positions:Object=u.wPos[a.id];
               var offset:Object=positions==null?null:positions[int(a.f)];
               if(merc.arm!=null) {
                  merc.arm.visible=int(u.sost)<2;
                  if(offset!=null && unit.visBmp!=null) {
                     merc.arm.x=Number(u.X)+(Number(offset.x)+unit.visBmp.x)*Number(u.storona);
                     merc.arm.y=Number(u.Y)+Number(offset.y)+unit.visBmp.y;
                  }
               }
            }
            return true;
         }
         // MovieClip child timelines advance on the stage. Re-running animate()
         // would select a pose from stale local AI counters and restart the clip.
         return pose.clip!=null;
      }
   }
}

package rconnect.game {
   /** Presentation-only eligibility and one native jump segment. No world writes. */
   public final class NativeJumpPose {
      private var owner:Object,room:Object,world:Object,poseClip:Object,bodyClip:Object;
      private var active:Boolean=false;
      private var serial:int=0;
      private var nativeJump:Number=NaN;

      private static function get(o:Object,key:String):* {
         if(o==null)return null;
         try{return o[key];}catch(error:*){}
         return null;
      }
      private static function number(o:Object,key:String):Number {
         var value:*=get(o,key);
         return value==null?NaN:Number(value);
      }
      public static function frame(dy:Number):int {
         return int(Math.max(1,Math.min(32,Math.round(16+dy))));
      }
      public static function eligible(u:Object,loc:Object,w:Object):Boolean {
         if(u==null || loc==null || w==null || get(u,"loc")!==loc)return false;
         if(number(w,"allStat")!=1 || get(w,"onPause")!==false || number(w,"t_exit")!=0)return false;
         if(number(u,"sost")!=1 || !(number(u,"hp")>0) || get(u,"stay")!==false
            || !(number(u,"aJump")>0) || get(u,"animOff")!==false || number(u,"t_work")!=0
            || get(u,"isFly")!==false || number(u,"isLaz")!=0 || get(u,"isPlav")!==false
            || number(u,"levit")!=0 || number(u,"t_port")!=0 || get(u,"animState")!=="jump")return false;
         var osn:Object=get(get(u,"vis"),"osn"),body:Object=get(osn,"body"),dy:Number=number(u,"dy");
         var jump:Number=number(u,"jumpNumb");
         // t_stay is native-private. Require the actual post-animation result,
         // not a guessed grace counter, to agree with the normal aJump>0 branch.
         return get(osn,"currentLabel")==="jump" && number(osn,"currentFrame")>=1
            && get(body,"isPlaying")===false && number(body,"totalFrames")>=32
            && isFinite(dy) && isFinite(jump) && jump>=0 && jump==int(jump)
            && number(body,"currentFrame")==frame(dy);
      }
      /** Called after every native game frame, even when no packet is sent. */
      public function observe(u:Object,loc:Object,w:Object):int {
         var osn:Object=get(get(u,"vis"),"osn"),body:Object=get(osn,"body");
         if(owner!==u || room!==loc || world!==w || poseClip!==osn || bodyClip!==body)active=false;
         owner=u;room=loc;world=w;
         poseClip=osn;bodyClip=body;
         if(!eligible(u,loc,w)){active=false;return 0;}
         // Native double-jump resets dy without leaving the jump label.
         // Its jumpNumb change is a discontinuity; an ordinary apex is not.
         var jump:Number=number(u,"jumpNumb");
         if(nativeJump!=jump)active=false;
         nativeJump=jump;
         if(!active){serial++;if(serial<=0)serial=1;}
         active=true;return serial;
      }
      private static function qualified(s:Object):Boolean {
         return s!=null && number(s,"nativeJumpRun")>0 && number(s,"nativeJumpRun")==int(s.nativeJumpRun)
            && get(s,"pose")==="jump" && get(s,"bodyPlaying")===false
            && number(s,"stay")==0 && number(s,"sost")==1 && number(s,"hp")>0
            && number(s,"poseFrame")>=1 && number(s,"poseFrame")==int(s.poseFrame)
            && isFinite(number(s,"dy")) && number(s,"bodyFrame")==frame(Number(s.dy));
      }
      /** Both endpoints certify the same native segment. Never modify velocity. */
      public static function between(a:Object,b:Object,t:Number):Number {
         if(!qualified(a) || !qualified(b) || !isFinite(t) || t<0 || t>1
            || a.nativeJumpRun!==b.nativeJumpRun || a.poseFrame!==b.poseFrame
            || get(a,"roomKey")==null || String(a.roomKey)=="" || a.roomKey!==b.roomKey
            || !isFinite(number(a,"roomEpoch")) || a.roomEpoch!==b.roomEpoch
            || get(a,"landId")==null || a.landId!==b.landId || get(a,"locId")==null || a.locId!==b.locId
            || !isFinite(number(a,"sampleTime")) || !isFinite(number(b,"sampleTime"))
            || Number(b.sampleTime)<=Number(a.sampleTime))return NaN;
         return frame(Number(a.dy)+(Number(b.dy)-Number(a.dy))*t);
      }
   }
}

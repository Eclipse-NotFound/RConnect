package rconnect.game {
   import flash.display.MovieClip;
   import flash.utils.Dictionary;

   /** visualPlayer frame scripts create visible wings by default. The native
    * UnitPlayer.animate hides/folds/flaps them; the inert NPC body cannot do it. */
   public class PeerAppearance {
      private var states:Dictionary=new Dictionary(true);
      public static function capture(u:Object):Object {
         var body:Object=GameBridge.probe(GameBridge.probe(GameBridge.probe(u,"vis"),"osn"),"body");
         var result:Object={};
         for each(var name:String in ["lwing","rwing"]) {
            var v:MovieClip=GameBridge.probe(body,name) as MovieClip;
            if(v==null)continue;
            var tip:Object=GameBridge.probe(GameBridge.probe(v,"wing"),"wing2");
            result[name]={visible:v.visible,frame:v.currentFrame,
               flap:GameBridge.probe(u,"isFly")===true&&!GameBridge.probe(u,"stay")&&!GameBridge.probe(u,"isPlav")&&!GameBridge.probe(u,"isLaz")&&v.currentFrame!=11,
               tip:GameBridge.probe(tip,"rotation")};
         }
         return result;
      }
      public function apply(u:Object,s:Object,paused:Boolean=false):void {
         var body:Object=GameBridge.probe(GameBridge.probe(GameBridge.probe(u,"vis"),"osn"),"body");
         for each(var name:String in ["lwing","rwing"]) {
            var v:MovieClip=GameBridge.probe(body,name) as MovieClip;
            if(v==null)continue;
            var wing:Object=s==null?null:s[name];
            v.visible=wing!=null&&wing.visible===true;
            if(!v.visible){v.stop();delete states[v];continue;}
            var f:int=Math.max(1,Math.min(v.totalFrames,int(wing.frame)));
            if(wing.flap===true&&!paused) {
               if(states[v]!==true || v.currentFrame==1 || v.currentFrame==11)v.gotoAndPlay(Math.max(2,f));
               states[v]=true;
            } else {
               if(v.currentFrame!=f)v.gotoAndStop(f);
               v.stop();states[v]=false;
            }
            var tip:Object=GameBridge.probe(GameBridge.probe(v,"wing"),"wing2");
            if(tip!=null&&wing.tip!=null)tip.rotation=Number(wing.tip);
         }
      }
   }
}

package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.MouseEvent;
   import flash.events.TimerEvent;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   import rconnect.core.Session;
   import rconnect.game.GameBridge;

   /** One disconnected game: actual beginMission versus cached gotoLand.
    * No seed injection, network packets, save editing or forced room layout. */
   public class SoloMapGenerationTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var mod:RConnectMod,t:Timer=new Timer(100),phase:String="boot",at:int=getTimer(),round:int=0;
      private var first:Object,previous:Object,firstLand:Object,previousLand:Object;
      private const TARGET:String="random_mane";
      public function SoloMapGenerationTestDoc() {
         if(NativeApplication.nativeApplication.applicationID.indexOf("rconnect-coop-host-")<0)return;
         t.addEventListener(TimerEvent.TIMER,tick);t.start();
      }
      private function check(ok:Boolean,s:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"solo-map "+s+" round="+round);}
      private function change(s:String):void {phase=s;at=getTimer();}
      private function hash(s:String):String {var h:uint=2166136261;for(var i:int=0;i<s.length;i++)h=uint(h*31+s.charCodeAt(i));return h.toString(16);}
      private function fingerprint():Object {
         var rows:Array=[],land:Object=mod.game.world.land;
         for each(var column:Object in land.locs)for each(var row:Object in column)for each(var room:Object in row) {
            if(room==null)continue;
            rows.push([room.landX,room.landY,room.landZ,String(room.room.id),Boolean(room.mirror),hash(room.room.xml.a.toXMLString())].join(":"));
         }
         rows.sort();
         return {layout:rows.join("|"),hash:hash(rows.join("|")),rooms:rows.length,seed:Number(GameBridge.probe(land,"rconnectLayoutSeed"))};
      }
      private function stable(id:String=null):Boolean {
         var w:Object=mod.game.world;
         return w!=null&&w.gg!=null&&w.gui!=null&&w.sats!=null&&w.land!=null&&w.land.act!=null
            &&String(w.game.curLandId)==String(w.land.act.id)&&(id==null||String(w.land.act.id)==id)
            &&!mod.game.isTransitioning()&&(!w.vblack.visible||w.vblack.alpha==0);
      }
      private function finish():void {change("done");t.stop();Log.d("COOP EFFECTS DONE solo-map offline");}
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null||mod.game.gg==null)return;
         if(mod.game.world.clickReq==1){mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN,true));mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP,true));}
         if(getTimer()-at>90000){check(false,"timeout "+phase);finish();return;}
         try {
            if(mod.session.mode!=Session.OFFLINE){check(false,"unexpected network session");finish();return;}
            mod.game.gg.invulner=true;
            if(phase=="boot"&&stable()) {
               check(String(mod.config.getValue("autoRole"))=="","automatic networking disabled");
               mod.game.forceCloseOverlays();mod.game.world.game.gotoLand("rbl");change("base");
            }else if(phase=="base"&&stable("rbl")) {
               mod.game.forceCloseOverlays();
               if(round==1)mod.game.world.game.gotoLand(TARGET);else mod.game.world.game.beginMission(TARGET);
               change("travel");
            }else if(phase=="travel"&&stable(TARGET)) {
               var current:Object=mod.game.world.land,data:Object=fingerprint();
               check(mod.session.mode==Session.OFFLINE,"remains offline through native travel");
               check(data.rooms>10,"multiple real rooms generated count="+data.rooms);
               Log.d("SOLO MAP "+JSON.stringify({round:round,data:data}));
               if(round==0){first=data;firstLand=current;}
               else if(round==1){
                  check(current===firstLand,"ordinary revisit retains native Land");
                  check(data.layout==first.layout,"ordinary revisit retains layout");
                  check(data.seed==first.seed||(!isFinite(data.seed)&&!isFinite(first.seed)),"ordinary revisit retains seed");
               }else {
                  check(current!==previousLand,"new expedition constructs a new native Land");
                  check(data.layout!=previous.layout,"new expedition changes layout");
               }
               previous=data;previousLand=current;
               if(round==3){finish();return;}
               round++;mod.game.world.game.gotoLand("rbl");change("base");
            }
         }catch(error:Error){check(false,error.getStackTrace());finish();}
      }
   }
}

package {
   import flash.display.Sprite;
   import flash.display.DisplayObjectContainer;
   import flash.events.MouseEvent;
   import flash.events.TimerEvent;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.system.ApplicationDomain;
   import flash.utils.Timer;
   import flash.utils.getQualifiedClassName;
   import flash.utils.getTimer;

   /** External driver: observe native menu, then click a copied real save. */
   public class ManualStartupTestDoc extends Sprite {
      private var timer:Timer=new Timer(100),at:int=getTimer(),phase:int=0;
      private var mod:Object,chooser:Object,menu:Object,expected:Object;
      public function ManualStartupTestDoc() {
         timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
      }
      private function log(s:String):void {
         var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath("RConnectLauncherTest.log"),FileMode.APPEND);
         f.writeUTFBytes(s+"\n");f.close();
      }
      private function check(ok:Boolean,s:String):void {log((ok?"PASS ":"FAIL ")+s);if(!ok)throw new Error(s);}
      private function tick(e:TimerEvent):void {
         try {
            if(getTimer()-at>50000)throw new Error("startup timeout phase="+phase);
            if(mod==null){mod=ApplicationDomain.currentDomain.getDefinition("RConnectMod").instance;chooser=ApplicationDomain.currentDomain.getDefinition("rconnect.core.ManualStartup");}
            var w:Object=mod.game.world;if(w==null)return;
            if(phase==0) {
               if(w.mm==null || !w.mm.loaded)return;
               check(w.gg==null && w.mm.active,"no automatic new game");
               check(!chooser.openSaveChooser(null),"not ready is deferred");
               expected=w.getSave(1);check(expected!=null && expected.est,"copied native save is readable");
               check(chooser.openSaveChooser(w),"native chooser call succeeds");
               for(var i:int=0;i<mod.main.numChildren;i++) {
                  var child:Object=mod.main.getChildAt(i);
                  if(getQualifiedClassName(child)=="visMainMenu")menu=child;
               }
               check(menu!=null && menu.dialLoad.visible,"save list is visible");
               check(menu.dialLoad.slot1.ggName.text.indexOf(String(expected.pers.persName))==0,"slot shows preserved character");
               phase=1;at=getTimer();
            } else if(phase==1 && getTimer()-at>3000) {
               check(w.gg==null && w.mm.active && menu.dialLoad.visible,"chooser waits for player input");
               menu.dialLoad.slot1.dispatchEvent(new MouseEvent(MouseEvent.CLICK));
               phase=2;at=getTimer();
            } else if(phase==2 && w.gg!=null && w.game!=null && w.loc!=null && w.ng_wait==0 && w.comLoad<0) {
               check(!w.verror.visible,"native load has no error dialog");
               check(w.pers.persName==expected.pers.persName && w.pers.level==expected.pers.level,"selected character and level loaded");
               check(w.game.curLandId==expected.game.land,"selected save location loaded");
               check(chooser.openSaveChooser(w) && !w.mm.active,"gameplay is never reopened as menu");
               log("DONE");timer.stop();
            }
         } catch(error:Error) {log("FAIL "+error.getStackTrace());timer.stop();}
      }
   }
}

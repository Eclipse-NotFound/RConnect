package {
 import flash.system.ApplicationDomain;
 import flash.events.MouseEvent;
 import flash.text.TextField;
 import flash.utils.getTimer;
 /** Optional BFieldCases adapter. Default-policy/native checks followed by
  * actual confirmation-frame/UI checks on both sides. */
 public final class BHorseshoeCases {
  private var mod:Object,api:Object,side:String,phase:int=0,seen:int=-1,at:int=0,old:Object;
  private var values:Array=[false,true,false];
  public function BHorseshoeCases(m:Object,r:Object,d:ApplicationDomain,c:Object,role:String,a:Object){mod=m;api=a;side=role;at=getTimer();}
  public function input():void {
   var w:Object=mod.access.world;
   for each(var key:String in ["keyLeft","keyRight","keyJump","keyAttack","keySit","keyRun","keyAction","keyTele"])w.ctr[key]=false;
  }
  private function ui(expected:Boolean):void {
   mod.ui.refresh();mod.hud.openPage("settings");
   mod.hud.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_WHEEL,true,false,0,0,null,false,false,false,false,-40));
   mod.hud.refresh();
   var button:TextField=mod.hud.getChildByName("rconnect-horseshoe-xp") as TextField;
   api.check(button!=null && button.visible && button.mouseEnabled==(side=="host"),"horseshoe settings control is visible and obeys role ownership "+phase);
   api.check(mod.ui.horseshoeXP.shared===expected,"horseshoe HUD reflects confirmed policy "+phase);
  }
  public function step():void {
   if(getTimer()-at>60000)throw new Error("Horseshoe network fixture timed out at "+phase);
   if(side=="join") {
    var control:Object=api.read("horseshoe-control.json");if(control==null)return;
    if(control.done){api.write("horseshoe-join-done.json",{done:true});api.finish();return;}
    var f:Object=mod.replica==null?null:mod.replica.lastFrame;
    if(f==null || control.stage==seen || f.presentation<control.presentation || f.horseshoeShared!==control.value)return;
    seen=control.stage;phase=seen;ui(control.value);
    var local:*=mod.preferences.getValue("shareHorseshoeXP");
    mod.ui.horseshoeXP.setShared(!control.value);mod.ui.refresh();
    api.check(mod.ui.horseshoeXP.shared===control.value && mod.preferences.getValue("shareHorseshoeXP")===local,
     "join cannot overwrite host horseshoe policy "+phase);
    api.write("horseshoe-ack-"+phase+".json",{value:control.value});return;
   }
   var s:Object=mod.host;
   if(phase==0) {
    if(!s.active || mod.access.world.t_exit>0 || !s.actors[0].unit.ggControl || !s.actors[1].unit.ggControl)return;
    old={policy:mod.preferences.getValue("shareHorseshoeXP"),menus:s.pause.policyMenus,sats:s.pause.policySats};
    api.check(old.policy=="1" && s.runtime.shareHorseshoeXP,"horseshoe XP sharing defaults on in fresh B profile");
    BHorseshoeChecks.run(mod,api.check);phase=1;at=getTimer();
   }
   if(phase==8){if(api.read("horseshoe-join-done.json")!=null)api.finish();return;}
   if(phase%2==1 && phase<=5) {
    var value:Boolean=values[(phase-1)/2];
    mod.ui.horseshoeXP.setShared(value);ui(value);
    api.write("horseshoe-control.json",{stage:phase,value:value,presentation:s.presentations+1});
    ++phase;at=getTimer();return;
   }
   if(phase%2==0 && api.read("horseshoe-ack-"+(phase-1)+".json")!=null) {
    if(phase<6){++phase;return;}
    mod.preferences.setValue("shareHorseshoeXP",old.policy);mod.preferences.save();mod.applyPreferences();mod.ui.refresh();mod.hud.refresh();
    api.picture("host-horseshoe-setting");api.write("horseshoe-control.json",{done:true});phase=8;
   }
  }
 }
}

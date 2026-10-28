package {
 import flash.system.ApplicationDomain;
 /** Test the real dependency validator at the packet boundary, without
  * advancing actors or touching the live Commands queue. */
 public final class BAddonInputChecks {
  public static function run(mod:Object,domain:ApplicationDomain,check:Function):void {
   var bridge:Object=mod.access.addons;
   if(bridge==null)return;
   var valid:Object=bridge.input();
   check(bridge.acceptsInput(valid),"addon accepts current real UI settings");
   check(bridge.acceptsInput(null),"addon accepts an absent optional control");
   var CommandsType:Class=domain.getDefinition("authority.Commands") as Class;
   var queue:Object=new CommandsType("addon-check",1,"test-room",bridge.acceptsInput);
   var packet:Object={session:"addon-check",player:1,epoch:1,room:"test-room",roomEpoch:1,weaponEpoch:1,
      seq:1,buttons:0,aimX:0,aimY:0,actions:[],msw:null,projectilePick:null,addons:valid};
   check(queue.accept(packet,100)=="","addon real settings pass Commands acceptance");
   var received:int=queue.accepted,action:int=queue.receivedAction;
   packet.seq=2;
   packet.addons={fa:{overlay:false,settings:{unknownSettingForBCheck:1}}};
   check(queue.accept(packet,101)=="addon-input","addon unknown setting is rejected before simulation");
   packet.addons={fa:{overlay:false,settings:{}}};
   if(valid.fa!=null)for(var key:String in valid.fa.settings) {
      packet.addons.fa.settings[key]=valid.fa.settings[key] is Boolean?1:"invalid-number";
      check(queue.accept(packet,102)=="addon-input","addon setting type is rejected before simulation");
      break;
   }
   packet.addons={fa:{overlay:"true",settings:{}}};
   check(queue.accept(packet,103)=="addon-input","addon nonboolean overlay is rejected");
   check(queue.accepted==received&&queue.receivedAction==action,"invalid addon packets leave accepted sequence and actions unchanged");
   packet.addons=valid;
   check(queue.accept(packet,104)=="","valid addon packet can reuse a rejected sequence");
  }
 }
}

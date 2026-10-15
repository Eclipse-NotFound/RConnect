package {
   import flash.events.KeyboardEvent;
   import flash.text.TextField;
   import rconnect.ui.NetHud;

   /** Exercise the real HUD while a test-local settings service arrives/replaces.
    * No production class or other mod is changed; the original carrier is restored
    * synchronously, before another game frame can observe the test service. */
   public class HiddenHudKeybindRegression {
      private static function service():Object {
         var api:Object={keybindVersion:1,calls:0,items:null};
         api.registerPage=function(id:String,title:String,items:Array,callback:*=null,hint:String="",meta:*=null):void {
            if(id=="rconnect-hotkeys"){api.calls++;api.items=items;}
         };
         api.isCapturingKey=function():Boolean{return false;};
         api.matchesKey=function(page:String,id:String,e:KeyboardEvent):Boolean {
            if(api.items==null)return false;
            for each(var item:Object in api.items)if(item.key==id) {
               var b:Object=item.get();
               return b.code!=0 && e.keyCode==b.code && e.ctrlKey==b.ctrl && e.altKey==b.alt && e.shiftKey==b.shift;
            }
            return false;
         };
         api.keyLabel=function(b:Object):String{return (b.ctrl?"Ctrl+":"")+(b.code>=112?"F"+(b.code-111):String(b.code));};
         return api;
      }
      public static function run(mod:RConnectMod,check:Function):void {
         var h:NetHud=mod.hud,carrier:Object=mod.main.getChildByName("ModSettingsCarrier");
         check(carrier!=null && carrier.modAPI!=null,"real settings carrier available before hidden-HUD regression");
         if(carrier==null || carrier.modAPI==null)return;
         var actual:Object=carrier.modAPI,first:Object=service(),second:Object=service();
         var panel:Object=null,chat:Object=null,panelBefore:Object=null,chatBefore:Object=null,restored:NetHud=null;
         try {
            h.collapse();h.visible=false;mod.stage.focus=null;
            carrier.modAPI=null;h.refresh();
            carrier.modAPI=first;h.refresh();
            check(!h.visible && h.collapsed && first.calls==1 && first.items.length==2,
               "hidden collapsed HUD registers a late settings service without opening");
            h.refresh();check(first.calls==1,"hidden HUD does not repeat registration each refresh");
            carrier.modAPI=second;h.refresh();
            check(!h.visible && h.collapsed && second.calls==1,"hidden HUD registers a replacement settings service");
            for each(var item:Object in second.items) {
               if(item.key=="panel"){panel=item;panelBefore=JSON.parse(JSON.stringify(item.get()));}
               if(item.key=="chat"){chat=item;chatBefore=JSON.parse(JSON.stringify(item.get()));}
            }
            panel.set({code:120,ctrl:false,alt:false,shift:false});
            chat.set({code:119,ctrl:true,alt:false,shift:false});
            // All events go through the actual production stage listeners.
            mod.stage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_DOWN,true,false,120,120,0,true));
            mod.stage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_UP,true,false,120,120,0,true));
            check(!h.visible,"remapped panel key still requires exact modifiers");
            mod.stage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_DOWN,true,false,120,120));
            check(h.visible && h.collapsed,"remap made while hidden opens the actual collapsed HUD");
            mod.stage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_DOWN,true,false,120,120));
            check(h.visible,"held remapped key does not toggle twice");
            mod.stage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_UP,true,false,120,120));
            mod.stage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_DOWN,true,false,120,120));
            mod.stage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_UP,true,false,120,120));
            check(!h.visible,"key release permits the next remapped panel action");
            mod.stage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_DOWN,true,false,119,119,0,true));
            mod.stage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_UP,true,false,119,119,0,true));
            check(h.visible && !h.collapsed && h.currentPage=="chat" && mod.stage.focus===h.tfChat,
               "remapped chat key opens and focuses actual chat from hidden HUD");
            h.openPage("settings");h.refresh();
            check(TextField(h.getChildByName("rconnect-shortcuts")).text.indexOf("F9")>=0,
               "expanded footer refreshes the new shortcut label");
            h.collapse();carrier.modAPI=first;
            restored=new NetHud(null,mod);
            check(restored.collapsed && first.items[0].get().code==120 && first.items[1].get().code==119,
               "fresh production HUD restores saved collapse and remapped preferences");
         } finally {
            if(restored!=null)restored.dispose();
            if(panel!=null && panelBefore!=null)panel.set(panelBefore);
            if(chat!=null && chatBefore!=null)chat.set(chatBefore);
            carrier.modAPI=actual;h.visible=true;h.collapse();h.refresh();mod.stage.focus=null;
         }
      }
   }
}

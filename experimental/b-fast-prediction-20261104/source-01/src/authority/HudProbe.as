package authority {
   import authority.ui.HudModel;
   import flash.events.MouseEvent;
   import flash.events.KeyboardEvent;
   import flash.events.Event;
   import flash.geom.Rectangle;
   import flash.text.TextField;
   import flash.utils.getTimer;
   /** Exercise the actual compact UI and normal session cleanup in AIR. */
   public final class HudProbe extends Probe {
      private var begin:int=-1,tick:int=0,phase:int=0,oldPlayer:Object,exitAt:int=-1;
      private var seenMessage:Boolean=false,settingsSeen:Boolean=false;
      private var dialogAt:int=0,dialogs:int=0;
      private var windowPhase:int=0,windowAt:int=0,windowWidth:int=0,windowHeight:int=0;
      private var windowBounds:Rectangle;
      public function HudProbe(a:NativeAccess,h:Boolean){super(a,h);}
      override public function message(value:Object):void {
         if(host && begin<0 && value.type=="input" && value.player==1 && value.probeStart is Number)begin=int(value.probeStart);
         if(value.type=="chat" && value.text=="中文聊天 <验证> ABC")seenMessage=true;
      }
      override public function input(frame:Object,session:HostSession):Object {
         frame.buttons=0;frame.actions=[];
         if(!host && begin>=0)frame.probeStart=begin;
         return frame;
      }
      private function click(name:String):void {
         var m:RConnectMod=RConnectMod.instance,t:TextField=m.hud.getChildByName(name) as TextField;
         if(t==null || !t.mouseEnabled)throw new Error("UI control not available: "+name);
         t.dispatchEvent(new MouseEvent(MouseEvent.CLICK,true));
      }
      private function windowChecks():Boolean {
         if(windowPhase==3)return true;
         var m:RConnectMod=RConnectMod.instance,w:Object=access.world,now:int=getTimer();
         if(windowPhase==0) {
            check(!w.pip.active,"network starts without an unsolicited native character menu");
            for(var i:int=0;i<5;i++)m.stage.dispatchEvent(new Event(Event.RESIZE));
            check(!w.pip.active,"same-size AIR resize notifications do not become menu input");
            windowBounds=m.stage.nativeWindow.bounds.clone();windowWidth=m.stage.stageWidth;windowHeight=m.stage.stageHeight;
            windowPhase=1;windowAt=now;m.stage.nativeWindow.width+=40;return false;
         }
         if(now-windowAt<400)return false;
         if(windowPhase==1) {
            check(m.stage.stageWidth!=windowWidth && w.pip.active,"actual owned-window resize still reaches the native layout and menu handler",
               {before:windowWidth,after:m.stage.stageWidth,pip:w.pip.active});
            w.pip.onoff(-1);windowPhase=2;windowAt=now;m.stage.nativeWindow.bounds=windowBounds;return false;
         }
         check(m.stage.stageWidth==windowWidth && m.stage.stageHeight==windowHeight,"owned test window returns to its original viewport");
         w.pip.onoff(5);m.stage.dispatchEvent(new Event(Event.RESIZE));
         check(w.pip.active,"duplicate resize preserves an intentionally opened native menu");
         w.pip.onoff(-1);windowPhase=3;return true;
      }
      override public function observe(session:HostSession,replica:ClientReplica):void {
         if(finished)return;
         var m:RConnectMod=RConnectMod.instance,w:Object=access.world;
         if(oldPlayer!=null && m.mode==HudModel.OFFLINE) {
            if(exitAt<0)exitAt=getTimer();
            if(getTimer()-exitAt<1000 || !access.ready())return;
            // Native loading returns random expeditions to the home base.
            // A fresh test character has not read its introductory dialogues;
            // acknowledge those through the native Script input, never force
            // the new actor's control flag or skip a production cutscene.
            if(!w.gg.ggControl && (w.gui.vis.dial.visible || w.gui.vis.inform.visible) && getTimer()-dialogAt>300) {
               dialogAt=getTimer();++dialogs;w.ctr.keyPressed=true;
               Log.write("return-native-dialogue",{advance:dialogs,dialog:w.gui.vis.dial.visible,inform:w.gui.vis.inform.visible});
            }
            if(!w.gg.ggControl && getTimer()-exitAt<15000)return;
            check(m.host==null && m.replica==null && access.definition("fe.loc.Location")["rconnectPlayerStep"]==null,
               "leaving removes the authority session and native scheduling hooks");
            check(w.gg.loc===w.loc && w.gui.gg===w.gg && w.invent.gg===w.gg && access.scope.depth==0,
               "leaving restores one native character, room and HUD ownership");
            check(host?w.gg===oldPlayer:w.gg!==oldPlayer,
               host?"host keeps its own native journey after teammate leaves":"join rebuilds its own journey instead of simulating the host replica");
            check(w.gg.hp>0 && w.gg.ggControl,"returned native character remains alive and controllable",
               {hp:w.gg.hp,control:w.gg.ggControl,work:w.gg.work,exit:w.t_exit,die:w.t_die,wait:getTimer()-exitAt,
                dead:w.pers.dead,cat:w.catPause,paused:w.onPause,stat:w.allStat,menu:w.mm.active,pip:w.pip.active,dialogs:dialogs});
            w.pip.onoff(-1);m.stage.dispatchEvent(new Event(Event.RESIZE));
            check(w.pip.active,"leaving restores the original native resize listener");w.pip.onoff(-1);
            finish();return;
         }
         var f:Object=host?(session==null?null:session.lastFrame):(replica==null?null:replica.lastFrame);
         if(f==null || !windowChecks())return;if(begin<0 && !host)begin=f.tick;if(begin<0)return;tick=f.tick-begin;
         if(oldPlayer==null)oldPlayer=w.gg;
         if(phase==0 && tick>25) {
            phase=1;m.hud.collapse();check(m.hud.panelWidth==280 && m.hud.panelHeight==36,"collapsed native overlay occupies 280 by 36 pixels");
            m.hud.openPage("settings");m.hud.setOpacity(60);check(Math.abs(m.hud.alpha-.6)<1/255 && m.hud.windowOpacity==60,
               "window opacity applies within AIR's 8-bit alpha precision",{requested:60,actual:m.hud.alpha});
            if(!host){click("rconnect-allow-grip");click("rconnect-struggle-grip");}
            else {m.hud.openPage("peer");click("rconnect-friendly-fire");m.hud.openPage("settings");click("rconnect-pause-menus");}
         }
         if(phase==1 && tick>95) {
            phase=2;
            if(host) {
               check(session.combat.enabled && session.pause.policyMenus && !session.pause.policySats,"host UI changes friendly fire and menu policy independently of SATS");
               check(session.actors[1].personal.allowGrab && !session.actors[1].personal.struggle,"join UI preferences reach only its real authoritative player");
               check(!session.actors[0].personal.allowGrab && session.actors[0].personal.struggle,"teammate preferences do not change the host's permissions");
            }else {
               check(f.friendlyFire && f.pausePolicies.menus && !f.pausePolicies.sats,"join observes host-only policies in confirmation");
               m.hud.openPage("peer");m.ui.refresh();m.hud.refresh();
               check(!TextField(m.hud.getChildByName("rconnect-friendly-fire")).mouseEnabled,"joining UI cannot change host-only friendly fire policy");
            }
            m.hud.collapse();
            m.stage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_DOWN,true,false,0,13,0,true));
            check(m.hud.currentPage=="chat" && m.stage.focus===m.hud.tfChat,"Ctrl+Enter opens local chat without invoking native Enter action");
            check(!m.requestTimeAction(),"focused chat input cannot activate shared time control");
            var priorConsole:Boolean=w.onConsol;
            try {w.onConsol=true;check(!m.requestTimeAction(),"native console blocks shared time-control input");}
            finally {w.onConsol=priorConsole;}
            m.stage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_DOWN,true,false,119,87));
            check(!w.ctr.keyBeUp && !w.ctr.keyJump,"typing in chat does not move the game character");
            m.stage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_UP,true,false,119,87));
            m.hud.tfChat.text="中文聊天 <验证> ABC";click("rconnect-send");m.hud.collapse();
         }
         if(phase==2 && tick>165) {
            phase=3;check(seenMessage && m.hud.chatLog.text.indexOf("中文聊天 <验证> ABC")>=0,"plain-text Chinese chat reaches the other player");
            m.stage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_DOWN,true,false,0,121));
            check(!m.hud.visible,"F10 hides the overlay");
            m.stage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_UP,true,false,0,121));
            m.stage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_DOWN,true,false,0,121));
            check(m.hud.visible && m.hud.collapsed,"F10 restores the previous compact state");
            m.stage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_UP,true,false,0,121));
            SceneChecks.picture(access,"compact-hud-60pct.png");
         }
         if(!host && phase==3 && tick>230){phase=4;m.leaveSession();}
      }
   }
}

package authority.ui {
   import authority.*;
   /** UI-only port. The retained compact layout never owns game/network state. */
   public final class HudModel {
      public static const OFFLINE:String="offline",WAITING:String="waiting",HOSTING:String="hosting",JOINING:String="joining",CONNECTED:String="connected";
      public var config:Preferences,session:Object,game:Object,exploration:Object,peerGrip:Object,friendlyFire:Object,navigation:Object,securityTerminals:Object,horseshoeXP:Object;
      public var version:String,versionInfo:Object={version:"1.02"};
      private var owner:RConnectMod;
      public function HudModel(owner:RConnectMod) {
         this.owner=owner;version=RConnectMod.VERSION;config=owner.preferences;game={world:owner.access.world};
         session={mode:OFFLINE,error:"",myName:config.getValue("nickname"),hostName:"",peers:[],remotes:[],rooms:{status:""}};
         session.startHost=function():void{owner.connectAs("host");};
         session.startJoin=function():void{owner.connectAs("join");};
         session.leave=function():void{owner.leaveSession();};
         session.sendChat=function(text:String):void{owner.sendChat(text);};
         session.pause={policyMenus:false,policySats:false,paused:false,canChangePolicy:true,
            description:function():String{return "全队已暂停 · 双方关闭相关界面后继续";},
            setPolicy:function(m:Boolean,s:Boolean):void{if(owner.role=="join")return;config.setValue("pauseMenus",m?"1":"0");config.setValue("pauseSats",s?"1":"0");config.save();owner.applyPreferences();refresh();}};
         exploration={enabled:true,setEnabled:function(value:Boolean):void{config.setValue("sharedExploration",value?"1":"0");config.save();owner.applyPreferences();refresh();}};
         peerGrip={allowed:false,struggle:true,throwDamageAllowed:false,
            setPreferences:function(allow:Boolean,struggle:Boolean):void {config.setValue("allowPeerGrip",allow?"1":"0");config.setValue("peerGripStruggle",struggle?"1":"0");config.save();owner.applyPreferences();refresh();},
            setThrowDamageAllowed:function(value:Boolean):void{config.setValue("peerThrowDamage",value?"1":"0");config.save();owner.applyPreferences();refresh();}};
         friendlyFire={enabled:false,canChangePolicy:true,setEnabled:function(value:Boolean):void{if(owner.role=="join")return;config.setValue("friendlyFire",value?"1":"0");config.save();owner.applyPreferences();refresh();}};
         securityTerminals={shared:true,canChangePolicy:true,setShared:function(value:Boolean):void{if(owner.role=="join")return;config.setValue("sharedSecurityHack",value?"1":"0");config.save();owner.applyPreferences();refresh();}};
         horseshoeXP={shared:true,canChangePolicy:true,setShared:function(value:Boolean):void{if(owner.role=="join")return;config.setValue("shareHorseshoeXP",value?"1":"0");config.save();owner.applyPreferences();if(owner.host!=null)owner.host.publish();refresh();}};
         navigation={travelling:false,unavailable:function():String{return owner.meetReason();},request:function():void{owner.meetPeer();}};
      }
      public function refresh():void {
         session.mode=owner.mode;session.hostName=owner.peerName;
         var f:Object=owner.host!=null?owner.host.lastFrame:owner.replica==null?null:owner.replica.lastFrame;
         var peer:Object=f==null?null:{name:owner.peerName,snap:f.players[owner.role=="host"?1:0]};
         session.peers=owner.host!=null && owner.host.active && peer!=null?[peer]:[];
         session.remotes=owner.role=="join" && owner.welcomed && peer!=null?[peer]:[];
         exploration.enabled=config.getValue("sharedExploration")=="1";
         peerGrip.allowed=config.getValue("allowPeerGrip")=="1";peerGrip.struggle=config.getValue("peerGripStruggle")!="0";peerGrip.throwDamageAllowed=config.getValue("peerThrowDamage")=="1";
         var policy:Object=f!=null && owner.role=="join"?f.pausePolicies:null,p:Object=session.pause;
         p.policyMenus=policy==null?config.getValue("pauseMenus")=="1":policy.menus;
         p.policySats=policy==null?config.getValue("pauseSats")=="1":policy.sats;
         p.canChangePolicy=owner.role!="join";p.paused=f!=null && f.paused;
         securityTerminals.canChangePolicy=owner.role!="join";
         securityTerminals.shared=f!=null && owner.role=="join"?f.securityShared!==false:config.getValue("sharedSecurityHack")!="0";
         horseshoeXP.canChangePolicy=owner.role!="join";
         horseshoeXP.shared=f!=null && owner.role=="join"?f.horseshoeShared!==false:config.getValue("shareHorseshoeXP")!="0";
         friendlyFire.canChangePolicy=owner.role!="join";friendlyFire.enabled=f!=null && owner.role=="join"?f.friendlyFire:config.getValue("friendlyFire")=="1";
      }
   }
}

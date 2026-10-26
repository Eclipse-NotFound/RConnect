"""Prepare the B-only security overlay from the deployed field9 frozen source.
No compiler, game launch, installed file or existing frozen source is changed.
"""
from pathlib import Path
import hashlib
import json
import difflib

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
BASE=ROOT/'build/ab/b190-field9-build/src'
NATIVE=ROOT/'build/ab/native-hooks-019/verified/scripts'

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def replace(s,a,b):
    assert s.count(a)==1,(a[:100],s.count(a))
    return s.replace(a,b,1)
def product(name,changes):
    p=BASE/name;s=p.read_text(encoding='utf-8');old=s
    for a,b in changes:s=replace(s,a,b)
    out=HERE/'src'/name;out.parent.mkdir(parents=True,exist_ok=True);out.write_text(s,encoding='utf-8')
    diff=''.join(difflib.unified_diff(old.splitlines(True),s.splitlines(True),fromfile=name,tofile=name))
    (HERE/'patches').mkdir(exist_ok=True)
    (HERE/'patches'/name.replace('/','_')).with_suffix('.patch').write_text(diff,encoding='utf-8')
    return {'baseline':sha(p),'overlay':sha(out)}

manifest={}
manifest['authority/HostSession.as']=product('authority/HostSession.as',[
 ('      public var combat:FriendlyCombat;','      public var combat:FriendlyCombat;\n      public var security:SecurityTerminals;'),
 ('         combat=new FriendlyCombat(this);','         security=new SecurityTerminals(this);local.security=remote.security=security;\n         combat=new FriendlyCombat(this);'),
 ('         runtime.tactics=tactics;','         runtime.tactics=tactics;runtime.security=security;'),
 ('         scene=new SceneSnapshot(access);','         scene=new SceneSnapshot(access);scene.security=security;'),
 ('         frame.friendlyFire=combat.enabled;','         frame.friendlyFire=combat.enabled;frame.securityShared=security.shared;'),
 ('         if(combat!=null)combat.dispose();','         if(combat!=null)combat.dispose();\n         if(security!=null)security.dispose();')])
manifest['authority/PlayerActor.as']=product('authority/PlayerActor.as',[
 ('      public var grips:PeerGrabs;','      public var grips:PeerGrabs;\n      public var security:SecurityTerminals;'),
 ('               try {PlayerPointer.run(actor,input,function():void {unit.step();});}',
  '               try {\n                  var stepNative:Function=function():void {PlayerPointer.run(actor,input,function():void {unit.step();});};\n                  if(security!=null)security.player(actor,stepNative);else stepNative();\n               }')])
manifest['authority/RoomRuntime.as']=product('authority/RoomRuntime.as',[
 ('      public var tactics:TacticsBridge;','      public var tactics:TacticsBridge;\n      public var security:SecurityTerminals;'),
 ('      private function stepOwnedObject(room:Object,object:Object):void {','      private function stepOwnedObject(room:Object,object:Object):void {\n         if(security!=null && security.stepObject(room,object))return;'),
 ('public function clearDepartedRooms():void {latestByRoom=', 'public function clearDepartedRooms():void {if(security!=null)security.resetWorld();latestByRoom=')])
manifest['authority/FriendlyCombat.as']=product('authority/FriendlyCombat.as',[
 ('      private function allowed(source:Object,target:Object,nativeAllowed:Boolean,kind:String):Boolean {',
  '      private function allowed(source:Object,target:Object,nativeAllowed:Boolean,kind:String):Boolean {\n         if(session.security!=null)nativeAllowed=session.security.hit(source,target,nativeAllowed);')])
manifest['authority/SceneSnapshot.as']=product('authority/SceneSnapshot.as',[
 ('      private var access:NativeAccess,ids:Dictionary=', '      public var security:SecurityTerminals;\n      private var access:NativeAccess,ids:Dictionary='),
 ('inter:NativeFields.capture(u.inter)','inter:interaction(u.inter)'),
 ('inter:NativeFields.capture(o.inter)});','inter:interaction(o.inter)});'),
 ('      private function color(c:Object):Array', '      private function interaction(inter:Object):Object {return security==null?NativeFields.capture(inter):security.capture(inter,1);}\n      private function color(c:Object):Array')])
manifest['RConnectMod.as']=product('RConnectMod.as',[
 ('preferences.getValue("friendlyFire")].join(":")','preferences.getValue("friendlyFire"),preferences.getValue("sharedSecurityHack")].join(":")'),
 ('            if(host.combat!=null)host.combat.enabled=preferences.getValue("friendlyFire")=="1";',
  '            if(host.combat!=null)host.combat.enabled=preferences.getValue("friendlyFire")=="1";\n            if(host.security!=null)host.security.shared=preferences.getValue("sharedSecurityHack")!="0";')])
manifest['authority/ui/Preferences.as']=product('authority/ui/Preferences.as',[
 ('friendlyFire:"0",pauseMenus:"0",pauseSats:"0"','friendlyFire:"0",pauseMenus:"0",pauseSats:"0",sharedSecurityHack:"1"')])
manifest['authority/ui/HudModel.as']=product('authority/ui/HudModel.as',[
 ('peerGrip:Object,friendlyFire:Object,navigation:Object;','peerGrip:Object,friendlyFire:Object,navigation:Object,securityTerminals:Object;'),
 ('         navigation={travelling:false,', '         securityTerminals={shared:true,canChangePolicy:true,setShared:function(value:Boolean):void{if(owner.role=="join")return;config.setValue("sharedSecurityHack",value?"1":"0");config.save();owner.applyPreferences();refresh();}};\n         navigation={travelling:false,'),
 ('         friendlyFire.canChangePolicy=owner.role!="join";', '         securityTerminals.canChangePolicy=owner.role!="join";\n         securityTerminals.shared=f!=null && owner.role=="join"?f.securityShared!==false:config.getValue("sharedSecurityHack")!="0";\n         friendlyFire.canChangePolicy=owner.role!="join";')])
manifest['authority/ui/NetHud.as']=product('authority/ui/NetHud.as',[
 ('      private var opacityPercent:int=100;','      private var opacityPercent:int=100;\n      private var securityMode:TextField,securityHint:TextField;'),
 ('         versionLabel=field("rconnect-version","settings",8,352,264,38);',
  '         securityMode=field("rconnect-security","settings",8,352,264,30,true);\n         securityHint=field("rconnect-security-hint","settings",8,388,264,58);\n         action(securityMode,function():void {if(mod.securityTerminals!=null)mod.securityTerminals.setShared(!mod.securityTerminals.shared);});\n         versionLabel=field("rconnect-version","settings",8,452,264,38);'),
 ('         versionLabel.text="RConnect B · "+mod.version',
  '         securityMode.text=tr("安保终端：","Security terminals: ","Терминалы: ")+(mod.securityTerminals==null || mod.securityTerminals.shared?tr("共享破解","Shared hack","Общий взлом"):tr("分别破解","Individual hacks","Личный взлом"));\n         enabled(securityMode,mod.securityTerminals!=null && mod.securityTerminals.canChangePolicy);\n         securityHint.text=tr("由宿主设置。只影响之后的破解，已获得的炮塔安全权限保留。","Host setting. Changes affect future hacks; earned turret safety remains.","Настройка ведущего. Изменения влияют на будущий взлом; полученный доступ сохраняется.");\n         versionLabel.text="RConnect B · "+mod.version'),
 ('            if(f==versionLabel)item.renderY=Math.max(352,308+policyHeight+4)+ownerExtra+gripExtra;',
  '            var securityY:Number=Math.max(352,308+policyHeight+4)+ownerExtra+gripExtra;\n            if(f==securityMode)item.renderY=securityY;\n            if(f==securityHint){item.renderY=securityY+36;item.renderH=Math.max(58,securityHint.textHeight+6);}\n            if(f==versionLabel)item.renderY=securityY+36+Math.max(58,securityHint.textHeight+6)+6;')])

# The three complete donor sources are based on the already-patched native019.
# Root must retain non-target method bodies when importing these donors.
native_changes={
 'fe/unit/Unit.as':[
  ('      public static var rconnectHitPolicy:Function = null;',
   '      public static var rconnectHitPolicy:Function = null;\n\n      public static const RCONNECT_SECURITY_B:String = "b-security-v1";\n\n      public static var rconnectSecurityB:Function;')],
 'fe/serv/Interact.as':[
  ('      public function save(param1:Object) : *',
   '''      public function rconnectSecurityActivate() : Boolean
      {
         return this.prob == null && this.allact == "hack_robot" && Unit.rconnectSecurityB != null
            && Unit.rconnectSecurityB("terminal",this,World.w.pers.security) === true;
      }
      
      public function rconnectSecurityState(state:Object = null) : Object
      {
         if(state != null)
         {
            var changed:Boolean = this.lock != int(state.lock);
            this.lock = int(state.lock);
            this.lockAtt = int(state.lockAtt);
            this.lockHP = Number(state.lockHP);
            this.saveLock = int(state.saveLock);
            this.is_act = Boolean(state.is_act);
            this.is_ready = Boolean(state.is_ready);
            this.unlock = int(state.unlock);
            this.master = int(state.master);
            if(changed) this.update();
         }
         return {lock:this.lock,lockAtt:this.lockAtt,lockHP:this.lockHP,saveLock:this.saveLock,
            is_act:this.is_act,is_ready:this.is_ready,unlock:this.unlock,master:this.master};
      }
      
      public function save(param1:Object) : *'''),
  ('      public function allAct() : *\n      {',
   '      public function allAct() : *\n      {\n         if(this.rconnectSecurityActivate()) return;')],
 'fe/unit/UnitTurret.as':[
  ('      override public function findCel(param1:Boolean = false) : Boolean\n      {',
   '''      public function rconnectSecurityCall(op:String, arg:* = null) : *
      {
         return Unit.rconnectSecurityB == null ? null : Unit.rconnectSecurityB(op,this,arg);
      }
      
      public function rconnectSecurityState() : Object
      {
         return {sleep:this.sleep,reprog:this.reprog,absolute:this.absVis,hidden:this.hidden};
      }
      
      public function rconnectSecurityClear(blocked:Function) : void
      {
         if(priorUnit != null && blocked(priorUnit)) priorUnit = null;
         if(celUnit != null && blocked(celUnit))
         {
            celUnit = null;
            aiSpok = 0;
            aiState = this.hidden > 0 ? 0 : 1;
            aiTCh = 0;
            if(currentWeapon != null) currentWeapon.findCel = false;
         }
      }
      
      override public function findCel(param1:Boolean = false) : Boolean
      {
         var securityResult:* = this.rconnectSecurityCall("find",param1);
         if(securityResult !== null) return Boolean(securityResult);'''),
  ('      override public function control() : *\n      {',
   '      override public function control() : *\n      {\n         this.rconnectSecurityCall("step");')]
}
native_manifest={}
for name,changes in native_changes.items():
    p=NATIVE/name;old=p.read_text(encoding='utf-8');s=old
    for a,b in changes:s=replace(s,a,b)
    out=HERE/'native-source'/name;out.parent.mkdir(parents=True,exist_ok=True);out.write_text(s,encoding='utf-8')
    (HERE/'patches'/name.replace('/','_')).with_suffix('.native.patch').write_text(''.join(difflib.unified_diff(old.splitlines(True),s.splitlines(True),fromfile=name,tofile=name)),encoding='utf-8')
    native_manifest[name]={'baseline':sha(p),'overlay':sha(out)}
manifest['authority/SecurityTerminals.as']={'baseline':None,'overlay':sha(HERE/'src/authority/SecurityTerminals.as')}
(HERE/'source-manifest.json').write_text(json.dumps({'baseline':'build/ab/b190-field9-build','native_baseline':'build/ab/native-hooks-019','product':manifest,'native':native_manifest},indent=2)+'\n',encoding='utf-8')
print('Prepared B security source overlay and three native donors; no compilation or deployment.')

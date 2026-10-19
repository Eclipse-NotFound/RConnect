"""Build an isolated security-terminal candidate on the pinned A39 source.

Edits are expressed as checked, narrow integrations, so concurrent room-entry
and teleport changes can be merged without overwriting an entire shared file.
Never writes installed files, baseline sources, or another feature overlay.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'build/m52/a22-fixes-39'
OVERLAY = ROOT / 'experimental/security-terminals/src'
PIN = 'a02e5aafc2ba529d37a78c83ac92a055121b72d347d56ab8ca720802cc9ddf60'


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def integrate(name, text):
    def change(old, new, count=1):
        nonlocal text
        assert text.count(old) == count, (name, old[:100], text.count(old), count)
        text = text.replace(old, new)
    if name == 'RConnectMod.as':
        change('"0.2.22-fix39-keybinds"', '"0.2.22-fix39-security1"')
        change('      public var friendlyFire:rconnect.core.FriendlyFire;',
               '      public var securityTerminals:rconnect.core.SecurityTerminals;\n      public var friendlyFire:rconnect.core.FriendlyFire;')
        change('         this.friendlyFire = new rconnect.core.FriendlyFire(this);',
               '         this.securityTerminals = new rconnect.core.SecurityTerminals(this);\n         game.securityTerminals = this.securityTerminals;\n         this.friendlyFire = new rconnect.core.FriendlyFire(this);')
    elif name == 'rconnect/core/Config.as':
        change('         friendlyFire: "0",', '         friendlyFire: "0",\n         sharedSecurityHack: "1",')
    elif name == 'rconnect/ui/NetHud.as':
        change('      private var friendlyFire:TextField,friendlyHint:TextField;',
               '      private var friendlyFire:TextField,friendlyHint:TextField;\n      private var securityMode:TextField,securityHint:TextField;')
        change('         versionLabel=field("rconnect-version","settings",8,436,264,38);',
               '         securityMode=field("rconnect-security","settings",8,436,264,30,true);\n         securityHint=field("rconnect-security-hint","settings",8,472,264,58);\n         versionLabel=field("rconnect-version","settings",8,536,264,38);\n         action(securityMode,function():void {\n            if(mod.securityTerminals!=null)mod.securityTerminals.setShared(!mod.securityTerminals.shared);\n         });')
        change('         versionLabel.text="RConnect v"', '''         securityMode.text=tr("安保终端：","Security terminals: ","Терминалы: ")+
            (mod.securityTerminals==null || mod.securityTerminals.shared?
               tr("共享破解","Shared hack","Общий взлом"):tr("分别破解","Individual hacks","Личный взлом"));
         enabled(securityMode,mod.securityTerminals!=null && mod.securityTerminals.canChangePolicy);
         securityHint.text=mod.securityTerminals!=null && !mod.securityTerminals.supported?
            tr("需重启并加载配套游戏版本。","Restart with the matching game build.","Перезапустите совместимую сборку игры."):
            tr("由宿主设置。只影响之后的破解，已获得的炮塔安全权限保留。",
               "Host setting. Applies to future hacks; existing turret access is kept.",
               "Настройка хоста. Только для новых взломов; полученный доступ сохраняется.");
         versionLabel.text="RConnect v"''')
        change('            if(f==versionLabel)item.renderY=Math.max(352,308+policyHeight+4)+36+\n               Math.max(42,friendlyHint.textHeight+6)+6+ownerExtra+gripExtra;',
               '''            var securityY:Number=Math.max(352,308+policyHeight+4)+36+
               Math.max(42,friendlyHint.textHeight+6)+6+ownerExtra+gripExtra;
            if(f==securityMode)item.renderY=securityY;
            if(f==securityHint){item.renderY=securityY+36;item.renderH=Math.max(58,securityHint.textHeight+6);}
            if(f==versionLabel)item.renderY=securityY+36+Math.max(58,securityHint.textHeight+6)+6;''')
    elif name == 'rconnect/game/GameBridge.as':
        change('      public var playerMines:rconnect.core.PlayerMines;',
               '      public var playerMines:rconnect.core.PlayerMines;\n      public var securityTerminals:rconnect.core.SecurityTerminals;\n      private function securityInteraction(i:Object):Boolean {return securityTerminals!=null && securityTerminals.ownsInteraction(i);}\n      private function securityTurret(u:Object):Boolean {return fe.unit.RConnectSecurityAccess.turret(u);}')
        change('      public function unitKey(o:Object):String {_units.enter(loc);return _units.known(o);}',
               '      public function unitKey(o:Object):String {_units.enter(loc);return _units.known(o);}\n      public function securityUnitKey(o:Object):String {_units.enter(loc);return _units.key(o);}\n      public function securityObjectKey(o:Object):String {_objects.enter(loc);return _objects.key(o);}')
        change('                     ent.ist = ist;', '                     if(!securityInteraction(iv))ent.ist = ist;')
        change('         if(iv==null || numOr(probe(iv,"autoClose"),0)>0 || probe(b,"dead")==true)return;',
               '         if(iv==null || securityInteraction(iv) || numOr(probe(iv,"autoClose"),0)>0 || probe(b,"dead")==true)return;')
        change('            var iv:Object = probe(lb, "inter");',
               '            var iv:Object = probe(lb, "inter");\n            if(securityInteraction(iv))return;')
        change('                  var iv:Object = probe(target, "inter");',
               '                  var iv:Object = probe(target, "inter");\n                  if(securityInteraction(iv))continue;')
        change('if(b!=null) {s.runtime=NativeRoomState.scalars(b);s.inter=NativeRoomState.scalars(probe(b,"inter"));s.interNative=RConnectInteractionAccess.capture(probe(b,"inter"));}',
               'if(b!=null) {s.runtime=NativeRoomState.scalars(b);\n               if(securityInteraction(probe(b,"inter")))securityTerminals.rememberInteraction(probe(b,"inter"),String(s.k));\n               else {s.inter=NativeRoomState.scalars(probe(b,"inter"));s.interNative=RConnectInteractionAccess.capture(probe(b,"inter"));}}')
        change('if(box!=null){NativeRoomState.restore(box,os.runtime);NativeRoomState.restore(probe(box,"inter"),os.inter);RConnectInteractionAccess.restore(probe(box,"inter"),os.interNative);}',
               'if(box!=null){NativeRoomState.restore(box,os.runtime);\n               if(securityInteraction(probe(box,"inter")))securityTerminals.restoreInteraction(probe(box,"inter"),String(os.k));\n               else {NativeRoomState.restore(probe(box,"inter"),os.inter);RConnectInteractionAccess.restore(probe(box,"inter"),os.interNative);}}')
        change('Number(u.fraction)>=100||Number(u.sost)>=3', '(Number(u.fraction)>=100 && !securityTurret(u))||Number(u.sost)>=3')
        change('numOr(probe(u,"fraction"),0) >= 100)', '(numOr(probe(u,"fraction"),0) >= 100 && !securityTurret(u)))')
        change('                  fraction: numOr(probe(u, "fraction"), 0),',
               '                  fraction: numOr(probe(u, "fraction"), 0),\n                  security: securityTurret(u)?fe.unit.RConnectSecurityAccess.state(u):null,')
        change('               target["storona"] = Number(e.storona) >= 0 ? 1 : -1;',
               '               target["storona"] = Number(e.storona) >= 0 ? 1 : -1;\n               if(freezeAI && securityTurret(target) && e.security!=null)fe.unit.RConnectSecurityAccess.mirror(target,e.security,int(e.fraction));')
        change('frac < 1 || frac >= 100 || isTrigger(u)', 'frac < 1 || (frac >= 100 && !securityTurret(u)) || isTrigger(u)')
        change('if(freezeAI && numOr(e.fraction,0)>0 && numOr(e.fraction,0)<100',
               'if(freezeAI && numOr(e.fraction,0)>0 && (numOr(e.fraction,0)<100 || securityTurret(target))')
        change('            if(frac >= 100)', '            if(frac >= 100 && String(e.cls)!="fe.unit::UnitTurret")')
        change('               if(vf >= 100)', '               if(vf >= 100 && !securityTurret(v))')
        change('isSceneHitUnit(previous) || probeNum(previous,"fraction",0)>=100)',
               'isSceneHitUnit(previous) || (probeNum(previous,"fraction",0)>=100 && !securityTurret(previous)))')
        change('&& probeNum(unit,"fraction",0)<100 && !used[unit])',
               '&& (probeNum(unit,"fraction",0)<100 || securityTurret(unit)) && !used[unit])')
        change('         if(playerMines!=null)playerMines.restore(s.mines as Array,authority,foreign);',
               '         if(playerMines!=null)playerMines.restore(s.mines as Array,authority,foreign);\n         if(securityTerminals!=null)securityTerminals.worldChanged();')
    return text


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('output',type=Path)
    ap.add_argument('--compile',action='store_true')
    args=ap.parse_args()
    out=(ROOT/args.output).resolve()
    assert out.parent==ROOT/'build/m52' and not out.exists(), 'Fresh build/m52 child required'
    parent=json.loads((BASE/'prepared.json').read_text(encoding='utf-8-sig'))
    assert sha(BASE/'RConnectMod.swf')==PIN==parent['candidate_sha256']
    for name,digest in parent['source'].items():assert sha(BASE/name)==digest,name
    out.mkdir()
    source={}
    for name,digest in parent['source'].items():
        p=BASE/name;relative=Path(name).relative_to('src').as_posix()
        text=p.read_text(encoding='utf-8-sig');target=out/name;target.parent.mkdir(parents=True,exist_ok=True)
        target.write_text(integrate(relative,text),encoding='utf-8')
    for p in OVERLAY.rglob('*.as'):
        target=out/'src'/p.relative_to(OVERLAY);target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,target)
    shutil.copytree(BASE/'tools/stubs',out/'tools/stubs')
    shutil.copyfile(BASE/'tools/build_mod.py',out/'tools/build_mod.py')
    for p in (out/'src').rglob('*'):
        if p.is_file():source[p.relative_to(out).as_posix()]=sha(p)
    receipt=dict(kind='security-terminals',base=str(BASE),base_sha256=PIN,source=source,
                 integration_sha256=sha(__file__),installed_modified=False,compiled=False)
    (out/'prepared.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
    if args.compile:
        sys.path.insert(0,str(ROOT/'tools/host_authority'))
        from common import JAVA,SDK
        with (out/'compile.log').open('w',encoding='utf-8') as log:
            subprocess.run([sys.executable,'-B','-X','utf8',str(out/'tools/build_mod.py'),'--java',str(JAVA),
                '--amxmlc',str(SDK/'bin/amxmlc.bat'),'--output',str(out/'RConnectMod.swf')],stdout=log,stderr=subprocess.STDOUT,check=True)
        receipt.update(compiled=True,sha256=sha(out/'RConnectMod.swf'))
        (out/'prepared.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
    print(json.dumps({k:v for k,v in receipt.items() if k!='source'}))


if __name__=='__main__':main()

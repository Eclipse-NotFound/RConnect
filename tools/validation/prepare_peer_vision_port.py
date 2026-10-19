"""Freeze a separate Q-permission overlay against exact fix39, never root/src."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

ROOT=Path(__file__).resolve().parents[2]

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def edit(path,before,after):
    text=path.read_text(encoding='utf-8-sig')
    assert text.count(before)==1,(path,before)
    path.write_text(text.replace(before,after),encoding='utf-8')

def main():
    ap=argparse.ArgumentParser();ap.add_argument('output');args=ap.parse_args()
    base=ROOT/'build/m52/a22-fixes-39';out=(ROOT/args.output).resolve()
    assert out.parent==ROOT/'build/m52' and not out.exists()
    assert sha(base/'prepared.json')=='ccb9401c418c75a9d014c52187abbcca84eabf0a32b44a198056f7fc7f26fbab'
    m=json.loads((base/'prepared.json').read_text())
    for name,h in {**m['source'],**m['inputs']}.items():assert sha(base/name)==h,name
    out.mkdir()
    shutil.copytree(base/'src',out/'src');shutil.copytree(base/'tools/stubs',out/'tools/stubs')
    shutil.copy2(base/'tools/build_mod.py',out/'tools/build_mod.py')
    for p in (ROOT/'experimental/peer-vision-port/src').rglob('*.as'):
        dest=out/'src'/p.relative_to(ROOT/'experimental/peer-vision-port/src')
        dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,dest)
    edit(out/'src/RConnectMod.as','"0.2.22-fix39-keybinds"','"0.2.22-peerport1-keybinds"')
    edit(out/'src/RConnectMod.as','public var playerMines:', 'public var peerVisionTeleport:rconnect.core.PeerVisionTeleport;\n      public var playerMines:')
    edit(out/'src/RConnectMod.as','this.playerMines = new', 'this.peerVisionTeleport = new rconnect.core.PeerVisionTeleport(this);\n         this.playerMines = new')
    edit(out/'src/rconnect/core/Config.as','friendlyFire: "0",','friendlyFire: "0",\n         peerVisionTeleport: "0",')
    hud=out/'src/rconnect/ui/NetHud.as'
    edit(hud,'private var friendlyFire:TextField,','private var peerPort:TextField;\n      private var friendlyFire:TextField,')
    edit(hud,'peerHint=field("rconnect-peer-hint","peer",8,115,264,72);',
        'peerPort=field("rconnect-peer-port","peer",8,115,264,28,true);\n'
        '         peerHint=field("rconnect-peer-hint","peer",8,147,264,96);\n'
        '         action(peerPort,function():void {\n'
        '            if(mod.peerVisionTeleport!=null)mod.peerVisionTeleport.setEnabled(!mod.peerVisionTeleport.enabled);\n'
        '         });')
    edit(hud,'peerHint.text=RCLocale.text("关闭后保留已收到的区域");',
        'peerPort.text=tr("Q 可用队友视野","Q: teammate sight","Q: обзор напарника")+": "+\n'
        '            RCLocale.text(mod.peerVisionTeleport!=null && mod.peerVisionTeleport.enabled?"开":"关");\n'
        '         enabled(peerPort,mod.peerVisionTeleport!=null && mod.peerVisionTeleport.canChangePolicy);\n'
        '         peerHint.text=tr("Q 传送由宿主设置。仅限同房队友当前可见区域；仍需原版技能、蓄力和魔力。",\n'
        '            "Host sets Q teleport. Uses current teammate sight in this room; native skill, charge and mana still apply.",\n'
        '            "Q настраивает ведущий. Только текущий обзор напарника в комнате; нужны навык, заряд и мана.");')
    edit(out/'tools/stubs/fe/unit/UnitPlayer.as','internal function actTele()',
        'internal var lurked:Boolean;\ninternal function actPort():* {}\ninternal function actTele()')
    (out/'tools/stubs/fe/inter/GUI.as').write_text('package fe.inter { public class GUI { internal function showPortCel():* {} } }',encoding='utf-8')
    edit(out/'tools/build_mod.py',',fe.inter.PipPage,',',fe.inter.GUI,fe.inter.PipPage,')
    # Freeze these exact integration seams alongside the hand-maintained helper
    # files for review; no live experimental/a22-fixes source is consumed.
    source={p.relative_to(out).as_posix():sha(p) for p in (out/'src').rglob('*.as')}
    inputs={p.relative_to(out).as_posix():sha(p) for p in (out/'tools').rglob('*') if p.is_file()}
    receipt=dict(kind='isolated-peer-vision-port',base='build/m52/a22-fixes-39',base_prepared_sha256=sha(base/'prepared.json'),
        source=source,inputs=inputs,changed={n:h for n,h in source.items() if m['source'].get(n)!=h},
        version='0.2.22-peerport1-keybinds',native_changes=False,script_sha256=sha(Path(__file__)))
    (out/'source.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2),encoding='utf-8')
    print(out)

if __name__=='__main__':main()

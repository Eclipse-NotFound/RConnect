"""Build menu shortcuts on the frozen, installed A22 fix15 source lineage."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import sys

MOD = Path(__file__).resolve().parents[2]
GAME = MOD.parents[1]
BASE = MOD / 'build/m52/a22-fixes-15'
OUT = MOD / 'build/keybind-output'
JAVA = Path(r'D:\Program Files\Adobe Animate 2024\jre\bin\java.exe')
SDK = GAME / 'mods/Sandevistan/build/tools/flexsdk'
PIN = '07b76ed8082462c43eae7048af041370fe315a5b6b23ccdf4e600e02ecd443a4'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def integrate(text):
    def change(old, new):
        nonlocal text
        assert text.count(old) == 1, f'Expected unique anchor: {old[:90]}'
        text = text.replace(old, new)
    change('      private var disposed:Boolean=false;',
           '      private var disposed:Boolean=false;\n      private var keybinds:NetKeybinds=new NetKeybinds(),shortcutHeld:Object={};')
    change('      public function refresh():void {\n         if(disposed)return;',
           '      public function refresh():void {\n         if(disposed)return;\n         keybinds.tick();')
    change('         footer.text=tr("Ctrl+Enter 聊天 · F10","Ctrl+Enter: chat · F10","Ctrl+Enter: чат · F10");',
           '         footer.text=keybinds.label("chat")+tr(" 聊天 · "," Chat · "," Чат · ")+keybinds.label("panel");')
    change('         if(_pauseBanner!=null) {',
           '         helpText.text=helpText.text.split("Ctrl+Enter").join(keybinds.label("chat")).split("F10").join(keybinds.label("panel"));\n         if(_pauseBanner!=null) {')
    change('      private function cancelDrag(e:Event):void {',
           '      private function cancelDrag(e:Event):void {\n         shortcutHeld={};')
    change('      private function keyDown(e:KeyboardEvent):void {',
           '      private function keyDown(e:KeyboardEvent):void {\n         if(keybinds.capturing())return;\n         if(shortcutHeld[e.keyCode]){e.stopImmediatePropagation();return;}')
    change('         if(e.keyCode==121) {',
           '         if(keybinds.matches("panel",e)) {\n            shortcutHeld[e.keyCode]=true;')
    change('         if(e.keyCode==13 && e.ctrlKey && !nativeBusy() && !(surface.focus is TextField && TextField(surface.focus).type==TextFieldType.INPUT)) {',
           '         if(keybinds.matches("chat",e) && !nativeBusy() && !(surface.focus is TextField && TextField(surface.focus).type==TextFieldType.INPUT)) {\n            shortcutHeld[e.keyCode]=true;')
    change('      private function keyUp(e:KeyboardEvent):void {',
           '      private function keyUp(e:KeyboardEvent):void {\n         delete shortcutHeld[e.keyCode];')
    return text


def main():
    prepared = json.loads((BASE / 'prepared.json').read_text(encoding='utf-8-sig'))
    assert prepared['candidate_sha256'] == PIN and digest(BASE/'RConnectMod.swf') == PIN
    sources = {}
    for rel, expected in prepared['source'].items():
        source = BASE / rel
        assert digest(source) == expected, f'Frozen source changed: {rel}'
        dest = OUT / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, dest)
        sources[rel] = expected
    for source in (BASE/'tools/stubs').rglob('*'):
        if source.is_file():
            dest = OUT / source.relative_to(BASE)
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, dest)
    (OUT/'tools').mkdir(parents=True, exist_ok=True)
    shutil.copy2(BASE/'tools/build_mod.py', OUT/'tools/build_mod.py')
    hud = OUT / 'src/rconnect/ui/NetHud.as'
    hud.write_text(integrate(hud.read_text(encoding='utf-8-sig')), encoding='utf-8')
    shutil.copy2(MOD/'src/rconnect/ui/NetKeybinds.as', OUT/'src/rconnect/ui/NetKeybinds.as')
    entry = OUT/'src/RConnectMod.as'
    text = entry.read_text(encoding='utf-8-sig')
    assert text.count('"0.2.22-fix15"') == 1
    entry.write_text(text.replace('"0.2.22-fix15"','"0.2.22-fix15-keybinds"'), encoding='utf-8')
    binary = OUT / 'candidate/RConnectMod.swf'
    subprocess.run([sys.executable,'-B','-X','utf8',str(OUT/'tools/build_mod.py'),
                    '--java',str(JAVA),'--amxmlc',str(SDK/'bin/amxmlc.bat'),
                    '--output',str(binary)],check=True)
    receipt = {'version':'0.2.22-fix15-keybinds','production_baseline_sha256':PIN,
               'baseline_source':sources,
               'source':{str(p.relative_to(OUT)).replace('\\','/'):digest(p) for p in (OUT/'src').rglob('*') if p.is_file()},
               'binary':str(binary),'bytes':binary.stat().st_size,
               'sha256':digest(binary),'experimental_a22_included':False,
               'authority_B_included':False,'release_modified':False}
    (OUT/'candidate.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({k:v for k,v in receipt.items() if k!='baseline_source'},ensure_ascii=False,indent=2))


if __name__ == '__main__':
    main()

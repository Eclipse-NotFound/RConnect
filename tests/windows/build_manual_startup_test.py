"""Freeze the installed M43 source plus only the manual-startup change."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'build/launcher/manual-candidate'
SRC = OUT / 'src'
JAVA = Path('C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe')
SDK = Path('D:/RemainsMod/mods/Sandevistan/build/tools/flexsdk')

if SRC.exists():
    raise SystemExit('Frozen source already exists; choose a new output before rebuilding')
shutil.copytree(ROOT / 'build/m43/final2/src', SRC)
shutil.copy2(ROOT / 'src/rconnect/core/ManualStartup.as', SRC / 'rconnect/core/ManualStartup.as')
entry = SRC / 'RConnectMod.as'
text = entry.read_text(encoding='utf-8-sig')
text = text.replace('import rconnect.core.RoomDiagnostics;', 'import rconnect.core.RoomDiagnostics;\n   import rconnect.core.ManualStartup;')
text = text.replace('this.roomDiagnostics = new RoomDiagnostics(this);', 'this.roomDiagnostics = new RoomDiagnostics(this);\n         new ManualStartup(this);')
entry.write_text(text, encoding='utf-8')
env = dict(os.environ, AIR_HOME=str(SDK))
compiler = [str(JAVA), '-Xmx384m', '-jar', str(SDK / 'lib/mxmlc.jar'), '+configname=air',
            '+flexlib=' + str(SDK / 'frameworks'), '-swf-version=38', '-debug=false', '-optimize=true']
subprocess.run(compiler + ['-source-path=' + str(SRC), '-external-library-path+=' + str(ROOT / 'build/GameCombatStubs.swc'),
                           '-output=' + str(OUT / 'RConnectMod.swf'), str(SRC / 'RConnectDoc.as')], env=env, check=True)
subprocess.run(compiler + ['-source-path=' + str(ROOT / 'tests'), '-output=' + str(OUT / 'EffectsDriver.swf'),
                           str(ROOT / 'tests/ManualStartupTestDoc.as')], env=env, check=True)
subprocess.run(compiler + ['-source-path=' + str(ROOT / 'tests/harness'), '-output=' + str(OUT / 'EffectsHarness.swf'),
                           str(ROOT / 'tests/harness/RConnectDoc.as')], env=env, check=True)
(OUT / 'inputs.json').write_text(json.dumps({str(p.relative_to(OUT)): hashlib.sha256(p.read_bytes()).hexdigest()
                                           for p in OUT.rglob('*') if p.is_file()}, indent=2), encoding='utf-8')
print('BUILT ' + str(OUT))

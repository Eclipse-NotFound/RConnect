"""Compile the isolated FA B bridge; root agent owns test registration and deployment."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import xml.etree.ElementTree as ET

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
GAME = ROOT.parents[1]
SDK = GAME / 'mods/Sandevistan/build/tools/flexsdk'
JAVA = Path('D:/Program Files/Adobe Animate 2024/jre/bin/java.exe')


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    out = (ROOT / args.output).resolve()
    if out.parent != (ROOT / 'build/ab').resolve() or not out.name.startswith('fa-b-') or out.exists():
        raise ValueError('Use a new build/ab/fa-b-* output directory')
    out.mkdir()
    for folder in ('src', 'data', 'build/stubs'):
        shutil.copytree(HERE / folder, out / folder)
    shutil.copy2(HERE / 'upstream.json', out / 'upstream.json')
    cfg = out / 'compiler-config.xml'
    cfg.write_text(f'''<flex-config><target-player>30.0</target-player><swf-version>38</swf-version>
<compiler><external-library-path><path-element>{SDK.as_posix()}/frameworks/libs/air/airglobal.swc</path-element></external-library-path>
<library-path><path-element>{SDK.as_posix()}/frameworks/libs/framework.swc</path-element></library-path>
<debug>false</debug><optimize>true</optimize><strict>true</strict></compiler><use-network>false</use-network>
<default-frame-rate>30</default-frame-rate><default-size><width>1280</width><height>800</height></default-size></flex-config>''', encoding='utf-8')
    commands = []
    for jar, extra in (
        ('compc.jar', [f'-source-path={out}/build/stubs', '-include-classes=fe.weapon.Weapon,fe.World,fe.unit.UnitPlayer,fe.inter.PipPage', f'-output={out}/stubs.swc']),
        ('mxmlc.jar', [f'-source-path={out}/src', f'-external-library-path+={out}/stubs.swc', '-includes=fe.weapon.FAWeaponBridge,fe.FAWorldBridge,fe.unit.FAPlayerBridge', f'-link-report={out}/link-report.xml', f'-output={out}/FirearmAttachmentsMod.swf', str(out / 'src/FADocument.as')]),
    ):
        command = [str(JAVA), '-Duser.language=en', '-Duser.country=US', '-Xmx512m', '-XX:+UseSerialGC', f'-Dflexlib={SDK}/frameworks', '-jar', str(SDK / 'lib' / jar), f'-load-config={cfg}', *extra]
        commands.append(command)
        with (out / (jar + '.log')).open('x', encoding='utf-8') as log:
            subprocess.run(command, cwd=out, env=dict(os.environ, AIR_HOME=str(SDK), JAVA_HOME=str(JAVA.parent.parent)), stdout=log, stderr=subprocess.STDOUT, check=True)
    definitions = {n.attrib.get('id') for n in ET.parse(out / 'link-report.xml').getroot().findall('.//script/def')}
    if definitions & {'fe:World', 'fe.weapon:Weapon', 'fe.unit:UnitPlayer', 'fe.inter:PipPage'}:
        raise ValueError('Native stub classes were embedded')
    files = {p.relative_to(out).as_posix(): sha(p) for folder in ('src', 'data', 'build/stubs') for p in (out / folder).rglob('*') if p.is_file()}
    (out / 'build-input.json').write_text(json.dumps(dict(version='0.3.5-b1', tested=False, deployed=False,
        candidate_sha256=sha(out / 'FirearmAttachmentsMod.swf'), source_files=files, upstream_sha256=sha(out / 'upstream.json'),
        script_sha256=sha(Path(__file__)), commands=commands), indent=2)+'\n', encoding='utf-8')
    print(out)


if __name__ == '__main__':
    main()

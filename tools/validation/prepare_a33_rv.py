"""Freeze the installed RV lineage plus the authorized wall comparison change."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parents[2]
RV = ROOT.parent / 'RealisticVision'
GAME = ROOT.parents[1]
sys.path.insert(0, str(ROOT / 'tools/host_authority'))
from common import JAVA, SDK

BASE = RV / 'build/wall-options-output/candidate'
BASE_SHA = 'baa48289d9cf86f64cff53b4734032ad29c89c3ac1704db2d89038d4b8db4275'
WALL_SHA = 'd5142d3d9d9885b804628cf7ac12c4fa9320c48c33dd62bf1101759dc8a2b7fd'
VERSION = 'v0.31.2-wall-cache-candidate'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def compile_as(entry, output, sources, external):
    output.parent.mkdir(parents=True, exist_ok=True)
    paths = lambda names: ''.join('<path-element>'+escape(str(p))+'</path-element>' for p in names)
    config = output.with_suffix('.compiler.xml')
    config.write_text('<flex-config><compiler><external-library-path>'+paths(external)+
        '</external-library-path><source-path>'+paths(sources)+
        '</source-path><debug>false</debug><optimize>true</optimize><omit-trace-statements>false</omit-trace-statements><theme/>'+
        '</compiler><target-player>32.0</target-player><swf-version>32</swf-version><use-network>false</use-network>'+
        '<static-link-runtime-shared-libraries>true</static-link-runtime-shared-libraries></flex-config>', encoding='utf-8')
    result = subprocess.run([str(JAVA), '-Dfile.encoding=UTF-8', '-jar', str(SDK/'lib/mxmlc.jar'),
        '+flexlib='+str(SDK/'frameworks'), '-load-config='+str(config), '-output='+str(output), str(entry)],
        capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=90)
    output.with_suffix('.compile.log').write_text(result.stdout+result.stderr, encoding='utf-8')
    if result.returncode:
        raise RuntimeError(result.stdout+result.stderr)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    out = (ROOT/args.output).resolve()
    assert out.parent == ROOT/'build/m52' and not out.exists()
    assert sha(BASE/'RealisticVisionMod.swf') == sha(RV/'release/RealisticVisionMod.swf') == BASE_SHA
    assert sha(BASE/'src/RVWallSurface.as') == WALL_SHA
    original = {p.relative_to(BASE).as_posix(): sha(p) for p in (BASE/'src').rglob('*') if p.is_file()}
    out.mkdir()
    shutil.copytree(BASE/'src', out/'src')
    shutil.copyfile(BASE/'RealisticVisionMod.swf', out/'control.swf')
    shutil.copyfile(RV/'src/RVWallSurface.as', out/'src/RVWallSurface.as')
    main = out/'src/RealisticVisionMod.as'
    text = main.read_text(encoding='utf-8-sig')
    old = 'v0.31.1-wall-options-candidate'
    assert text.count(old) == 1
    main.write_text(text.replace(old, VERSION), encoding='utf-8')
    shutil.copyfile(RV/'build/GameStubs.swc', out/'GameStubs.swc')
    air = GAME/'mods/Sandevistan/build/tools/airsdk/frameworks/libs/air/airglobal.swc'
    compile_as(main, out/'RealisticVisionMod.swf', [out/'src'], [air, out/'GameStubs.swc'])
    checks = out/'checks/src'
    checks.mkdir(parents=True)
    for name, source in [('RVWallSurface',out/'src/RVWallSurface.as'),
                         ('BaselineWallSurface',BASE/'src/RVWallSurface.as')]:
        text = source.read_text(encoding='utf-8-sig').replace('RVWallSurface',name)
        (checks/(name+'.as')).write_text(re.sub(r'\bprivate\b','public',text), encoding='utf-8')
    shutil.copyfile(ROOT/'tests/rv/WallComparisonChecks.as', checks/'WallComparisonChecks.as')
    shutil.copyfile(RV/'build/wall-options/BoundaryChecks.as', checks/'BoundaryChecks.as')
    for entry in ('WallComparisonChecks','BoundaryChecks'):
        compile_as(checks/(entry+'.as'), out/'checks'/(entry+'.swf'), [checks], [air])
    source = {p.relative_to(out).as_posix():sha(p) for p in (out/'src').rglob('*') if p.is_file()}
    changed = sorted(n for n in original if source[n] != original[n])
    assert changed == ['src/RVWallSurface.as','src/RealisticVisionMod.as'], changed
    assert {p.relative_to(BASE).as_posix():sha(p) for p in (BASE/'src').rglob('*') if p.is_file()} == original
    assert sha(RV/'release/RealisticVisionMod.swf') == BASE_SHA
    inputs = {p.relative_to(out).as_posix():sha(p) for p in checks.rglob('*') if p.is_file()}
    inputs['GameStubs.swc'] = sha(out/'GameStubs.swc')
    manifest = dict(kind='isolated-rv-wall-comparison', version=VERSION, installed=False,
        baseline_sha256=BASE_SHA, candidate_sha256=sha(out/'RealisticVisionMod.swf'),
        parent_source=original, source=source, changed=changed, inputs=inputs,
        preparer_sha256=sha(__file__), tests={p.name:sha(p) for p in (out/'checks').glob('*.swf')})
    (out/'prepared.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({k:manifest[k] for k in ('version','candidate_sha256','changed')},ensure_ascii=False))


if __name__ == '__main__':
    main()

"""Preserve the installed shortcut client while merging frozen A22 motion fixes.

This only builds a new isolated candidate. It never installs binaries or edits
the shortcut owner's sources. Both input source trees are checked completely.
"""
import argparse
import json
from pathlib import Path
import subprocess
import sys

from prepare_a22_fixes import ROOT, JAVA, SDK, sha, put
from build_keybinds import integrate

UI_VERSION = '0.2.22-fix15-keybinds'
UI_SHA = 'b2ed7f3a9b1d176dffb2b912d69da8084982906ff71d6fba8367bd36514e84f8'
UI_FILES = {'src/rconnect/ui/NetHud.as', 'src/rconnect/ui/NetKeybinds.as'}


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def verify_ui_deployment(path, baseline_hash):
    record = read(path)
    assert record['status'] == 'installed-and-verified', 'Shortcut deployment is not verified yet'
    clients = [r for r in record['clients'] if r['mod'] == 'RConnect']
    assert len(clients) == 1
    client = clients[0]
    assert client['after'].lower() == UI_SHA and client['before'].lower() == baseline_hash
    assert Path(client['target']).resolve() == ROOT/'release/RConnectMod.swf'
    assert record['authorization'], 'Missing recorded authorization'


def verify_ui(base, ui):
    bm, km = read(base/'prepared.json'), read(ui/'candidate.json')
    assert km['version'] == UI_VERSION and km['sha256'] == UI_SHA
    assert km['production_baseline_sha256'] == bm['candidate_sha256']
    assert km['baseline_source'] == bm['source']
    assert sha(ui/'candidate/RConnectMod.swf') == UI_SHA
    expected = set(bm['source']) | {'src/rconnect/ui/NetKeybinds.as'}
    names = {p.relative_to(ui).as_posix() for p in (ui/'src').rglob('*.as')}
    assert names == expected, 'Unexpected shortcut source inventory'
    for name, digest in bm['source'].items():
        assert sha(base/name) == digest
        if name == 'src/RConnectMod.as':
            assert (ui/name).read_text(encoding='utf-8-sig') == (
                base/name).read_text(encoding='utf-8-sig').replace('"'+bm['version']+'"', '"'+UI_VERSION+'"')
        elif name == 'src/rconnect/ui/NetHud.as':
            assert (ui/name).read_text(encoding='utf-8-sig') == integrate((base/name).read_text(encoding='utf-8-sig'))
        else:
            assert sha(ui/name) == digest, 'Shortcut candidate changed unrelated source: '+name
    return {name: sha(ui/name) for name in sorted(names)}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('output')
    ap.add_argument('--ui-deployment', required=True, type=Path)
    args = ap.parse_args()
    out = (ROOT/args.output).resolve()
    assert out.parent == ROOT/'build/m52' and not out.exists()
    base, motion, ui = [ROOT/p for p in ('build/m52/a22-fixes-15', 'build/m52/a22-fixes-24', 'build/keybind-output')]
    bm, m = read(base/'prepared.json'), read(motion/'prepared.json')
    ui_sources = verify_ui(base, ui)
    deployment = args.ui_deployment.resolve()
    assert deployment.is_file() and deployment.is_relative_to(ROOT.parents[1]/'mods/ModLoader')
    verify_ui_deployment(deployment, bm['candidate_sha256'])
    assert sha(ROOT/'release/RConnectMod.swf') == UI_SHA, 'Shortcut client is not installed'
    assert sha(ROOT.parents[1]/'pfe.swf') == m['candidate_game_sha256'], 'Native game changed'
    for name, digest in {**m['source'], **m['inputs']}.items():
        assert sha(motion/name) == digest, 'Motion input changed: '+name
    assert sha(motion/'RConnectMod.swf') == m['candidate_sha256']
    assert m['control_sha256'] == bm['candidate_sha256']
    for name in m['source']:
        put(out/name, (motion/name).read_bytes())
    for name in UI_FILES:
        put(out/name, (ui/name).read_bytes())
    entry = out/'src/RConnectMod.as'
    text = entry.read_text(encoding='utf-8-sig')
    version = '0.2.22-fix25-keybinds'
    assert text.count('"'+m['version']+'"') == 1
    entry.write_text(text.replace('"'+m['version']+'"', '"'+version+'"'), encoding='utf-8')
    for name in m['inputs']:
        if name.startswith('tools/stubs/'):
            put(out/name, (motion/name).read_bytes())
    for path in (ROOT/'tests').rglob('*'):
        if path.is_file():
            put(out/path.relative_to(ROOT), path.read_bytes())
    for name in ('tools/build_mod.py', 'tools/build_effects_driver.py'):
        put(out/name, (ROOT/name).read_bytes())
    put(out/'control.swf', (ui/'candidate/RConnectMod.swf').read_bytes())
    put(out/'native/pfe.swf', (motion/'native/pfe.swf').read_bytes())
    put(out/'evidence/keybind-candidate.json', (ui/'candidate.json').read_bytes())
    put(out/'evidence/keybind-deployment.json', deployment.read_bytes())
    with (out/'build.log').open('w', encoding='utf-8') as stream:
        subprocess.run([sys.executable, '-B', '-X', 'utf8', str(out/'tools/build_mod.py'),
                        '--java', str(JAVA), '--amxmlc', str(SDK/'bin/amxmlc.bat'),
                        '--output', str(out/'RConnectMod.swf')], cwd=ROOT,
                       stdout=stream, stderr=subprocess.STDOUT, check=True)
    assert ui_sources == verify_ui(base, ui), 'Shortcut source changed during build'
    assert sha(ROOT/'release/RConnectMod.swf') == UI_SHA
    assert sha(ROOT.parents[1]/'pfe.swf') == m['candidate_game_sha256']
    m.update(version=version, candidate_sha256=sha(out/'RConnectMod.swf'),
             control_sha256=UI_SHA, control_version=UI_VERSION,
             base_prepared_sha256=sha(motion/'prepared.json'), script_sha256=sha(Path(__file__)),
             source={p.relative_to(out).as_posix():sha(p) for p in (out/'src').rglob('*.as')},
             inputs={p.relative_to(out).as_posix():sha(p) for d in ('tools','tests') for p in (out/d).rglob('*') if p.is_file()},
             keybind_merge=dict(motion_base=motion.relative_to(ROOT).as_posix(), motion_prepared_sha256=sha(motion/'prepared.json'),
                                ui_source=ui_sources, ui_candidate_sha256=sha(out/'evidence/keybind-candidate.json'),
                                deployment_path=str(deployment), deployment_sha256=sha(out/'evidence/keybind-deployment.json'),
                                recipe_sha256=sha(ROOT/'tools/validation/build_keybinds.py')))
    (out/'prepared.json').write_text(json.dumps(m, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps(dict(version=version, sha256=m['candidate_sha256'], control=m['control_sha256'],
                          preserved_ui=sorted(UI_FILES), installation_modified=False)))


if __name__ == '__main__':
    main()

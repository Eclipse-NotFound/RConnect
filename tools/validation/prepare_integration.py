"""Prepare new core candidates after the independent compact HUD release."""
import argparse, ast, datetime, json, re, shutil
from pathlib import Path
from validation_baseline import ROOT, GAME, LEGACY, AFTER_UI, UI_SHA, sha, read, verify_protected
from run_final_regressions import REQUIRED

def copy_new(src, dst):
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.exists():
        assert dst.read_bytes() == src.read_bytes(), str(dst)
    else:
        shutil.copy2(src, dst)

ap = argparse.ArgumentParser()
ap.add_argument('mode', choices=['baseline', 'freeze', 'built'])
ap.add_argument('snapshot', nargs='?', default='build/m46/final-after-ui-01')
a = ap.parse_args()

if a.mode == 'baseline':
    out = ROOT / AFTER_UI
    ui = ROOT / 'build/ui-20261006/stable-ui-07'
    receipt = read(ui / 'deployment.json')
    assert receipt['status'] == 'deployed-smoke-passed'
    assert sha(ROOT / 'release/RConnectMod.swf') == receipt['sha256'] == UI_SHA
    old = read(ROOT / LEGACY / 'inputs.json')
    protected = dict(old['protected'])
    for name, digest in protected.items():
        if name.lower() == 'mods/rconnect/release/rconnectmod.swf':
            digest = UI_SHA
            protected[name] = digest
        assert sha(GAME / name) == digest, name
    out.mkdir(parents=True, exist_ok=False)
    copy_new(ROOT / 'release/RConnectMod.swf', out / 'RConnectMod.swf')
    copy_new(ui / 'input.json', out / 'ui-source-input.json')
    data = {'at': datetime.datetime.now().astimezone().isoformat(),
            'version': '0.2.17-dev', 'next_core_version': '0.2.18-dev',
            'release_sha256': UI_SHA, 'protected': protected,
            'release_source_manifest': 'build/ui-20261006/stable-ui-07/input.json',
            'release_source_manifest_sha256': sha(ui / 'input.json'),
            'deployment_receipt_sha256': sha(ui / 'deployment.json'),
            'normal_smoke_run': receipt['smoke']['run'],
            'retained_legacy_baseline': LEGACY,
            'retained_legacy_inputs_sha256': sha(ROOT / LEGACY / 'inputs.json')}
    (out / 'inputs.json').write_text(json.dumps(data, indent=2), encoding='utf-8')
    print(json.dumps({'baseline': AFTER_UI, 'sha256': UI_SHA, 'protected': len(protected)}))
else:
    out = (ROOT / a.snapshot).resolve()
    assert out.parent == ROOT / 'build/m46' and out.name.startswith('final'), out
    if a.mode == 'freeze':
        baseline = ROOT / AFTER_UI / 'inputs.json'
        version = re.search(r'VERSION:String\s*=\s*"([^"]+)"',
                            (ROOT / 'src/RConnectMod.as').read_text(encoding='utf-8-sig')).group(1)
        assert version == '0.2.18-dev'
        m = {'version': version, 'baseline_path': AFTER_UI,
             'baseline_inputs_sha256': sha(baseline), 'required_entries': REQUIRED + ['HudTestDoc']}
        verify_protected(m)
        out.mkdir(parents=True, exist_ok=False)
        sources = {}
        for p in sorted((ROOT / 'src').rglob('*')):
            if p.is_file():
                name = p.relative_to(ROOT).as_posix()
                copy_new(p, out / name); sources[name] = sha(p)
        paths = sorted((ROOT / 'tests').rglob('*.as')) + sorted((ROOT / 'tools/stubs').rglob('*.as'))
        paths += [ROOT / 'tools' / n for n in ('build_mod.py', 'build_effects_driver.py',
                  'run_coop_regression.py', 'RConnect.Process.ps1', 'keep_test_responsive.ps1', 'verify_mask_png.py')]
        paths += sorted((ROOT / 'tools/validation').glob('*.py'))
        profiles = {}
        for role, expected in [('host', '9c5b3eea2f9480b208c546750e26e0da828932b50048acace14cf39e4970ccc2'),
                               ('join', 'e17dda5168a40509f4ccc430806ceb0a2cab9acc8500ffb9c772b008a2601c3f')]:
            p = ROOT / 'build/grip-20261005/profiles' / (role + '-PFEgame0.sol')
            assert sha(p) == expected, role + ' paired template changed'
            frozen = out / 'profiles' / p.name; copy_new(p, frozen); paths.append(frozen)
            profiles[role] = {'path': frozen.relative_to(ROOT).as_posix(), 'sha256': expected}
        tests = {}
        for p in paths:
            name = p.relative_to(ROOT).as_posix()
            copy_new(p, out / 'verified-files' / name); tests[name] = sha(p)
            if p.suffix == '.py': ast.parse(p.read_text(encoding='utf-8-sig'))
        m.update(source=sources, profiles=profiles)
        (out / 'source-input.json').write_text(json.dumps(m, indent=2), encoding='utf-8')
        (out / 'verified-test-input.json').write_text(json.dumps(tests, indent=2), encoding='utf-8')
        print(json.dumps({'sources': len(sources), 'verification': len(tests), 'version': version,
                          'required': len(m['required_entries']), 'baseline': AFTER_UI}))
    else:
        p = out / 'source-input.json'; m = read(p)
        verify_protected(m)
        for name, digest in m['source'].items(): assert sha(ROOT / name) == sha(out / name) == digest, name
        m.update(candidate_sha256=sha(out / 'RConnectMod.swf'), size=(out / 'RConnectMod.swf').stat().st_size)
        p.write_text(json.dumps(m, indent=2), encoding='utf-8')
        print(json.dumps({k: v for k, v in m.items() if k not in ('source', 'profiles')}))

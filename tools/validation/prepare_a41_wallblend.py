"""Rebase the two approved comparison caches onto the exact CS 0.7 WallBlend."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil

from prepare_a40_wallblend import optimized, replace_once
from prepare_a33_rv import compile_as

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT.parents[1]
CS = GAME / 'mods/ContinuousScene'
UPSTREAM = CS / 'build/generated/wb-production'
BASE_SHA = 'df9aa07265e2538e115a5f048d272b85fc1c34d00ec4bc81585cd40d96648f76'
MANIFEST_SHA = '16930126a306c55e5c16725537e2941c5d4c4a7167cacd720d4fe310775b843a'
BASE_VERSION = '0.5.6-scene'
VERSION = '0.5.7-scene'
LAYERS = ('BackgroundBlendLayer.as', 'BlendLayer.as')
CHANGED = ['WallBlendMod.as', 'wallblend/BackgroundBlendLayer.as', 'wallblend/BlendLayer.as']


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def save(path, value):
    Path(path).write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding='utf-8')


def files(folder, pattern='*.as'):
    return {p.relative_to(folder).as_posix(): sha(p) for p in sorted(folder.rglob(pattern))}


def freeze(out):
    assert not out.exists(), 'Preserve every prior preparation and result'
    manifest_path = UPSTREAM / 'source-manifest.json'
    assert sha(manifest_path) == MANIFEST_SHA, 'CS source manifest changed'
    manifest = read(manifest_path)
    assert manifest['version'] == BASE_VERSION
    expected = {str(Path(p['source']).relative_to('src')).replace('\\', '/'): p['candidateSHA256'].lower()
                for p in manifest['files']}
    assert files(UPSTREAM) == expected, 'Generated source differs from the CS receipt'
    installed = GAME / 'mods/WallBlend/release/WallBlendMod.swf'
    control = CS / 'build/candidate-v07-wall/WallBlendMod.swf'
    assert sha(installed) == sha(control) == BASE_SHA
    deployment = read(CS / 'state/deployment-v07.json')
    assert deployment['status'] == 'verified' and deployment['passed']
    item = next(p for p in deployment['files'] if p['relative'] == 'mods/WallBlend/release/WallBlendMod.swf')
    assert item['after'].lower() == BASE_SHA
    out.mkdir()
    for name in expected:
        for sub in ('baseline-src', 'src'):
            dest = out / sub / name
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(UPSTREAM / name, dest)
    shutil.copyfile(control, out / 'control.swf')
    for name in LAYERS:
        path = out / 'src/wallblend' / name
        path.write_text(optimized(path.read_text(encoding='utf-8-sig'), name), encoding='utf-8')
    entry = out / 'src/WallBlendMod.as'
    entry.write_text(replace_once(entry.read_text(encoding='utf-8-sig'),
                                 '"' + BASE_VERSION + '"', '"' + VERSION + '"'), encoding='utf-8')
    current = files(out / 'src')
    assert sorted(n for n in current if current[n] != expected[n]) == CHANGED
    # The version change is separate. The only behavioral edits reuse the
    # reviewed A40 transformations verbatim; all CS drawing changes stay intact.
    for name in LAYERS:
        original = (out / 'baseline-src/wallblend' / name).read_text(encoding='utf-8-sig')
        assert (out / 'src/wallblend' / name).read_text(encoding='utf-8') == optimized(original, name)
    provenance = out / 'provenance'
    provenance.mkdir()
    for source in (manifest_path, CS / 'state/deployment-v07.json',
                   CS / 'build/wallblend_compat.py', CS / 'build/wallblend_perf.py',
                   CS / 'build/wall-candidate-build.ps1', UPSTREAM / 'air-config.xml',
                   Path(__file__), Path(__file__).with_name('prepare_a40_wallblend.py')):
        shutil.copyfile(source, provenance / source.name)
    assert files(UPSTREAM) == expected and sha(manifest_path) == MANIFEST_SHA
    assert sha(installed) == sha(control) == BASE_SHA, 'Baseline changed during preparation'
    save(out / 'frozen.json', dict(
        kind='isolated-wallblend-comparison', version=VERSION, baseline_version=BASE_VERSION,
        baseline_sha256=BASE_SHA, parent_source=expected, changed=CHANGED,
        source={'src/' + n: h for n, h in current.items()},
        baseline_source={'baseline-src/' + n: h for n, h in expected.items()},
        provenance={'provenance/' + n: h for n, h in files(provenance, '*').items()},
        deployment_allowed=False, preparer_sha256=sha(__file__)))
    print(json.dumps(dict(event='source-frozen', output=str(out), version=VERSION,
                          parent_files=len(expected), changed=CHANGED)), flush=True)


def build(out):
    frozen = read(out / 'frozen.json')
    assert frozen['preparer_sha256'] == sha(__file__)
    for name, value in {**frozen['source'], **frozen['baseline_source'], **frozen['provenance']}.items():
        assert sha(out / name) == value, name
    assert sha(Path(__file__).with_name('prepare_a40_wallblend.py')) == sha(
        out / 'provenance/prepare_a40_wallblend.py'), 'Reviewed comparison recipe changed'
    assert sha(out / 'control.swf') == frozen['baseline_sha256'] == BASE_SHA
    assert not (out / 'prepared.json').exists() and not (out / 'checks').exists()
    air = GAME / 'mods/Sandevistan/build/tools/airsdk/frameworks/libs/air/airglobal.swc'
    compile_as(out / 'src/WallBlendDoc.as', out / 'WallBlendMod.swf', [out / 'src'], [air])
    checks = out / 'checks/src'
    checks.mkdir(parents=True)
    for name in LAYERS:
        for baseline in (True, False):
            source = out / ('baseline-src' if baseline else 'src') / 'wallblend' / name
            class_name = ('Baseline' if baseline else '') + Path(name).stem
            text = source.read_text(encoding='utf-8-sig').replace(Path(name).stem, class_name)
            if baseline and name == 'BackgroundBlendLayer.as':
                start = text.index('            var started:int=getTimer(), parts:Array=')
                end = text.index('            var stamp:String=parts.join("|")', start)
                body = text[start:end] + '            return parts.join("|");\n'
                text = replace_once(text, '        private function findNative(',
                    '        public function stateKey(loc:*):String {\n' + body +
                    '        }\n\n        private function findNative(')
            dest = checks / 'wallblend' / (class_name + '.as')
            dest.parent.mkdir(exist_ok=True)
            dest.write_text(re.sub(r'\bprivate\b', 'public', text), encoding='utf-8')
    for source in (ROOT / 'tests/wallblend').glob('*.as'):
        shutil.copyfile(source, checks / source.name)
    compile_as(checks / 'WallKeyChecks.as', out / 'checks/WallKeyChecks.swf', [checks, out / 'src'], [air])
    for name, value in frozen['source'].items():
        assert sha(out / name) == value, name
    prepared = dict(frozen, candidate_sha256=sha(out / 'WallBlendMod.swf'),
                    frozen_sha256=sha(out / 'frozen.json'),
                    inputs={p.relative_to(out).as_posix(): sha(p) for p in checks.rglob('*.as')},
                    tests={'WallKeyChecks.swf': sha(out / 'checks/WallKeyChecks.swf')})
    save(out / 'prepared.json', prepared)
    print(json.dumps(dict(event='compiled', version=VERSION,
                          candidate_sha256=prepared['candidate_sha256'])), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=('freeze', 'build'))
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    out = (ROOT / args.output).resolve()
    assert out.parent == ROOT / 'build/m52'
    (freeze if args.mode == 'freeze' else build)(out)


if __name__ == '__main__':
    main()

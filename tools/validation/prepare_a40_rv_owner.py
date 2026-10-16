"""Freeze RV's exact owner-delivered D28 candidate for isolated coop tests only."""
import argparse
import json
from pathlib import Path
import shutil

from release_a22_map import ROOT, GAME, sha, read, require, save


OWNER = '01a088fa-b17e-7fc1-85bc-b767327bf4fd'
BINARY = '65b6bf90859cc78decef504ff7c912884d038e027e579bf0c51bebb046be7217'
BASELINE = 'baa48289d9cf86f64cff53b4734032ad29c89c3ac1704db2d89038d4b8db4275'
MAIN = 'dd183e4ce0d2065ec6f4a472eb35a7f1411bd7abb0829c7a839e4aeb56640bf1'
HELPER = '02d18cce5b9479a114fa70ae935d6d7f13b78a933e969868482979ae642271eb'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    out = (ROOT/args.output).resolve()
    require(out.parent == ROOT/'build/m52' and not out.exists(), 'New isolated output required')
    origin = GAME/'mods/RealisticVision/build/wall-restore-output'
    source = origin/'candidate'
    require(sha(source/'RealisticVisionMod.swf') == BINARY, 'Owner binary changed')
    require(sha(source/'src/RealisticVisionMod.as') == MAIN, 'Owner main source changed')
    require(sha(source/'src/RVWallSurface.as') == HELPER, 'Owner helper changed')
    installed = GAME/'mods/RealisticVision/release/RealisticVisionMod.swf'
    require(sha(installed) == BASELINE, 'Installed baseline changed')
    production = read(origin/'production/result.json')
    require(production['sha256'] == BINARY and production['status'] == 'PASS'
            and len(production['runs']) == 2
            and all(r['exit'] == 0 and r['checks'] == 10 for r in production['runs']),
            'Owner production-byte checks incomplete')
    expected_classes = {'RealisticVisionMod', 'RVWallSurface', 'RVExplorationCarrier', 'RVKeybinds',
                        'modlocales.vision.RVLocale', 'modlocales.vision.RVLocaleMessages'}
    require(set((source/'classes.txt').read_text(encoding='utf-8-sig').split()) == expected_classes,
            'Unexpected production class set')
    files = {p.relative_to(source): p for p in (source/'src').rglob('*') if p.is_file()}
    require({str(n.with_suffix('')).replace('\\', '/')[4:].replace('/', '.')
             for n in files if n.suffix == '.as'} == expected_classes, 'Unexpected source set')
    files.update({Path(n): source/n for n in ('RealisticVisionMod.swf', 'classes.txt',
                   'RealisticVisionMod.compiler.xml', 'RealisticVisionMod.compile.log')})
    files[Path('evidence/owner-production-result.json')] = origin/'production/result.json'
    before = {str(n).replace('\\', '/'): sha(p) for n, p in files.items()}
    out.mkdir()
    for name, path in files.items():
        target = out/name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, target)
        require(sha(target) == before[name.as_posix()] == sha(path), 'Owner input changed during copy')
    require(sha(installed) == BASELINE, 'Installation changed during freeze')
    manifest = dict(kind='isolated-rv-owner-candidate', version='0.32.0-wall-restore-candidate',
                    origin_thread=OWNER, origin_directory=str(source), deployment_allowed=False,
                    baseline_sha256=BASELINE, candidate_sha256=BINARY,
                    source={n: h for n, h in before.items() if n.startswith('src/')},
                    inputs={n: h for n, h in before.items() if not n.startswith('src/')
                            and n != 'RealisticVisionMod.swf'},
                    scope='Owner-delivered D28 visual restoration and comparison cache; isolated testing only.',
                    preparer_sha256=sha(__file__))
    save(out/'prepared.json', manifest)
    print(json.dumps(dict(candidate_sha256=BINARY, prepared_sha256=sha(out/'prepared.json'),
                          source_files=len(manifest['source']), deployment_allowed=False)))


if __name__ == '__main__':
    main()

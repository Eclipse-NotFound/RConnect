"""Read-only verification of approved first-raster sources; never builds or starts AIR."""
from pathlib import Path
import argparse
import hashlib
import json
import re
import sys

if sys.flags.optimize:
    raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
GAME = ROOT.parents[1]
LAD = GAME / 'mods/LightAndDarkness'
PROPOSAL = ROOT / 'experimental/goal-ordinary-lamp-first-raster-proposal'
EXPORT = ROOT / 'build/m52/recovery-room-first-raster-current-source-02'
UI_HOST = ROOT / 'build/m52/goal-native-loading-host-03'
LAD_SHA = '8adba6914df5aada4df12a646b6c22df4b95b9630a55dd05ca7f713621c7e3ef'
A796 = 'a796827173af7d6fab9885fb66ecc62182ab5335918a30c7cce4c44914a238b7'
UI_SHA = '2db0b4eb542661c45e5fa0056e7de44e730fee3cf1eac642f6f147f3ce1c2b82'
PINS = {
    PROPOSAL / 'ordinary-lamp-first-raster.diff': 'add79b2b8984c9819b9b87d398bba6b1e237d98b7dd7dba94f7be840346bb816',
    PROPOSAL / 'README.md': 'f6daf1a6a7bdb3d22047e28dfc152e2e446080639411d0358796f25b9a358617',
    EXPORT / 'receipt.json': 'fd125e64837c84a6a3ba339c9f60e42fc526dcc152503c0dc53bcaa82b257a66',
    UI_HOST / 'build.json': '29011f30899e9314855f91ed00ec6b1a35193e8934bd2c5023a244dd5a7f2c07',
    UI_HOST / 'method-audit.json': '16f1e82671b772c46a9b3bf89bfdcc5316c7f5d704f136f21b5b909aa79d5250',
    UI_HOST / 'retain.json': 'ed020b98e6e528cf0169a3b25c19e8e0184f87df5c2dd91f838aefad7b52b717',
}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def inventory(path):
    return {p.relative_to(path).as_posix(): sha(p) for p in sorted(Path(path).rglob('*.as'))}


def patch_parts():
    parts = []
    for line in (PROPOSAL / 'ordinary-lamp-first-raster.diff').read_text('utf-8').splitlines(True):
        if line.startswith('--- '):
            parts.append([])
        assert parts
        parts[-1].append(line)
    assert len(parts) == 2
    assert parts[0][0] == '--- a/lad-proposal/src/lad/LadRuntime.as\n'
    assert parts[1][0] == '--- a/host-proposal/fe/graph/Grafon.as\n'
    return parts


def apply(source, patch, reverse=False):
    """Exact-context forward/reverse application; no fuzzy offsets or filesystem writes."""
    lines = source.splitlines(True)
    out, pos, index = [], 0, 2
    while index < len(patch):
        m = re.fullmatch(r'@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@[^\n]*\n', patch[index])
        assert m, patch[index]
        old_start, old_count, new_start, new_count = int(m[1])-1, int(m[2] or 1), int(m[3])-1, int(m[4] or 1)
        start = new_start if reverse else old_start
        assert start >= pos
        out.extend(lines[pos:start]); pos = start; index += 1
        consumed = emitted = 0
        while index < len(patch) and not patch[index].startswith('@@ '):
            line = patch[index]
            assert line[0] in ' +-'
            mark = {'+': '-', '-': '+'}.get(line[0], line[0]) if reverse else line[0]
            if mark in ' -':
                assert pos < len(lines) and lines[pos] == line[1:], (pos+1, line)
                pos += 1; consumed += 1
            if mark in ' +':
                out.append(line[1:]); emitted += 1
            index += 1
        assert (consumed, emitted) == ((new_count, old_count) if reverse else (old_count, new_count))
    return ''.join(out + lines[pos:])


def method_bodies(source, indent):
    # These frozen AS sources have no regexp literals; strings/comments may contain braces.
    mask = re.sub(r'//[^\n]*|/\*[\s\S]*?\*/|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'',
                  lambda m: ''.join('\n' if c == '\n' else ' ' for c in m[0]), source)
    found = {}
    pattern = r'(?m)^ {'+str(indent)+r'}(?:public|private|internal|protected)\s+(?:(?:static|final|override)\s+)*function\s+(\w+)\s*\('
    for m in re.finditer(pattern, mask):
        begin = mask.index('{', m.end()); depth = 1; end = begin + 1
        while depth:
            assert end < len(mask)
            depth += (mask[end] == '{') - (mask[end] == '}'); end += 1
        assert m[1] not in found
        found[m[1]] = source[m.start():end]
    assert found
    return found


def method_proof(before, after, indent, changed, added, constructor):
    a, b = method_bodies(before, indent), method_bodies(after, indent)
    assert set(b)-set(a) == set(added) and set(a)-set(b) == set()
    actual = {name for name in a if a[name] != b[name]}
    assert actual == set(changed), actual
    assert a[constructor] == b[constructor]
    return dict(original_methods=len(a), unchanged_methods=len(a)-len(actual),
                changed_methods=sorted(actual), added_methods=sorted(added), constructor_unchanged=True,
                changed_original_sha256={name: hashlib.sha256(a[name].encode()).hexdigest() for name in sorted(actual)})


def expected():
    for path, digest in PINS.items():
        assert sha(path) == digest, str(path)
    deployment = read(LAD / 'state/brightness-deployment-2026-10-21.json')
    assert deployment['sha256'] == LAD_SHA
    assert inventory(LAD / 'src') == deployment['source'], 'LAD source changed since exact 8ADBA deployment'
    export = read(EXPORT / 'receipt.json')
    assert export['passed'] and export['source_sha256'] == A796
    source_path = EXPORT / 'source/scripts/fe/graph/Grafon.as'
    assert sha(source_path) == export['files']['source/scripts/fe/graph/Grafon.as'] == '667d4295f417e67dbc7298a082e5b409cdba5a4c3b61c0104a0840bbd9b12540'
    built, audit, retained = read(UI_HOST/'build.json'), read(UI_HOST/'method-audit.json'), read(UI_HOST/'retain.json')
    assert built['compiled'] and built['build_checks_passed'] and built['base_sha256'] == A796 and built['candidate_sha256'] == UI_SHA
    assert built['inputs_unchanged'] and built['installation_unchanged']
    assert built['method_audit'] == audit and built['retain'] == retained
    assert audit['passed'] and audit['exact_retained_roundtrip'] and audit['non_target_bodies_byte_exact'] == 3275
    assert audit['original_constructors_byte_exact'] and audit['original_static_initializers_byte_exact']
    assert len(audit['allowed_changed_bodies']) == 10 and all(name.startswith('fe.World::') for name in audit['allowed_changed_bodies'])
    assert retained['changed_original_methods'] == audit['allowed_changed_bodies']
    patch = patch_parts()
    bases = [(LAD/'src/lad/LadRuntime.as').read_text('utf-8'), source_path.read_text('utf-8')]
    candidates = [apply(base, part) for base, part in zip(bases, patch)]
    for base, candidate, part in zip(bases, candidates, patch):
        assert apply(candidate, part, True) == base
    proof = {
        'lad': method_proof(bases[0], candidates[0], 8,
            ['beforeSceneRaster','onFrame','attach','detach'],
            ['beginOrdinaryRaster','completeOrdinaryRaster','ordinaryRasterIdentity','ordinaryRasterOwnsPixels','restoreOrdinaryRefs','cancelOrdinaryRaster','canUseOrdinaryRaster'], 'LadRuntime'),
        'host': method_proof(bases[1], candidates[1], 6, ['drawLoc'],
            ['beginOrdinaryLampRaster','completeOrdinaryLampRaster'], 'Grafon'),
        'whole_sources_reverse_exact_lf': True,
        'host_2db0_grafon_bytecode_unchanged_from_a796': True,
        'scope': 'Text restoration and existing host03 bytecode receipt only; new candidate is not compiled.'}
    return candidates, deployment['source'], proof


def verify():
    manifest = read(HERE/'source-manifest.json')
    assert manifest['kind'] == 'ordinary-lamp-first-raster-source-v1'
    candidates, originals, proof = expected()
    assert manifest['original_lad_sources'] == originals and manifest['restoration_proof'] == proof
    assert inventory(HERE/'lad/src') == manifest['candidate_lad_sources']
    assert inventory(HERE/'host') == manifest['candidate_host_sources']
    assert (HERE/'lad/src/lad/LadRuntime.as').read_text('utf-8') == candidates[0]
    assert (HERE/'host/fe/graph/Grafon.as').read_text('utf-8') == candidates[1]
    for name, digest in originals.items():
        if name != 'lad/LadRuntime.as':
            assert sha(HERE/'lad/src'/name) == digest
    assert (HERE/'host.diff').read_text('utf-8') == ''.join(patch_parts()[1])
    assert read(HERE/'restoration-proof.json') == proof
    frozen = read(HERE/'FROZEN.json')
    files = {p.relative_to(HERE).as_posix(): sha(p) for p in sorted(HERE.rglob('*')) if p.is_file() and p.name != 'FROZEN.json'}
    assert files == frozen['files']
    return manifest


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', required=True)
    parser.parse_args()
    value = verify()
    print(json.dumps(dict(kind=value['kind'], passed=True, lad_sources=len(value['candidate_lad_sources']),
                         restoration=value['restoration_proof'], compiled=False, air_started=False), ensure_ascii=False))

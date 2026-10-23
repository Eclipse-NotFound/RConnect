"""ACC-based ordinary-wall host: explicit prepare/build/verify, never AIR/install.

Only --build starts Java. A successful build is compilation/resource/readback
evidence, NOT approval of changed bytecode bindings, exception CFG or gameplay.
"""
from pathlib import Path
import argparse, difflib, hashlib, importlib.util, json, re, subprocess, sys

if sys.flags.optimize:
    raise RuntimeError('Do not use -O/-OO: input and safety assertions must remain enabled')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
GAME = ROOT.parents[1]
M52 = ROOT / 'build/m52'
NATIVE = ROOT / 'experimental/recovery-ordinary-wall-sv-host'
BASE = M52 / 'recovery-wall-surfaces-host-01'
PRODUCT = M52 / 'recovery-ordinary-wall-sv-production-01'
DEFAULT = M52 / 'recovery-ordinary-wall-sv-host-01'
JAVA = Path('C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe')
FFDEC = ROOT.parent / 'Sandevistan/build/tools/ffdec/ffdec-cli.jar'
RC_KEY = 'mods/Rconnect/release/RConnectMod.swf'
RC_OLD = '574d2b51490ae8b25a1396555600f56a301f8a20ae50104c0e35cf2796441afe'
RC_OFFLINE = 'eb3653533cfb305bcca0b0cfe5e81bc306ea28fa400aae751ab7b5ae1cfa5fee'
BEFC = 'befcf0509e11fac9fef7afb834708b8b93752a14ae3d5cd72b42aa6d42f9b82a'
ACC = 'acc336b5f28012a5f0d2ef57d0a3bf46be46f72f1e4c3a69a2f063cae0535dfd'
PATCHED = ('fe.graph.Grafon', 'fe.loc.Location')
REPRESENTATIVES = ('MainFE', 'fe.World', 'fe.loc.Game', 'fe.loc.Land', 'fe.inter.Camera', 'fe.inter.GUI')
CHANGED = {'fe.graph.Grafon': {'drawLoc', 'tileDie', 'decal'}, 'fe.loc.Location': {'hitTile', 'dieTile'}}
SOURCE = {
    'fe/graph/Grafon.as': '818b56f1ee0d6d0f92d8a37aaaec15c9748b0023326de900c4bc0c2d2b261da5',
    'fe/loc/Location.as': '0ecce22f33a215d13f9a29ca1fc62d6a6ef5225981d9e4badb7609812f200267',
}
CHAIN = (
    ('recovery-native-travel-host-01', 'e159fe0f0a1cbb34596d18b9979f439e80823fbeda369be7b2220a42e8e5d30c',
     'bde1e160ebe4b274a793c4b07793a59f653a57be18595e56714f74b02c182d33', 'Game travel bridge'),
    ('recovery-first-raster-host-03', 'fd92fbd5ae92b5c8d4cbf8151d11796a140810f34988b7031e258c747d86734e',
     '1dfa42c494c33eafb0cab1ca5b6ad43f5a6ae73419ce657827e952a4dfd74312', 'Grafon first raster'),
    ('recovery-wall-surfaces-host-01', ACC,
     '9214ed94353f883bb01a9cd50d195c95cb05fb637213ff23112abc4907fb5ffd', 'Grafon large wall bridge'),
)
PINS = {
    JAVA: '9fcc7d5d43918e389df240d44601c98a4d3aa9e7d0cbbd6d208304e0b574c7e2',
    FFDEC: '23c1e70ff2b08388e35de10afd97a2875386cbfdc2ef99c8176d40b4f8a3ada9',
    ROOT / 'tools/validation/runtime_memory.py': 'd4894962771929b5b88f1d123c3603221dab06294657d33bc6229a2282fbf8f6',
    ROOT / 'tools/validation/prepare_recovery_native_travel.py': '08bee153297f5f37fb44d75c0b4c9f02c9cd1454aab863cec2b97a1c6692da43',
    ROOT / 'tools/host_authority/common.py': '4beec61d4df070a9e69919a87ad6b77f3160be9505e5fe6b2cfc84a2ca210c8a',
    ROOT / 'tools/host_authority/patch_native.py': '56af29a0d087e73b2d9c2141641a6f639543e5925eba2125617fac5d96a0f3cb',
    ROOT.parent / 'ModLoader/tools/test_registry.py': '58db3a594f34e9906d55992f769b3e154970d8fa37fda1c2f43ae1f6751b0033',
    M52 / 'recovery-ordinary-wall-sv-component-02/intent.json': 'f37acbaff091522b744bd72cbfce3e4c0a5c4b455637b686d4c33e455d03deda',
    M52 / 'recovery-first-raster-host-recheck-03/receipt.json': '56f07ae744a8dfffc8276178e3e89a375118794a97b4de3e6862664d817d2755',
    M52 / 'recovery-wall-surfaces-host-recheck-01/receipt.json': '888d19485ea8e9d70f92188e7e61de5cffad8dcfa7a88499b00c88d6bedb3e49',
    NATIVE / 'prepare.py': '9b7e0ec4b1c056ef2f26af85b1ed77e23491d453a27939cf90cf09550b73cc0f',
    NATIVE / 'ordinary-bridge.inc.as': '7d5c8eef7dc4e8510287794a2fdcf130914412f881fa3f38af3969ab7b86e886',
    NATIVE / 'prepared.json': '56575d9ee2333b0ef00439d6b6e34b8f76ac6644a7076af460d88536eacd88e5',
    NATIVE / 'source-review.json': '3f4a229eab32a38d7170145caee22eee79bd18dd6b8700f727a4b0398bdf3f7f',
    PRODUCT / 'RConnectMod.swf': 'c6a3b1136bde63c32d23c4e555dfc240f3a573384d19c4fe9636a4138193496d',
    PRODUCT / 'prepared.json': '707718036263940c4f63ee1babe3f913735e81aee4e181f95f9b6cb4dad30083',
    PRODUCT / 'compile.json': 'fdacc3602fcbf0c7ab6b77556f621ea8ac10edae4e4593e640e093fad3260144',
}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def text(path):
    return Path(path).read_text(encoding='utf-8-sig')


def save(path, value):
    with Path(path).open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.write('\n')


def target(path):
    out = (ROOT / Path(path)).resolve()
    assert out.parent == M52.resolve() and re.fullmatch(r'recovery-ordinary-wall-sv-host-\d{2,}', out.name)
    return out


def installation():
    # Preserve the successful component's exact 22 inputs, allowing only this
    # separately approved RC replacement. Never accept arbitrary current state.
    intent = M52 / 'recovery-ordinary-wall-sv-component-02/intent.json'
    assert sha(intent) == PINS[intent]
    expected = read(intent)['installation_before']
    assert len(expected) == 22 and expected[RC_KEY] == RC_OLD and expected['pfe.swf'] == BEFC
    assert sha(GAME / 'mods/loader-manifest.txt') == expected['mods/loader-manifest.txt']
    paths = {GAME / 'pfe.swf', GAME / 'mods/loader-manifest.txt'}
    for line in text(GAME / 'mods/loader-manifest.txt').splitlines():
        if line.startswith('#') or '|' not in line:
            continue
        directory, entry = line.split('|')[:2]
        names = [entry + '.swf', 'config.txt', 'config.json']
        if directory.lower() == 'continuousscene':
            names.append('scene.xml')
        for name in names:
            path = GAME / 'mods' / directory / 'release' / name
            if path.is_file():
                paths.add(path)
    actual = {p.relative_to(GAME).as_posix(): sha(p) for p in sorted(paths)}
    assert actual.get(RC_KEY) in (RC_OLD, RC_OFFLINE), 'Unreviewed installed RConnect'
    allowed = dict(expected)
    allowed[RC_KEY] = actual[RC_KEY]
    assert actual == allowed, 'Installation drift outside the exact RC574D/EB365 allowance'
    return actual


def reviewed_inputs():
    pins = dict(PINS)
    for folder, binary, manifest, _ in CHAIN:
        pins[M52 / folder / 'pfe.swf'] = binary
        pins[M52 / folder / 'prepared.json'] = manifest
    for path, digest in pins.items():
        assert sha(path) == digest, str(path)
    travel = read(M52 / CHAIN[0][0] / 'prepared.json')
    assert travel['original_sha256'] == BEFC and travel['compiled'] and travel['validated']
    prior = CHAIN[0][1]
    for folder, binary, _, _ in CHAIN[1:]:
        meta = read(M52 / folder / 'prepared.json')
        assert meta['base_sha256'] == prior and meta['candidate_sha256'] == binary and meta['compiled']
        prior = binary
    for folder, candidate in (('recovery-first-raster-host-recheck-03', CHAIN[1][1]),
                              ('recovery-wall-surfaces-host-recheck-01', ACC)):
        receipt = read(M52 / folder / 'receipt.json')
        assert receipt['validated'] is True and receipt['candidate_sha256'] == candidate
    native = read(NATIVE / 'prepared.json')
    for path, digest in native['inputs'].items():
        pins[Path(path)] = digest
    for name, digest in native['outputs'].items():
        pins[NATIVE / name] = digest
    assert {name[4:]: digest for name, digest in native['outputs'].items() if name.startswith('src/')} == SOURCE
    # ACC's actual exports, not just the pre-import authoring source, are the
    # comparison baseline. Location was not previously imported into ACC.
    meta = read(BASE / 'prepared.json')
    for cls in PATCHED + REPRESENTATIVES:
        name = 'after/scripts/' + cls.replace('.', '/') + '.as'
        pins[BASE / name] = meta['readback_files'][name]
    pins[BASE / 'after-classes.txt'] = meta['readback_files']['after-classes.txt']
    for path, digest in pins.items():
        assert sha(path) == digest, str(path)
    spec = importlib.util.spec_from_file_location('wall_sv_frozen_native_source', NATIVE / 'prepare.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.prepare(verify=True)  # Existing generator: source-only, no writes/JVM.
    compiled = read(PRODUCT / 'compile.json')
    assert compiled['compiled'] and compiled['compile_exit'] == 0 and compiled['candidate_sha256'] == PINS[PRODUCT / 'RConnectMod.swf']
    pins[Path(__file__).resolve()] = sha(__file__)
    return {str(p): digest for p, digest in pins.items()}


def commands(out):
    names = ','.join(PATCHED + REPRESENTATIVES)
    args = [
        ('before.log', ['-selectclass', names, '-export', 'script', out / 'before', BASE / 'pfe.swf']),
        ('import.log', ['-importScript', BASE / 'pfe.swf', out / 'pfe.swf', out / 'import']),
        ('after.log', ['-selectclass', names, '-export', 'script', out / 'after', out / 'pfe.swf']),
        ('pcode.log', ['-format', 'script:pcode', '-selectclass', ','.join(PATCHED), '-export', 'script', out / 'pcode', out / 'pfe.swf']),
        ('before-classes.txt', ['-dumpAS3', BASE / 'pfe.swf']),
        ('after-classes.txt', ['-dumpAS3', out / 'pfe.swf']),
    ]
    return [{'log': name, 'argv': [str(JAVA), '-Xmx512m', '-jar', str(FFDEC), *map(str, argv)]} for name, argv in args]


def verify(out):
    out = target(out)
    inputs = reviewed_inputs()
    meta = read(out / 'prepared.json')
    assert meta['kind'] == 'ordinary-wall-sv-ACC-host' and meta['inputs'] == inputs
    assert meta['import_sources'] == SOURCE and meta['base_sha256'] == ACC
    assert meta['original_installed_host_sha256'] == BEFC and meta['dependency_chain'] == [list(x) for x in CHAIN]
    assert meta['patched_classes'] == list(PATCHED) and meta['representatives'] == list(REPRESENTATIVES)
    assert meta['allowed_installed_rc_sha256'] == [RC_OLD, RC_OFFLINE]
    assert not any(meta[k] for k in ('compiled', 'installed', 'air_started', 'validated', 'gameplay_qualified', 'performance_qualified'))
    old_install = read(M52 / 'recovery-ordinary-wall-sv-component-02/intent.json')['installation_before']
    assert meta['installation_before'][RC_KEY] in (RC_OLD, RC_OFFLINE)
    old_install[RC_KEY] = meta['installation_before'][RC_KEY]
    assert old_install == meta['installation_before']
    assert {p.relative_to(out / 'import').as_posix(): sha(p) for p in (out / 'import').rglob('*') if p.is_file()} == SOURCE
    assert read(out / 'commands.json') == commands(out)
    assert sha(out / 'commands.json') == meta['commands_sha256']
    installation()
    return meta


def prepare(out):
    out = target(out)
    assert not out.exists(), 'Preserve prior candidate/failure; choose a new numbered output'
    inputs = reviewed_inputs()
    before = installation()
    out.mkdir()
    save(out / 'prepare-start.json', {'inputs': inputs, 'installation_before': before})
    try:
        for name, digest in SOURCE.items():
            dest = out / 'import' / name
            dest.parent.mkdir(parents=True, exist_ok=True)
            with dest.open('xb') as stream:
                stream.write((NATIVE / 'src' / name).read_bytes())
            assert sha(dest) == digest
        save(out / 'commands.json', commands(out))
        assert reviewed_inputs() == inputs and installation() == before
        save(out / 'prepared.json', dict(kind='ordinary-wall-sv-ACC-host', base_sha256=ACC,
            original_installed_host_sha256=BEFC, dependency_chain=CHAIN, inputs=inputs, import_sources=SOURCE,
            patched_classes=PATCHED, representatives=REPRESENTATIVES, commands_sha256=sha(out / 'commands.json'),
            installation_before=before, allowed_installed_rc_sha256=[RC_OLD, RC_OFFLINE],
            compiled=False, air_started=False, installed=False, validated=False,
            gameplay_qualified=False, performance_qualified=False))
        return verify(out)
    except BaseException as exc:
        save(out / 'prepare-failure.json', dict(error_type=type(exc).__name__, error=str(exc)))
        raise


# Lexical comparison deliberately does not rename variables, move declarations,
# quote object keys, change braces or erase FFDec pseudo expressions.
LEX = re.compile(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|//[^\n]*|/\*[\s\S]*?\*/|\s+|\w+|[^\w\s]')


def tokens(source):
    return [m for m in LEX.finditer(source) if not m[0].isspace() and not m[0].startswith(('//', '/*'))]


def token_text(source):
    return ''.join(m[0] for m in tokens(source))


def methods(source):
    ts = tokens(source)
    result = {}
    for i, item in enumerate(ts):
        if item[0] != 'function' or ts[i + 1][0] in ('(',):
            continue  # Anonymous nested function.
        start = i
        while start and ts[start - 1][0] in ('public', 'private', 'protected', 'internal', 'static', 'override', 'final'):
            start -= 1
        name = ts[i + 1][0]
        if name in ('get', 'set'):
            name += ' ' + ts[i + 2][0]
        at = i + 2
        while ts[at][0] != '{':
            at += 1
        depth = 1
        end = at + 1
        while depth:
            depth += (ts[end][0] == '{') - (ts[end][0] == '}')
            end += 1
        assert name not in result, name
        result[name] = source[ts[start].start():ts[end - 1].end()]
    return result


def audit(out):
    # Imports are read-only helper modules, already hard-pinned before build.
    sys.path.insert(0, str(ROOT / 'tools/validation'))
    sys.path.insert(0, str(ROOT / 'tools/host_authority'))
    from prepare_recovery_native_travel import normalized, movie_header
    from patch_native import swf_tags
    evidence = {}
    before_tags, after_tags = swf_tags(BASE / 'pfe.swf'), swf_tags(out / 'pfe.swf')
    save(out / 'tag-inventory.json', {
        phase: [dict(index=i, type=kind, length=len(data), sha256=hashlib.sha256(data).hexdigest())
                for i, (kind, data) in enumerate(tags)]
        for phase, tags in [('before', before_tags), ('after', after_tags)]})
    assert len(before_tags) == len(after_tags)
    changed = []
    for i, (old, new) in enumerate(zip(before_tags, after_tags)):
        assert old[0] == new[0], ('tag type', i)
        if old != new:
            assert old[0] in (72, 82), ('non-code tag changed', i, old[0])
            changed.append(i)
    assert changed and movie_header(BASE / 'pfe.swf') == movie_header(out / 'pfe.swf')
    assert normalized(text(out / 'before-classes.txt')) == normalized(text(out / 'after-classes.txt')) == normalized(text(BASE / 'after-classes.txt'))
    evidence.update(non_code_tags_unchanged=True, movie_header_unchanged=True, class_list_unchanged=True, changed_code_tags=changed)
    representatives = {}
    for cls in PATCHED + REPRESENTATIVES:
        rel = Path(*cls.split('.')).with_suffix('.as')
        old, new = text(out / 'before/scripts' / rel), text(out / 'after/scripts' / rel)
        assert normalized(old) == normalized(text(BASE / 'after/scripts' / rel)), ('ACC before mismatch', cls)
        if cls in REPRESENTATIVES:
            assert normalized(old) == normalized(new), ('Representative changed', cls)
            representatives[cls] = hashlib.sha256(normalized(new).encode()).hexdigest()
            continue
        authored = text(out / 'import' / rel)
        b, a, e = methods(old), methods(new), methods(authored)
        # Includes the Grafon property getter omitted by source-review.json's
        # named-method count: 90 methods + get rconnectRasterPending.
        assert len(b) == (91 if cls == 'fe.graph.Grafon' else 74)
        assert set(a) == set(e) and set(b) <= set(a), ('Method set', cls)
        unchanged = sorted(set(b) - CHANGED[cls])
        for name in unchanged:
            assert token_text(b[name]) == token_text(a[name]), ('Unmodified method changed', cls, name)
        modified = sorted(CHANGED[cls] | (set(e) - set(b)))
        checks = {name: token_text(a[name]) == token_text(e[name]) for name in modified}
        (out / (cls + '.source-readback.diff')).write_text(''.join(difflib.unified_diff(
            authored.splitlines(True), new.splitlines(True), fromfile='authored/' + str(rel), tofile='readback/' + str(rel))), encoding='utf-8')
        pcode = out / 'pcode/scripts' / rel.with_suffix('.pcode')
        assert pcode.is_file() and pcode.stat().st_size > 0, ('Missing pcode', cls)
        evidence[cls] = dict(unchanged_methods=unchanged, changed_or_new_methods=modified,
            changed_method_token_equal=checks, changed_readback_review_required=True, pcode_sha256=sha(pcode),
            exception_cfg_review_required=True, binding_review_required=True)
    evidence['representative_normalized_sha256'] = representatives
    evidence['readback_integrity_passed'] = True
    # Even exact text is not a semantic proof of compiler-resolved slots/CFG.
    evidence['source_semantics_qualified'] = False
    save(out / 'readback-audit.json', evidence)
    return evidence


def build(out, wait):
    out = target(out)
    meta = verify(out)
    assert not any((out / n).exists() for n in ('build-start.json', 'build.json', 'pfe.swf', 'before', 'after', 'pcode'))
    before = installation()
    prepared_hash = sha(out / 'prepared.json')
    save(out / 'build-start.json', dict(prepared_sha256=prepared_hash, installation_before=before))
    result = dict(prepared_sha256=prepared_hash, installation_at_prepare=meta['installation_before'], installation_before=before,
        commands=[], compiled=False, build_checks_passed=False, validated=False, air_started=False, installed=False,
        gameplay_qualified=False, performance_qualified=False, source_semantics_qualified=False)
    sys.path.insert(0, str(ROOT.parent / 'ModLoader/tools'))
    sys.path.insert(0, str(ROOT / 'tools/validation'))
    from test_registry import Registration
    from runtime_memory import snapshot, wait_owned
    failure = None
    try:
        with Registration(owner='RConnect / 普通墙面宿主构建', resource='game', purpose='ACC + Grafon/Location only; no AIR/install',
                          run_dir=out, evidence=out / 'build.json', wait=wait) as record:
            for command in commands(out):
                verify(out)
                assert installation() == before, 'Installed inputs changed during this build'
                memory = snapshot()
                name = command['log']
                save(out / (name + '.memory-before.json'), memory)
                assert memory['free_commit_bytes'] >= 1024**3, 'Less than 1 GiB before FFDec'
                item = dict(command, pid=None, exit_code=None, reaped=False)
                result['commands'].append(item)
                process = None
                with (out / name).open('x', encoding='utf-8') as stdout, (out / (name + '.stderr.log')).open('x', encoding='utf-8') as stderr:
                    try:
                        record.before_launch('FFDec ' + name)
                        process = subprocess.Popen(command['argv'], cwd=out, stdout=stdout, stderr=stderr, creationflags=subprocess.CREATE_NO_WINDOW)
                        item['pid'] = process.pid
                        record.child(process.pid)
                        item['exit_code'] = wait_owned(process, 300, out / (name + '.memory-timeline.json'))
                    finally:
                        if process is not None:
                            if process.poll() is None:
                                process.kill()
                            process.wait()
                            item['reaped'] = process.poll() is not None
                        record.child_stopped()
                assert item['exit_code'] == 0 and item['reaped'], item
                for path in (out / name, out / (name + '.stderr.log')):
                    assert not any(s in text(path) for s in ('SEVERE:', 'Unknown preprocessor instruction', 'Exception in thread')), str(path)
                if name == 'import.log':
                    result.update(compiled=True, candidate_sha256=sha(out / 'pfe.swf'))
            result['audit'] = audit(out)
            verify(out)
            assert installation() == before
            result['build_checks_passed'] = True
            record.outcome = 'passed'
            record.note = 'Compilation/resources/unchanged code passed; changed binding/exception CFG and native testing remain'
    except BaseException as exc:
        failure = exc
        result.update(error_type=type(exc).__name__, error=str(exc))
    finally:
        try:
            result['installation_after'] = installation()
            result['installation_unchanged'] = result['installation_after'] == before
            result['inputs_unchanged'] = reviewed_inputs() == meta['inputs'] and sha(out / 'prepared.json') == prepared_hash
            if not result['installation_unchanged'] or not result['inputs_unchanged']:
                result['build_checks_passed'] = False
                failure = failure or AssertionError('Final installation/input comparison failed')
        except BaseException as exc:
            failure = failure or exc
            result.update(build_checks_passed=False, final_check_error=str(exc))
        result['artifacts'] = {p.relative_to(out).as_posix(): sha(p) for p in sorted(out.rglob('*')) if p.is_file()}
        save(out / 'build.json', result)
    if failure is not None:
        raise failure
    return result


def verify_result(out):
    meta = verify(out)
    if not (out / 'build.json').exists():
        return dict(prepared_verified=True, compiled=False, installed=False)
    result = read(out / 'build.json')
    assert result['prepared_sha256'] == sha(out / 'prepared.json')
    for name, digest in result['artifacts'].items():
        assert sha(out / name) == digest, name
    assert result['compiled'] and result['build_checks_passed'] and result['inputs_unchanged'] and result['installation_unchanged']
    assert result['candidate_sha256'] == sha(out / 'pfe.swf')
    assert result['installation_before'] == result['installation_after']
    assert len(result['commands']) == 6 and all(x['exit_code'] == 0 and x['reaped'] for x in result['commands'])
    assert not any(result[k] for k in ('validated', 'air_started', 'installed', 'gameplay_qualified', 'performance_qualified', 'source_semantics_qualified'))
    return dict(prepared_verified=True, compiled=True, build_checks_passed=True, validated=False, candidate_sha256=result['candidate_sha256'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=DEFAULT)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--check-inputs', action='store_true')
    mode.add_argument('--prepare', action='store_true')
    mode.add_argument('--build', action='store_true')
    mode.add_argument('--verify', action='store_true')
    parser.add_argument('--registry-wait', type=float, default=900)
    args = parser.parse_args()
    out = target(args.output)
    if args.check_inputs:
        value = dict(inputs=len(reviewed_inputs()), installation=installation(), jvm_started=False)
    elif args.prepare:
        meta = prepare(out)
        value = dict(prepared=str(out), inputs=len(meta['inputs']), compiled=False, installed=False)
    elif args.build:
        value = build(out, args.registry_wait)
        value = {k: value[k] for k in ('compiled', 'build_checks_passed', 'validated', 'candidate_sha256')}
    else:
        value = verify_result(out)
    print(json.dumps(value, ensure_ascii=False))


if __name__ == '__main__':
    main()

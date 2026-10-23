"""One-method mask whitelist candidate. Only --build starts registered Java."""
from pathlib import Path
import argparse
import difflib
import hashlib
import importlib.util
import json
import re
import shutil
import subprocess
import sys

if sys.flags.optimize:
    raise RuntimeError('Do not disable admission assertions')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
M52 = ROOT / 'build/m52'
BASE = M52 / 'recovery-ordinary-wall-sv-host-05'
DEFAULT = M52 / 'recovery-ordinary-mask-host-02'
PREVIOUS = ROOT / 'experimental/recovery-ordinary-method-transplant/build_final.py'
PREVIOUS_SHA = '9ef068b71942430f14391b4112fa32a82cf78318561200165a2397e29df671af'
HELPER = ROOT / 'experimental/recovery-ordinary-mask-host-fix/single_method.py'
HELPER_SHA = 'c84e369cbc14aef543186f6b645b9f5986201882c1c3522634c79310ffc0cbe4'
DONOR_SOURCE = ROOT / 'experimental/recovery-ordinary-wall-sv-host-v2/src/fe/graph/Grafon.as'
DONOR_SOURCE_SHA = 'dd6299fbe5db88b7741c43722f5fbb18b45e36fa9aadb9134b128b464515a085'
RESOURCE_PROOF = ROOT / 'experimental/recovery-ordinary-wall-room-failure/mask-resource-evidence.json'
RESOURCE_SHA = '5d6412a1f9af99cb91b7061951e4921dfb63a1a866990c85da22083c42fee693'
BASE_SWF_SHA = '00c7c511ffa51745cb4932e820365091d2540978eedd6dfe726a5cfd7818aa48'
EB365 = 'eb3653533cfb305bcca0b0cfe5e81bc306ea28fa400aae751ab7b5ae1cfa5fee'
TARGET = 'fe.graph.Grafon::0:1:ordinaryMaskBounds'
_modules = None

def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024*1024), b''): h.update(block)
    return h.hexdigest()

def read(path): return json.loads(Path(path).read_text(encoding='utf-8-sig'))
def text(path): return Path(path).read_text(encoding='utf-8-sig')
def save(path, value):
    with Path(path).open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2); stream.write('\n')

def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    return module

def modules():
    global _modules
    assert sha(PREVIOUS) == PREVIOUS_SHA
    assert sha(HELPER) == HELPER_SHA
    assert sha(DONOR_SOURCE) == DONOR_SOURCE_SHA
    if _modules is None:
        previous = load(PREVIOUS, 'ordinary_mask_previous_final')
        _modules = previous, previous.modules()[1], load(HELPER, 'ordinary_mask_single_method')
    return _modules

def installation():
    old = modules()[1]
    actual = old.installation()
    assert actual[old.RC_KEY] == EB365, 'Require current exact EB365 installation'
    return actual

def target(path):
    out = (ROOT / Path(path)).resolve()
    assert out.parent == M52.resolve() and re.fullmatch(r'recovery-ordinary-mask-host-\d{2,}', out.name)
    return out

def revised_source():
    _, old, helper = modules()
    source = text(DONOR_SOURCE)
    pattern = r'\s*&&\s*'.join(re.escape('factory !== ' + n) for n in helper.ORIGINAL)
    matches = list(re.finditer(pattern, source))
    assert len(matches) == 1
    original = matches[0].group(0)
    revised = original + ' && ' + ' && '.join('factory !== ' + n for n in helper.ADDED)
    result = source.replace(original, revised)
    a, b = old.methods(source), old.methods(result)
    assert set(a) == set(b) and all(a[n] == b[n] for n in a if n != 'ordinaryMaskBounds')
    assert a['ordinaryMaskBounds'].replace(original, revised) == b['ordinaryMaskBounds']
    return result

def expected_readback_method():
    # The donor is authored compilable source; comparison remains against the
    # original host05 decompiler form, changing only its exact guard tokens.
    _, old, helper = modules()
    original = ' && '.join('factory !== ' + n for n in helper.ORIGINAL)
    revised = original + ' && ' + ' && '.join('factory !== ' + n for n in helper.ADDED)
    source = old.methods(text(BASE / 'after/scripts/fe/graph/Grafon.as'))['ordinaryMaskBounds']
    assert source.count(original) == 1
    return source.replace(original, revised)

def reviewed_inputs():
    previous, _, helper = modules()
    previous.verify_result(BASE)
    assert sha(BASE / 'pfe.swf') == BASE_SWF_SHA
    assert sha(BASE / 'final.xml') == helper.BASE_XML_SHA
    assert sha(RESOURCE_PROOF) == RESOURCE_SHA
    result = dict(read(BASE / 'prepared.json')['inputs'])
    for name, digest in read(BASE / 'build.json')['artifacts'].items():
        assert sha(BASE / name) == digest
        result[str(BASE / name)] = digest
    for path in (Path(__file__), PREVIOUS, HELPER, DONOR_SOURCE, RESOURCE_PROOF, BASE / 'build.json', BASE / 'prepared.json',
                 ROOT.parent / 'ModLoader/tools/test_registry.py', ROOT / 'tools/validation/runtime_memory.py'):
        result[str(path.resolve())] = sha(path)
    result.update(helper.dependencies())
    assert result[str(PREVIOUS)] == PREVIOUS_SHA
    return result

def commands(out):
    _, old, _ = modules()
    selected = ','.join(old.PATCHED + old.REPRESENTATIVES)
    steps = [
        ('donor-import', ['-importScript', BASE / 'pfe.swf', out / 'donor.swf', out / 'import']),
        ('donor-xml', ['-swf2xml', out / 'donor.swf', out / 'donor.xml']),
        ('serialize', ['-xml2swf', out / 'retained.xml', out / 'serialized.swf']),
        ('serialized-xml', ['-swf2xml', out / 'serialized.swf', out / 'serialized.xml']),
        ('final-xml', ['-swf2xml', out / 'pfe.swf', out / 'final.xml']),
        ('final-as', ['-selectclass', selected, '-export', 'script', out / 'after', out / 'pfe.swf']),
        ('final-pcode', ['-format', 'script:pcode', '-selectclass', ','.join(old.PATCHED), '-export', 'script', out / 'pcode', out / 'pfe.swf']),
        ('final-classes', ['-dumpAS3', out / 'pfe.swf'])]
    return [dict(name=name, argv=[str(old.JAVA), '-Dfile.encoding=UTF-8', '-Duser.language=en',
            '-Duser.country=US', '-Xmx512m', '-jar', str(old.FFDEC), *map(str, args)]) for name, args in steps]

def copies():
    _, old, _ = modules()
    result = {'before-classes.txt': BASE / 'after-classes.txt'}
    for cls in old.PATCHED + old.REPRESENTATIVES:
        rel = cls.replace('.', '/') + '.as'
        result['before/scripts/' + rel] = BASE / 'after/scripts' / rel
    return result

def verify(out):
    out = target(out); meta = read(out / 'prepared.json')
    assert meta['kind'] == 'ordinary-mask-one-method-host' and meta['base_sha256'] == BASE_SWF_SHA
    for path, digest in meta['inputs'].items(): assert sha(path) == digest, path
    assert meta['commands'] == commands(out)
    assert meta['copied_sources'] == {name: sha(path) for name, path in copies().items()}
    for name, digest in meta['copied_sources'].items(): assert sha(out / name) == digest, name
    assert sha(out / 'import/fe/graph/Grafon.as') == meta['source_sha256']
    assert text(out / 'import/fe/graph/Grafon.as') == revised_source()
    assert sha(out / 'source.diff') == meta['diff_sha256']
    assert installation() == meta['installation_before']
    assert all(meta[k] is False for k in ('compiled', 'validated', 'air_started', 'installed'))
    return meta

def prepare(out):
    out = target(out)
    assert not out.exists(), 'Preserve previous candidate/failure; use a new output'
    pins, before = reviewed_inputs(), installation()
    source = revised_source()
    out.mkdir()
    save(out / 'prepare-start.json', dict(inputs=pins, installation_before=before))
    for name, path in copies().items():
        dest = out / name; dest.parent.mkdir(parents=True, exist_ok=True); shutil.copyfile(path, dest)
    dest = out / 'import/fe/graph/Grafon.as'; dest.parent.mkdir(parents=True)
    with dest.open('x', encoding='utf-8', newline='\n') as stream: stream.write(source)
    difference = ''.join(difflib.unified_diff(text(DONOR_SOURCE).splitlines(True),
        source.splitlines(True), fromfile='native-v2/fe/graph/Grafon.as', tofile='mask-fix/fe/graph/Grafon.as'))
    with (out / 'source.diff').open('x', encoding='utf-8', newline='\n') as stream: stream.write(difference)
    assert installation() == before
    save(out / 'prepared.json', dict(kind='ordinary-mask-one-method-host', target=TARGET, inputs=pins,
        base_sha256=BASE_SWF_SHA, donor_source_sha256=DONOR_SOURCE_SHA, installation_before=before, commands=commands(out),
        copied_sources={name: sha(path) for name, path in copies().items()}, source_sha256=sha(dest),
        diff_sha256=sha(out / 'source.diff'), compiled=False, validated=False, air_started=False, installed=False,
        gameplay_qualified=False, performance_qualified=False))
    return verify(out)

def readback(out):
    _, old, helper = modules()
    assert text(out / 'after-classes.txt').split() == text(out / 'before-classes.txt').split(), 'Class inventory changed'
    unchanged = {}
    for cls in old.PATCHED + old.REPRESENTATIVES:
        rel = cls.replace('.', '/') + '.as'
        before, after = text(out / 'before/scripts' / rel), text(out / 'after/scripts' / rel)
        if cls != 'fe.graph.Grafon':
            assert old.token_text(before) == old.token_text(after), 'Other class changed: ' + cls
            unchanged[cls] = True
        else:
            a, b = old.methods(before), old.methods(after)
            assert set(a) == set(b)
            for name in a:
                if name != 'ordinaryMaskBounds': assert old.token_text(a[name]) == old.token_text(b[name]), name
            assert old.token_text(b['ordinaryMaskBounds']) == old.token_text(expected_readback_method()), 'Target source differs from whitelist-only change'
            unchanged[cls] = len(a)-1
    sig, header, tags = helper.support.raw_swf(BASE / 'pfe.swf')
    fsig, fheader, final = helper.support.raw_swf(out / 'pfe.swf')
    assert sig == fsig and header == fheader and len(tags) == len(final)
    assert [i for i in range(len(tags)) if tags[i][2] != final[i][2]] == [332]
    result = dict(readback_integrity_passed=True, target=TARGET, unchanged_classes_methods=unchanged,
        raw_resources_preserved=True, class_list_unchanged=True, changed_tag_indices=[332],
        target_source_whitelist_only=True, source_path='after/scripts/fe/graph/Grafon.as',
        pcode_path='pcode/scripts/fe/graph/Grafon.pcode', validated=False)
    save(out / 'readback-audit.json', result)
    return result

def build(out, wait):
    out = target(out); meta = verify(out)
    assert not any((out / n).exists() for n in ('build-start.json', 'build.json', 'donor.swf', 'retained.xml', 'pfe.swf', 'after', 'pcode'))
    _, old, helper = modules()
    before, prepared_hash = installation(), sha(out / 'prepared.json')
    save(out / 'build-start.json', dict(prepared_sha256=prepared_hash, installation_before=before))
    result = dict(prepared_sha256=prepared_hash, installation_before=before, commands=[], compiled=False,
        build_checks_passed=False, validated=False, air_started=False, installed=False,
        gameplay_qualified=False, performance_qualified=False)
    sys.path.insert(0, str(ROOT.parent / 'ModLoader/tools'))
    sys.path.insert(0, str(ROOT / 'tools/validation'))
    from test_registry import Registration
    from runtime_memory import snapshot, wait_owned
    failure = None
    try:
        with Registration(owner='RConnect / 普通蒙版单方法修正', resource='game',
                purpose='One whitelist body retained over exact host05; no AIR/install', run_dir=out,
                evidence=out / 'build.json', wait=wait) as record:
            def ready(name):
                verify(out)
                memory = snapshot(); save(out / (name + '.memory-before.json'), memory)
                assert memory['free_commit_bytes'] >= 1024**3, 'Less than 1 GiB before ' + name
            for command in commands(out):
                name = command['name']; ready(name)
                item = dict(command, pid=None, exit_code=None, reaped=False); result['commands'].append(item)
                process = None
                stdout_path = out / ('after-classes.txt' if name == 'final-classes' else name + '.log')
                stderr_path = out / (name + '.stderr.log')
                with stdout_path.open('x', encoding='utf-8') as stdout, stderr_path.open('x', encoding='utf-8') as stderr:
                    try:
                        record.before_launch('FFDec ' + name)
                        process = subprocess.Popen(command['argv'], cwd=out, stdout=stdout, stderr=stderr, creationflags=subprocess.CREATE_NO_WINDOW)
                        item['pid'] = process.pid; record.child(process.pid)
                        item['exit_code'] = wait_owned(process, 300, out / (name + '.memory-timeline.json'))
                    finally:
                        if process is not None:
                            if process.poll() is None: process.kill()
                            process.wait(); item['reaped'] = process.poll() is not None
                        record.child_stopped()
                assert item['exit_code'] == 0 and item['reaped'], item
                for path in (stdout_path, stderr_path):
                    assert not any(word in text(path) for word in ('SEVERE:', 'Unknown preprocessor instruction', 'Exception in thread')), str(path)
                if name == 'donor-xml':
                    ready('retain'); result['retain'] = helper.retain(BASE / 'final.xml', out / 'donor.xml', out / 'retained.xml')
                    assert result['retain']['passed']; save(out / 'retain.json', result['retain'])
                if name == 'serialized-xml':
                    ready('serialized-audit'); result['serialized_audit'] = helper.audit(BASE / 'final.xml', out / 'serialized.xml', out / 'retained.xml')
                    assert result['serialized_audit']['passed']; save(out / 'serialized-audit.json', result['serialized_audit'])
                    ready('splice'); result['splice'] = helper.splice(BASE / 'pfe.swf', out / 'serialized.swf', out / 'pfe.swf')
                    assert result['splice']['passed']; save(out / 'splice.json', result['splice'])
                    result.update(compiled=True, candidate_sha256=sha(out / 'pfe.swf'))
                if name == 'final-xml':
                    ready('method-audit'); result['method_audit'] = helper.audit(BASE / 'final.xml', out / 'final.xml', out / 'retained.xml')
                    assert result['method_audit']['passed']; save(out / 'method-audit.json', result['method_audit'])
            ready('readback-audit'); result['readback_audit'] = readback(out)
            result['build_checks_passed'] = True; record.outcome = 'passed'
            record.note = 'One method/resources/readback retained; independent admission and native tests pending'
    except BaseException as exc:
        failure = exc; result.update(error_type=type(exc).__name__, error=str(exc))
    finally:
        try:
            result['installation_after'] = installation()
            result['installation_unchanged'] = result['installation_after'] == before
            verify(out)
            result['inputs_unchanged'] = sha(out / 'prepared.json') == prepared_hash
            if not result['installation_unchanged'] or not result['inputs_unchanged']:
                raise AssertionError('Final input/installation drift')
        except BaseException as exc:
            failure = failure or exc; result.update(build_checks_passed=False, final_check_error=str(exc))
        result['artifacts'] = {p.relative_to(out).as_posix(): sha(p) for p in sorted(out.rglob('*')) if p.is_file()}
        save(out / 'build.json', result)
    if failure: raise failure
    return verify_result(out)

def verify_result(out):
    out = target(out); verify(out)
    if not (out / 'build.json').exists(): return dict(compiled=False, validated=False, prepared_verified=True)
    result = read(out / 'build.json')
    assert result['prepared_sha256'] == sha(out / 'prepared.json')
    for name, digest in result['artifacts'].items():
        path = (out / name).resolve(); assert path.is_relative_to(out) and sha(path) == digest, name
    assert all(result[k] is True for k in ('compiled', 'build_checks_passed', 'inputs_unchanged', 'installation_unchanged'))
    assert result['installation_before'] == result['installation_after'] == installation()
    assert len(result['commands']) == 8 and all(x['exit_code'] == 0 and x['reaped'] for x in result['commands'])
    assert [dict(name=x['name'], argv=x['argv']) for x in result['commands']] == commands(out)
    for key, name in (('retain', 'retain.json'), ('serialized_audit', 'serialized-audit.json'), ('splice', 'splice.json'),
                      ('method_audit', 'method-audit.json'), ('readback_audit', 'readback-audit.json')):
        assert result[key] == read(out / name)
        assert result[key]['readback_integrity_passed' if key == 'readback_audit' else 'passed'] is True
    assert result['method_audit']['target'] == TARGET
    assert result['candidate_sha256'] == sha(out / 'pfe.swf')
    assert all(result[k] is False for k in ('validated', 'air_started', 'installed', 'gameplay_qualified', 'performance_qualified'))
    return result

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=DEFAULT)
    parser.add_argument('--registry-wait', type=float, default=900)
    mode = parser.add_mutually_exclusive_group(required=True)
    for name in ('prepare', 'build', 'verify'): mode.add_argument('--' + name, action='store_true')
    args = parser.parse_args(); assert args.registry_wait >= 0
    out = target(args.output)
    if args.prepare: prepare(out); result = dict(prepared=True, compiled=False, validated=False)
    elif args.build: result = build(out, args.registry_wait)
    else: result = verify_result(out)
    print(json.dumps({k: result[k] for k in ('prepared', 'prepared_verified', 'compiled', 'build_checks_passed', 'validated', 'candidate_sha256') if k in result}))

if __name__ == '__main__': main()

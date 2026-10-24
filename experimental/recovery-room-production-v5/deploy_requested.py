"""Install the exact existing candidate at the user's explicit request, before final performance acceptance."""
from pathlib import Path
import argparse, hashlib, importlib.util, json, os, sys, time, uuid

if sys.flags.optimize:
    raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT.parents[1]
PRODUCT = ROOT/'build/m52/recovery-room-production-05'
RELEASE = ROOT/'release/RConnectMod.swf'
KEY = 'mods/Rconnect/release/RConnectMod.swf'
OLD = 'df0fa0e2ca952e77e5132e75d71e73558dc919c7b8cdeba5da05fc9e94dc01e7'
NEW = '78c052aea963f1689b705ae1e14d274916ae1a1f7e81933390caf8d1a88f4699'

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))

def save(path, value):
    with Path(path).open('x', encoding='utf-8') as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.write('\n')
        stream.flush()
        os.fsync(stream.fileno())

def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

def audit():
    verifier = load('roomfix5_deploy_tint', ROOT/'experimental/recovery-room-mask-native/current_tint_verifier.py')
    before = verifier.installation()
    assert before[KEY] == OLD and sha(RELEASE) == OLD
    historical = verifier.build_environment()
    prepared, compiled = read(PRODUCT/'prepared.json'), read(PRODUCT/'compile.json')
    assert compiled['compiled'] and compiled['sources_unchanged'] and compiled['installation_unchanged']
    assert sha(PRODUCT/'RConnectMod.swf') == NEW == compiled['candidate_sha256']
    assert prepared['version'] == '0.2.24-roomfix5'
    for folder, section in (('src', 'source'), ('tools', 'inputs')):
        observed = {p.relative_to(PRODUCT/folder).as_posix(): sha(p)
                    for p in (PRODUCT/folder).rglob('*') if p.is_file()}
        assert observed == prepared[section], folder
    overlay = load('roomfix5_exact_overlay', ROOT/'experimental/recovery-room-production-v5/prepare.py')
    manifest = overlay.verify()
    assert prepared['source'] == manifest['candidate_source']
    return verifier, before, dict(candidate_sha256=NEW, version='0.2.24-roomfix5',
        candidate=str(PRODUCT/'RConnectMod.swf'), prepared_sha256=sha(PRODUCT/'prepared.json'),
        compile_sha256=sha(PRODUCT/'compile.json'), overlay_manifest_sha256=sha(ROOT/'experimental/recovery-room-production-v5/source-manifest.json'),
        source=prepared['source'], historical_build_environment=historical,
        current_host_transition_proof=verifier.proof_inputs(), deployment_script_sha256=sha(__file__))

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output', type=Path, required=True)
    args = ap.parse_args()
    out = (ROOT/args.output).resolve()
    assert out.parent == ROOT/'build/m52' and not out.exists()
    assert out.name == 'recovery-room-user-deploy-01'
    verifier, before, proof = audit()
    out.mkdir()
    save(out/'audit.json', proof)
    sys.path.insert(0, str(GAME/'mods/ModLoader/tools'))
    from test_registry import Registration
    # File replacement only; does not launch or claim to run a game test.
    with Registration(owner='RConnect / 用户要求先部署', purpose='Atomic RC-only install; native/performance acceptance remains pending',
                      run_dir=out, evidence=out/'deployment.json', resource='offline', wait=0) as record:
        backup = out/'RConnectMod.before.swf'
        temporary = RELEASE.with_name('RConnectMod.swf.roomfix5-'+uuid.uuid4().hex+'.tmp')
        replaced = False
        temporary_owned = False
        assert not temporary.exists()
        expected = dict(before); expected[KEY] = NEW
        state = dict(status='not-installed', version=proof['version'], before_sha256=OLD, candidate_sha256=NEW,
            release=str(RELEASE), candidate=proof['candidate'], backup=str(backup),
            installation_before=before, expected_installation_after=expected,
            registry_id=record.id, user_requested_deploy_before_final_validation=True,
            authorization='先部署，再按房间加载、同步、原版耗时与git性能回退任务继续',
            performance_qualified=False, native_mask_regression_passed=False, smoke_status='pending',
            audit_sha256=sha(out/'audit.json'), utc_ms=int(time.time()*1000))
        try:
            assert verifier.installation() == before
            with backup.open('xb') as stream:
                stream.write(RELEASE.read_bytes()); stream.flush(); os.fsync(stream.fileno())
            assert sha(backup) == OLD
            with temporary.open('xb') as stream:
                temporary_owned = True
                stream.write((PRODUCT/'RConnectMod.swf').read_bytes()); stream.flush(); os.fsync(stream.fileno())
            assert sha(temporary) == NEW and sha(RELEASE) == OLD
            save(out/'deployment-intent.json', state)
            assert verifier.installation() == before and sha(temporary) == NEW
            os.replace(temporary, RELEASE)
            temporary_owned = False
            replaced = True
            assert sha(RELEASE) == NEW
            from run_security_terminals import installation
            after = installation()
            assert after == expected
            state.update(status='user-requested-installed', installation_after=after,
                         backup_sha256=sha(backup), release_sha256=sha(RELEASE))
            record.outcome='completed'
            record.note='Only RC replaced after backup; user requested installation before final acceptance, not a test pass'
        except BaseException as error:
            state['error'] = repr(error)
            if replaced and sha(RELEASE) == NEW:
                assert sha(backup) == OLD
                if temporary_owned and temporary.exists(): temporary.unlink()
                temporary_owned = False
                with temporary.open('xb') as stream:
                    temporary_owned = True
                    stream.write(backup.read_bytes()); stream.flush(); os.fsync(stream.fileno())
                os.replace(temporary, RELEASE)
                temporary_owned = False
                assert sha(RELEASE) == OLD
                state['status'] = 'rolled-back'
            raise
        finally:
            if temporary_owned and temporary.exists(): temporary.unlink()
            state['release_sha256_final'] = sha(RELEASE)
            save(out/'deployment.json', state)
    print(json.dumps(dict(status=state['status'], release_sha256=state['release_sha256_final'],
                          receipt=str(out/'deployment.json'), performance_qualified=False)))

if __name__ == '__main__':
    main()

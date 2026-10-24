"""Keep roomfix5's ABE2 compilation distinct from the verified A796 runtime."""
import hashlib
import json
from pathlib import Path
import sys

if sys.flags.optimize:
    raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT, GAME = HERE.parents[1], HERE.parents[1].parents[1]
PRODUCT = ROOT/'build/m52/recovery-room-production-05'
CS = GAME/'mods/ContinuousScene'
RECEIPT = CS/'state/scene-tint-deployment-20261024.json'
BUILD = CS/'build/generated/scene-compat-20261024/tint/product'
CANDIDATE = CS/'knowledge/experiments/evidence/tint-components-20261024-candidate-r1/summary.json'
SMOKE = CS/'knowledge/experiments/evidence/tint-components-20261024-installed-r1/summary.json'
OLD_HOST = 'abe2b65edf3d0e4e0fa8eca76a60e577d40e47f20b9acecebec7730849a2602a'
NEW_HOST = 'a796827173af7d6fab9885fb66ecc62182ab5335918a30c7cce4c44914a238b7'
PRODUCT_SHA = '78c052aea963f1689b705ae1e14d274916ae1a1f7e81933390caf8d1a88f4699'
METHODS = ['fe.graph.Grafon::0:1:sceneUpdateEntityColor', 'fe.graph.Grafon::0:1:sceneEntitySameColor']
PINS = {
    PRODUCT/'prepared.json': 'acdc405a6e214531831cbb532178337aaa7fb9f154a91a1f8b543a6480dd6c58',
    PRODUCT/'compile.json': '68fcca0717bd9800725822211650c6fd74787a98a839432b5ed0216cb0ae48d4',
    RECEIPT: 'b88e98557b9ddf87caffe6f625a4c0e687f44ebc52b9baa40b4fb6f3cbce3b12',
    BUILD/'build.json': '7b62c88f5c918e07dda31178df788cd2195ace4b092cfbba8f9be087105ea74d',
    BUILD/'semantic-audit.json': '0a24c942735d105956dac367b8097a34e1da57f747403080493c917b61f5cf83',
    BUILD/'predicate-proof.json': '9ab2e34123c1da1e912ea177beb4b3bf2f000d4477c7f48927386a3dc87870a4',
    CANDIDATE: 'ad6b929a1b77ed075b89a62ba1fbddfa3e316dbebe8502b371dc5ae1d817dbeb',
    SMOKE: 'a0db3947c439d9f1a74df28d8a3ca45c88e2962a2ef29934b97806566cb2d825',
}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def normalized(values):
    return {n.replace('\\', '/').lower(): h.lower() for n, h in values.items()}


def build_environment():
    """Historical bytes from the completed product build, never current install."""
    for path in (PRODUCT/'prepared.json', PRODUCT/'compile.json'):
        assert sha(path) == PINS[path], str(path)
    prepared, compiled = read(PRODUCT/'prepared.json'), read(PRODUCT/'compile.json')
    assert prepared['version'] == '0.2.24-roomfix5'
    assert compiled['compiled'] is True and compiled['sources_unchanged'] is True
    assert compiled['installation_unchanged'] is True and compiled['candidate_sha256'] == PRODUCT_SHA
    assert len(compiled['commands']) == 2 and all(c['exit_code'] == 0 for c in compiled['commands'])
    before = prepared['installation_before']
    assert before == compiled['installation_before'] == compiled['installation_after']
    assert len(before) == 22 and before['pfe.swf'] == OLD_HOST
    assert before['mods/Rconnect/release/RConnectMod.swf'] == 'df0fa0e2ca952e77e5132e75d71e73558dc919c7b8cdeba5da05fc9e94dc01e7'
    assert before['mods/RealisticVision/release/RealisticVisionMod.swf'] == '0dbe0d7a95b8e496fb393d7fcd75f88d60c34a1d0fabb33266b122e3fa04f2bf'
    return dict(before)


def proof_inputs():
    """Read only fixed receipts/small sources; do not rescan a mod tree."""
    for path, digest in PINS.items():
        assert sha(path) == digest, str(path)
    r, b, a = read(RECEIPT), read(BUILD/'build.json'), read(BUILD/'semantic-audit.json')
    assert r['status'] == 'verified' and r['scope'] == ['root pfe.swf']
    assert r['base'].lower() == b['base'].lower() == a['baseSHA256'].lower() == OLD_HOST
    assert r['candidate'].lower() == b['candidate'].lower() == a['candidateSHA256'].lower() == NEW_HOST
    assert Path(r['buildReceipt']).resolve() == (BUILD/'build.json').resolve()
    assert r['buildReceiptSHA256'].lower() == PINS[BUILD/'build.json']
    assert b['audit'].lower() == PINS[BUILD/'semantic-audit.json']
    assert b['exactPredicateProof'].lower() == PINS[BUILD/'predicate-proof.json']
    assert b['productionCandidate'] is True and b['diagnosticOnly'] is False
    assert b['targets'] == a['auditTargets'] == a['actualChangedBodies'] == a['allowedChangedMethods'] == METHODS
    assert a['passed'] is True and a['unchangedMethodBodies'] == 5769 and a['unchangedClassLayouts'] == 1016
    assert a['addedFields'] == a['addedMethods'] == [] and a['newMethods'] == a['newFields'] == 0
    for key in ('methodAndClassIndicesPreserved', 'originalConstantPoolPreserved', 'nonABCSWFEnvelopePreserved',
                'preservedOriginalLayout', 'constructorsPreserved', 'originalBranchesPreserved', 'originalPrivateIdentitiesPreserved'):
        assert a[key] is True, key
    assert a['importedClassCopied'] is False
    before, after = normalized(r['installedInputsBefore']), normalized(r['installedInputsAfter'])
    changed = {n for n in before.keys() | after.keys() if before.get(n) != after.get(n)}
    assert changed == {'pfe.swf'} and before['pfe.swf'] == OLD_HOST and after['pfe.swf'] == NEW_HOST
    for name, digest in normalized(build_environment()).items():
        assert before[name] == digest and after[name] == (NEW_HOST if name == 'pfe.swf' else digest), name
    assert (Path(r['candidateEvidence'])/'summary.json').resolve() == CANDIDATE.resolve()
    assert r['candidateSummarySHA256'].lower() == PINS[CANDIDATE]
    assert Path(r['smokeSummary']).resolve() == SMOKE.resolve() and r['smokeSummarySHA256'].lower() == PINS[SMOKE]
    for path, kind in ((CANDIDATE, 'candidate'), (SMOKE, 'installed')):
        summary = read(path)
        assert summary['qualification']['passed'] is True and summary['componentsOnly'] is True
        assert summary['hostKind'] == kind and summary['hostSHA256'].lower() == NEW_HOST
        assert summary['performanceEligible'] is False and summary['performanceAcceptance'] is False
        v = summary['verification']
        assert v['passed'] is True and v['expectFixed'] is True and v['terminalOnly'] is True
        assert len(v['cases']) == 20 and len({row['name'] for row in v['cases']}) == 20
        assert all(row['passed'] is True for row in v['cases'])
    smoke = read(SMOKE)
    assert smoke['installedHostSHA256'].lower() == NEW_HOST and smoke['candidateBaseSHA256'].lower() == OLD_HOST
    assert smoke['installedPathSmoke'] is True and smoke['copiedActualInstalledHost'] is True
    pins = {str(path): digest for path, digest in PINS.items()}
    for table in (b['sourceInputs'], r['smokeInputs']):
        for path, digest in table.items():
            assert sha(path) == digest.lower(), path
            pins[path] = digest.lower()
    return pins


def installation():
    proof_inputs()
    sys.path.insert(0, str(ROOT/'tools/validation'))
    from run_security_terminals import installation as actual
    expected = build_environment()
    expected['pfe.swf'] = NEW_HOST
    value = actual()
    assert value == expected, 'Runtime changed beyond the verified ABE2 -> A796 host transition'
    return value


def evidence():
    return dict(kind='roomfix5-abe2-build-a796-runtime', product_sha256=PRODUCT_SHA,
                compile_installation=build_environment(), runtime_installation=installation(),
                proof_inputs=proof_inputs(), compile_relabelled_as_runtime=False,
                new_native_mask_test_passed=False, performance_qualified=False)

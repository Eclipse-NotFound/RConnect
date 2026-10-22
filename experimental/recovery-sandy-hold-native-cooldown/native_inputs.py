"""One nonzero-cooldown variant; exact existing RV83 / early2 / host03 / Sand003."""
from pathlib import Path
import hashlib,importlib.util,json

HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];M52=ROOT/'build/m52'
OLD=HERE.parent/'recovery-sandy-hold-native-lifecycle'
BASE=HERE.parent/'recovery-paint-native-cpu-rv83-v2/baseline.py'
CANDIDATE=M52/'recovery-early-exit-compile-01'
HOST=M52/'recovery-early-paint-host-03'
HOST_SHA='29d36cdd94aadc5368156f80e854808d78b74baf8347ebfcc80c644d73601ef7'
REVIEW=M52/'recovery-early-paint-host-recheck-03/receipt.json'
REVIEW_SHA='1a1c83a3910576e62be8dc21aaa21988ff6c33f81ded9d6b3cbd83a008a11b2c'
CONFIG=ROOT.parent/'Sandevistan/release/config.txt'
CONFIG_SHA='d91c4c2889aba19b1bcfb356885921b0605a50188b270a9e7619d2116e7ebdc3'
COOLDOWN=120

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text(encoding='utf-8-sig'))
def save(p,v):Path(p).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def once(text,old,new):
    assert text.count(old)==1,('Exact adaptation mismatch',old,text.count(old))
    return text.replace(old,new,1)
assert sha(BASE)=='89321d66502193e11816501e1d56329015846180a6fe2dea330fa6380eab3b81'
spec=importlib.util.spec_from_file_location('cooldown_exact_rv83_baseline',BASE)
baseline=importlib.util.module_from_spec(spec);spec.loader.exec_module(baseline)
installation=baseline.installation

def verify_tools():
    pins=read(HERE/'inputs.json')
    for n,h in pins['sources'].items():assert sha(HERE/n)==h,n
    for n,h in pins['originals'].items():assert sha(n)==h,n
    baseline.verify_tools()
    assert sha(CONFIG)==CONFIG_SHA
    return pins
def audit(path):verify_tools();return baseline.audit(path)
def sandy_input(mode):verify_tools();return baseline.sandy_input(mode)
def frozen_vision():verify_tools();return baseline.frozen_vision()

def host_input(path,installed):
    verify_tools();assert path.resolve()==HOST.resolve()
    assert sha(REVIEW)==REVIEW_SHA
    review=read(REVIEW);meta=read(HOST/'prepared.json')
    assert all(review[k] is True for k in ('compiled','source_readback_passed','pcode_bindings_passed',
        'exception_cfg_passed','validated','installation_unchanged','source_unchanged'))
    assert review['candidate_sha256']==meta['candidate_sha256']==sha(HOST/'pfe.swf')==HOST_SHA
    assert review['builder_manifest_sha256']==sha(HOST/'prepared.json')==baseline.HOST_MANIFEST_SHA
    assert meta['compiled'] and meta['source_readback_passed'] and meta['pcode_syntax_passed']
    assert meta['diagnostic_only'] and meta['source_unchanged'] and meta['installation_unchanged']
    assert meta['patched_classes']==['fe.graph.Grafon'] and meta['base_sha256']==baseline.original.HOST_SHA
    source='eb487597d89073d61e1dffc7789c46130379c45276a9fde5f180008d87e0f960'
    assert meta['import_sources']=={'fe/graph/Grafon.as':source}
    assert sha(HOST/'import/fe/graph/Grafon.as')==source
    for mapping in (meta['inputs'],meta['readback_files'],review['inputs'],review['readback_files']):
        assert mapping
        for n,h in mapping.items():
            p=Path(n);assert sha(p if p.is_absolute() else HOST/p)==h,n
    assert HOST_SHA in review['inputs'].values()
    assert set(review['readback_files'].values()) >= {sha(HOST/'after/scripts/fe/graph/Grafon.as'),sha(HOST/'pcode/scripts/fe/graph/Grafon.pcode')}
    assert installation()==installed==baseline.expected_installation()
    base=baseline.original.host_input(baseline.original.HOST,installed)
    return dict(directory=str(HOST),candidate_sha256=HOST_SHA,manifest_sha256=sha(HOST/'prepared.json'),
        recheck=str(REVIEW),recheck_sha256=REVIEW_SHA,original_sha256=installed['pfe.swf'],base=base,
        source_inputs_unchanged=True,diagnostic_only=True,performance_qualified=False,
        paint_observer_used=False)
def verify_host_intent(path,intent,installed):
    assert host_input(path,installed)==intent
    audit(CANDIDATE)

def config_bytes(raw):
    assert hashlib.sha256(raw).hexdigest()==CONFIG_SHA
    assert raw.splitlines().count(b'cooldown=0')==1 and raw.count(b'cooldown=0')==1
    return raw.replace(b'cooldown=0',b'cooldown=120',1)
def configure_sand(frozen,output):
    path=frozen/'mods/Sandevistan/release/config.txt'
    raw=path.read_bytes();changed=config_bytes(raw)
    path.write_bytes(changed)  # Only this invocation's isolated snapshot.
    save(output/'cooldown-config.json',dict(original_sha256=CONFIG_SHA,isolated_sha256=sha(path),
        changed_key='cooldown',old=0,new=COOLDOWN,installed_unchanged=sha(CONFIG)==CONFIG_SHA))

def queued_gate(args,output):
    receipt=dict(passed=False,air_started=False,private_copies_built=False,phase='registered before private copies')
    try:
        verify_tools();intent=read(Path(args.effects_driver).resolve().parent/'intent.json')
        actual=installation();receipt.update(expected=intent['installation'],actual=actual)
        assert actual==intent['installation']==baseline.expected_installation() and len(actual)==22
        assert args.solo and args.all_mods and args.effects and args.require_exclusive_air
        assert args.candidate.resolve()==(CANDIDATE/'RConnectMod.swf').resolve()
        assert args.game_candidate.resolve()==(HOST/'pfe.swf').resolve()
        assert args.vision_candidate.resolve()==frozen_vision().resolve()
        assert args.sandy_candidate.resolve()==Path(sandy_input('bridge')['candidate']).resolve()
        assert audit(CANDIDATE)['sha256']==intent['candidate_sha256']
        verify_host_intent(HOST,intent['host'],actual)
        assert sandy_input('bridge')==intent['sandy']
        assert sha(Path(args.effects_driver)/'EffectsDriver.swf')==intent['driver_sha256']
        receipt['passed']=True
    except BaseException as e:
        receipt.update(error_type=type(e).__name__,error=str(e))
        for name in ('installation-gate.json','error.json','result.json'):save(output/name,receipt)
        raise
    save(output/'installation-gate.json',receipt)

def audit_row(row):
    assert row['passed'] is True and row['checks']==43 and row['failed']==0
    assert row['holdFrames']==12 and row['keyboardCode']==220
    assert row['cooldownFreezeQualified'] is True and row['cooldownAdvanced'] is True
    assert row['enemyManualStepQualified'] is False and row['travelFallbackQualified'] is False
    assert row['functionOnly'] is True and row['performanceQualified'] is False
    rows=row['observations'];held=[r for r in rows if r['label']=='held-frame']
    assert len(held)==12 and [r['phaseFrame'] for r in held]==list(range(1,13))
    start=[r for r in rows if r['label']=='held'];assert len(start)==1
    initial=start[0]['state'];assert 0<initial['cooldownLeft']<=COOLDOWN
    assert initial['enemyEnabled'] is False and initial['debugTest'] is False
    assert all(r['state']==initial and r['controls']==start[0]['controls'] for r in held)
    assert initial['held'] is True and initial['phase']=='idle'
    release=[r for r in rows if r['label']=='cooldown'];assert len(release)==1
    assert release[0]['state']['held'] is False and release[0]['state']['cooldownLeft']==initial['cooldownLeft']
    progress=[r for r in rows if r['label']=='cooldown-progress'];assert len(progress)==1
    assert progress[0]['phaseFrame']==8 and progress[0]['state']['held'] is False
    assert 0<progress[0]['state']['cooldownLeft']<initial['cooldownLeft']
    zero=[r for r in rows if r['label']=='cooldown-zero'];assert len(zero)==1
    assert zero[0]['state']['phase']=='idle' and zero[0]['state']['held'] is False and zero[0]['state']['cooldownLeft']==0
    assert release[0]['frame']<progress[0]['frame']<zero[0]['frame']
    assert [v['kind'] for v in row['keyEvents'] if v['phase']=='held']==['down','down','up']
    keys=[v for v in row['keyEvents'] if v['phase']=='cooldown']
    assert [v['kind'] for v in keys]==['down','up'] and all(v['frame']==zero[0]['frame'] for v in keys)
    assert row['cleanup']['final']['held'] is False and row['cleanup']['final']['phase']=='idle'
    return True

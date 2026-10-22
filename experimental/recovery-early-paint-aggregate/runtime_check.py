"""Offline-only baseline/runtime-adapter audit. No freeze, JVM or AIR."""
from pathlib import Path
import json
import baseline
import runtime_adapter

HERE=Path(__file__).resolve().parent

def rejects(fn):
    try:fn()
    except (AssertionError,KeyError,ValueError,FileNotFoundError):return True
    raise AssertionError('A negative admission case was accepted')

def check_core():
    evidence=baseline.verify_tools();current=evidence['installation']
    previous=baseline.read(baseline.HOST_MANIFEST)['installation_before']
    baseline.assert_current(current,previous)
    old=dict(previous);old[baseline.RV_KEY]=baseline.RV_OLD
    baseline.assert_current(current,old)
    baseline.assert_current(current,current)
    negatives=[]
    cases={
      'installed-old-AB46':dict(current,**{baseline.RV_KEY:baseline.RV_PREVIOUS}),
      'installed-test-7852':dict(current,**{baseline.RV_KEY:baseline.RV_OLD}),
      'installed-other-RV':dict(current,**{baseline.RV_KEY:'0'*64}),
      'installed-other-mod':dict(current,**{'mods/Rconnect/release/RConnectMod.swf':'0'*64}),
      'installed-missing':{k:v for k,v in current.items() if k!='pfe.swf'},
      'installed-added':dict(current,unapproved='0'*64)}
    for name,value in cases.items():
        rejects(lambda v=value:baseline.assert_current(v,previous));negatives.append(name)
    for name,value in (
       ('source-other-RV',dict(previous,**{baseline.RV_KEY:'0'*64})),
       ('source-other-mod',dict(previous,**{'pfe.swf':'0'*64}))):
        rejects(lambda v=value:baseline.assert_current(current,v));negatives.append(name)
    assert baseline.sha(baseline.frozen_vision())==baseline.RV_OLD
    candidate=baseline.ROOT/'build/m52/recovery-early-exit-compile-01'
    audited=baseline.audit(candidate)
    assert audited['sha256']=='d356483f927c608b5973982558127ce4feb0873a36676909ed3b3d6ac8b7acb3'
    sand=baseline.sandy_input('bridge')
    assert sand['candidate_sha256']=='3e220b595f54249c82fcad36e1b13364c0456c4e8b5f4e20f876c3964c7d331c'
    rejects(lambda:baseline.sandy_input('legacy'));negatives.append('legacy-sand-mode')
    driver_path,_=baseline.original.verify_original_driver()
    host=baseline.original.host_input(baseline.original.HOST,current)
    assert host['candidate_sha256']=='2d415dd373236fff3c7a691db4eff8327a6de97b91c23d8a818ec77082b3dd29'
    original=runtime_adapter.original_paint_source();adapted=runtime_adapter.outer_source()
    assert adapted.count(runtime_adapter.NEW_RUNNER)==1
    reversed_source=baseline.replace_once(adapted,runtime_adapter.NEW_RUNNER,runtime_adapter.OLD_RUNNER)
    assert reversed_source.count(repr(runtime_adapter.KIND))==2
    reversed_source=reversed_source.replace(repr(runtime_adapter.KIND),"'ensure-work'",2)
    assert reversed_source==original
    runner=runtime_adapter.runner_source()
    assert runner==runtime_adapter.RUNNER.read_text(encoding='utf-8-sig')
    for old in ('--require-exclusive-air','len(r[\'rows\'])==3','process.returncode==0','result[\'passed\']=result[\'passed\'] and result[\'profile_valid\']'):
        assert old in adapted,old
    for name,value in [('missing-exact-marker',''),('duplicate-exact-marker','x x')]:
        rejects(lambda v=value:baseline.replace_once(v,'x','y'));negatives.append(name)
    compile(adapted,'aggregate-outer-source','exec')
    compile(runner,'aggregate-unchanged-runner','exec')
    assert baseline.installation()==current
    return dict(installed_rv_sha256=baseline.RV_NEW,runtime_rv_sha256=baseline.RV_OLD,
       unchanged_installation_fields=21,original_scene_driver=str(driver_path),
       early2_sha256=audited['sha256'],sand_sha256=sand['candidate_sha256'],
       original_host_audit_reused=True,outer_adapter_reversible=True,unchanged_native_runner=True,
       baseline_negative_cases=negatives,air_started=False,jvm_started=False,runtime_frozen=(HERE/'runtime-inputs.json').exists())

def check_admission():
    import native_inputs as n
    baseline.verify_tools()
    reviewed=n.read(n.REVIEW)
    receipt_sha=baseline.sha(n.REVIEW)
    result,files=n.validate_host(n.HOST,baseline.installation(),receipt_sha)
    assert result['candidate_sha256']==n.HOST_SHA=='29d36cdd94aadc5368156f80e854808d78b74baf8347ebfcc80c644d73601ef7'
    negatives=[]
    for flag in n.QUALIFICATION_FIELDS:
        bad=dict(reviewed);bad[flag]=False
        rejects(lambda v=bad:n.qualified_review(v));negatives.append('missing-'+flag)
    rejects(lambda:n.validate_host(n.HOST,baseline.installation(),'0'*64));negatives.append('wrong-review-hash')
    rejects(lambda:n.validate_host(n.HOST.parent/'recovery-early-paint-host-02',baseline.installation(),receipt_sha));negatives.append('rejected-host02')
    assert result['independent_diagnostic_validated'] and files
    if not (HERE/'runtime-inputs.json').exists():
        rejects(n.verify_tools);negatives.append('unfrozen-runtime-refused')
    return dict(host03_validated=True,review_sha256=receipt_sha,reviewed_file_count=len(files),admission_negative_cases=negatives)

def check_runtime_profile():
    """Additional runtime restrictions never rewrite the frozen source audit."""
    import native_inputs as n
    import audit_checks as fixtures
    assert n.profile.__file__==str(HERE/'audit_runtime.py')
    originals=baseline.read(HERE/'inputs.json')['sources']
    for name in ('audit_profile.py','audit_checks.py'):
        assert baseline.sha(HERE/name)==originals[name]
    positive=fixtures.fixture()
    assert n.profile.audit_profiles(positive,fixtures.travels(positive))['valid']
    def one_call_shortened(p):
        p['buckets'][0].update(calls=1,positiveMsCalls=1,totalMs=2,maxMs=2,
            firstCall=2,lastCall=2,firstStarted=20,lastFinished=25,
            firstStartedWall=1020,lastFinishedWall=1025)
        p.update(targetCalls=2,observedCalls=2,positiveMsCalls=2,inclusiveTotalMs=7)
    mutations=(
        ('row-and-bucket-share-call-index',lambda p:p['buckets'][0].__setitem__('firstCall',1)),
        ('single-call-bucket-understates-work',one_call_shortened),
        ('unbound-profile-claims-target-calls',lambda p:p.__setitem__('rasterRoomBound',False)))
    negatives=[]
    for name,mutate in mutations:
        value=fixtures.fixture();mutate(value[0]);travels=fixtures.travels(value)
        # Each was a real gap in the immutable old audit, not an unrelated failure.
        assert fixtures.audit_profiles(value,travels)['valid']
        rejects(lambda:n.profile.audit_profiles(value,travels));negatives.append(name)
    old=baseline.ROOT/'build/cooperation/84ff2d9da3/host.log'
    before=baseline.sha(old)
    rejects(lambda:n.paint_audit_log(old));negatives.append('original-84ff2d9da3-partial-failure')
    assert baseline.sha(old)==before
    return dict(runtime_profile_positive_passed=True,runtime_profile_negative_cases=negatives,
        frozen_source_audits_unchanged=True,old_failure_log_sha256=before)

if __name__=='__main__':
    result=check_core()
    result.update(check_admission())
    result.update(check_runtime_profile())
    print(json.dumps(result,ensure_ascii=False))

"""Install the specifically user-requested candidate, retaining failed performance evidence.

This does not produce a normal release qualification. The user said directly
"直接部署" after the density failure was explained. Integrity, current-baseline
security checks, backup and installed-loader smoke remain mandatory.
"""
from check_coop_bundle import M52, ROOT, read, save, sha, verify
from release_coop_bundle import check_log, deploy, GAME
from run_security_terminals import installation


def main():
    candidate=M52/'coop-bundle-04'
    native=M52/'security-native-03'
    tested=M52/'coop-bundle-rebase-security-01'
    manifest=verify(candidate)
    assert sha(candidate/'prepared.json')=='4d0743b2fdd61586b22193c431e5d5fba534d77ca33e0bc5483b2f286ae112b1'
    assert sha(candidate/'RConnectMod.swf')==manifest['sha256']=='574d2b51490ae8b25a1396555600f56a301f8a20ae50104c0e35cf2796441afe'
    assert manifest['held_features']==['peer-port'] and not manifest.get('diagnostic_only')
    patch=read(native/'prepared.json')
    assert sha(native/'pfe.swf')==patch['candidate_sha256']=='02bfabe6a3b4881dfa1227515e71f2a8ea863d4b1b468fbe1d8008aeba7d9240'
    assert patch['loader_unchanged'] and patch['non_code_tags_unchanged']
    baseline=installation()
    cs_receipt=GAME/'mods/ContinuousScene/state/deployment-v08.json'
    cs=read(cs_receipt);assert cs['passed'] and cs['status']=='verified'
    for item in cs['files']:
        assert baseline[item['relative']]==item['after'].lower()
    assert baseline['pfe.swf']==patch['original_sha256']
    assert baseline['mods/Rconnect/release/RConnectMod.swf']==manifest['base_sha256']
    intent=read(tested/'intent.json');rows=read(tested/'result.json')
    assert intent['installation']==baseline and intent['native']==patch
    assert intent['candidate_sha256']==manifest['sha256'] and intent['wb'] is None
    drivers=ROOT/intent['drivers'];dm=read(drivers/'prepared.json')
    assert intent['driver_manifest']==sha(drivers/'prepared.json')
    assert dm['source_manifest']==sha(candidate/'prepared.json')
    for name,digest in dm['files'].items():assert sha(drivers/name)==digest,name
    assert len(rows)==1
    row=rows[0];assert row['name']=='security' and row['passed'] and row['exit_code']==0 and not row['installation_changes']
    folder=ROOT/'build/cooperation'/row['run'];actual=read(folder/'run.json')
    assert sha(folder/'run.json')==row['run_sha256']
    assert sha(folder/'input.json')==actual['input_manifest_sha256']
    assert not actual['solo'] and len(actual['pids'])==2
    assert not read(folder/'memory-timeline.json')['stopped_for_pressure']
    for role in ('host','join'):
        check_log(folder,role,manifest['version'])
        assert sha(folder/(role+'.log'))==row[role]['log_sha256']
        inp=actual['inputs'][role]
        assert inp['game']==patch['candidate_sha256'] and inp['production']==manifest['sha256']
        assert inp['driver']==sha(drivers/'security/EffectsDriver.swf')
        assert inp['harness']==sha(drivers/'security/EffectsHarness.swf')
        for name,digest in inp['modules'].items():
            key=name.replace('\\','/')
            assert digest==(inp['harness'] if key.lower()=='mods/rconnect/release/rconnectmod.swf' else baseline[key]),key
    summary=candidate/'regression-summary-01.json'
    old=read(summary)
    assert len(old['cases'])==24
    assert [r['case'] for r in old['cases'] if not r['passed']]==['density']
    proof=dict(version=manifest['version'],candidate_sha256=manifest['sha256'],native_sha256=patch['candidate_sha256'],
        prepared_sha256=sha(candidate/'prepared.json'),baseline=baseline,
        qualification='user-requested candidate; NOT density-performance-qualified',
        authorization=dict(user_message='直接部署',thread='01a086bb-378c-7f60-b8e1-50d90ffa0996',date='2026-10-19'),
        known_limitations=['Density performance failed on the prior composition; no claim of resolution.',
            '23 functional categories passed on prior CS baseline; current CS baseline receives security and installed-loader smoke only.'],
        held_features=manifest['held_features'],prior_regression_sha256=sha(summary),
        native_manifest_sha256=sha(native/'prepared.json'),cs_receipt_sha256=sha(cs_receipt),
        security_run=row['run'],security_result_sha256=sha(tested/'result.json'),
        recipe_sha256=sha(__file__))
    proof_path=candidate/'user-deployment-audit.json'
    assert not proof_path.exists()
    save(proof_path,proof)
    deploy(candidate,proof,native=native,proof_file=proof_path.name)


if __name__=='__main__':main()

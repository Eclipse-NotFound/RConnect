"""Retain successful, failed and externally interrupted B195 evidence as observed.

This is a forensic inventory, not a substitute for audit_suite/release gates.
No failed flag is waived or rewritten. Installation changes remain explicit.
"""
from common import ROOT, read, save, sha, verify_files
from run_probe import records
from audit_checkpoint import RuntimeFiles, require


def main():
    out = ROOT/'build/ab/qualification-195-attempts.json'
    if out.exists():
        raise FileExistsError(out)
    expected = {}
    for key, name, manifest_name, artifact, target in (
        ('build','b3-build-195','build-input.json','RConnectMod.swf','mods/Rconnect/release/RConnectMod.swf'),
        ('native','native-hooks-019','native-input.json','pfe.swf','pfe.swf'),
        ('tdfc','tdfc-build-004','build-input.json','TDFCMod.swf','mods/TDFC/release/TDFCMod.swf'),
        ('rv','rv-build-003','build-input.json','RealisticVisionMod.swf','mods/RealisticVision/release/RealisticVisionMod.swf'),
        ('msw','msw-build-011','build-input.json','MoreSkillsWeaponsMod.swf','mods/MoreSkills&Weapons/release/MoreSkillsWeaponsMod.swf'),
        ('sandy','sandy-build-001','build-input.json','SandevistanMod.swf','mods/Sandevistan/release/SandevistanMod.swf')):
        folder = ROOT/'build/ab'/name
        manifest = read(folder/manifest_name)
        verify_files(folder,manifest['sources'])
        require(sha(folder/artifact)==manifest['candidate_sha256'],'Frozen artifact changed')
        expected[key] = (sha(folder/manifest_name),target,manifest['candidate_sha256'])
    verified, attempts = {}, []
    for name in ('b3-suite-195','b3-suite-195-cont-01'):
        folder = ROOT/'build/ab'/name
        suite = read(folder/'suite.json')
        for row in suite['results']:
            run = folder/row['scenario']
            receipt = read(run/'run.json')
            require(sha(run/'run.json')==row['run_receipt_sha256'],'Original receipt changed')
            require(receipt['complete'] and receipt['owned_processes_exited']
                    and all(p['code'] is not None for p in receipt['process_exit_codes']), 'Run did not finish/exit')
            require(receipt['script_sha256']==sha(run/'tools/run_probe.py'),'Captured runner changed')
            runtime = RuntimeFiles(run,verified)
            roles = {}
            for role,value in receipt['roles'].items():
                require(value['runtime_unchanged'],'Runtime changed')
                for key,(manifest,target,digest) in expected.items():
                    require(receipt[key+'_manifest_sha256']==manifest,'Wrong frozen tuple')
                    runtime.check(role+'/'+target,digest)
                for path,digest in value['files'].items():
                    runtime.check(role+'/'+path,digest)
                runtime.check(role+'/authority-test.xml',value['descriptor_sha256'])
                runtime.check(role+'/mods/Rconnect/release/config.txt',value['config_sha256'])
                events = records(run/(role+'.log'))
                counts = {kind:sum(e['kind']==kind for e in events) for kind in ('PASS','FAIL','FATAL','error','DONE')}
                require(counts['PASS']==value['passed'] and counts['FAIL']==value['failed']
                        and bool(counts['DONE'])==value['done'],'Log summary differs')
                for path,digest in value['auxiliary_logs'].items():
                    require(sha(run/(role+'.'+path))==digest,'Auxiliary log changed')
                for path,digest in value['pictures'].items():
                    require(sha(run/'pictures'/role/path)==digest,'Retained image changed')
                roles[role] = dict(counts=counts,log_sha256=sha(run/(role+'.log')),
                    failures=[e['data'] for e in events if e['kind'] in ('FAIL','FATAL','error')])
            changes = {path:dict(before=digest,after=receipt['protected_after'].get(path))
                       for path,digest in receipt['protected_before'].items()
                       if receipt['protected_after'].get(path)!=digest}
            require(receipt['installation_unchanged']==(not changes),'Protection flag differs from fingerprints')
            attempts.append(dict(path=str(run.relative_to(ROOT)),scenario=row['scenario'],
                receipt_sha256=sha(run/'run.json'),roles=roles,runtime_bytes_verified=True,
                runner_exit=row['runner_exit'],installation_unchanged=receipt['installation_unchanged'],
                external_installation_changes=changes,original_suite_safe_cleanup=row['safe_cleanup']))
    result = dict(kind='historical-attempt-inventory',attempts=attempts,unique_archived_blobs_verified=len(verified),
        script_sha256=sha(__file__),agreed_regression_categories_complete=False,release_gate_complete=False,
        limitations=['Includes raw failures and an installation-protection failure; none is waived',
                     'Runtime bytes verified independently of external installation changes',
                     'Does not establish the cause of external changes or the bloodwing pixel mismatch'])
    save(out,result)
    print(dict(attempts=len(attempts),unique_archived_blobs_verified=len(verified),release_gate_complete=False))


if __name__=='__main__':
    main()

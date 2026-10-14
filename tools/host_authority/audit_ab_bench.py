"""Verify the completed ABBA receipt, original candidates and lossless runtime archives."""
import argparse, json
from common import ROOT, inside_build, read, save, sha, verify_files
from archive_evidence import blob_data
from analyze_ab_bench import summarize

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--series',required=True);ap.add_argument('--driver',required=True);a=ap.parse_args()
    out=inside_build(ROOT/a.series);s=read(out/'series.json');driver=inside_build(ROOT/a.driver);d=read(driver/'build-input.json')
    assert s['order']=='ABBA' and len(s['results'])==4
    verify_files(driver,d['sources']);verify_files(driver,d['files'])
    for name,h in s['scripts'].items():assert sha(ROOT/'tools/host_authority'/name)==h,name
    expected={'A':read(ROOT/'build/ab/baseline-001/baseline.json')['A_sha256'], 'B':read(ROOT/'build/ab/b3-build-193/build-input.json')['candidate_sha256']}
    checked=set();rows=[];qualification=[]
    for i,variant in enumerate('ABBA'):
        run=out/('%02d-%s'%(i+1,variant));r=read(run/'run.json');archive=read(run/'runtime-archive.json')
        assert r['driver_sha256']==sha(driver/'build-input.json') and r['variant']==variant
        assert r['installation_unchanged'] and r['owned_processes_exited'] and all(p['code'] is not None for p in r['process_exit_codes'])
        assert archive['complete'] and archive['run_receipt_sha256']==sha(run/'run.json')
        qualification.append(dict(run=run.name,errors=summarize(run)['errors']))
        for role,role_data in r['roles'].items():
            assert role_data['done'] and role_data['runtime_unchanged'] and role_data['candidate_sha256']==expected[variant]
            for name,h in role_data['files'].items():
                entry=archive['files'][role+'/'+name];assert entry['sha256']==h
                if h not in checked:
                    data=blob_data(inside_build(ROOT/archive['store']),h);assert len(data)==entry['size'];checked.add(h)
            rows.append(dict(run=run.name,role=role,candidate=role_data['candidate_sha256'],files=len(role_data['files']),log=sha(run/'evidence'/role/'ABBench.log')))
        for name,h in r['protected_after'].items():assert sha(ROOT.parents[1]/name)==h,name
    result=dict(byte_integrity_passed=True,all_workload_gates_passed=not any(q['errors'] for q in qualification),qualification=qualification,
        series=sha(out/'series.json'),comparison=sha(out/'comparison.json'),driver=sha(driver/'build-input.json'),unique_runtime_blobs_verified=len(checked),roles=rows,script_sha256=sha(__file__))
    save(out/'audit.json',result);print(json.dumps(result))
if __name__=='__main__':main()

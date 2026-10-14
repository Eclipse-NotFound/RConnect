"""Preserve paired algorithm measurements separately from whole-game observations."""
import argparse, statistics
from pathlib import Path
from common import ROOT, inside_build, read, save, sha, verify_files
from run_probe import records
from analyze_ab_bench import summarize
from audit_checkpoint import RuntimeFiles, require

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--paired',required=True);ap.add_argument('--trials',nargs='+',required=True);ap.add_argument('--output',required=True);a=ap.parse_args()
    out=inside_build(ROOT/a.output)
    if out.exists():raise FileExistsError(out)
    verified={};inputs=[]
    for name in [a.paired]+a.trials:
        folder=inside_build(ROOT/name);r=read(folder/'run.json');runtime=RuntimeFiles(folder,verified)
        require(r['complete'] and r['installation_unchanged'] and r['owned_processes_exited'],'Incomplete/unclean run: '+name)
        for role,v in r['roles'].items():
            require(v['runtime_unchanged'],'Runtime mutated: '+name)
            for p,digest in v['files'].items():runtime.check(role+'/'+p,digest)
        require(r['protected_before']==r['protected_after'],'Installation changed during '+name)
        for p,digest in r['protected_after'].items():require(sha(ROOT.parents[1]/p)==digest,'Installed bytes no longer match '+p)
        inputs.append(dict(path=name,receipt=sha(folder/'run.json'),runtimeFiles=sum(len(v['files']) for v in r['roles'].values())))
    paired=inside_build(ROOT/a.paired);r=read(paired/'run.json');rows=[]
    for role in ('host','join'):
        events=records(paired/(role+'.log'));done=[x for x in events if x['kind']=='DONE']
        require(len(done)==1 and done[0]['data']['failed']==0,'Paired test failed')
        require(not any(x['kind'] in ('FAIL','FATAL') for x in events),'Paired failure preserved')
        for e in events:
            if e['kind']!='algorithm-profile':continue
            d=e['data'];before=d['previous'];after=d['current']
            require(len(before)==len(after)==24,'Missing alternating chunks')
            rows.append(dict(role=role,algorithm=d['algorithm'],mode=d['mode'],callsPerChunk=d['calls'],chunks=24,
                beforeMeanMs=statistics.mean(before),afterMeanMs=statistics.mean(after),meanSaving=1-sum(after)/sum(before),
                fasterChunks=sum(y<x for x,y in zip(before,after)),rawSha256=sha(paired/(role+'.log'))))
    require(len(rows)==14,'Incomplete paired mode matrix')
    trials=[]
    for name in a.trials:
        folder=inside_build(ROOT/name);s=summarize(folder);r=read(folder/'run.json');profiles=[]
        for role in ('host','join'):
            events=records(folder/'evidence'/role/'ABBench.log')
            for e in events:
                if e['kind']!='result':continue
                d=e['data'];t=d['timings'];denom=t.get('host.publish',{}).get('n')
                profiles.append(dict(role=role,enemies=d['expectedEnemies'],publications=denom,
                    normalizedMs={k:v['totalMs']/denom for k,v in t.items()} if denom else None))
            errors=[x for x in records(folder/'evidence'/role/'RConnect-B.log') if x['kind'] in ('FAIL','FATAL')]
            require(not errors,'B runtime errors: '+name+'/'+role)
        s.update(buildManifests=r['build_manifests'],profiles=profiles);trials.append(s)
    # The promoted fixed reader must be the identical algorithm actually paired.
    diagnostic=ROOT/'build/ab/b3-build-194';candidate=ROOT/'build/ab/b3-build-195'
    for folder in (diagnostic,candidate):
        m=read(folder/'build-input.json');verify_files(folder,m['sources']);require(sha(folder/'RConnectMod.swf')==m['candidate_sha256'],'Build changed')
    terrain='src/authority/TerrainScan.as'
    require(sha(diagnostic/terrain)==sha(candidate/terrain)==sha(ROOT/'experimental/host-authority'/terrain),'Promoted terrain reader differs from paired reader')
    save(out,dict(scope='Local algorithm experiment and profiled native trials; not a release or whole-game speedup qualification',
        byteIntegrityPassed=True,paired=rows,trials=trials,inputs=inputs,verifiedBlobs=len(verified),
        terrainSourceSha256=sha(candidate/terrain),candidateManifestSha256=sha(candidate/'build-input.json'),
        wholeGameSpeedupQualified=False,scriptSha256=sha(__file__)))
    print(out)
if __name__=='__main__':main()

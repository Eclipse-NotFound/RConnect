"""Summarize original A/B logs; refuse to rank incomplete or mismatched workloads."""
import argparse, json, statistics
from common import ROOT, inside_build, read, save, sha
from run_probe import records

def percentile(values,p):
    values=sorted(values)
    return values[min(len(values)-1,int(len(values)*p))] if values else None

def summarize(folder):
    folder=inside_build(folder);receipt=read(folder/'run.json');errors=[];rows=[];geometry={}
    if not receipt['complete'] or not receipt['installation_unchanged'] or not receipt['owned_processes_exited']:errors.append('Run did not complete cleanly')
    for role,metadata in receipt['roles'].items():
        log=folder/'evidence'/role/'ABBench.log';events=records(log)
        geometry[role]=[x['data'] for x in events if x['kind']=='ready']
        results=[x['data'] for x in events if x['kind']=='result']
        if len(results)!=2:errors.append(role+': missing two measured phases')
        if any(x['kind']=='fatal' for x in events):errors.append(role+': fixture fatal')
        for data in results:
            frames=data['intervals'];samples=data['samples'];count=data['expectedEnemies']
            if not frames or not samples:errors.append(role+': no frames/samples');continue
            for sample in samples:
                if sample['enemies']['count']!=count or sample['enemies']['attached']!=count:errors.append(role+': enemy body population differs');break
                if 'players' not in sample:errors.append(role+': no fixed-position evidence');continue
                for i,p in enumerate(sample['players']):
                    expected=250+(i if receipt['variant']=='B' and role=='host' else 0 if role=='host' else 1)*80
                    if abs(p['x']-expected)>4 or abs(p['y']-879)>4 or p['hp']<p['maxhp']:errors.append(role+': player drifted or lost health')
            paid=[before-after for before,after in zip(data['baseAmmo'],data['finalAmmo'])]
            if any(x<=0 for x in paid):errors.append(role+': player did not fire')
            # Inventory feedback can be delayed on B join; authoritative host totals
            # are retained separately, never interpreted as a second payer.
            for start in range(0,len(samples)-5,5):
                first,last=samples[start],samples[min(start+5,len(samples)-1)]
                if any(a<=b for a,b in zip(first['ammo'],last['ammo'])):errors.append(role+': a five-sample window stopped consuming ammunition');break
            rows.append(dict(role=role,phase=data['phase'],enemies=count,fps=1000/statistics.mean(frames),meanMs=statistics.mean(frames),p95Ms=percentile(frames,.95),maxMs=max(frames),over100ms=sum(x>100 for x in frames)/len(frames),rttMedianMs=statistics.median(data['rtt']) if data['rtt'] else None,rttP95Ms=percentile(data['rtt'],.95),heapMedianMiB=statistics.median(x['heap'] for x in samples)/2**20,paidAmmo=paid,visibleRange=[min(x['enemies']['visible'] for x in samples),max(x['enemies']['visible'] for x in samples)],rawLogSha256=sha(log)))
    machine=read(folder/'machine.json');cpu=[]
    for a,b in zip(machine,machine[1:]):
        dif=[y-x for x,y in zip(a['cpuTicks'],b['cpuTicks'])];total=dif[1]+dif[2]
        if total>0:cpu.append(100*(1-dif[0]/total))
    return dict(run=folder.name,variant=receipt['variant'],driver=receipt['driver_sha256'],errors=sorted(set(errors)),geometry=geometry,rows=rows,machine=dict(cpuMedian=statistics.median(cpu) if cpu else None,availableMinGiB=min(x['available'] for x in machine)/2**30,commitAvailableMinGiB=min(x['commitAvailable'] for x in machine)/2**30),receiptSha256=sha(folder/'run.json'))

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--runs',nargs='+',required=True);ap.add_argument('--output',required=True);a=ap.parse_args()
    out=inside_build(ROOT/a.output)
    if out.exists():raise FileExistsError(out)
    values=[summarize(ROOT/p) for p in a.runs];errors=[v['run']+': '+e for v in values for e in v['errors']]
    if len({v['driver'] for v in values})>1:errors.append('Different test fixture bytes')
    geometries=[json.dumps(g,sort_keys=True) for v in values for rows in v['geometry'].values() for g in rows]
    if len(set(geometries))>1:errors.append('Different room/window geometry')
    result=dict(runs=values,comparisonValid=not errors,errors=errors,note='Stage ENTER_FRAME cadence and application-level socket echo. Not GPU presentation timing, end-to-end input latency or exhaustive gameplay qualification.')
    save(out,result);print(json.dumps(result,ensure_ascii=False))
if __name__=='__main__':main()

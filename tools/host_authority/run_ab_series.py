"""Alternating serial trials; archive each completed copy before launching the next."""
import argparse, subprocess, sys
from pathlib import Path
from common import ROOT, inside_build, save, sha
from analyze_ab_bench import summarize

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--driver',required=True);ap.add_argument('--output',required=True);ap.add_argument('--seconds',type=int,default=45);a=ap.parse_args()
    out=inside_build(ROOT/a.output)
    if out.exists():raise FileExistsError(out)
    out.mkdir(parents=True);tools=Path(__file__).parent;results=[]
    scripts={n:sha(tools/n) for n in ('run_ab_series.py','run_ab_bench.py','analyze_ab_bench.py','archive_evidence.py','common.py','run_probe.py')}
    for i,variant in enumerate('ABBA'):
        for n,h in scripts.items():
            if sha(tools/n)!=h:raise ValueError('Test tool changed during frozen series: '+n)
        run=out/('%02d-%s'%(i+1,variant));relative=run.relative_to(ROOT).as_posix()
        command=[sys.executable,'-B','-X','utf8',str(tools/'run_ab_bench.py'),'--variant',variant,'--driver',a.driver,'--seconds',str(a.seconds),'--timeout','360','--output',relative]
        with (out/('%02d-runner.log'%(i+1))).open('x',encoding='utf-8') as log:r=subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
        if (run/'run.json').exists():
            result=summarize(run);results.append(result);save(out/'series.json',dict(order='ABBA',results=results,scripts=scripts,complete=False))
            archived=subprocess.run([sys.executable,'-B','-X','utf8',str(tools/'archive_evidence.py'),'--runs',relative],cwd=ROOT)
            if archived.returncode:raise RuntimeError('Archive verification failed')
        else:raise RuntimeError('No finalized run receipt')
        print({'trial':i+1,'variant':variant,'errors':result['errors']},flush=True)
        if r.returncode or result['errors']:raise RuntimeError('Trial invalid; retain evidence and stop')
    save(out/'series.json',dict(order='ABBA',results=results,scripts=scripts,complete=True))
    subprocess.run([sys.executable,'-B','-X','utf8',str(tools/'analyze_ab_bench.py'),'--runs',*[str((out/('%02d-%s'%(i+1,v))).relative_to(ROOT)) for i,v in enumerate('ABBA')],'--output',str((out/'comparison.json').relative_to(ROOT))],cwd=ROOT,check=True)
if __name__=='__main__':main()

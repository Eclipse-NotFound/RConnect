"""Read-only checks; no compiler/AIR invocation."""
from pathlib import Path
import ast,json
import run
HERE=Path(__file__).resolve().parent
def main():
    checks=[]
    def yes(ok,name):
        assert ok,name
        checks.append(name)
    doc=(HERE/'component/SamplerPositiveDoc.as').read_text(encoding='utf-8')
    adapter=HERE/'component/FlashPaintTailSampler.as'
    yes(run.sha(adapter)=='f0706d7fdff62a0aaeebd1e200e8899a3f534a1d1abb76a56d4a2d4ade3f1601','exact frozen v3 real adapter')
    yes(doc.count('new FlashPaintTailSampler(true)')==1 and 'flash.sampler' not in doc,'only adapter invokes real sampler')
    yes('TARGET_MS:int=150' in doc and 'MAX_CHUNKS:int=131072,CHUNK_SIZE:int=256' in doc,'bounded 150ms AS work')
    yes('r.iterations=r.chunks*CHUNK_SIZE;r.checksum=checksum;' in doc,'arithmetic result retained')
    sequence=['api.start(token)','checksum=computeChunk(checksum)','api.pause(token)','api.count(token)',
              'api.samples(token)','api.stop(token)','api.clear(token);r.cleared=true','api.release(token)']
    positions=[doc.index(s) for s in sequence];yes(positions==sorted(positions),'exact work/pause/count/enumerate/cleanup order')
    yes('r.cpu>0' in doc and 'r.totalSamples==r.visited' in doc,'positive CPU and consistent paused enumeration required')
    yes(doc.count('r.assertions=')==1 and 'r.failed=ok?0:1' in doc,'one real positive control assertion')
    yes('finally' not in doc and 'return value;' in doc,'explicit cleanup and terminal nonvoid return')
    original=run.ORIGINAL.read_text(encoding='utf-8-sig');adapted=run.source()
    yes(adapted.replace(run.NEW,run.OLD,1)==original,'only single compiler-mode substitution')
    yes("'-debug=false', '-optimize=true'" in adapted and "'-debug=true'" not in adapted,'same native compiler mode')
    yes('1024**3' in adapted and 'with Registration(' in adapted and 'HiddenProcess(' in adapted,'original 1GiB registered hidden component runner')
    for p in (HERE/'run.py',HERE/'check.py'):
        ast.parse(p.read_text(encoding='utf-8'),filename=str(p));checks.append('Python syntax '+p.name)
    print(json.dumps(dict(checks=checks,count=len(checks),compiled=False,air_started=False,performance_qualified=False),indent=2))
if __name__=='__main__':main()

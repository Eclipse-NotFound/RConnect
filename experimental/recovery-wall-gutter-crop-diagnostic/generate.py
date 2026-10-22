"""Insert only external passive observations into exact frozen driver04."""
import difflib
import hashlib
import json
from pathlib import Path

HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
BASE=ROOT/'build/m52/recovery-wall-surfaces-driver-04/tests'
ACTOR='LargeWallSurfaceTestDoc.as'
ACTOR_SHA='8b705228e106b32db9fbd2bbe01e2ec495e2f58e829f53b981fe17a63bdc8f36'
PROBE='NativeWallSurfaceProbe.as'
PROBE_SHA='18efaeda6c265cf33862cdc6cb21f9ede07a55677b3b8df81b29c5bd6092e71f'


def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()


EDITS=[
 ('      private var allRows:Array=[],proofs:Array=[],failed:int=0;',
  '\n      private var colorProbe:NativeWallColorProbe=new NativeWallColorProbe();'),
 ('link.addEventListener(TcpLink.MESSAGE,receive);', 'colorProbe.attach(link);'),
 ('         pose();\n         if(phase=="sample" && source)',
  None),
 ('            if(fresh>0 && pre!=null) {',
  '\n               colorProbe.observe("native-after-hits",hits.slice(hits.length-fresh));'),
 ('         baseline=NativeWallSurfaceProbe.capture(mod.game.world.grafon,area);',
  '\n         colorProbe.begin(round,target,mod.game.world.grafon,source,host?"host":"join");'),
 ('            sampleEnd=getTimer();phase="sampled";', 'colorProbe.stopSampling();'),
 ('         var payload:String=JSON.stringify(local),file:File=',None),
 ('         release();if(landClass!=null',None),
]


def apply(source):
    result=source;replacements=[]
    for before,addition in EDITS:
        assert result.count(before)==1,before
        if addition is not None:after=before+addition
        elif before.startswith('         pose();'):after=before.replace('         pose();','         pose();colorProbe.nextFrame();')
        elif before.startswith('         var payload:'):after='         local.gutterDiagnostic=colorProbe.exportEvidence();\n'+before
        else:after=before.replace('         release();','         colorProbe.close();release();')
        result=result.replace(before,after);replacements.append((before,after))
    return result,replacements


def main():
    assert sha(BASE/ACTOR)==ACTOR_SHA and sha(BASE/PROBE)==PROBE_SHA
    target=HERE/'tests'/ACTOR;assert not target.exists(),'Preserve frozen diagnostic source'
    old=(BASE/ACTOR).read_text(encoding='utf-8-sig');new,edits=apply(old)
    target.write_text(new,encoding='utf-8');(HERE/'tests'/PROBE).write_bytes((BASE/PROBE).read_bytes())
    (HERE/'driver-observations.patch').write_text(''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile='driver04/'+ACTOR,tofile='gutter-diagnostic/'+ACTOR)),encoding='utf-8')
    reverse=new
    for before,after in reversed(edits):assert reverse.count(after)==1;reverse=reverse.replace(after,before)
    assert reverse==old,'Observation stripping must recover original driver exactly'
    (HERE/'actor-inputs.json').write_text(json.dumps(dict(ancestor_sha256=ACTOR_SHA,probe_sha256=PROBE_SHA,
        changes=len(edits),strip_exact=True,gameplay_assertions_unchanged=True,production_modified=False,
        tests={p.name:sha(p) for p in sorted((HERE/'tests').glob('*.as'))}),indent=2)+'\n',encoding='utf-8')
    print('External observations inserted; original actor recovered exactly by strip')


if __name__=='__main__':main()

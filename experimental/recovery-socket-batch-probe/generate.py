"""Only declared observer hooks; original timed methods and every stimulus retained."""
import difflib
import hashlib
import json
from pathlib import Path
import sys
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SOURCE = ROOT/'build/m52/recovery-density-corridor-drivers-03'


def edits():
    return [
        ('      private var trajectoryDiag:DensityTrajectoryTotals;',
         '      private var trajectoryDiag:DensityTrajectoryTotals;\n      private var socketProbe:SocketBatchProbe;'),
        ('trajectoryTotals:Boolean=false) {', 'trajectoryTotals:Boolean=false,socketDiagnostic:Boolean=false) {'),
        ('         host=id.indexOf("-host-")>=0;',
         '         host=id.indexOf("-host-")>=0;\n'
         '         if(socketDiagnostic)socketProbe=new SocketBatchProbe(host?"host":"join",function():Object {\n'
         '            return {phase:phase,density:densityProbe,frame:frames};\n'
         '         });'),
        ('private function watch(l:TcpLink):void {if(l!=null&&!links[l])',
         'private function watch(l:TcpLink):void {if(socketProbe!=null)socketProbe.watch(l);if(l!=null&&!links[l])'),
        ('         if(phase=="done")return;\n',
         '         if(phase=="done")return;\n         if(socketProbe!=null)socketProbe.finish();\n'),
    ]


def expected():
    before=(SOURCE/'tests/SustainedDensityTestDoc.as').read_text('utf-8-sig')
    after=before
    for old,new in edits():
        assert after.count(old)==1, old
        after=after.replace(old,new)
    return before,after


def main():
    before,after=expected()
    (HERE/'tests/SustainedDensityTestDoc.as').write_text(after,encoding='utf-8')
    (HERE/'diagnostic.patch').write_text(''.join(difflib.unified_diff(before.splitlines(True),after.splitlines(True),
        fromfile='driver03/SustainedDensityTestDoc.as',tofile='socket-batch/SustainedDensityTestDoc.as')),encoding='utf-8')
    base=ROOT/'experimental/recovery-current-profile-sampler'
    run=(base/'run.py').read_text('utf-8')
    changes=[('from sampler import M52, PROFILE, frozen_sources, verify_sampler, sha, save, write_diagnostic',
              'from probe import M52, PROFILE, frozen_sources, verify_probe, sha, save, write_diagnostic'),
             ('recovery-current-profile-sampler-drivers-01','recovery-socket-batch-probe-drivers-01'),
             ('verify_sampler(drivers)','verify_probe(drivers)'),
             ('profile-wrapper.stdout.log','socket-wrapper.stdout.log'),
             ('profile-wrapper.stderr.log','socket-wrapper.stderr.log')]
    for old,new in changes:
        assert old in run,old
        run=run.replace(old,new)
    (HERE/'run.py').write_text(run,encoding='utf-8')
    (HERE/'run-edits.json').write_text(json.dumps([dict(before=a,after=b) for a,b in changes],
        ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    inputs=json.loads((base/'inputs.json').read_text('utf-8'))
    inputs.pop('only_build_entry_change',None)
    inputs['kind']='external-socket-data-message-bounded-probe-source'
    inputs['compiled']=False;inputs['air_started']=False
    # The old CPU analyzer is not used. The registered build, settings wrapper and audit are unchanged.
    inputs['dependencies'].pop(str(ROOT/'experimental/recovery13-density-review/analyze.py'),None)
    extra=[base/'run.py',ROOT/'build/m52/recovery-20/prepared.json']
    extra += [ROOT/'build/m52/recovery-20/src'/x for x in ('rconnect/net/TcpLink.as',
        'rconnect/net/NetMessageEvent.as','rconnect/net/Protocol.as','rconnect/net/HostServer.as',
        'rconnect/core/Session.as','rconnect/core/RoomSync.as')]
    for path in extra:inputs['dependencies'][str(path)]=hashlib.sha256(path.read_bytes()).hexdigest()
    (HERE/'inputs.json').write_text(json.dumps(inputs,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'hooks':len(edits()),'driver_sha256':hashlib.sha256(after.encode()).hexdigest()}))


if __name__=='__main__': main()

"""Source checks and small dispatch-boundary model; not AS/AIR execution."""
import json
import importlib.util
from pathlib import Path
import sys
sys.dont_write_bytecode=True
import probe
from analyze import validate
spec=importlib.util.spec_from_file_location('socket_probe_generate',Path(__file__).with_name('generate.py'))
generate=importlib.util.module_from_spec(spec)
spec.loader.exec_module(generate)


def main():
    here,root=probe.HERE,probe.ROOT
    labels=[]
    def check(ok,label):
        assert ok,label
        labels.append(label)
    inputs=probe.read(here/'inputs.json')
    for name,digest in inputs['dependencies'].items():
        check(probe.sha(Path(name))==digest,'pinned '+str(Path(name).relative_to(root)))
    meta=probe.original.verify(probe.SOURCE)
    check(meta['compiled'] and meta['compile_exit']==0,'original formal driver03 verification')
    for name,digest in inputs['tests'].items():
        check(probe.sha(probe.SOURCE/name)==digest,'unchanged frozen '+name)
    before,expected=generate.expected()
    actual=(here/'tests/SustainedDensityTestDoc.as').read_text('utf-8')
    check(actual==expected,'exact five external observer edits')
    reverted=actual
    for old,new in reversed(generate.edits()):
        check(reverted.count(new)==1,'unique reverse edit '+old[:40])
        reverted=reverted.replace(new,old)
    check(reverted==before,'all non-observer text preserved; no timed stimulus or threshold edits')
    check('super(true,false,false,true);' in (here/'tests/SocketBatchTestDoc.as').read_text('utf-8'),
          'new entry explicitly disables existing CPU sampler and trajectory diagnostic')
    run=(root/'experimental/recovery-current-profile-sampler/run.py').read_text('utf-8')
    for edit in probe.read(here/'run-edits.json'):run=run.replace(edit['before'],edit['after'])
    check(run==(here/'run.py').read_text('utf-8'),'run adapter only declared import/default/log-name edits')
    check('assert user_before ==' in run and "assert report['user_settings_unchanged']" in run,
          'live settings checked against frozen capture before and after')
    for name in ('probe.py','run.py','check.py','generate.py','analyze.py'):
        compile((here/name).read_text('utf-8'),name,'exec');check(True,'Python syntax '+name)
    registered=(root/'experimental/recovery-density-fixture/prepare.py').read_text('utf-8-sig')
    check("resource='game'" in registered and "assert snapshot()['free_commit_bytes'] >= 1024**3" in registered,
          'unchanged registered game build and 1 GiB compiler gate')
    lower=(root/'tools/run_coop_regression.py').read_text('utf-8-sig')
    check('minimum_start_gib=3 if args.solo else 6' in lower and "row['free_commit_bytes']<512*1024**2" in lower,
          'unchanged 6 GiB dual startup and 512 MiB running protection')
    as3=(here/'tests/SocketBatchProbe.as').read_text('utf-8')
    added='\n'.join(new for old,new in generate.edits())
    check('.world.frame' not in added and 'nativeFrame' not in added+as3,
          'observer never reads nonexistent sealed World.frame; only existing driver frame counter')
    check('return {phase:phase,density:densityProbe,frame:frames};' in added,
          'context uses driver-owned phase/frame fields without touching native world')
    class SealedWorldModel:
        __slots__=()
    rejected=False
    try:getattr(SealedWorldModel(),'frame')
    except AttributeError:rejected=True
    check(rejected,'pure model counterexample: a missing sealed field is not a nullable native frame')
    net=(root/'build/m52/recovery-20/src/rconnect/net/TcpLink.as').read_text('utf-8-sig')
    session=(root/'build/m52/recovery-20/src/rconnect/core/Session.as').read_text('utf-8-sig')
    check('public var socket:Socket;' in net and 'socket.addEventListener(ProgressEvent.SOCKET_DATA, onData);' in net,
          'public Socket and native priority zero verified')
    check('dispatchEvent(new NetMessageEvent(MESSAGE, msg));' in net,
          'native while loop synchronously dispatches each decoded message')
    check('link.addEventListener(TcpLink.MESSAGE, onLinkMessage);' in session and
          'link.addEventListener(TcpLink.MESSAGE, onHostMessage);' in session,
          'Session handlers have default priority zero on both roles')
    check('stopImmediatePropagation' not in net+session and 'stopPropagation' not in net+session,
          'inspected native listeners do not stop propagation; incomplete runtime still invalidates probe')
    check('HIGH:int=1000000,LOW:int=-1000000' in as3 and
          'link.addEventListener(TcpLink.MESSAGE,messageEnd,false,LOW)' in as3,
          'MESSAGE-low returns after Session/default listeners and original -100000 test listener')
    check(all(s not in as3 for s in ('readBytes(', 'readUTF', '.send(', 'startSampling(',
          'stopImmediatePropagation(', 'stopPropagation(', 'JSON.stringify(p)', 'JSON.stringify(e.data)')),
          'observer neither consumes Socket bytes nor sends/mutates/stops/samples/serializes messages')
    check(as3.count('JSON.stringify(')==1 and as3.count('Log.d(')==1,
          'only final bounded summary is serialized/logged')
    check('KEEP:int=16,ROWS:int=64,CELLS:int=1200,UNITS:int=512,PLAYERS:int=16' in as3,
          'fixed retention and metadata scan bounds')
    check('if(bucket(b.startContext)!="outside")' in as3,
          'initialization and outside batches cannot displace load longest16')
    check('if(bucket(b.startContext)!=bucket(b.endContext))a.phaseCrossings++' in as3,
          'cross-phase batch is explicitly counted without splicing')
    check('if(requested && open==0)emit();' in as3 and 'if(open==0)emit();' in as3,
          'finish inside dispatch waits for DATA-low; original DONE remains untouched')
    check('r.wallChars+=(a[i].d as String).length' in as3 and 'decode' not in as3,
          'wall encoded lengths are read directly, never decoded or rebuilt')
    # Pure event-order model: does not claim the AS was executed.
    order=sorted([(0,0,'Session'),(0,1,'original-test'),(-100000,2,'original-cost'),
                  (1000000,3,'probe-begin'),(-1000000,4,'probe-end')],key=lambda x:(-x[0],x[1]))
    check([x[2] for x in order]==['probe-begin','Session','original-test','original-cost','probe-end'],
          'priority model preserves original relative order and encloses synchronous handlers')
    active=True;pending=True;exported=not active
    check(not exported,'finish in MESSAGE cannot export an unfinished DATA batch')
    active=False;exported=pending and not active
    check(exported,'DATA-low permits one final export')
    rows=[{'duration':i,'phase':'load'} for i in range(20)]
    rows += [{'duration':99999,'phase':'outside'}]
    kept=sorted((r for r in rows if r['phase']=='load'),key=lambda r:-r['duration'])[:16]
    check(len(kept)==16 and kept[0]['duration']==19 and kept[-1]['duration']==4,
          'longest16 model retains only load batches even with a huge initialization batch')
    payload=dict(role='join',diagnosticOnly=True,performanceQualified=False,wireSendTimeAvailable=False,
        longest=[],phases={f'load{i}':{'batches':1} for i in range(7)},attachments=[{'socketUnchanged':True}],
        open=0,orphanMessages=0,missingEnd=0,nestedData=0,nestedMessage=0,faults=0,attachFailures=0,metadataTruncated=0)
    check(validate(payload,'join'),'complete seven-phase bounded schema is collectable, not performance qualified')
    for key in ('open','orphanMessages','missingEnd','nestedData','nestedMessage','faults','attachFailures','metadataTruncated'):
        broken=dict(payload);broken[key]=1
        check(not validate(broken,'join'),'reject incomplete diagnostic '+key)
    broken=dict(payload,attachments=[{'socketUnchanged':False}])
    check(not validate(broken,'join'),'replaced Socket invalidates claimed continuous observation')
    result=dict(assertions=len(labels),passed=len(labels),failed=0,labels=labels,static_only=True,
        compiled=False,air_started=False,performance_qualified=False)
    probe.save(here/'static-check.json',result)
    print(json.dumps({k:v for k,v in result.items() if k!='labels'}))


if __name__=='__main__':main()

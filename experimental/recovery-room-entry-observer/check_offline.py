"""No AIR/JVM. Verify exact patch/old assertions/source contracts and evidence."""
import ast,json,re
from pathlib import Path
from generate import HERE,ROOT,BASE,BASE_MANIFEST,sha,read,save,check,assertion_calls

def main():
    rows=[]
    def add(value,label):
        rows.append(dict(passed=bool(value),label=label))
        assert value,label
    add(sha(BASE/'prepared.json')==BASE_MANIFEST,'Exact compiled scene12 manifest')
    detail=check()
    add(detail['all_original_probe_assertions_unchanged'],'Every original observer check/require body is unchanged')
    add(detail['original_suite_byte_exact'],'Original native room/scalar suites are copied byte-exact')
    add(detail['component_uses_exact_observer_helper'],'Component and driver share exact observation helper bytes')
    suite=(HERE/'component/RoomEntryObserverChecks.as').read_text(encoding='utf-8')
    count=len(assertion_calls(suite))-1 # Exclude only the catch-all error report.
    add(count==43,'Exactly 43 normal AS component assertions prepared (not executed)')
    for p in sorted(HERE.glob('*.py')):ast.parse(p.read_text(encoding='utf-8-sig'),str(p))
    add(True,'All new Python source parses without launching subprocesses')
    helper=(HERE/'tests/RoomEntryConfirmation.as').read_text(encoding='utf-8')
    add(all(s in helper for s in ('room===v.room && land===v.land','int(p.barrier)!=int(v.term)',
        'int(p.epoch)!=int(v.epoch)','v.canSync!==true','if(!same(v) ||','peerAcknowledged=true;return true;')),
        'Separate local commit/ACK and actual identity/stamp guards present')
    probe=(HERE/'tests/RoomEntryProbe.as').read_text(encoding='utf-8')
    add('settled,false,-2147483648' in probe and 'if(e.currentTarget!==connection)return;' in probe,
        'Observer runs after Session and rejects old socket identities')
    add(not any(s in probe+helper for s in ('onPause=true','rooms.receive(','.send(','.release(','.commit(')),
        'Observer neither controls pause nor drives production protocol')
    old=ROOT/'build/m52/recovery-first-raster-entry-room-01/result.json'
    result=read(old)
    add(result['run']=='a542373a5f' and result['passed'] is False and result['exit_code']==1,
        'Original native13 failed result remains failed')
    host=ROOT/'build/cooperation/a542373a5f/host.log'
    join=host.with_name('join.log')
    add(sha(host)=='7332cb5dccd96e293dd46f0080958ad79871d1076a83d456612e98fad330c87e'
        and sha(join)=='0d3305e199cbd4b55b6280e5ec2edb67244b044ca1097069d97c2353b71e5eb7',
        'Both original failed-run native logs remain byte-exact')
    text=host.read_text(encoding='utf-8-sig');events=[];failures=[]
    for line in text.splitlines():
        if line.startswith('A22 ROOM RECEIVE '):
            item=json.loads(line.split('A22 ROOM RECEIVE ',1)[1])
            if item['op'] in ('ready','ack'):events.append(item)
        elif line.startswith('ROOM ENTRY FAILURE '):failures.append(json.loads(line.split('ROOM ENTRY FAILURE ',1)[1]))
    firstReady=next(e for e in events if e['op']=='ready' and e['barrier']==1)
    firstAck=next(e for e in events if e['op']=='ack' and e['barrier']==1)
    add(firstReady['at']==72647 and firstAck['at']==73202 and
        [f['at'] for f in failures]==[72699,72701] and
        all(firstReady['at']<f['at']<firstAck['at'] for f in failures),
        'Both old failures lie strictly after native host commit and before peer ACK')
    timeline=[]
    for ready in [e for e in events if e['op']=='ready']:
        ack=next((e for e in events if e['op']=='ack' and e['barrier']==ready['barrier']),None)
        timeline.append(dict(term=ready['barrier'],ready_finished=ready['at'],ready_context=ready['context'],
                             ack_finished=ack['at'] if ack else None,
                             ack_after_local_ms=ack['at']-ready['at'] if ack else None))
    save(HERE/'native-timeline.json',dict(run='a542373a5f',original_result_sha256=sha(old),
        original_passed=False,original_exit=1,host_log_sha256=sha(host),join_log_sha256=sha(join),
        host_checks=result['roles']['host']['checks'],join_checks=result['roles']['join']['checks'],
        failures=failures,timeline=timeline,observation_only=True))
    add(sha(ROOT/'experimental/recovery-first-raster-native/run_native.py')==
        '69d6e237b642821479f6d05c9af9a74f7cd62a4884578d4072fbeb7b7402ea6a',
        'Underlying 600s/native/22-input runner is unchanged')
    output=dict(passed=True,assertions=rows,checks=len(rows),failed=0,as_component_assertions_prepared=count,
                as_component_executed=False,compiled=False,air_started=False,native_rerun=False)
    save(HERE/'offline-result.json',output)
    print(json.dumps({k:v for k,v in output.items() if k!='assertions'},ensure_ascii=False))

if __name__=='__main__':main()

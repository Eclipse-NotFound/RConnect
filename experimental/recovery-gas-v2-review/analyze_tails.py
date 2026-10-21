"""Read existing v2 gas evidence and split each failed verifier branch.

Only this review directory receives output. No verifier/driver/production edits,
no tolerance changes, no AIR/JVM. Diagnostic matching is explicitly not a pass.
"""
import hashlib
import importlib.util
import json
from pathlib import Path
import re

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
RUN=ROOT/'build/m52/recovery-gas-v2-native-01'
LOGS=ROOT/'build/cooperation/b15c17f816'
DRIVER=ROOT/'build/m52/recovery-gas-v2-driver-01'
VERIFIER=ROOT/'experimental/recovery-gas-native-v2/verify_results.py'


def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path):return json.loads(path.read_text(encoding='utf-8-sig'))


def main():
    recorded=read(RUN/'gas-verification.json');runner=read(RUN/'result.json')
    assert recorded['passed'] is False and runner['passed'] is True
    assert sha(VERIFIER)==recorded['source_analyzer_sha256']
    spec=importlib.util.spec_from_file_location('exact_recorded_gas_verifier',VERIFIER)
    verifier=importlib.util.module_from_spec(spec);spec.loader.exec_module(verifier)
    cases,parse_errors=verifier.read_cases(LOGS/'host.log',LOGS/'join.log')
    assert not parse_errors and len(cases)==8
    for name,digest in recorded['artifacts'].items():assert sha(RUN/name)==digest
    for role in ('host','join'):
        assert sha(LOGS/(role+'.log'))==runner[role]['log_hashes'][role+'.log']
        for n in range(4):assert read(RUN/'gas-proof'/role/('round-'+str(n)+'-proof.json'))==cases[(role,n)]['proof']
    reproduced=verifier.analyze(LOGS/'host.log',LOGS/'join.log')
    assert reproduced['errors']==recorded['errors'] and reproduced['comparisons']==recorded['comparisons']
    failures=[];rounds=[]
    for n in range(4):
        source_role,remote_role=('host','join') if n%2==0 else ('join','host')
        a=cases[(source_role,n)]['proof'];b=cases[(remote_role,n)]['proof']
        assert a['playbackCursorObserved'] is False and b['playbackCursorObserved'] is False
        native_by_wire={}
        for native in a['nativeRows']:
            source_visual=next(v for v in a['visualRows'] if v['id']==native['visual'])
            wires=[w for w in b['wireRows'] if verifier.source_match(native,source_visual,w)]
            assert len(wires)==1
            assert wires[0]['key'] not in native_by_wire
            native_by_wire[wires[0]['key']]=(native,source_visual)
        exact_pass=0;round_failed=[];lags=[];diagnostic_keys=[]
        for remote in b['visualRows']:
            strict=[w for w in b['wireRows'] if verifier.display_match(remote,w) is not None]
            if len(strict)==1:
                exact_pass+=1;lags.append(remote['bornWall']-strict[0]['firstWall']);diagnostic_keys.append(strict[0]['key']);continue
            # Decompose original gates without changing their thresholds. A
            # unique ordered candidate is a diagnostic association only; it
            # remains a failed full display_match until all original gates pass.
            ordered=[]
            for wire in b['wireRows']:
                samples=remote['samples'];frames=wire['frames']
                structure=(bool(samples) and bool(frames) and verifier.increasing(samples,'at') and
                    verifier.increasing(samples,'frame') and verifier.increasing(frames,'at') and
                    samples[0]['at']==remote.get('bornAt') and samples[-1]['at']<remote.get('endAt',0))
                if not structure:continue
                chosen=[];cursor=0
                for sample in samples:
                    found=next((i for i in range(cursor,len(frames)) if verifier.pose_match(sample,frames[i])),None)
                    if found is None:break
                    chosen.append(found);cursor=found
                if len(chosen)!=len(samples):continue
                captures_ok=True
                for cap in remote.get('captures',[]):
                    indices=[i for i,s in enumerate(samples) if s['frame']==cap.get('frame') and s['at']==cap.get('at')]
                    if len(indices)!=1:captures_ok=False;break
                    k=indices[0];lo=chosen[k-1] if k else 0;hi=chosen[k]
                    if not any(verifier.pose_match(cap,frames[i]) for i in range(lo,hi+1)):captures_ok=False
                ordered.append((wire,chosen,captures_ok))
            assert len(strict)==0 and len(ordered)==1,(n,remote['id'],'not a unique diagnostic candidate')
            wire,chosen,captures_ok=ordered[0]
            diagnostic_keys.append(wire['key'])
            native,source_visual=native_by_wire[wire['key']]
            final_ok=verifier.pose_match(remote['samples'][-1],wire['frames'][-1])
            terminal_ok=remote['endAt']>=wire['endReceivedAt'] and remote['endWall']>=wire['endReceivedWall']
            exact_errors=[]
            if not final_ok:exact_errors.append('missing_final_source_pose')
            if not terminal_ok:exact_errors.append('removed_before_terminal_receipt')
            if not captures_ok:exact_errors.append('captured_revision_mismatch')
            row=dict(round=n,source_role=source_role,remote_role=remote_role,remote_visual=remote['id'],
                source_part=native['id'],source_visual=source_visual['id'],wire=wire['key'],
                original_strict_match_count=len(strict),ordered_candidate_count=len(ordered),
                exact_failure_gates=exact_errors,source_frame_count=len(wire['frames']),remote_sample_count=len(remote['samples']),
                final_native_pose_ever_observed=any(verifier.pose_match(s,wire['frames'][-1]) for s in remote['samples']),
                trailing_source_samples_not_displayed=len(wire['frames'])-1-chosen[-1],
                source_last_two=source_visual['samples'][-2:],source_part_metadata=native,
                wire_last_two=wire['frames'][-2:],wire_metadata={k:v for k,v in wire.items() if k!='frames'},
                remote_last_two=remote['samples'][-2:],remote_last_two_source_indices=chosen[-2:],
                remote_metadata={k:v for k,v in remote.items() if k not in ('samples','captures')},
                full_source_wire_history_matches_original_tolerances=True,
                terminal_receipt_to_removal_ms=remote['endWall']-wire['endReceivedWall'],
                last_observed_remote_pose_to_removal_ms=remote['endAt']-remote['samples'][-1]['observedAt'],
                remote_removal_after_source_observed_end_ms=remote['endWall']-native['endWall'],
                source_last_pose_interval_before_end_ms=wire['end']-wire['frames'][-1]['at'],
                receive_to_first_display_ms=remote['bornWall']-wire['firstWall'],
                private_playback_cursor='unknown',final_frame_receive_time='not recorded per frame')
            failures.append(row);round_failed.append(remote['id']);lags.append(row['receive_to_first_display_ms'])
        assert len(set(diagnostic_keys))==len(diagnostic_keys) and set(diagnostic_keys)==set(native_by_wire)
        rounds.append(dict(round=n,source_parts=len(a['nativeRows']),wire_rows=len(b['wireRows']),remote_visuals=len(b['visualRows']),
            original_strict_display_matches=exact_pass,failed_display_ids=round_failed,
            diagnostic_only_unique_association=True,
            receive_to_first_display_ms_range=[min(lags),max(lags)]))
    expected=[(int(re.search(r'round=(\d+)',e)[1]),int(re.search(r'id=(\d+)$',e)[1]))
              for e in recorded['errors'] if 'display has' in e]
    assert [(x['round'],x['remote_visual']) for x in failures]==expected and len(failures)==10
    assert all(x['exact_failure_gates']==['missing_final_source_pose'] for x in failures)
    inputs=[RUN/'result.json',RUN/'gas-verification.json',LOGS/'host.log',LOGS/'join.log',VERIFIER,
            DRIVER/'tests/GasPulseProbe.as',DRIVER/'tests/GasPulseNativeTestDoc.as']
    inputs += list((RUN/'gas-proof').rglob('*.json'))
    result=dict(original_qualification_passed=False,original_errors=len(recorded['errors']),
        round_summary=rounds,failed_entries=failures,ordered_ambiguities=0,removed_before_terminal_receipt=0,
        missing_final_pose=10,missing_one_trailing_source_sample=9,missing_two_trailing_source_samples=1,
        artifact_hashes_match_recorded=True,logged_proofs_equal_saved_json=True,original_verifier_results_reproduced=True,
        private_playback_cursor='unknown; not observed',premature_relative_to_cursor_proven=False,
        input_hashes={str(p.relative_to(ROOT)):sha(p) for p in inputs},JVM_started=False,AIR_started=False)
    (HERE/'tail-evidence.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(dict(failed_entries=10,missing_one=9,missing_two=1,ordered_ambiguities=0,
        removed_before_terminal_receipt=0,rounds=rounds),ensure_ascii=False))


if __name__=='__main__':main()

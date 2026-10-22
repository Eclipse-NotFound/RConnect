"""Preserve aggregate audit; report CPU tail integrity separately, never performance."""
from pathlib import Path
import hashlib,importlib.util,json
_path=Path(__file__).resolve().parent.parent/'recovery-early-paint-aggregate/audit_runtime.py'
assert hashlib.sha256(_path.read_bytes()).hexdigest()=='a6c2173da00e367f12b00bf8b741d8ab85d03b5957254d74a9c6865af1f89e39'
_spec=importlib.util.spec_from_file_location('tail_frozen_aggregate_audit',_path)
prior=importlib.util.module_from_spec(_spec);_spec.loader.exec_module(prior)

def audit_log(path):
    result=prior.audit_log(path)  # All original three-segment and aggregate rules first.
    tails=[];outputs=[];summaries=[]
    for line in Path(path).read_text(encoding='utf-8-sig').splitlines():
        for prefix,values in [('EARLY PAINT TAIL ',tails),('EARLY PAINT TAIL OUTPUT ',outputs),
                              ('EARLY PAINT TAIL SUMMARY ',summaries)]:
            if line.startswith(prefix) and line[len(prefix):].startswith('{'):
                values.append(json.loads(line[len(prefix):]))
    assert len(tails)==len(outputs)==3 and len(summaries)==1,'Incomplete tail diagnostic output'
    assert [r['segment'] for r in tails]==[0,1,2]==[r['segment'] for r in outputs]
    summary=summaries[0]
    assert summary['segments']==3 and summary['globalFaults']==0 and summary['cleanupBlocked'] is False
    assert summary['diagnosticOnly'] is True and summary['performanceQualified'] is False and summary['runtimeQualified'] is False
    for row,output in zip(tails,outputs):
        assert row['diagnosticOnly'] is True and row['performanceQualified'] is False and row['closed'] is True
        assert output['diagnosticOnly'] is True and output['performanceQualified'] is False
        assert output['encodeStart']<=output['encodeEnd']<=output['outputStart']<=output['outputEnd']
        assert output['encodeStartWall']<=output['encodeEndWall']<=output['outputStartWall']<=output['outputEndWall']
        assert output['encodeMs']==output['encodeEnd']-output['encodeStart']>=0
        assert output['outputMs']==output['outputEnd']-output['outputStart']>=0
        assert 0<=row['visited']<=32768 and row['cpu']+row['allocationsSkipped']+row['deletionsSkipped']==row['visited']
        assert row['uniqueStacks']==len(row['stacks'])<=1024 and row['stackTextChars']<=262144
        assert all(type(v) is int and v>0 for v in row['stacks'].values())
        assert sum(row['stacks'].values())<=row['cpu']
        assert row['cpuEvidenceAvailable']==(row['cpu']>0)
        untruncated=not row['sampleTruncated'] and all(row[k]==0 for k in
            ('stackOverflow','depthTruncated','textTruncated','textOverflow'))
        assert row['samplingComplete']==(row['complete'] and untruncated)
        assert row['cpuEvidenceComplete']==(row['samplingComplete'] and row['cpu']>0)
        if row['complete']:
            assert row['reason']=='next-stage-enter' and row['triggered'] and row['claimed'] and row['started']
            assert row['stopStage']==row['startStage']+1 and not row['errors'] and not row.get('extraErrors',0)
            assert all(row[k] is True for k in ('clockOrdered','ownerPreserved','identityPreserved','slotPreserved','cleanupComplete'))
            c=row['clocks'];order=('observed','setupStart','setupEnd','startCall','startReturned','stop','pauseReturned','collectStart','collectEnd')
            assert row['ensure']['residentBefore']==0 and row['ensure']['residentAfter']>0
            for field in ('t','wall'):
                values=[c[k][field] for k in order]
                assert values==sorted(values)
            assert row['collectMs']==c['collectEnd']['t']-c['collectStart']['t']>=0
            assert row['cleanupMs']==c['cleanupEnd']['t']-c['cleanupStart']['t']>=0
            assert c['collectStart']['t']<=c['cleanupStart']['t']<=c['cleanupEnd']['t']<=c['collectEnd']['t']
            assert c['collectEnd']['t']<=output['encodeStart']
            if row['samplingComplete']:assert row['totalSamples']==row['visited']==sum(row['stacks'].values())+row['allocationsSkipped']+row['deletionsSkipped']
        if not row['triggered']:
            assert not row['started'] and not row['complete'] and row['reason']=='not-triggered'
    result['tail_cpu']=dict(diagnostic_only=True,performance_qualified=False,runtime_qualified=False,
        rows=tails,output_timing=outputs,summary=summary,
        sampling_complete=all(r['samplingComplete'] for r in tails),
        cpu_evidence_complete=all(r['cpuEvidenceComplete'] for r in tails),
        measured_scope='ensure callback tail until next stage ENTER +1000000; not the entire inter-frame gap',
        timing_caution='collectMs includes cleanupMs; output timing marker cost is unmeasured; do not sum nested intervals',
        no_cpu_caution='No CPU samples do not prove sleep, GPU or network waiting; empty file/line is retained')
    return result

"""Keep original motion summaries and separately qualify CPU observations."""
from pathlib import Path
import hashlib, importlib.util
HERE=Path(__file__).resolve().parent
def load(path,name,expected):
    assert hashlib.sha256(path.read_bytes()).hexdigest()==expected
    spec=importlib.util.spec_from_file_location(name,path)
    m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
motion=load(HERE.parent/'goal-three-issues-native/analyze.py','goal_cpu_motion_summary',
 'ac369d4d4a63607e737a550730df609c328be73792bd0e971468b2427b0c0508')
summarize=motion.summarize
def cpu_summary(data,role,appid):
    assert data['kind']=='ordinary-native-jump-cpu-v1' and data['applicationId']==appid and data['role']==role
    assert data['diagnosticOnly'] is True and data['performanceQualified'] is False and data['smoothnessQualified'] is False
    assert data['samplerStopped'] is True and len(data['profiles'])==1
    p=data['profiles'][0]
    assert p['role']==role and p['kind']=='native-jump' and p['measurementReason']=='measurement-complete'
    assert p['diagnosticOnly'] is True and p['samplerStopped'] is True and p['droppedRows']==0
    assert p['counts']=={'0':6}
    rows=p['frames'];selected=[r for r in rows if r['sampled']]
    assert len(selected)==6
    count=0
    for r in rows:
        expected=r['renderAt']>0 and count<6 and r['renderAt']-p['measurementStartedAt']>=1000+2500*count
        assert r['selected'] is expected and r['sampled'] is expected
        if expected:count+=1
    assert count==6 and p['measurementEndedAt']>=max(r['stop'] for r in selected)
    assert all(r['phase']==0 for r in rows)
    assert all(r['complete'] and r['reason']=='next-enter' and r['stackOverflow']==0
      and r['depthTruncated']==0 and 'error' not in r for r in selected)
    assert all('error' not in r for r in rows)
    report=tail.summarize(p)
    assert report['cpu_samples']>0,'No CPU samples: function attribution unavailable'
    report.update(role=role,diagnostic_complete=True,measured_window='six first eligible windows after 1/3.5/6/8.5/11/13.5 seconds',
      offsets_ms=[r['renderAt']-p['measurementStartedAt'] for r in selected],
      warning='Counts are not exclusive time; pauses and collection perturb later frames; zero-sample wall time is unexplained')
    return report

# Filled from the actual frozen analyzer by prepare-time binding, not a new algorithm.
TAIL=HERE.parent/'recovery-after-render-sampler/analyze.py'
TAIL_SHA='89b78d98d3ef324def013f4efd228550f8ff10c98ab535174e04a2d9848435d3'
tail=load(TAIL,'goal_cpu_original_tail_summary',TAIL_SHA)

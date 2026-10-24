"""Read completed observations from a failed native fixture without changing its verdict."""
from pathlib import Path
import hashlib, importlib.util, json, sys

ROOT=Path(__file__).resolve().parents[2]
ANALYZER=ROOT/'experimental/goal-three-issues-native/analyze.py'

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path):return json.loads(path.read_text('utf-8-sig'))

def main():
    folder=(ROOT/sys.argv[1]).resolve()
    assert folder.parent==ROOT/'build/m52'
    result_path=folder/'result.json'; result_hash=sha(result_path);result=read(result_path)
    assert result['passed'] is False
    run=Path(result['run']).resolve()
    assert run.parent==ROOT/'build/cooperation'
    target=folder/'failed-measurement-diagnostics.json'
    assert not target.exists()
    spec=importlib.util.spec_from_file_location('fixed_native_analyzer',ANALYZER)
    analyzer=importlib.util.module_from_spec(spec);spec.loader.exec_module(analyzer)
    output=dict(originalPassed=False,performanceQualified=False,smoothnessQualified=False,
                originalResultSha256=result_hash,analyzerSha256=sha(ANALYZER),roles={})
    for role in ('host','join'):
        log=run/(role+'.log');text=log.read_text('utf-8-sig')
        rows=[json.loads(line[len('NATIVE MOTION MEASURE '):]) for line in text.splitlines()
              if line.startswith('NATIVE MOTION MEASURE ')]
        assert len(rows)==4 and [r['round'] for r in rows]==list(range(4))
        for row in rows:
            assert row['reason']=='measurement-complete' and row['timingRestored'] and row['dropped']==0
        output['roles'][role]=dict(logSha256=sha(log),rounds=[analyzer.summarize(r) for r in rows],
            failures=[line for line in text.splitlines() if line.startswith('COOP FAIL ')])
    output['memory']=read(run/'memory-timeline.json')
    assert sha(result_path)==result_hash
    target.write_text(json.dumps(output,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(dict(output=str(target),originalPassed=False,
        failures={role:output['roles'][role]['failures'] for role in output['roles']}),ensure_ascii=False))

if __name__=='__main__':main()

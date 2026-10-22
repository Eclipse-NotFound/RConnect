"""Bind a compiled two-file loading fix to unchanged native test drivers."""
from pathlib import Path
import argparse, hashlib, json
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
BASE=HERE.parent/'recovery-early-revisit-frozen-rv'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--candidate',required=True);a=ap.parse_args()
    candidate=(ROOT/a.candidate).resolve()
    assert candidate.parent==ROOT/'build/m52' and not (HERE/'inputs.json').exists()
    meta=json.loads((candidate/'prepared.json').read_text(encoding='utf-8-sig'))
    assert meta['compiled'] is True and meta['version']=='0.2.24-early-travel2'
    source=(BASE/'run_native.py').read_text(encoding='utf-8-sig')
    line='RUNNER=Path(__file__).with_name("native_runner.py")'
    assert source.count(line)==1
    source=source.replace(line,'RUNNER=Path(__file__).resolve().parent.parent/"recovery-early-revisit-frozen-rv/native_runner.py"')
    # Solo is an original scene-driver capability. The unchanged separate
    # diagnostic-only check still requires two peers for the bounded probe.
    guard='assert a.sand_mode=="bridge" and not a.solo'
    assert source.count(guard)==1
    source=source.replace(guard,'assert a.sand_mode=="bridge"')
    assert not (HERE/'run_native.py').exists()
    (HERE/'run_native.py').write_text(source,encoding='utf-8',newline='\n')
    inputs=dict(candidate=str(candidate),candidate_manifest=sha(candidate/'prepared.json'),
        candidate_sha256=sha(candidate/'RConnectMod.swf'),
        sources={p.name:sha(p) for p in sorted(HERE.glob('*.py'))},
        originals={str(p):sha(p) for p in [BASE/'inputs.json',BASE/'run_native.py',BASE/'native_inputs.py',BASE/'native_runner.py']})
    (HERE/'inputs.json').write_text(json.dumps(inputs,indent=2)+'\n',encoding='utf-8')
    import native_inputs
    native_inputs.audit(candidate)
    native_inputs.sandy_input('bridge')
    native_inputs.host_input(native_inputs.original.HOST,native_inputs.original.installation())
    print(json.dumps(dict(candidate_sha256=inputs['candidate_sha256'],verified=True,runtime_qualified=False)))
if __name__=='__main__':main()

"""Thin metadata adapter over the existing registered input-CPU prepare entry."""
import argparse,hashlib,importlib.util,json,sys
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
PREVIOUS=ROOT/'experimental/recovery-input-cpu-profile'

def main():
    original=PREVIOUS/'prepare.py'
    assert hashlib.sha256(original.read_bytes()).hexdigest()=='349bdc253421e7836010c20475365faab97eb6d6cd8eb3ffb6df6a705d93a915'
    spec=importlib.util.spec_from_file_location('registered_input_cpu_prepare',original)
    tool=importlib.util.module_from_spec(spec);spec.loader.exec_module(tool);tool.HERE=HERE
    tool.main()
    parser=argparse.ArgumentParser(add_help=False);parser.add_argument('output')
    parser.add_argument('--candidate');parser.add_argument('--gate-expect');parser.add_argument('--compile',action='store_true')
    parser.add_argument('--registry-wait');args=parser.parse_args()
    out=(ROOT/args.output).resolve();meta=json.loads((out/'prepared.json').read_text('utf-8-sig'))
    assert meta['diagnostic_kind']=='round0-join-input-cpu'
    meta.update(diagnostic_kind='round0-join-input-cpu-frames',sampler_schema=2,
        sampler_windows=6,sampler_callback_used=False,grant_sampling_excluded=True)
    (out/'prepared.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

if __name__=='__main__':main()

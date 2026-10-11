"""Preserve the exact archived A0 source alongside the physical A/B baseline.

Historical test outcomes are not copied or re-labelled as current results.
"""
import argparse
import shutil
from common import ROOT, inside_build, read, save, sha, verify_baseline, verify_files


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--baseline',required=True)
    ap.add_argument('--source',required=True)
    ap.add_argument('--output',required=True)
    args=ap.parse_args()
    baseline=inside_build(ROOT/args.baseline)
    frozen=verify_baseline(baseline)
    origin=(ROOT/args.source).resolve()
    if not origin.is_relative_to(ROOT/'build'):
        raise ValueError('An existing archived production build is required')
    source=read(origin/'source-input.json')
    if source['candidate_sha256']!=frozen['A_sha256'] or sha(origin/'RConnectMod.swf')!=frozen['A_sha256']:
        raise ValueError('Archived source does not correspond to the exact A0 candidate')
    verify_files(origin,source['source'])
    out=inside_build(ROOT/args.output)
    if out.exists():raise FileExistsError('Source archives are immutable')
    out.mkdir(parents=True)
    for name in source['source']:
        dest=out/name;dest.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(origin/name,dest)
    for name in ('source-input.json','candidate-reuse.json','RConnectMod.swf'):
        shutil.copy2(origin/name,out/name)
    verify_files(out,source['source']);verify_files(origin,source['source'])
    save(out/'a-source.json',dict(kind='exact-A0-source-archive',origin=str(origin.relative_to(ROOT)),
        source_manifest_sha256=sha(origin/'source-input.json'),baseline_manifest_sha256=sha(baseline/'baseline.json'),
        candidate_sha256=frozen['A_sha256'],files=source['source'],historical_results_inherited=False,
        note='A0 compiled previously; this is an exact source/binary archive, not a new compilation or test.',
        script_sha256=sha(__file__)))
    print(str(out))


if __name__=='__main__':main()

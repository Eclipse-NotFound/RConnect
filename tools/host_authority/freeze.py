"""Preserve exact A bytes and physical dependencies from a verified snapshot."""
import argparse
import shutil
from datetime import datetime, timezone
from common import ROOT, inside_build, read, save, sha, verify_files, verify_baseline


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--runtime', type=str, required=True, help='Existing physical diagnostic runtime snapshot')
    ap.add_argument('--output', required=True)
    args = ap.parse_args()
    origin = (ROOT/args.runtime).resolve()
    if not origin.is_relative_to(ROOT/'build'):
        raise ValueError('Use an existing snapshot inside this mod; never read live release inputs implicitly')
    source = read(origin/'runtime-input.json')
    verify_files(origin/'game', source['files'])
    out = inside_build(ROOT/args.output)
    if out.exists():
        raise FileExistsError('Never overwrite an A/B baseline')
    if shutil.disk_usage(ROOT).free < sum((origin/'game'/n).stat().st_size for n in source['files'])*3:
        raise RuntimeError('Insufficient room for isolated copies')
    out.mkdir(parents=True)
    for name, digest in source['files'].items():
        dest = out/'game'/name
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(origin/'game'/name, dest)
        if sha(dest) != digest:
            raise RuntimeError('Copy mismatch: '+name)
    verify_files(origin/'game', source['files'])
    manifest = dict(kind='host-authority-ab-baseline', experimental_only=True,
        created_at=datetime.now(timezone.utc).isoformat(), files=source['files'],
        origin=str(origin.relative_to(ROOT)), origin_manifest_sha256=sha(origin/'runtime-input.json'),
        inherited_test_results=False, baseline_role='A0 exact installed RConnect with explicitly pinned external inputs',
        recorded_external_transitions=source.get('observed_external_transition', {}),
        A_sha256=sha(out/'game/mods/Rconnect/release/RConnectMod.swf'),
        script_sha256=sha(__file__))
    save(out/'baseline.json', manifest)
    verify_baseline(out)
    print('Frozen A/B baseline: '+str(out), flush=True)


if __name__ == '__main__':
    main()

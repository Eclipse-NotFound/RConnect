"""Freeze one native-input driver for old fix39 and a peer-grenade candidate."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'tools/host_authority'))
from common import JAVA, SDK


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('candidate', type=Path)
    ap.add_argument('output', type=Path)
    ap.add_argument('--probe', action='store_true')
    args = ap.parse_args()
    candidate = (ROOT/args.candidate).resolve()
    out = (ROOT/args.output).resolve()
    assert candidate.is_relative_to(ROOT/'build/m52')
    assert out.parent == ROOT/'build/m52' and not out.exists()
    out.mkdir()
    (out/'tools').mkdir()
    (out/'build').mkdir()
    shutil.copytree(ROOT/'experimental/peer-projectile-grip/tests', out/'tests')
    shutil.copytree(ROOT/'tests/harness', out/'tests/harness')
    shutil.copy2(candidate/'build/GameCombatStubs.swc', out/'build/GameCombatStubs.swc')
    builder = (ROOT/'tools/build_effects_driver.py').read_text('utf-8-sig')
    assert "choices=[" in builder
    builder = builder.replace("choices=[", "choices=['PeerProjectileGripTestDoc','PeerProjectileGripProbeDoc',", 1)
    entry = 'PeerProjectileGripProbeDoc' if args.probe else 'PeerProjectileGripTestDoc'
    (out/'tools/build_effects_driver.py').write_text(builder, 'utf-8')
    with (out/'build.log').open('w', encoding='utf-8') as log:
        subprocess.run([sys.executable, '-B', '-X', 'utf8', str(out/'tools/build_effects_driver.py'),
            '--candidate', str(candidate/'RConnectMod.swf'), '--source-root', str(candidate/'src'),
            '--java', str(JAVA), '--sdk', str(SDK), '--entry', entry,
            '--output', str(out/'build/candidate')], stdout=log, stderr=subprocess.STDOUT, check=True)
    shutil.copytree(out/'build/candidate', out/'build/control')
    control = ROOT/'build/m52/a22-fixes-39/RConnectMod.swf'
    (out/'build/control/driver-input.json').write_text(json.dumps(dict(
        entry=entry, candidate_sha256=sha(control)), indent=2), 'utf-8')
    record = dict(candidate_sha256=sha(candidate/'RConnectMod.swf'), control_sha256=sha(control),
        driver_sha256=sha(out/'build/candidate/EffectsDriver.swf'),
        inputs={p.relative_to(out).as_posix():sha(p) for p in (out/'tests').rglob('*.as')})
    (out/'prepared.json').write_text(json.dumps(record, indent=2), 'utf-8')
    print(json.dumps(record, indent=2))


if __name__ == '__main__':
    main()

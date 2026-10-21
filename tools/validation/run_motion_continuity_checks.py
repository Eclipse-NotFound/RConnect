"""Exact-source motion component replay on an owned hidden AIR desktop.

No game, saves or networking. Test times are fixed inputs, not FPS evidence.
Teleport and native weapon boundaries throw if reached; never silently emulate.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import uuid
from prepare_motion_transport import ROOT, BASE, JAVA, SDK, sha
from runtime_memory import snapshot, wait_owned

GAME = ROOT.parents[1]
sys.path.insert(0, str(GAME/'mods/ModLoader/tools'))
from test_registry import Registration
from air_test_process import HiddenProcess


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding='utf-8')


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--source', type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--entry', choices=['MotionContinuityChecks', 'RemoteMotionClockTestDoc', 'ProjectileContinuityChecks'], default='MotionContinuityChecks')
    ap.add_argument('--registry-wait', type=float, default=300)
    args = ap.parse_args()
    source, out = [(ROOT/p).resolve() for p in (args.source, args.output)]
    assert source.is_relative_to(ROOT) and out.parent == ROOT/'build/m52' and not out.exists()
    out.mkdir()
    with Registration(owner='RConnect / 运动连续性组件', purpose='实际AS3播放时钟与固定轨迹回归；不计游戏FPS',
                      run_dir=out, evidence=out/'receipt.json', resource='game', wait=args.registry_wait) as registration:
        src = out/'src'
        shutil.copytree(ROOT/'tests/motion-continuity', src)
        originals={}
        names=['RemoteMotion','ProjectileVisuals','EnergyImpactVisuals']
        for optional in ('ProjectileFrameStream', 'ImpactEventQueue', 'BallisticImpactVisuals'):
            if (source/('rconnect/game/'+optional+'.as')).exists():names.append(optional)
        for name in names:
            relative=Path('rconnect/game')/(name+'.as')
            origin=source/relative
            if not origin.is_file():origin=BASE/'src'/relative
            originals[str(origin)]=sha(origin)
            shutil.copyfile(origin,src/relative)
        for name in ['HeldMotionBufferRegression','DropMotionBurstRegression','NativeEffectRateRegression',
                     'MotionCadenceRegression','RemoteMotionClockTestDoc']:
            shutil.copyfile(ROOT/'tests'/f'{name}.as', src/f'{name}.as')
        before = {str(p):sha(p) for p in [GAME/'pfe.swf', ROOT/'release/RConnectMod.swf']}
        record = dict(source=str(source), source_sha256=sha(source/'rconnect/game/RemoteMotion.as'),
                      runner_sha256=sha(Path(__file__)), entry=args.entry, installed=before, originals=originals,
                      files={p.relative_to(src).as_posix():sha(p) for p in src.rglob('*.as')},
                      game_loaded=False, native_game_pass=False)
        save(out/'inputs.json', record)
        command = [str(JAVA), '-Xmx256m', '-jar', str(SDK/'lib/mxmlc.jar'), '+configname=air',
                   '+flexlib='+str(SDK/'frameworks'), '-swf-version=38', '-debug=false', '-optimize=true',
                   '-source-path='+str(src), '-output='+str(out/'Checks.swf'), str(src/(args.entry+'.as'))]
        with (out/'compile.log').open('w', encoding='utf-8') as log:
            code = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, env=dict(os.environ, AIR_HOME=str(SDK))).returncode
        if code:
            print((out/'compile.log').read_text(encoding='utf-8',errors='replace')[-6000:])
            raise SystemExit(code)
        memory = snapshot(); save(out/'memory-before.json',memory)
        assert memory['free_commit_bytes']>=1024**3, 'Component requires 1 GiB commit headroom'
        appid = 'rconnect-motion-continuity-'+uuid.uuid4().hex
        descriptor = out/'application.xml'
        descriptor.write_text('<application xmlns="http://ns.adobe.com/air/application/30.0"><id>'+appid+
            '</id><versionNumber>1.0</versionNumber><filename>Checks</filename><initialWindow>'+
            '<content>Checks.swf</content><visible>false</visible><width>100</width><height>100</height>'+
            '</initialWindow><supportedProfiles>extendedDesktop</supportedProfiles></application>',encoding='utf-8')
        with (out/'stdout.log').open('w',encoding='utf-8') as log:
            registration.before_launch('component / '+appid)
            process=HiddenProcess([str(GAME/'adl64.exe'),'-runtime',str(GAME/'runtimes/air/win64'),str(descriptor)],
                                  cwd=out,stdout=log,stderr=log)
            registration.child(process.pid)
            save(out/'process.json',dict(pid=process.pid,appid=appid,desktop=process.desktop))
            try:
                code=wait_owned(process,40,out/'memory-timeline.json')
            finally:
                if process.poll() is None:process.kill();process.wait()
                process.close();registration.child_stopped()
        result_path=Path(os.environ['APPDATA'])/appid/'Local Store/result.json'
        result={}
        if result_path.is_file():
            shutil.copyfile(result_path,out/'result.json')
            result=json.loads(result_path.read_text(encoding='utf-8'))
        unchanged=all(sha(Path(p))==h for p,h in before.items())
        receipt=dict(exit=code,passed=result.get('pass'),failed=result.get('fail'),
                     installation_unchanged=unchanged,source_unchanged=all(sha(Path(p))==h for p,h in originals.items()),
                     swf_sha256=sha(out/'Checks.swf'),native_game_pass=False)
        save(out/'receipt.json',receipt);print(json.dumps(receipt))
        for row in result.get('checks',[]):
            if not row['pass']:print(json.dumps(row,ensure_ascii=False))
        if code or result.get('fail')!=0 or not unchanged or not receipt['source_unchanged']:raise SystemExit(code or 1)
        registration.outcome='passed';registration.note='固定轨迹组件通过，不代表实机或网络性能合格'


if __name__=='__main__':main()

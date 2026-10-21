"""Freeze selected external native motion drivers; production remains external."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from check_coop_bundle import ROOT, M52, JAVA, SDK, sha, read, save, inventory


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--case', action='append', choices=('native-jump','fast-held','continuity'))
    args = ap.parse_args()
    out = (ROOT / args.output).resolve()
    assert out.parent == M52 and not out.exists()
    sys.path.insert(0, str(ROOT.parents[1] / 'mods/ModLoader/tools'))
    from test_registry import Registration
    with Registration(owner='RConnect / 原生运动补充驱动', purpose='选定运动回归驱动编译',
                      run_dir=out, evidence=out/'prepared.json', wait=300) as record:
        base = M52 / 'coop-bundle-drivers-04'
        manifest = read(base / 'prepared.json')
        for name, digest in manifest['files'].items():
            assert sha(base/name) == digest, name
        out.mkdir()
        shutil.copytree(base/'tests', out/'tests')
        declarations = base/'ProductionDeclarations.swc'
        stubs = M52/'coop-bundle-04/build/GameCombatStubs.swc'
        all_entries = {'native-jump': 'NativeJumpNetworkTestDoc', 'fast-held': 'FastHeldTestDoc',
                       'continuity': 'PresentationContinuityTestDoc'}
        entries = {k: all_entries[k] for k in (args.case or ['native-jump','fast-held'])}
        results = {}
        for kind, entry in entries.items():
            shutil.copyfile(ROOT/'tests'/(entry+'.as'), out/'tests'/(entry+'.as'))
            dest = out/kind
            dest.mkdir()
            shutil.copyfile(base/'EffectsHarness.swf', dest/'EffectsHarness.swf')
            command = [str(JAVA), '-Xmx384m', '-jar', str(SDK/'lib/mxmlc.jar'), '+configname=air',
                       '+flexlib='+str(SDK/'frameworks'), '-swf-version=38', '-debug=false', '-optimize=true',
                       '-source-path='+str(out/'tests'), '-external-library-path+='+str(declarations),
                       '-external-library-path+='+str(stubs), '-output='+str(dest/'EffectsDriver.swf'),
                       str(out/'tests'/(entry+'.as'))]
            with (dest/'compile.log').open('w', encoding='utf-8') as log:
                code = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT,
                                      env=dict(os.environ, AIR_HOME=str(SDK))).returncode
            results[kind] = code
            save(dest/'driver-input.json', dict(candidate_sha256=manifest['candidate_sha256'], entry=entry,
                                               diagnostic_only=True))
            if code:
                print((dest/'compile.log').read_text(encoding='utf-8', errors='replace')[-5000:])
        save(out/'prepared.json', dict(compile_exits=results, files=inventory(out),
            recipe_sha256=sha(__file__), declarations_sha256=sha(declarations), stubs_sha256=sha(stubs),
            base_manifest_sha256=sha(base/'prepared.json')))
        if any(results.values()):
            raise SystemExit(1)
        record.outcome = 'passed'
        record.note = '选定外部驱动编译成功；没有原生运行结论'
        print(json.dumps(dict(output=str(out), compile_exits=results)), flush=True)


if __name__ == '__main__':
    main()

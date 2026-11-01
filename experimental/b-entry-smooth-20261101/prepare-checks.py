"""Freeze an external observer on the existing small B test runtime."""
from pathlib import Path
import argparse, json, os, shutil, subprocess, sys
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
RC = HERE.parents[1]
sys.path.insert(0, str(RC / 'tools/host_authority/field2_driver'))
import run as r

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', required=True)
    a = ap.parse_args()
    if Path(a.out).name != a.out or not a.out.startswith('prepared-entry-') or not a.out.endswith('.json'):
        raise ValueError('New preparation basename required')
    work = RC / 'build/ab/b-field2-runtime-01'
    parent = work / 'prepared-smooth-09.json'
    old = r.read(parent)
    frozen = Path(old['compiler_command'][-1]).parent
    r.verify_files(frozen, old['helpers'])
    if r.sha(frozen / 'BStartupDriverMod.as') != old['driver']:
        raise ValueError('Parent observer changed')
    folder = work / ('driver-' + Path(a.out).stem)
    output = work / a.out
    if output.exists() or folder.exists():
        raise FileExistsError(output)
    with r.Registration(owner='RConnect B / entry and sparse motion', purpose='Compile external checks', run_dir=folder, evidence=output, wait=600) as reg:
        mutable = {'pfe.swf', 'mods/rconnect/release/rconnectmod.swf', 'mods/rconnect/release/config.txt'}
        r.verify_files(work / 'game', {k:v for k,v in old['files'].items() if k.lower() not in mutable})
        folder.mkdir()
        for source in frozen.glob('*.as'):
            shutil.copy2(source, folder / source.name)
        shutil.copy2(HERE / 'BEntryMotionChecks.as', folder / 'BEntryMotionChecks.as')
        source = folder / 'BStartupDriverMod.as'
        text = source.read_text(encoding='utf-8')
        replacements = {
            '     BDeltaPrefixChecks.run(domain,check);': '     BDeltaPrefixChecks.run(domain,check);\n     BEntryMotionChecks.run(domain,check);\n     if(cfg.scenario=="ui")BEntryMotionChecks.beforeLoad(mod,role,check);',
            'click(role);phase=2;return;': 'if(cfg.scenario=="ui")BEntryMotionChecks.beforeConnect(mod,role,check);if(mod.role=="")click(role);phase=2;return;'
        }
        for before, after in replacements.items():
            if text.count(before) != 1:
                raise ValueError('Observer seam changed: ' + before)
            text = text.replace(before, after)
        source.write_text(text, encoding='utf-8')
        swf = folder / 'BStartupDriverMod.swf'
        command = [str(r.JAVA), '-Xmx512m', '-jar', str(r.SDK/'lib/mxmlc.jar'), '+configname=air', '+flexlib='+str(r.SDK/'frameworks'), '-source-path='+str(folder), '-swf-version=38', '-debug=true', '-optimize=true', '-output='+str(swf), str(source)]
        with (folder/'build.log').open('x', encoding='utf-8') as log:
            subprocess.run(command, env=dict(os.environ, AIR_HOME=str(r.SDK)), stdout=log, stderr=subprocess.STDOUT, check=True)
        target = work / 'game/mods/BStartupDriver/release/BStartupDriverMod.swf'
        shutil.copy2(swf, target)
        files = dict(old['files'])
        for name in files:
            if name.lower() == 'mods/bstartupdriver/release/bstartupdrivermod.swf':
                files[name] = r.sha(target)
        helpers = {p.name:r.sha(p) for p in folder.glob('*.as') if p.name != source.name}
        r.save(output, dict(old, files=files, driver=r.sha(source), helpers=helpers, compiler_command=command, parent_preparation=parent.name, parent_sha256=r.sha(parent)))
        reg.outcome = 'passed'
    print(output)

if __name__ == '__main__':
    main()

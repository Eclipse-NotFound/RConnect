"""Build the existing read-only CPU sampler against the frozen bundle.

This changes only the external diagnostic driver. It cannot qualify a release:
its entry class differs from the unprofiled density gate.
"""
import os
import shutil
import subprocess
from check_coop_bundle import M52, JAVA, SDK, read, save, sha, inventory, verify


def main():
    candidate = M52 / 'coop-bundle-04'
    original = M52 / 'coop-bundle-drivers-04'
    out = M52 / 'coop-bundle-density-profile-drivers-01'
    m = verify(candidate)
    d = read(original / 'prepared.json')
    assert not out.exists()
    assert d['candidate_sha256'] == m['sha256']
    for name, digest in d['files'].items():
        assert sha(original / name) == digest, name
    out.mkdir()
    shutil.copytree(original / 'tests', out / 'tests')
    shutil.copyfile(original / 'ProductionDeclarations.swc', out / 'ProductionDeclarations.swc')
    target = out / 'density'
    target.mkdir()
    shutil.copyfile(original / 'density/EffectsHarness.swf', target / 'EffectsHarness.swf')
    entry = 'ProjectileProfileTestDoc'
    command = [str(JAVA), '-Xmx384m', '-jar', str(SDK / 'lib/mxmlc.jar'),
               '+configname=air', '+flexlib=' + str(SDK / 'frameworks'),
               '-swf-version=38', '-debug=false', '-optimize=true',
               '-source-path=' + str(out / 'tests'),
               '-external-library-path+=' + str(out / 'ProductionDeclarations.swc'),
               '-external-library-path+=' + str(candidate / 'build/GameCombatStubs.swc'),
               '-output=' + str(target / 'EffectsDriver.swf'), str(out / 'tests' / (entry + '.as'))]
    with (out / 'compile.log').open('w', encoding='utf-8') as log:
        subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True,
                       env=dict(os.environ, AIR_HOME=str(SDK)))
    save(target / 'driver-input.json', dict(candidate_sha256=m['sha256'], entry=entry,
                                          diagnostic_only=True))
    save(out / 'prepared.json', dict(candidate_sha256=m['sha256'],
         source_manifest=sha(candidate / 'prepared.json'), recipe_sha256=sha(__file__),
         diagnostic_only=True, origins=dict(driver_manifest=sha(original / 'prepared.json')),
         files=inventory(out)))
    print('Diagnostic driver built; production unchanged; no release qualification')


if __name__ == '__main__':
    main()

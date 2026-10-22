"""Pure source/receipt checks; never invokes build(), main() or an AIR runner."""
import ast
import json
from pathlib import Path
import sys
sys.dont_write_bytecode = True
import sampler


def main():
    here, root = sampler.HERE, sampler.ROOT
    inputs = sampler.read(here/'inputs.json')
    labels = []
    def check(ok, label):
        assert ok, label
        labels.append(label)
    for name, digest in inputs['dependencies'].items():
        check(sampler.sha(Path(name)) == digest, 'pinned dependency '+str(Path(name).relative_to(root)))
    meta = sampler.original.verify(sampler.SOURCE)
    check(meta['compiled'] and meta['compile_exit'] == 0, 'original formal driver03 verifier passes')
    check(meta['entry'] == 'ProjectileLoadTestDoc', 'unprofiled driver03 remains unmodified')
    for name, digest in inputs['tests'].items():
        check(sampler.sha(sampler.SOURCE/name) == digest, 'same test source '+name)
    check(len(inputs['tests']) == 11, 'all eleven driver03 AS classes retained')
    profile_entry = (sampler.SOURCE/'tests/ProjectileProfileTestDoc.as').read_text('utf-8-sig')
    check('super(true,true);' in profile_entry, 'existing profile constructor used unchanged')
    actual = (here/'run.py').read_text('utf-8')
    old = (sampler.PROFILE/'run.py').read_text('utf-8-sig')
    expected = old
    for i, edit in enumerate(sampler.read(here/'run-edits.json')):
        check(expected.count(edit['before']) == 1, 'unique run adapter edit '+str(i+1))
        expected = expected.replace(edit['before'], edit['after'])
    check(expected == actual, 'run adapter exactly matches declared thirteen edits')
    for name in ('sampler.py', 'run.py', 'check.py'):
        compile((here/name).read_text('utf-8'), name, 'exec')
        check(True, 'syntax '+name)
    guard = old[old.index('    user_before ='):old.index('    wrapper =')]
    check(guard in actual, 'live settings must equal captured SHA before launch')
    check("assert report['user_settings_unchanged']" in actual, 'live settings checked again after runtime')
    code = (here/'sampler.py').read_text('utf-8')
    check('meta = original.freeze(out, True)' in code and "meta.update(entry='ProjectileProfileTestDoc'" in code,
          'registered original freeze followed only by sampler metadata/entry')
    check('meta = original.base.build(out, args.registry_wait)' in code, 'registered original build reused directly')
    registered = (root/'experimental/recovery-density-fixture/prepare.py').read_text('utf-8-sig')
    check("resource='game'" in registered and "assert snapshot()['free_commit_bytes'] >= 1024**3" in registered,
          'same game registration and 1 GiB compiler gate')
    lower = (root/'tools/run_coop_regression.py').read_text('utf-8-sig')
    check('minimum_start_gib=3 if args.solo else 6' in lower and "row['free_commit_bytes']<512*1024**2" in lower,
          'same 6 GiB dual startup and 512 MiB running protection')
    payload = 'PROJECTILE PROFILE '+json.dumps({'role':'join','frames':[{'cpu':1,'stacks':{'TypeError Error #1009':1}}]})
    check(sampler.runtime_errors(payload, 'join') == [], 'error words inside valid CPU profile are data')
    check(sampler.runtime_errors(payload+'\nCOOP FAIL original threshold', 'join') == ['COOP FAIL original threshold'],
          'real COOP FAIL remains an assertion failure')
    check(sampler.runtime_errors(payload+'\nTypeError: Error #1009', 'join') == ['TypeError: Error #1009'],
          'real exception outside profile remains an error')
    check(bool(sampler.runtime_errors('PROJECTILE PROFILE broken', 'join')), 'malformed profile is not silently discarded')
    check(bool(sampler.runtime_errors(payload, 'host')), 'wrong-role profile is rejected')
    check('performance_qualified=False' in code and 'release_qualified=False' in code,
          'sampling never confers performance or release qualification')
    result = dict(assertions=len(labels), passed=len(labels), failed=0, labels=labels,
                  static_only=True, compiled=False, air_started=False, performance_qualified=False)
    sampler.save(here/'static-check.json', result)
    print(json.dumps({k:v for k,v in result.items() if k != 'labels'}))


if __name__ == '__main__':
    main()

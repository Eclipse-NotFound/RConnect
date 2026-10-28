"""Review the existing FFDec output after correcting an overbroad namespace assertion."""
import json, re
from pathlib import Path
from build import RC, BASE, inventory, sha, save

folder = RC / 'build/m52/a-stutter-repair-02'
meta = json.loads((folder / 'compile.json').read_text('utf8'))
old = json.loads((folder / 'class-audit.json').read_text('utf8'))
assert old['candidate_sha256'] == meta['candidate_sha256'] == sha(folder / 'RConnectMod.swf')
assert inventory(folder / 'src') == meta['source']
actual = {m.group(1) for m in re.finditer(r'^([\w.]+)\s+\d+\s*$',
          (folder / 'classes.txt').read_text('utf8', errors='replace'), re.M)}
expected = {str(Path(n).with_suffix('')).replace('\\', '.').replace('/', '.') for n in meta['source']}
baseline = set(json.loads((BASE / 'class-audit.json').read_text('utf8'))['classes'])
assert actual == expected == baseline
assert not actual.intersection({'fe.World', 'fe.unit.Unit', 'fe.unit.UnitPlayer',
                                'fe.weapon.Weapon', 'fe.weapon.Bullet', 'fe.loc.Location'})
changed = [n for n, h in meta['source'].items() if h != sha(BASE / 'src' / n)]
assert set(changed) == {'RConnectMod.as', 'rconnect/game/UnitPresentation.as', 'rconnect/game/ProjectileVisuals.as'}
result = dict(passed=True, candidate_sha256=meta['candidate_sha256'], classes=len(actual),
              native_stubs_embedded=[], changed=changed, log_sha256=sha(folder / 'classes.txt'),
              prior_result_sha256=sha(folder / 'class-audit.json'), reused_output=True,
              explanation='Prior blanket fe.* rejection incorrectly included existing RConnect access bridges; exact 81 source and baseline definitions match.')
save(folder / 'class-audit-recheck.json', result)
print(json.dumps(result))

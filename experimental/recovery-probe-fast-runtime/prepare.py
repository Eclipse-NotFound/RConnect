"""Prepare only a small exact-recovery13 component; never launch a VM.

The old proposal is read-only. No complete GameBridge overlay is produced.
"""
import difflib
import hashlib
import importlib.util
import json
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
GAME = ROOT.parents[1]
OLD = ROOT / 'experimental/recovery-probe-fast'
BASE = ROOT / 'build/m52/recovery-13'
BRIDGE = BASE / 'src/rconnect/game/GameBridge.as'
HOST = ROOT / 'build/m52/recovery-first-raster-host-03/pfe.swf'
EXPECTED_BRIDGE = '26bb0f7cd4da7c74c83bd2657575823247196c41a861babf23bb40c17fc3cbf7'
EXPECTED_RC = '1177eb1ae9b227bcf3c0eb39dedad92b63ac16dcb7ffb0b421ea0a2024bfddb1'
EXPECTED_HOST = 'fd92fbd5ae92b5c8d4cbf8151d11796a140810f34988b7031e258c747d86734e'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def digest(text):
    return hashlib.sha256(text.encode('utf-8')).hexdigest()


def read(path):
    return Path(path).read_text(encoding='utf-8-sig')


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


def write(name, value):
    path = (HERE / name).resolve()
    assert path.is_relative_to(HERE)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding='utf-8')


def inputs():
    paths = [BRIDGE, BASE/'RConnectMod.swf', HOST,
             ROOT/'build/m52/recovery-01/src/rconnect/game/GameBridge.as',
             OLD/'prepare.py', OLD/'audit_native_slots.py', OLD/'audit.json',
             ROOT/'tools/validation/run_recovery_component.py']
    paths += sorted((OLD/'components').rglob('*.as'))
    paths += sorted((OLD/'negative').glob('*.as'))
    return {str(p): sha(p) for p in paths}


def generate():
    before_inputs = inputs()
    assert sha(BRIDGE) == EXPECTED_BRIDGE
    assert sha(BASE/'RConnectMod.swf') == EXPECTED_RC
    assert sha(HOST) == EXPECTED_HOST
    old = module('probe_old_prepare', OLD/'prepare.py')
    audit = module('probe_slot_audit', OLD/'audit_native_slots.py')
    source = read(BRIDGE)
    ancestor = read(ROOT/'build/m52/recovery-01/src/rconnect/game/GameBridge.as')
    assert old.constants(source) == old.constants(ancestor)
    methods = {}
    for name in ('probe', 'probeOptional', 'probeNum'):
        exact = old.function(source, name)
        assert exact == old.function(ancestor, name), name
        methods[name] = dict(sha256=digest(exact), unchanged_from_recovery01=True)
    tables = {re.search(r'NATIVE_\w+_FIELDS', x)[0]: digest(x) for x in old.constants(source)}
    extra = '\n'.join('private static const NATIVE_' + k + '_FIELDS:Object={' +
              ','.join(f + ':true' for f in fields) + '};'
              for k, fields in [('WEAPON', old.WEAPON), ('BULLET', old.BULLET)])
    anchor = '            || o is Pt && NATIVE_POINT_FIELDS[name]===true'
    changed = ('            || o is Pt && (NATIVE_POINT_FIELDS[name]===true\n'
               '               || o is Weapon && NATIVE_WEAPON_FIELDS[name]===true\n'
               '               || o is Bullet && NATIVE_BULLET_FIELDS[name]===true)')
    assert source.count(anchor) == 1
    # This string is only used to extract small members; never written as a full class.
    proposed = extra + '\n' + source.replace(anchor, changed, 1)
    assert old.function(proposed, 'probeOptional') == old.function(source, 'probeOptional')
    for path in sorted((OLD/'components').rglob('*.as')):
        if path.name not in ('ProbeBefore.as', 'ProbeAfter.as', 'ProbeFastChecks.as'):
            write('components/' + path.relative_to(OLD/'components').as_posix(), read(path))
    write('components/probecheck/ProbeBefore.as', old.class_source('ProbeBefore', source))
    write('components/probecheck/ProbeAfter.as', old.class_source('ProbeAfter', proposed))
    old_members = '\n'.join(old.constants(source) + [old.function(source, 'probe'), old.function(source, 'probeOptional')])
    new_members = '\n'.join(old.constants(proposed) + [old.function(proposed, 'probe'), old.function(proposed, 'probeOptional')])
    write('methods-only.patch', ''.join(difflib.unified_diff(old_members.splitlines(True), new_members.splitlines(True),
          fromfile='exact-recovery13/extracted-members', tofile='component-only/proposed-members')))

    doc = read(OLD/'components/ProbeFastChecks.as')
    old_enable = ('            var config:File=File.applicationDirectory.resolvePath("benchmark-enabled.txt");\n'
                  '            if(config.exists && failed==0)benchmark();')
    assert doc.count(old_enable) == 1
    doc = doc.replace(old_enable, '            if(failed==0)benchmark();\n'
        '            check(benchmarks.length==6,"all six explicit benchmark groups executed");\n'
        '            for each(var measured:Object in benchmarks) {\n'
        '               var complete:Boolean=measured.pairs.length==6;\n'
        '               for(var j:int=0;j<measured.pairs.length;j++) {\n'
        '                  var pair:Object=measured.pairs[j];\n'
        '                  complete=complete && pair.order==(j%2==0?"before-after":"after-before")\n'
        '                     && pair.beforeMs>=0 && pair.afterMs>=0;\n'
        '               }\n'
        '               check(complete,"six AB/BA pairs recorded: "+measured.name);\n'
        '            }')
    doc = doc.replace('failed:failed,checks:checks,benchmarks:benchmarks,',
        'failed:failed,assertions:checks,benchmarks:benchmarks,\n'
        '            benchmarkEnabled:true,abBaPairsPerGroup:6,warmupReadsPerPath:10000,\n'
        '            allocationReadsPerPath:20000,baselineGameBridgeSHA:"'+EXPECTED_BRIDGE+'",\n'
        '            allocationSamplesAreNotTotalAllocationCounts:true,')
    doc = doc.replace('/** Explicit opt-in only. No pass threshold is inferred from a microbench.',
                      '/** Always enabled by this dedicated runtime component. No performance pass threshold is inferred.')
    doc = doc.replace('var data:Object={name:set.name,iterations:60000,pairs:[]};',
                      'var data:Object={name:set.name,iterations:60000,fixtureRows:set.rows.length,pairs:[]};')
    assert 'benchmark-enabled.txt' not in doc and 'assertions:checks' in doc
    write('components/ProbeFastChecks.as', doc)

    for path in (OLD/'negative').glob('*.as'):
        write('negative/' + path.name, read(path))
    write('negative/PositiveCompileChecks.as', '''package {
   import flash.display.Sprite;
   import fe.weapon.Weapon;
   import fe.weapon.Bullet;
   public class PositiveCompileChecks extends Sprite {
      public function PositiveCompileChecks() {
         var w:LegalWeapon=new LegalWeapon(), b:LegalBullet=new LegalBullet();
         w.hold=1;b.babah=true;trace(w.hold,b.babah,w.extraGetter,b.extraGetter);
      }
   }
   internal class LegalWeapon extends Weapon {public function get extraGetter():int{return 1;}}
   internal class LegalBullet extends Bullet {public function get extraGetter():Boolean{return true;}}
}
''')

    slots = {}
    native_hash, classes = audit.inspect_swf(HOST)
    assert native_hash == EXPECTED_HOST
    parents = {'fe.weapon::Weapon':'fe::Obj', 'fe.weapon::Bullet':'fe::Obj',
               'fe::Obj':'fe::Pt', 'fe::Pt':'Object',
               'fe.weapon::PhisBullet':'fe.weapon::Bullet', 'fe.weapon::SmartBullet':'fe.weapon::Bullet'}
    for name, parent in parents.items():
        matches = [x for x in classes if x['name'] == name]
        assert len(matches) == 1 and matches[0]['parent'] == parent, name
        wanted = old.WEAPON if name == 'fe.weapon::Weapon' else old.BULLET if name == 'fe.weapon::Bullet' else []
        verified = {}
        for field in wanted:
            traits = [t for t in matches[0]['traits'] if t['name'] == field and
                      t['namespace_kind'] == 0x16 and t['namespace'] == '']
            assert len(traits) == 1 and traits[0]['kind'] == 0, (name, field)
            verified[field] = traits[0]
        slots[name] = dict(parent=parent, flags=matches[0]['flags'], slots=verified)
    assert inputs() == before_inputs
    evidence = dict(baseline=str(BASE), baseline_rc_sha256=EXPECTED_RC, bridge_sha256=EXPECTED_BRIDGE,
        host_sha256=EXPECTED_HOST, methods=methods, original_tables=tables,
        added_fields={'Weapon':old.WEAPON, 'Bullet':old.BULLET}, exact_host_traits=slots,
        inputs=before_inputs, production_overlay_written=False, JVM_started=False, AIR_started=False,
        component_compiled=False, benchmark_run=False,
        boundary='Real extracted algorithms; sealed slot/hierarchy fixtures, no native constructors or game weighting.')
    write('extraction.json', json.dumps(evidence, ensure_ascii=False, indent=2)+'\n')
    return evidence


if __name__ == '__main__':
    result = generate()
    print(json.dumps(dict(exact_methods=len(result['methods']), tables=len(result['original_tables']),
        public_slots=27, benchmark_groups=6, JVM_started=False, AIR_started=False)))

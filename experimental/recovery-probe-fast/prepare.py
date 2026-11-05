"""Read-only source audit; write only this proposal's overlay and components.

Never starts Java or AIR. Component ProbeBefore/ProbeAfter are extracted from
the actual frozen GameBridge source, not manually reimplemented algorithms.
"""
import hashlib
import json
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
GAME = ROOT.parents[1]
BASE = ROOT / 'build/m52/recovery-01/src/rconnect/game/GameBridge.as'
REF = GAME / 'game-reference/decompiled/1.02/src102/scripts'
WEAPON = ['owner', 'b', 'kol_shoot', 'hold', 'rashod', 'id', 'variant', 'rot',
          't_prep', 't_reload', 'rapid', 'flare', 'visexpl']
BULLET = ['owner', 'weap', 'babah', 'isExpl', 'vel', 'explRadius', 'spring',
          'flame', 'parr', 'tilehit', 'tipDecal', 'inWater', 'tipDamage', 'flare']


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write(relative, text):
    path = (HERE / relative).resolve()
    assert path.is_relative_to(HERE)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding='utf-8')


def declarations(relative):
    path = REF / relative
    text = path.read_text(encoding='utf-8-sig')
    fields = {}
    for match in re.finditer(r'\bpublic\s+var\s+(\w+)\s*:\s*([\w.*]+)', text):
        fields[match[1]] = dict(type=match[2], line=text[:match.start()].count('\n') + 1)
    return path, text, fields


def function(text, name):
    match = re.search(r'(?:public|private) static function ' + name + r'\(', text)
    assert match, name
    start = text.index('{', match.start())
    level = 1
    end = start + 1
    while level:
        level += (text[end] == '{') - (text[end] == '}')
        end += 1
    return text[match.start():end]


def constants(text):
    return re.findall(r'private static const NATIVE_\w+_FIELDS:Object=\{.*?\};', text, re.S)


def field_names(text, category):
    block = next(s for s in constants(text) if 'NATIVE_' + category + '_FIELDS:' in s)
    return re.findall(r'(\w+):true', block)


def class_source(name, text):
    imports = '\n'.join('   import ' + x + ';' for x in [
        'flash.display.DisplayObject', 'fe.unit.Unit', 'fe.Pt', 'fe.serv.Interact',
        'fe.weapon.Weapon', 'fe.weapon.Bullet'])
    members = '\n'.join(constants(text) + [function(text, 'probe'), function(text, 'probeOptional')])
    return 'package probecheck {\n' + imports + '\n   public class ' + name + ' {\n' + members + '\n   }\n}\n'


def fixture(relative, parent, fields, extra=''):
    package, name = relative.rsplit('/', 1)
    name = name[:-3]
    package = package.replace('/', '.')
    declarations_ = []
    for key, info in fields.items():
        kind = info['type']
        # Primitive/Array fields retain their native type. Native game object
        # references use Object, with identity tested; no native world is built.
        if kind not in ('Number', 'int', 'uint', 'Boolean', 'String', '*', 'Array', 'Object'):
            kind = 'Object'
        declarations_.append('      public var ' + key + ':' + kind + ';')
    write('components/' + relative, 'package ' + package + ' {\n   public class ' + name +
          (' extends ' + parent if parent else '') + ' {\n' + '\n'.join(declarations_) + '\n' +
          extra + '\n   }\n}\n')


def main():
    old = BASE.read_text(encoding='utf-8-sig')
    references = {}
    for relative in ['fe/Pt.as', 'fe/Obj.as', 'fe/unit/Unit.as', 'fe/serv/Interact.as',
                     'fe/weapon/Weapon.as', 'fe/weapon/Bullet.as',
                     'fe/weapon/PhisBullet.as', 'fe/weapon/SmartBullet.as']:
        path, text, fields = declarations(relative)
        references[relative] = dict(path=str(path), sha256=sha(path), fields=fields, text=text)
    for cls, fields in [('Weapon', WEAPON), ('Bullet', BULLET)]:
        text = references['fe/weapon/' + cls + '.as']['text']
        assert re.search(r'class ' + cls + r' extends Obj', text)
        known = references['fe/weapon/' + cls + '.as']['fields']
        assert all(field in known for field in fields), (cls, set(fields) - known.keys())
        for field in fields:
            assert not re.search(r'public\s+function\s+(get|set)\s+' + field + r'\s*\(', text)
    assert 'class Obj extends Pt' in references['fe/Obj.as']['text']
    new = old.replace('   import fe.Pt;', '   import fe.Pt;\n   import fe.weapon.Weapon;\n   import fe.weapon.Bullet;', 1)
    anchor = '      /** 安全探测成员；成员不存在/不可访问时返回 null。 */'
    addition = ('      // Verified 1.02 public slots. Weapon/Bullet inherit Pt; no getter\n'
                '      // or Proxy can replace these inherited variable traits. Unknown\n'
                '      // names retain the original membership check and protected read.\n')
    for cls, fields in [('WEAPON', WEAPON), ('BULLET', BULLET)]:
        addition += '      private static const NATIVE_' + cls + '_FIELDS:Object={' + ','.join(f + ':true' for f in fields) + '};\n'
    assert old.count(anchor) == 1
    new = new.replace(anchor, addition + '\n' + anchor, 1)
    before = '            || o is Pt && NATIVE_POINT_FIELDS[name]===true'
    after = ('            || o is Pt && (NATIVE_POINT_FIELDS[name]===true\n'
             '               || o is Weapon && NATIVE_WEAPON_FIELDS[name]===true\n'
             '               || o is Bullet && NATIVE_BULLET_FIELDS[name]===true)')
    assert new.count(before) == 1
    new = new.replace(before, after, 1)
    assert function(old, 'probeOptional') == function(new, 'probeOptional')
    write('src/rconnect/game/GameBridge.as', new)
    write('components/probecheck/ProbeBefore.as', class_source('ProbeBefore', old))
    write('components/probecheck/ProbeAfter.as', class_source('ProbeAfter', new))
    pt_names = field_names(old, 'POINT')
    pt = references['fe/Pt.as']['fields']
    assert all(k in pt for k in pt_names)
    fixture('fe/Pt.as', None, {k: pt[k] for k in pt_names})
    fixture('fe/Obj.as', 'fe.Pt', {})
    hierarchy = {**pt, **references['fe/Obj.as']['fields'], **references['fe/unit/Unit.as']['fields']}
    unit_fields = field_names(old, 'UNIT')
    assert all(k in hierarchy for k in unit_fields), set(unit_fields) - hierarchy.keys()
    fixture('fe/unit/Unit.as', 'fe.Obj', {k: hierarchy[k] for k in unit_fields if k not in pt_names})
    inter = references['fe/serv/Interact.as']['fields']
    fixture('fe/serv/Interact.as', None, {k: inter[k] for k in field_names(old, 'INTERACT')})
    fixture('fe/weapon/Weapon.as', 'fe.Obj', {k: references['fe/weapon/Weapon.as']['fields'][k] for k in WEAPON},
            '      internal var is_attack:Boolean=false;')
    fixture('fe/weapon/Bullet.as', 'fe.Obj', {k: references['fe/weapon/Bullet.as']['fields'][k] for k in BULLET},
            '      internal var expl_t:int=0;')
    fixture('fe/weapon/PhisBullet.as', 'fe.weapon.Bullet', {})
    fixture('fe/weapon/SmartBullet.as', 'fe.weapon.Bullet', {})
    fields = {'Weapon': WEAPON, 'Bullet': BULLET}
    write('components/probecheck/FieldLists.as', 'package probecheck { public class FieldLists {\n' +
          '\n'.join('public static const ' + k.upper() + ':Array=' + json.dumps(v) + ';' for k, v in fields.items()) + '\n}}\n')
    audit = dict(base=dict(path=str(BASE), sha256=sha(BASE)), overlay_sha256=sha(HERE / 'src/rconnect/game/GameBridge.as'),
                 added_fields={k: {f: references['fe/weapon/' + k + '.as']['fields'][f] for f in names}
                               for k, names in fields.items()},
                 references={k: {a:b for a,b in v.items() if a != 'text' and a != 'fields'} for k,v in references.items()},
                 compile_stubs={k:dict(path=str(ROOT / 'tools/stubs/fe/weapon' / (k + '.as')),
                                      sha256=sha(ROOT / 'tools/stubs/fe/weapon' / (k + '.as')),
                                      limitation='type identity only; incomplete inheritance and fields') for k in fields},
                 probe_optional_source_equal=True, java_started=False, air_started=False)
    write('audit.json', json.dumps(audit, ensure_ascii=False, indent=2) + '\n')
    import difflib
    write('proposal.patch', ''.join(difflib.unified_diff(old.splitlines(True), new.splitlines(True),
          fromfile='recovery-01/src/rconnect/game/GameBridge.as', tofile='overlay/src/rconnect/game/GameBridge.as')))
    print(json.dumps(dict(weapon_fields=len(WEAPON), bullet_fields=len(BULLET),
                         source_bytes=(HERE / 'src/rconnect/game/GameBridge.as').stat().st_size, java_started=False, air_started=False)))


if __name__ == '__main__':
    main()

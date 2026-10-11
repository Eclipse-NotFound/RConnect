"""Add opt-in native scheduling/input seams to an isolated, pinned game copy.

Callbacks default to null. Native behavior remains the fallback for A. This
does not change the installation, loader, map generator, assets or class list.
"""
import argparse
import difflib
import struct
import subprocess
import zlib
from common import ROOT, JAVA, FFDEC, inside_build, verify_baseline, sha, save


def once(source, before, after):
    if source.count(before) != 1:
        raise ValueError('Native anchor absent or ambiguous: '+before[:100])
    return source.replace(before, after, 1)


def modify(name, source):
    if 'RCONNECT_AUTHORITY_HOOKS' in source:
        raise ValueError('Refuse to patch an already patched native class')
    if name == 'fe.unit.Unit':
        anchor = '      public function findCel(param1:Boolean = false) : Boolean\n      {'
        return once(source, anchor,
            '      public static const RCONNECT_AUTHORITY_HOOKS:String = "b1-v3";\n'
            '      public static var rconnectFindTarget:Function = null;\n'
            '      private static var rconnectFinding:Boolean = false;\n\n'+anchor+'\n'
            '         if(rconnectFindTarget != null && !rconnectFinding)\n         {\n'
            '            rconnectFinding = true;\n            try\n            {\n'
            '               return Boolean(rconnectFindTarget(this,param1));\n            }\n'
            '            finally\n            {\n               rconnectFinding = false;\n            }\n         }')
    if name == 'fe.inter.Ctr':
        source = once(source, '      public function Ctr(param1:* = null)',
            '      public static const RCONNECT_AUTHORITY_HOOKS:String = "b1-v3";\n\n'
            '      public function Ctr(param1:* = null, bindStage:Boolean = true)')
        first = '         World.w.swfStage.addEventListener(MouseEvent.MIDDLE_MOUSE_DOWN,this.onMiddleMouseDown1);'
        last = '         World.w.swfStage.addEventListener(KeyboardEvent.KEY_UP,this.onKeyboardUpEvent);'
        source = once(source, first, '         if(bindStage)\n         {\n'+first)
        return once(source, last, last+'\n         }')
    if name == 'fe.loc.Location':
        source = once(source, '      public var land:Land;',
            '      public static const RCONNECT_AUTHORITY_HOOKS:String = "b1-v3";\n'
            '      public static var rconnectPlayerStep:Function = null;\n'
            '      public static var rconnectObjectStep:Function = null;\n\n      public var land:Land;')
        source = once(source, '         this.gg.step();',
            '         if(rconnectPlayerStep != null)\n         {\n            rconnectPlayerStep(this);\n         }\n'
            '         else\n         {\n            this.gg.step();\n         }')
        if source.count('               obj.step();') != 2:
            raise ValueError('Expected active and invisible object step anchors')
        return source.replace('               obj.step();',
            '               if(rconnectObjectStep != null)\n               {\n                  rconnectObjectStep(this,obj);\n               }\n'
            '               else\n               {\n                  obj.step();\n               }')
    if name == 'fe.loc.Land':
        source = once(source, '      public var loc:Location;',
            '      public static const RCONNECT_AUTHORITY_HOOKS:String = "b1-v3";\n'
            '      public static var rconnectRoomStep:Function = null;\n\n      public var loc:Location;')
        block = '''            this.loc.step();
            if(this.loc_t > 0)
            {
               --this.loc_t;
               if(Boolean(this.prevloc) && this.loc != this.prevloc)
               {
                  this.prevloc.stepInvis();
               }
            }'''
        return once(source, block,
            '            if(rconnectRoomStep != null)\n            {\n               rconnectRoomStep(this);\n            }\n'
            '            else\n            {\n'+block+'\n            }')
    if name == 'fe.unit.UnitPlayer':
        source = once(source, '      override public function damage(param1:Number, param2:int, param3:Bullet = null, param4:Boolean = false) : Number\n      {',
            '      public static const RCONNECT_AUTHORITY_HOOKS:String = "b1-v3";\n'
            '      public static var rconnectDamage:Function = null;\n\n'
            '      override public function damage(param1:Number, param2:int, param3:Bullet = null, param4:Boolean = false) : Number\n      {\n'
            '         if(rconnectDamage != null && World.w.gg != this)\n         {\n'
            '            return Number(rconnectDamage(this,param1,param2,param3,param4));\n         }')
        return source
    raise ValueError(name)


def swf_tags(path):
    raw = path.read_bytes()
    if raw[:3] == b'CWS':
        raw = raw[:8]+zlib.decompress(raw[8:])
    elif raw[:3] != b'FWS':
        raise ValueError('Unsupported SWF header')
    pos = 8+(5+4*(raw[8] >> 3)+7)//8+4
    result = []
    while pos < len(raw):
        tag = struct.unpack_from('<H', raw, pos)[0]
        pos += 2
        size, kind = tag & 63, tag >> 6
        if size == 63:
            size = struct.unpack_from('<I', raw, pos)[0]
            pos += 4
        data = raw[pos:pos+size]
        if len(data) != size:
            raise ValueError('Invalid SWF tag length')
        result.append((kind, data))
        pos += size
        if kind == 0:
            break
    return result


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--baseline', required=True)
    ap.add_argument('--output', required=True)
    args = ap.parse_args()
    baseline = inside_build(ROOT/args.baseline)
    verify_baseline(baseline)
    out = inside_build(ROOT/args.output)
    if out.exists():
        raise FileExistsError('Native experiments never overwrite an earlier result')
    out.mkdir(parents=True)
    original = baseline/'game/pfe.swf'
    classes = ['fe.inter.Ctr', 'fe.loc.Location', 'fe.loc.Land', 'fe.unit.Unit', 'fe.unit.UnitPlayer']
    ff = [str(JAVA), '-Xmx768m', '-jar', str(FFDEC)]
    with (out/'patch.log').open('w', encoding='utf-8') as log:
        def run(args):
            subprocess.run(ff+args, stdout=log, stderr=subprocess.STDOUT, check=True)
        run(['-selectclass', ','.join(classes+['MainFE']), '-export', 'script', str(out/'export'), str(original)])
        for name in classes:
            rel = name.replace('.', '/')+'.as'
            source = (out/'export/scripts'/rel).read_text(encoding='utf-8-sig')
            modified = modify(name, source)
            dest = out/'import'/rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_text(modified, encoding='utf-8')
            (out/(name+'.patch')).write_text(''.join(difflib.unified_diff(source.splitlines(True), modified.splitlines(True),
                fromfile='A/'+rel, tofile='B/'+rel)), encoding='utf-8')
        run(['-importScript', str(original), str(out/'pfe.swf'), str(out/'import')])
        run(['-selectclass', ','.join(classes+['MainFE']), '-export', 'script', str(out/'verified'), str(out/'pfe.swf')])
    for name in classes:
        source = (out/'verified/scripts'/(name.replace('.', '/')+'.as')).read_text(encoding='utf-8-sig')
        if 'RCONNECT_AUTHORITY_HOOKS' not in source:
            raise RuntimeError('Patch missing after round trip: '+name)
    if (out/'export/scripts/MainFE.as').read_bytes() != (out/'verified/scripts/MainFE.as').read_bytes():
        raise RuntimeError('Loader unexpectedly changed')
    before, after = swf_tags(original), swf_tags(out/'pfe.swf')
    if len(before) != len(after):
        raise RuntimeError('SWF tag list changed')
    changed = [i for i, (a, b) in enumerate(zip(before, after)) if a != b]
    if not changed or any(before[i][0] != 82 or after[i][0] != 82 for i in changed):
        raise RuntimeError('Non-code SWF content changed')
    for label, path in [('before', original), ('after', out/'pfe.swf')]:
        with (out/(label+'-classes.txt')).open('w', encoding='utf-8') as log:
            subprocess.run(ff+['-dumpAS3', str(path)], stdout=log, check=True)
    if (out/'before-classes.txt').read_bytes() != (out/'after-classes.txt').read_bytes():
        raise RuntimeError('Native class list changed')
    save(out/'native-input.json', dict(experimental_only=True, capability='b1-v3',
        baseline=str(baseline.relative_to(ROOT)), baseline_manifest_sha256=sha(baseline/'baseline.json'),
        original_sha256=sha(original), candidate_sha256=sha(out/'pfe.swf'),
        sources={p.relative_to(out).as_posix():sha(p) for p in sorted((out/'import').rglob('*.as'))},
        changed_tags=changed, loader_unchanged=True, class_list_unchanged=True,
        script_sha256=sha(__file__)))
    verify_baseline(baseline)
    print('Opt-in native hooks: '+str(out/'pfe.swf'), flush=True)


if __name__ == '__main__':
    main()

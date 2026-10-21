"""Derive a two-file acid footprint candidate from frozen recovery-07; no JVM/AIR."""
import argparse
import difflib
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT / 'build/m52/recovery-07/src/rconnect/game'
PINNED = {
    'BurnVisuals.as': '74be601fe5404e70f13440ed15ce5b32950153ae6c5c3bfbab9e902ad2abe070',
    'ProjectileExplosionVisuals.as': '42ca278448b3768c5168c13d03efc9b57602fdc8aea6189990d7a6cd0dab78d2',
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def one(text, old, new):
    assert text.count(old) == 1, old
    return text.replace(old, new, 1)


def sources():
    assert all(sha(BASE / p) == h for p, h in PINNED.items()), 'Frozen ancestor changed'
    old = {p: (BASE / p).read_text(encoding='utf-8') for p in PINNED}
    new = dict(old)
    text = old['BurnVisuals.as']
    text = one(text, 'Cosmetic copies of the native burning status and fire left by a fire blast.',
               'Cosmetic copies of burning status and native fire/acid blast footprints.')
    text = one(text, '''      /** Reproduce Bullet.explLiquid("fire",-33)'s *visual* footprint after
       * the native blast changed the source tiles. This reads only the source
       * Location and sends coordinates, so a receiver with a delayed terrain
       * patch still gets the correct fire positions. Native fire Part has no
       * damage or terrain behavior (fe.graph.Part.step). */''', '''      /** Read Bullet.explLiquid's surface footprint after native terrain damage.
       * Fire uses phY1-33 and excludes water; acid uses phY1 even in water.
       * Coordinates come from the source, never a receiver's delayed terrain.
       * Both emit native cosmetic Part objects, without damage behavior. */''')
    text = one(text, '''         if(b==null || int(GameBridge.probe(b,"tipDamage"))!=3
            || Number(GameBridge.probe(b,"inWater"))>0)return out;''', '''         if(b==null)return out;
         var type:int=int(GameBridge.probe(b,"tipDamage"));
         if(type!=3 && type!=10)return out;
         if(type==3 && Number(GameBridge.probe(b,"inWater"))>0)return out;''')
    text = one(text, '''            var fireY:Number=Number(GameBridge.probe(tile,"phY1"))-33;
            if(!isFinite(fireY))continue;
            out.push({x:(tx+.5)*40,y:fireY});''', '''            var surfaceY:Number=Number(GameBridge.probe(tile,"phY1"))-(type==3?33:0);
            if(!isFinite(surfaceY))continue;
            out.push({x:(tx+.5)*40,y:surfaceY});''')
    text = one(text, 'public static function playGround(main:Object,room:Object,points:Array):void {',
               'public static function playGround(main:Object,room:Object,points:Array,kind:String="fire"):void {\n'
               '         if(kind!="fire" && kind!="acid")return;')
    text = one(text, '''            if(isFinite(x)&&isFinite(y)&&x>=0&&y>=0&&x<=maxX&&y<=maxY)
               emitter.emit("fire",room,x,y);''', '''            if(isFinite(x)&&isFinite(y)&&x>=0&&y>=0&&x<=maxX&&y<=maxY) {
               // Native explLiquid jitters +/-2px. Keep the existing fire path;
               // acid draws its cosmetic jitter here, not on the source RNG.
               emitter.emit(kind,room,x+(kind=="acid"?Math.random()*4-2:0),y);
            }''')
    new['BurnVisuals.as'] = text
    new['ProjectileExplosionVisuals.as'] = one(old['ProjectileExplosionVisuals.as'],
        '               if(!repeat){names=["acidexpl","acidkap"];snd="acid_e";}',
        '               if(!repeat){names=["acidexpl","acidkap"];snd="acid_e";\n'
        '                  BurnVisuals.playGround(main,loc,state.ground as Array,"acid");}')
    return old, new


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(value.encode('utf-8'))


def derived(old, new):
    out = {}
    for name, text in new.items():
        out['src/rconnect/game/' + name] = text
    for suffix, source in [('Before', old), ('After', new)]:
        for name, text in source.items():
            for original in ('BurnVisuals', 'ProjectileExplosionVisuals'):
                text = text.replace(original, original + suffix)
            out['components/rconnect/game/' + name[:-3] + suffix + '.as'] = text
    out['proposal.patch'] = ''.join(''.join(difflib.unified_diff(
        old[name].splitlines(True), new[name].splitlines(True),
        fromfile='recovery-07/src/rconnect/game/' + name,
        tofile='recovery-acid-ground/src/rconnect/game/' + name)) for name in old)
    return out


def verify():
    old, new = sources()
    expected = derived(old, new)
    assert all((HERE / p).read_text(encoding='utf-8') == value for p, value in expected.items())
    manifest = json.loads((HERE / 'inputs.json').read_text(encoding='utf-8'))
    inventory = {p.relative_to(HERE).as_posix(): sha(p)
                 for tree in ('src', 'components') for p in sorted((HERE / tree).rglob('*')) if p.is_file()}
    assert inventory == manifest['files']
    assert manifest['prepare_sha256'] == sha(Path(__file__))
    assert manifest['patch_sha256'] == sha(HERE / 'proposal.patch')
    assert manifest['baseline'] == PINNED
    return {'verified': True, 'overlay_files': 2, 'expected_assertions': manifest['expected_assertions'],
            'JVM_started': False, 'AIR_started': False}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--verify', action='store_true')
    args = parser.parse_args()
    if not args.verify:
        old, new = sources()
        for path, value in derived(old, new).items():
            write(HERE / path, value)
        manifest = {'baseline': PINNED, 'ancestor': 'build/m52/recovery-07',
                    'prepare_sha256': sha(Path(__file__)), 'patch_sha256': sha(HERE / 'proposal.patch'),
                    'expected_assertions': 49, 'native_game_tested': False, 'performance_qualified': False,
                    'files': {p.relative_to(HERE).as_posix(): sha(p)
                              for tree in ('src', 'components') for p in sorted((HERE / tree).rglob('*')) if p.is_file()}}
        write(HERE / 'inputs.json', json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(verify()))

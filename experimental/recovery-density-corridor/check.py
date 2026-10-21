"""Small pure-Python source/geometry check; does not compile, freeze or run AIR."""
import ast
import json
import math
from pathlib import Path
import re
from prepare import HERE, ROOT, FROZEN, check_source, sha, read, save


def geometry():
    # Native LMG speed is 200; non-gravity speed variation is [0.8,1.2).
    # Frozen frame stimulus is -pi/3 +/- .2; bounded mazil<=30 contributes
    # +/-15 degrees, devMult<=1, deviation=0, native non-player recoilUp=0.
    # Runtime preparation checks these conditions without changing them.
    amin, amax = -math.pi / 3 - .2 - math.pi / 12, -math.pi / 3 + .2 + math.pi / 12
    vmax = 240
    assert -math.pi/2 < amin < amax < 0
    rows = []
    for step in range(1, 4):
        distance = step * vmax
        # Loose axis-aligned enclosure is enough; every actual ray is inside.
        xmin, xmax = 240, 460 + distance * math.cos(amax)
        ymin, ymax = 860 - distance * abs(math.sin(amin)), 950
        assert 40 < xmin < xmax < 1880 and 40 < ymin < ymax < 960
        rows.append(dict(step=step, max_distance=distance, envelope=[xmin, ymin, xmax, ymax]))
    reference = ROOT.parents[1] / 'game-reference/decompiled/1.02/src102/scripts/fe'
    refs = [reference / 'AllData.as', reference / 'weapon/Weapon.as', reference / 'weapon/Bullet.as',
            reference / 'loc/Tile.as', reference / 'loc/Location.as', reference / 'graph/Grafon.as']
    return dict(static_geometry_only=True, runtime_verified=False, unchanged_native_speed=True,
        native_speed_variation=[160, 240], muzzle_bounds=[240, 860, 460, 950],
        direction_radians=[amin, amax], open_rectangle=[40, 40, 1880, 960],
        guaranteed_collision_free_native_steps_if_preconditions_hold=3,
        conservative_first_possible_boundary_distance=(860-40)/abs(math.sin(amin)),
        steps=rows,
        limits=['Geometry does not guarantee final visibility, TCP delivery, source sampling or FPS.',
                'Runtime muzzle/native parameter checks must pass; native findCel=false uses existing forceRot. No warm-up shots.',
                'Perimeter collision still uses native Bullet.run; no damage/lifetime/speed patch.',
                'Existing 80 disabled enemies are ignored by native Bullet.run; both players are left of muzzle cone.',
                'Unknown active static objects/proxies fail setup instead of being silently ignored.',
                'Geometry is for initial bounded fixture; actual measured motion checks remain decisive.'],
        reference_sha256={str(p.relative_to(ROOT.parents[1])): sha(p) for p in refs})


def main():
    check_source()
    for path in HERE.glob('*.py'):
        ast.parse(path.read_text(encoding='utf-8'))
    for path in (HERE / 'tests').glob('*.as'):
        code = path.read_text(encoding='utf-8-sig')
        code = re.sub(r'/\*.*?\*/|//[^\n]*|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'', '', code, flags=re.S)
        stack = []
        for char in code:
            if char in '({[': stack.append(char)
            elif char in ')}]': assert stack and stack.pop() == {')':'(',']':'[','}':'{'}[char], path
        assert not stack, path
    proof = geometry()
    save(HERE / 'geometry-proof.json', proof)
    source = (HERE / 'tests/CorridorFixture.as').read_text(encoding='utf-8')
    # The setup may not forge or invoke bullet simulation. It uses real native
    # Tile defaults/mainFrame and Location.remObj/redrawLoc before timing only.
    for forbidden in ('b.dx=', 'b.dy=', 'b.liv=', 'gun.speed=', 'gun.speedMult=', '.attack()', '.step()', '.run()'):
        assert forbidden not in source, forbidden
    main_src = (HERE / 'tests/SustainedDensityTestDoc.as').read_text(encoding='utf-8')
    assert main_src.count('CorridorFixture.apply(') == 2
    assert 'CorridorFixture' not in main_src.split('      private function frame(e:Event):void {', 1)[1]
    report = dict(static_checks=True, as_compiled=False, air_started=False, runtime_verified=False,
        fixed_driver_manifest_sha256=sha(FROZEN / 'prepared.json'),
        original_frame_and_render_unchanged=True, original_seven_windows_and_assertions_unchanged=True,
        setup_only_changes=True, no_production_edit=True, no_warmup=True,
        geometry_sha256=sha(HERE / 'geometry-proof.json'),
        files={p.relative_to(HERE).as_posix():sha(p) for p in sorted(HERE.rglob('*')) if p.suffix in ('.py','.as','.json') and p.name!='static-check.json'})
    save(HERE / 'static-check.json', report)
    print(json.dumps({k:v for k,v in report.items() if k!='files'}, ensure_ascii=False))


if __name__ == '__main__':
    main()

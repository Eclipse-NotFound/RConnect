"""Source-only ordinary-room counterpart of the tested native pixel correction."""
from pathlib import Path
import hashlib,json,shutil,difflib

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
BASE=ROOT/'experimental/recovery-wall-color-buildsrc/components'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def inventory(p):return {x.relative_to(p).as_posix():sha(x) for x in sorted(p.rglob('*')) if x.is_file()}

assert not (HERE/'components').exists(), 'Do not overwrite a frozen experiment'
actual=ROOT/'build/m52/recovery-wall-color-integration-component-01'
r=json.loads((actual/'receipt.json').read_text())
assert r['passed'] and r['observed_checks']==69 and r['checks_failed']==0
assert inventory(BASE)==inventory(actual/'src')
shutil.copytree(BASE,HERE/'components')
name='rconnect/game/WallImpactVisuals.as'
before=(BASE/name).read_bytes();after=before
for a,b in [
 (b'b.setPixel32(x,y,color);',b'b.setPixel32(x,y,NativeWallColor.setter(color));'),
 (b'b.setPixel32(x,y,uint(c.values[key]));',b'b.setPixel32(x,y,NativeWallColor.setter(uint(c.values[key])));')]:
 assert after.count(a)==1
 after=after.replace(a,b)
(HERE/'components'/name).write_bytes(after)
overlay=HERE/'src'/name;overlay.parent.mkdir(parents=True,exist_ok=True);overlay.write_bytes(after)
checks=(BASE/'WallSurfaceChecks.as').read_text()
anchor='   }catch(error:Error){check(false,"uncaught: "+error.getStackTrace());}'
assert checks.count(anchor)==1
addon=(HERE/'small-checks.inc').read_text()
(HERE/'components/WallSurfaceChecks.as').write_text(checks.replace(anchor,addon+anchor),encoding='utf-8')
(HERE/'ordinary-setters.patch').write_text(''.join(difflib.unified_diff(before.decode().splitlines(True),after.decode().splitlines(True),fromfile='recovery18/'+name,tofile='ordinary-color/'+name)),encoding='utf-8')
manifest=dict(kind='ordinary-wall-color-source-only',baseline=inventory(BASE),source=inventory(HERE/'src'),components=inventory(HERE/'components'),
 baseline_component_receipt_sha256=sha(actual/'receipt.json'),expected_checks=85,original_checks=69,added_checks=16,
 compiled=False,air_started=False,installed=False,performance_qualified=False)
(HERE/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print('Prepared 85 checks and two exact final-setter replacements only')

"""Compile-only fixture fixes plus a same-pixel red counterexample. No production edits."""
from pathlib import Path
import argparse,difflib,hashlib,json,sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
BASE=ROOT/'experimental/recovery-ordinary-wall-edge'
PIN='17c19ab989f3a357d79a01a58a42bcc50d817b2751c165c9dbc026ae95dc4ca3'
EXPECTED=136
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def save(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def inventory(p):return {x.relative_to(p).as_posix():sha(x) for x in sorted(p.rglob('*.as'))}
def test_source():
 t=(BASE/'components/WallSurfaceChecks.as').read_text()
 assert t.count(' import fe.graph.Grafon;')==1
 t=t.replace(' import fe.graph.Grafon;',' import fe.graph.Grafon;\n import fe.weapon.Bullet;')
 assert t.count('fe.weapon.Bullet')==7
 t=t.replace('fe.weapon.Bullet','Bullet').replace(' import Bullet;',' import fe.weapon.Bullet;')
 assert t.count('    edgeChecks();')==1
 t=t.replace('    edgeChecks();','    edgeChecks();\n    samePixelChecks();')
 assert t.endswith(' }\n}\n')
 return t[:-5]+(HERE/'same-pixel.as.txt').read_text()+' }\n}\n'
def verify():
 m=read(HERE/'inputs.json')
 for p,h in m['inputs'].items():assert sha(Path(p))==h,p
 assert inventory(HERE/'components')==m['components']
 for name in m['components']:
  if name not in ['WallSurfaceChecks.as','fe/graph/Grafon.as']:
   assert (HERE/'components'/name).read_bytes()==(BASE/'components'/name).read_bytes(),name
 assert (HERE/'components/WallSurfaceChecks.as').read_text()==test_source()
 assert (HERE/'components/fe/graph/Grafon.as').read_bytes()==(BASE/'components/fe/graph/Grafon.as').read_bytes().replace(b'for each(var entry in this.sceneChunks)',b'for each(var entry:Object in this.sceneChunks)')
 return {'passed':True,'production_unchanged':True,'original_132_assertions_preserved':True,'expected_checks':EXPECTED,'expected_product_failure':'134 same-pixel last-arrival ink converges after earlier native erase','compiled':False,'air_started':False}
def main():
 assert not (HERE/'components').exists()
 assert sha(BASE/'handoff.json')==PIN
 orig=read(BASE/'inputs.json');assert inventory(BASE/'components')==orig['components']
 files=list((BASE/'components').rglob('*.as'))
 for f in files:
  dest=HERE/'components'/f.relative_to(BASE/'components');dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(f.read_bytes())
 (HERE/'components/WallSurfaceChecks.as').write_text(test_source(),encoding='utf-8')
 g=HERE/'components/fe/graph/Grafon.as';b=g.read_bytes();assert b.count(b'for each(var entry in this.sceneChunks)')==1;g.write_bytes(b.replace(b'for each(var entry in this.sceneChunks)',b'for each(var entry:Object in this.sceneChunks)'))
 inputs=[Path(__file__),HERE/'run_component.py',HERE/'same-pixel.as.txt',BASE/'handoff.json',BASE/'inputs.json',ROOT/'tools/validation/run_recovery_component.py',ROOT/'build/m52/recovery-ordinary-wall-edge-component-01/receipt.json',ROOT/'build/m52/recovery-ordinary-wall-edge-component-01/compile.log',ROOT/'build/m52/recovery21-small-wall-component-01/compile.log']+files
 save(HERE/'inputs.json',{'base_handoff_sha256':PIN,'inputs':{str(p):sha(p) for p in inputs},'components':inventory(HERE/'components'),'expected_checks':EXPECTED,'expected_failure_label':'134 same-pixel last-arrival ink converges after earlier native erase','production_changes':False,'compiled':False,'air_started':False})
 changes=[]
 for n in ['WallSurfaceChecks.as','fe/graph/Grafon.as']:
  changes.extend(difflib.unified_diff((BASE/'components'/n).read_text().splitlines(True),(HERE/'components'/n).read_text().splitlines(True),fromfile='frozen-v1/'+n,tofile='v2-fixture/'+n))
 (HERE/'fixture.patch').write_text(''.join(changes),encoding='utf-8')
 r=verify();save(HERE/'static-checks.json',r);print(json.dumps(r))
if __name__=='__main__':
 if '--verify' in sys.argv:print(json.dumps(verify()))
 else:main()

"""Reuse driver04's strict pixel/proof checks with ordinary-front admission.
PNG representation compatibility affects only the artifact check, never peer uints.
"""
from pathlib import Path
import hashlib, importlib.util, inspect

HERE=Path(__file__).resolve().parent
ROOT=next(p for p in HERE.parents if (p/'tools/validation/prepare_recovery.py').is_file())
FROZEN=ROOT/'build/m52/recovery-wall-surfaces-driver-04/inputs/large-wall/verify_results.py'
PNG=ROOT/'experimental/recovery-wall-surfaces-native-proof-review/verify_evidence.py'
PINS={FROZEN:'a3e8d886772d8facada4363331e79b6277c582b316f05c00e360e7edd247e874',
 PNG:'1b330ee95266852bcf0c14065de5e40d22231f125a46e12516152a36335d4dad'}
def load(path,name):
 assert hashlib.sha256(path.read_bytes()).hexdigest()==PINS[path]
 spec=importlib.util.spec_from_file_location(name,path);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module
base=load(FROZEN,'ordinary_wall_frozen_analyzer');png=load(PNG,'ordinary_wall_png_representation')
CASES,pairs,delta=base.CASES,base.pairs,base.delta

def ordinary_surfaces(row):
 area=row['area'];assert area['w']==area['h']==128 and 0<=area['x']<=1792 and 0<=area['y']<=872
 for key in ('surfaces','finalSurfaces'):
  assert len(row[key])==1,'Ordinary proof requires one actual native front'
  s=row[key][0]
  assert s['mode']=='ordinary' and s['sceneLarge'] is False
  assert s['width']==1920 and s['height']==1000 and s['x']==s['y']==s['originX']==s['originY']==0
  assert s['roomWidth']==48 and s['roomHeight']==25 and s['residentChunks']==0
  assert s['backingIdentity'] is True and s['uniqueFront'] is True and s['staged'] is True and s['visible'] is True
 for hit in row['hits']:
  assert area['x']<=hit['x']<area['x']+128 and area['y']<=hit['y']<area['y']+128

def comparison_source():
 source=inspect.getsource(base.compare)
 edits=[
  ("assert target['x'] > 1920 or target['y'] > 1000", "assert 0 <= target['x'] < 1920 and 0 <= target['y'] < 1000"),
  ("assert hit['x'] > 1920 or hit['y'] > 1000, 'Actual collision did not cross old limit'", "assert 0 <= hit['x'] < 1920 and 0 <= hit['y'] < 1000, 'Actual collision left ordinary front'"),
  ("assert all(x['scratchDifferent'] and x['staged'] for x in row['surfaces'] + row['finalSurfaces'])\n        assert all(x['width'] == x['side'] + 2*x['gutter'] and x['height'] == x['width'] for x in row['surfaces'])", "ordinary_surfaces(row)"),
 ]
 for before,after in edits:
  assert source.count(before)==1,before
  source=source.replace(before,after)
 return source
scope=dict(base.__dict__,ordinary_surfaces=ordinary_surfaces)
exec(compile(comparison_source(),'<driver04 ordinary admission only>','exec'),scope)
compare=scope['compare']

def analyze(root,logs):
 reports={}
 def png_check(path,expected):reports[str(path.relative_to(root))]=png.compatible_words(expected,base.png_words(path))
 source=inspect.getsource(base.analyze)
 before="assert png_words(png) == row[field], 'PNG does not contain corresponding real crop: ' + png.name"
 assert source.count(before)==1;source=source.replace(before,'_png_check(png,row[field])')
 env=dict(base.__dict__,compare=compare,_png_check=png_check)
 exec(compile(source,'<driver04 artifact PNG representation only>','exec'),env)
 result=env['analyze'](root,logs)
 result.update(scene_mode='ordinary',png_audit=reports,
  png_representation_compatible=len(reports)==32 and all(r['representation_compatible'] for r in reports.values()),
  source_remote_comparison='exact uint equality; no tolerance',performance_qualified=False)
 result['passed']=bool(result['passed'] and result['png_representation_compatible'])
 return result

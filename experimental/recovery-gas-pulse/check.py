"""Offline proposal integrity only. Does not claim AS3 behavior or launch tools."""
import ast
import json
from pathlib import Path
import re
from unittest.mock import patch
import prepare as recipe

rows=[]
def check(name,ok):
 assert ok,name
 rows.append(dict(label=name,passed=True))

def main():
 with patch('subprocess.Popen',side_effect=AssertionError('Offline only')):
  info=recipe.verify();check('Manifest and exact recovery11 ancestor',info['verified'])
  source=recipe.HERE/'src/rconnect/game';control=recipe.HERE/'components/control';candidate=recipe.HERE/'components/candidate'
  check('Exactly four production overlays',set(p.name for p in source.glob('*.as'))==set(recipe.PINNED))
  for n in recipe.REAL:
   rel='rconnect/game/'+n+'.as'
   assert (control/rel).read_bytes()==(recipe.BASE/'src'/rel).read_bytes()
   expected=recipe.HERE/'src'/rel if (recipe.HERE/'src'/rel).is_file() else recipe.BASE/'src'/rel
   assert (candidate/rel).read_bytes()==expected.read_bytes()
  check('Component real classes are full exact before and after',True)
  altered={p.relative_to(control).as_posix() for p in control.rglob('*.as')
           if p.read_bytes()!=(candidate/p.relative_to(control)).read_bytes()}
  check('Control and candidate differ only in four production classes',altered=={'rconnect/game/'+n for n in recipe.PINNED})
  test=(control/'GasPulseChecks.as').read_text()
  check('63 direct assertions excluding catch and definition',len(re.findall(r'\bcheck\(',test))-2==63)
  check('Shared entry and boundary fixtures unchanged',all((control/p.relative_to(recipe.HERE/'tests')).read_bytes()==p.read_bytes()
        for p in (recipe.HERE/'tests').rglob('*.as') if p.relative_to(recipe.HERE/'tests').as_posix() not in {'rconnect/game/'+n+'.as' for n in recipe.REAL}))
  unit=(source/'UnitPresentation.as').read_text();energy=(source/'EnergyImpactVisuals.as').read_text()
  check('No additional source object-chain traversal',unit.count('get(loc,"firstObj")')==1 and energy.count('get(loc,"firstObj")')==1)
  check('Room gas uses delta and explicit point budget','deltaRecords(gasRecords,64)' in energy and 'roomParts:true,effectsOnly:true,main:false' in unit)
  check('Native pulse countdown is never read or synthesized','expl_t' not in unit and 'explPeriod' not in unit and 'explKol' not in unit)
  check('New and legacy projectile and death replay are separated',all('ignoreNativePart(emitter.arr[name].cast' in (source/n).read_text()
      and '.nativeGasParts===true' in (source/n).read_text() for n in ['ProjectileExplosionVisuals.as','DeathVisuals.as']))
  check('Native end changes only gas lifetime','if(ended && s.strictEnd===true)' in energy and 'forget(channel:Object,now:int)' in energy)
  for p in recipe.HERE.glob('*.py'):ast.parse(p.read_text(encoding='utf-8'))
  check('Python recipes parse without any launched process',True)
 result=dict(passed=True,count=len(rows),checks=rows,AS3_executed=False,JVM_started=False,AIR_started=False,
             production_qualified=False,performance_qualified=False)
 recipe.put(recipe.HERE/'offline-checks.json',json.dumps(result,ensure_ascii=False,indent=2)+'\n')
 print(json.dumps(dict(passed=True,count=len(rows),AS3_executed=False,JVM_started=False,AIR_started=False)))

if __name__=='__main__':main()

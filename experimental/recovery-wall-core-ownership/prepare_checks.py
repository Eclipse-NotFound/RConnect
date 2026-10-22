"""Freeze the existing 69 checks plus eight bounded ownership counterchecks.

Only prepares source; does not start Java/AIR, alter production or create a
candidate. Use the existing run_recovery_component.py if the parent elects to
execute it. The two desired-ownership checks should fail on exact recovery18.
"""
from pathlib import Path
import hashlib
import json
import shutil

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
OLD=ROOT/'experimental/recovery-wall-color-buildsrc/components'
BASE=ROOT/'build/m52/recovery-18/src'
OUTPUT=HERE/'components'
PRODUCTION=('rconnect/game/WallSurfaceBridge.as','rconnect/game/WallImpactVisuals.as',
            'rconnect/game/NativeWallColor.as','rconnect/net/RoomCodec.as',
            'rconnect/net/WallCellCodec.as')
BRIDGE_SHA='b7f58ccb994f30f86041249c56730831345e95742127814e1afa77bd44d69ad1'

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def inventory(p):return {f.relative_to(p).as_posix():sha(f) for f in sorted(p.rglob('*.as'))}
def save(p,value):p.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def text(p):return p.read_text(encoding='utf-8-sig')

def expected():
    value=text(OLD/'WallSurfaceChecks.as')
    assert value.count('  private function run(e:Event):void {')==1
    assert value.count('   }catch(error:Error){check(false,"uncaught: "+error.getStackTrace());}')==1
    value=value.replace('  private var assertions:Array=[],failed:int=0;',
       '  private var assertions:Array=[],failed:int=0;\n  private var ownershipObservations:Array=[];')
    value=value.replace('  private function run(e:Event):void {',
       text(HERE/'ownership-methods.inc')+'  private function run(e:Event):void {')
    value=value.replace('   }catch(error:Error){check(false,"uncaught: "+error.getStackTrace());}',
       text(HERE/'ownership-checks.inc')+'   }catch(error:Error){check(false,"uncaught: "+error.getStackTrace());}')
    value=value.replace('failed:failed,diagnostic_only:true}',
       'failed:failed,diagnostic_only:true,ownershipObservations:ownershipObservations}')
    return value

def verify():
    assert sha(BASE/PRODUCTION[0])==BRIDGE_SHA
    assert text(OUTPUT/'WallSurfaceChecks.as')==expected()
    old=inventory(OLD);actual=inventory(OUTPUT)
    assert old==inventory(ROOT/'build/m52/recovery-wall-color-integration-component-01/src')
    assert set(old)==set(actual)
    assert {n for n in old if old[n]!=actual[n]}=={'WallSurfaceChecks.as'}
    for name in PRODUCTION:assert sha(OUTPUT/name)==sha(BASE/name),name
    receipt=json.loads(text(ROOT/'build/m52/recovery-wall-color-integration-component-01/component-result.json'))
    assert receipt['passed'] is True and receipt['failed']==0 and receipt['count']==69
    assert len(receipt['assertions'])==69 and all(a['passed'] for a in receipt['assertions'])
    assert text(HERE/'ownership-checks.inc').count('    ownershipCase(')==4
    return dict(passed=True,old_checks_preserved=69,added_checks=8,expected_checks=77,
       predicted_failed_labels=[
        'ownership desired: observed differing core survives replay and becomes logical color',
        'ownership desired: core unchanged from native baseline survives replay and becomes logical color'],
       counterchecks_executed=False,production_classes_byte_exact=True,
       native_painter_is_existing_fixture=True,native_game_test=False,performance_qualified=False)

if __name__=='__main__':
    if not OUTPUT.exists():
        assert sha(BASE/PRODUCTION[0])==BRIDGE_SHA
        shutil.copytree(OLD,OUTPUT)
        (OUTPUT/'WallSurfaceChecks.as').write_text(expected(),encoding='utf-8')
    result=verify()
    save(HERE/'static-checks.json',result)
    inputs=[HERE/'prepare_checks.py',HERE/'ownership-checks.inc',HERE/'ownership-methods.inc',
       HERE/'README.md',HERE/'interface-risk.md',
       ROOT/'tools/validation/run_recovery_component.py',
       ROOT/'build/m52/recovery-wall-color-integration-component-01/component-result.json',
       ROOT/'build/m52/recovery-wall-surfaces-host-01/after/scripts/fe/graph/Grafon.as']
    inputs += list(OLD.rglob('*.as'))+[BASE/n for n in PRODUCTION]
    save(HERE/'handoff.json',dict(kind='source-only-wall-core-counterexamples',
       base_candidate='recovery18',base_host='ACC336B5',
       input_sources={str(p):sha(p) for p in inputs},sources=inventory(OUTPUT),
       checks=result,production_overlay=False,host_overlay=False,
       blocked_by='design cost and safety responsibility, not permission',
       next='Stop production expansion. Parent may run this exact control component.'))
    print(json.dumps(result,ensure_ascii=False))

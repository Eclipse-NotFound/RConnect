"""Read-only exact production diff and fixture provenance checks; no AIR."""
from pathlib import Path
import ast,hashlib,json
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];BASE=ROOT/'build/m52/recovery-early-compile-01'
OLD=ROOT/'experimental/recovery-early-travel'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def text(p):return p.read_text(encoding='utf-8-sig')
def main():
    checks=[]
    def check(ok,label):assert ok,label;checks.append(label)
    for p in HERE.glob('*.py'):ast.parse(text(p));checks.append('syntax '+p.name)
    data=read(HERE/'integration.json')
    for p,h in data['input_sources'].items():check(sha(Path(p))==h,'unchanged source '+Path(p).name)
    for row in data['source']:check(sha(HERE/'src'/row['path'])==row['sha256'],'prepared '+row['path'])
    old=text(BASE/'src/rconnect/core/RoomSync.as');new=text(HERE/'src/rconnect/core/RoomSync.as')
    reverted=new.replace('         TravelGuard.endTravel();\n         if(nativeTravel.current!=null)nativeTravel.finish(nativeTravel.id);','         if(nativeTravel.current!=null)nativeTravel.finish(nativeTravel.id);',1)
    reverted=reverted.replace('               if(!completingEarly)TravelGuard.endTravel();','               TravelGuard.endTravel();',1)
    check(reverted==old,'exactly two production statement edits; cancellation and ordinary paths otherwise identical')
    check(new.index('         TravelGuard.endTravel();\n         if(nativeTravel.current!=null)')>new.index('if(!game.mapGeneration.releaseEarly(id))'),'complete release follows successful external release')
    fixtures=read(HERE/'component-inputs.json')
    for group,files in fixtures['components'].items():
        for rel,h in files.items():check(sha(HERE/'components'/group/rel)==h,'frozen component '+group+'/'+rel)
    for name,group in [('EarlyTravelRoomChecks','room'),('NativeTravelRoomChecks','room'),('EarlyTravelGateChecks','gate'),('EarlyNativeChecks','native'),('EarlyExternalChecks','external'),('EarlyTileChecks','tile')]:
        check(sha(HERE/'components'/group/(name+'.as'))==sha(OLD/'components'/group/(name+'.as')),'old assertions byte-identical '+name)
    for group in ('guard-fixed','guard-baseline'):
        check(sha(HERE/'components'/group/'rconnect/core/TravelGuard.as')==sha(BASE/'src/rconnect/core/TravelGuard.as'),'full real guard '+group)
        expected=HERE/'src/rconnect/core/RoomSync.as' if group=='guard-fixed' else BASE/'src/rconnect/core/RoomSync.as'
        check(sha(HERE/'components'/group/'rconnect/core/RoomSync.as')==sha(expected),'full real RoomSync '+group)
        check(sha(HERE/'components'/group/'EarlyExitAuthorizationChecks.as')==sha(HERE/'tests/EarlyExitAuthorizationChecks.as'),'same new test '+group)
    a=fixtures['components']['guard-fixed'];b=fixtures['components']['guard-baseline']
    check([n for n in a if a[n]!=b[n]]==['rconnect/core/RoomSync.as'],'baseline and fix differ only in actual RoomSync')
    print(json.dumps({'count':len(checks),'failed':0,'compiled':False,'air_started':False,'production_changes':data['changed'],'original_assertion_entries_unchanged':6},indent=2))
if __name__=='__main__':main()

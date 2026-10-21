"""Static identities and method boundaries only; not AS/runtime qualification."""
import ast,json,re
from generate import HERE,ROOT,BASE,ROOM,sha,put
def methods(s):
    result={}
    for m in re.finditer(r'^      (?:public|private)(?: static)? function (?:get )?(\w+)\(',s,re.M):
        i=s.index('{',m.start())+1;start=i;depth=1
        while depth:depth+=(s[i]=='{')-(s[i]=='}');i+=1
        result[m[1]]=s[start:i-1]
    return result
def main():
    rows=[]
    def check(ok,label):
        rows.append(dict(passed=bool(ok),label=label));assert ok,label
    for p in HERE.glob('*.py'):ast.parse(p.read_text(encoding='utf-8'));check(True,'Python syntax '+p.name)
    original=methods((BASE/'src'/ROOM).read_text(encoding='utf-8-sig'))
    source=(HERE/'src'/ROOM).read_text(encoding='utf-8');current=methods(source)
    changed={'reset','before','observeHost','startPreparedMap','openFirstRaster','finishFirstRaster','acceptsJoinGrant','handle','fail'}
    for name,text in original.items():
        if name not in changed:check(current[name]==text,'unchanged RoomSync method '+name)
    check(set(current)-set(original)=={'cancelSeedRaster'},'only one new RoomSync lifecycle helper')
    check('seedRaster.start(info,game.world,previousLand,epoch,pending)' in current['startPreparedMap'],'bind only after actual startSharedTravel true')
    check(current['startPreparedMap'].index('if(game.startSharedTravel(info))')<current['startPreparedMap'].index('seedRaster.start('),'seed selection not merely receipt')
    check('hold(' not in current['openFirstRaster'] and 'onPause' not in current['openFirstRaster'],'initial hook does not pause exitStep')
    check('seeded?"":String(receipt.travelId)' in current['finishFirstRaster'],'local token never emitted in ACK')
    check('firstRaster.sameGrant(int(msg.barrier),int(msg.epoch),seedRaster.active?seedRaster.id' in current['handle'],'duplicate grant compares internal identity')
    check('TravelPlacement.place(game.gg,Number(seedRaster.anchor.x),Number(seedRaster.anchor.y))' in current['handle'],'random entry uses first valid seal anchor')
    check(current['handle'].index('TravelPlacement.place(game.gg,Number(seedRaster.anchor.x)')<current['handle'].index('firstRaster.restored('),'anchor installed before awaiting native frame')
    for p in (HERE/'src').rglob('*.as'):
        rel=p.relative_to(HERE/'src');check(sha(p)==sha(HERE/'components/room'/rel),'real component '+str(rel))
    check(sha(HERE/'components/room/rconnect/core/FirstRasterGate.as')==sha(BASE/'src/rconnect/core/FirstRasterGate.as'),'same previously validated FirstRasterGate')
    comp=json.loads((HERE/'component-inputs.json').read_text(encoding='utf-8'))
    for rel,h in comp['sources'].items():check(sha(ROOT/rel)==h,'component source '+rel)
    put('source-checks.json',json.dumps(dict(passed=True,checks=len(rows),assertions=rows,compiled=False,air_started=False),indent=2)+'\n')
    put('manifest.json',json.dumps(dict(files={p.relative_to(HERE).as_posix():sha(p) for p in sorted(HERE.rglob('*'))
        if p.is_file() and p.name!='manifest.json' and '__pycache__' not in p.parts},compiled=False,runtime_tested=False),indent=2)+'\n')
    print(json.dumps(dict(static_checks=len(rows),compiled=False,air_started=False)))
if __name__=='__main__':main()

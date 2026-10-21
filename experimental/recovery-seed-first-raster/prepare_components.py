"""Copy exact previous real RoomSync fixture, append only seed lifecycle cases."""
from pathlib import Path
import hashlib,json
from generate import HERE,ROOT,BASE,sha,put,change
FIX=ROOT/'experimental/recovery-first-raster/components/room'
def main():
    sources={}
    for p in sorted(FIX.rglob('*.as')):
        rel=p.relative_to(FIX).as_posix();s=p.read_text(encoding='utf-8-sig');sources[str(p.relative_to(ROOT))]=sha(p)
        if rel=='NativeTravelRoomChecks.as':
            s=change(s,'try{run();rasterCases();}','try{run();rasterCases();seedCases();}')
            s=change(s,'      private function run():void {',(HERE/'tests/seed-cases.inc').read_text(encoding='utf-8')+'\n      private function run():void {')
        if rel=='rconnect/game/GameBridge.as':
            s=change(s,'world.land={act:{id:String(info.curLandId)},loc_t:0};',
                'world.land={act:{id:String(info.curLandId)},loc_t:0,rconnectLayoutSeed:info.layoutSeed==null?0:Number(info.layoutSeed),sceneMerged:info.sceneMerged===true};')
            s=change(s,'return {curLandId:world.game.curLandId,curCoord:"",roomKey:roomKey(),roomEpoch:roomEpoch,',
                'return {curLandId:world.game.curLandId,curCoord:"",roomKey:roomKey(),roomEpoch:roomEpoch,layoutSeed:world.land.rconnectLayoutSeed,sceneMerged:world.land.sceneMerged===true,')
        put('components/room/'+rel,s)
    for p in sorted((HERE/'src').rglob('*.as')):
        sources[str(p.relative_to(ROOT))]=sha(p);put('components/room/'+p.relative_to(HERE/'src').as_posix(),p.read_text(encoding='utf-8'))
    sources[str((HERE/'tests/seed-cases.inc').relative_to(ROOT))]=sha(HERE/'tests/seed-cases.inc')
    put('component-inputs.json',json.dumps(dict(sources=sources,files={p.relative_to(HERE/'components/room').as_posix():sha(p) for p in sorted((HERE/'components/room').rglob('*.as'))},
        compiled=False,runtime_tested=False,native_game_test=False),indent=2)+'\n')
    print('Real RoomSync seed lifecycle fixture prepared; no compiler or AIR')
if __name__=='__main__':main()

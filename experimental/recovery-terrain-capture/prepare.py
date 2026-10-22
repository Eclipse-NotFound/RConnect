"""Materialize/verify AS-only TerrainSync proposal. Never compiles or launches processes."""
import argparse,difflib,hashlib,json
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];BASE=ROOT/'build/m52/recovery-14'
REL='rconnect/game/TerrainSync.as'
BASE_SOURCE='317c9658b0632f3bb8333c11cd302c68ef45e7a9f2f54ed6b6c631b6c1b92b44'
BASE_MANIFEST='cbc7d3dd962100d90865aa6b05dd85b61d0b794708dc97ccf46a38dc3aab8001'
GAME_TILE=ROOT.parents[1]/'game-reference/decompiled/1.02/src102/scripts/fe/loc/Tile.as'
TILE_HASH='ce77b312880301eba59c82f72d81dba92d51bba5d0c9929345c5ea743f601cc1'
OLD='''            if(t==null || matchesTile(t,old)) continue;'''
NEW='''            if(t==null) continue;
            // This local-damage observer only consumes the old collision state
            // and HP. Full host patches still compare all presentation fields.
            var native:Tile=t as Tile;
            if(native!=null) {
               if(old.p===native.phis && old.h===native.hp) continue;
            } else if(matchesTile(t,old)) continue;'''
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def planned():
    assert sha(BASE/'prepared.json')==BASE_MANIFEST
    assert sha(BASE/'src'/REL)==BASE_SOURCE==sha(ROOT/'build/m52/recovery-15/src'/REL)
    assert sha(GAME_TILE)==TILE_HASH
    source=(BASE/'src'/REL).read_text('utf-8-sig');assert source.count(OLD)==1
    after=source.replace(OLD,NEW);control=source.replace('public class TerrainSync','public class ControlTerrainSync')
    assert control.count('public class ControlTerrainSync')==1
    files={'src/'+REL:after.encode(),'components/'+REL:after.encode(),
        'components/rconnect/game/ControlTerrainSync.as':control.encode(),
        'components/fe/loc/Tile.as':GAME_TILE.read_bytes(),
        'proposal.patch':''.join(difflib.unified_diff(source.splitlines(True),after.splitlines(True),fromfile='recovery-14/'+REL,tofile='capture-only/'+REL)).encode()}
    inputs={str(BASE/'prepared.json'):BASE_MANIFEST,str(BASE/'src'/REL):BASE_SOURCE,str(GAME_TILE):TILE_HASH}
    for name in ('NativeTileState','NativeRoomState'):
        p=BASE/'src/rconnect/game'/(name+'.as');files['components/rconnect/game/'+name+'.as']=p.read_bytes();inputs[str(p)]=sha(p)
    for name in ('fe/unit/Unit.as','fe/unit/RConnectUnitAccess.as','rconnect/game/GameBridge.as','rconnect/game/TurretDisplay.as'):
        p=ROOT/'experimental/recovery-terrain-loop/components'/name;files['components/'+name]=p.read_bytes();inputs[str(p)]=sha(p)
    return files,inputs
def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--materialize',action='store_true');a=ap.parse_args()
    files,inputs=planned()
    if a.materialize:
        for name,raw in files.items():
            p=HERE/name;p.parent.mkdir(parents=True,exist_ok=True)
            if p.exists():assert p.read_bytes()==raw,'Existing materialized source differs: '+name
            else:p.write_bytes(raw)
    assert all((HERE/n).read_bytes()==raw for n,raw in files.items())
    manifest=dict(base_candidate_sha256='225a794040c71f2a55ff433366a7969201ac3a58ffaab0a655cee1e4eefbe5f7',
        base_source_sha256=BASE_SOURCE,inputs=inputs,compiled=False,runtime_tested=False,
        sources={p.relative_to(HERE).as_posix():sha(p) for p in sorted(HERE.rglob('*.as'))})
    (HERE/'inputs.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(dict(verified=True,as_files=len(manifest['sources']),compiled=False,runtime_tested=False)))
if __name__=='__main__':main()

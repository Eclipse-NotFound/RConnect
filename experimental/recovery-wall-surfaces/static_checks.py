"""Static provenance, exact overlay and negative readback checks only."""
import json,hashlib,re
from pathlib import Path
import generate as g
import prepare_components as component
import verify_readback as readback

HERE=g.HERE
def main():
    checks=[]
    def check(v,label):
        assert v,label
        checks.append({'label':label,'passed':True})
    pins=json.loads((HERE/'inputs.json').read_text(encoding='utf-8'))
    check(all(g.sha(Path(p))==h for p,h in pins['originals'].items()),'pinned originals unchanged')
    check(all(g.sha(HERE/p)==h for p,h in pins['overlays'].items()),'overlay hashes unchanged')
    check(g.sha(HERE/'generate.py')==pins['recipe_sha256'],'generator matches manifest')
    wall=(HERE/'src'/g.WALL).read_text(encoding='utf-8')
    host=(HERE/'native/fe/graph/Grafon.as').read_text(encoding='utf-8')
    check(wall==g.wall_overlay((g.BASE/'src'/g.WALL).read_text(encoding='utf-8-sig')),'wall changes are exact listed replacements')
    check(host==g.host_overlay(g.HOST.read_text(encoding='utf-8-sig')),'host changes are exact listed replacements')
    game=(HERE/'src'/g.GAME).read_text(encoding='utf-8')
    check(game.replace('_presentation.retainUnsent=value;_wall.networkActive=value;','_presentation.retainUnsent=value;')==
          (g.BASE/'src'/g.GAME).read_text(encoding='utf-8-sig'),'GameBridge only changes one setter')
    meta=json.loads((HERE/'component-inputs.json').read_text(encoding='utf-8'))
    check(all(g.sha(Path(p))==h for p,h in meta['sources'].items()),'component production sources exact')
    check(all(g.sha(HERE/'components'/p)==h for p,h in meta['files'].items()),'component freeze exact')
    fixture=(HERE/'components/fe/graph/Grafon.as').read_text(encoding='utf-8')
    for name,h in meta['native_methods'].items():
        check(component.method(host,name)==component.method(fixture,name) and
              hashlib.sha256(component.method(host,name).encode()).hexdigest()==h,'real native method '+name)
    check(readback.verify(host),'positive generated host readback anchors')
    negatives=[('before callback missing','this.rconnectWallNotify("before",wallMark,affected)','null'),
               ('after callback missing','this.rconnectWallNotify("after",wallMark,affected,wallToken)','null'),
               ('scratch origin not restored','this.sceneX = ox;','this.sceneX = 0;'),
               ('extra random draw','stamp = kind == "decal" ?','stamp = Math.random() ?'),
               ('selected clips missing','group.clips : null','null : null')]
    for label,a,b in negatives:
        damaged=host.replace(a,b)
        check(damaged!=host,'negative mutation exists: '+label)
        rejected=False
        try:readback.verify(damaged)
        except (AssertionError,ValueError):rejected=True
        check(rejected,'negative host rejected: '+label)
    bridge=(HERE/'src/rconnect/game/WallSurfaceBridge.as').read_text(encoding='utf-8')
    check('new Dictionary(true)' in bridge and 'marks[mark]={life:lifetimes[loc]' in bridge and
          'marks[mark]={loc:' not in bridge,'native mark weak values do not retain room/history/key')
    check('list.length>1200' in wall and 'MAX_CELLS:int=64' in wall and 'MAX_WIRE:int=48000' in wall,'existing safety limits retained')
    entry=(HERE/'components/WallSurfaceChecks.as').read_text(encoding='utf-8')
    check('passed:failed==0' in entry,'runner result has boolean passed')
    check(entry.count('check(')-2+3==54,'planned runtime 54 checks, including four base rectangles; not executed')
    (HERE/'static-results.json').write_text(json.dumps({'passed':True,'checks':checks,'count':len(checks),
        'compiled':False,'air_started':False,'runtime_qualification':False},indent=2)+'\n',encoding='utf-8')
    print(str(len(checks))+' static checks; component 54 planned, not run')
if __name__=='__main__':main()

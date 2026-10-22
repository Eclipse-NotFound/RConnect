"""Freeze exact whole RC classes and extracted native methods into a small component."""
from pathlib import Path
import hashlib,json,re,shutil
import generate as g
HERE=g.HERE;ROOT=g.ROOT;BASE=g.BASE
def method(s,name):
 m=re.search(r'(?:public|private) function '+name+r'\(',s);assert m,name
 start=s.index('{',m.start());depth=0
 for i in range(start,len(s)):
  if s[i]=='{':depth+=1
  elif s[i]=='}':
   depth-=1
   if depth==0:return s[m.start():i+1]
 raise AssertionError(name)
def main():
 g.main()
 dst=HERE/'components'
 for name in [g.WALL,'rconnect/game/WallSurfaceBridge.as']:
  g.put('components/'+name,(HERE/'src'/name).read_text(encoding='utf-8'))
 old=(BASE/'src'/g.WALL).read_text(encoding='utf-8-sig').replace('class WallImpactVisuals','class WallBefore').replace('function WallImpactVisuals(','function WallBefore(')
 g.put('components/rconnect/game/WallBefore.as',old)
 for name in ['rconnect/net/RoomCodec.as','rconnect/net/WallCellCodec.as']:
  g.put('components/'+name,(BASE/'src'/name).read_text(encoding='utf-8-sig'))
 g.put('components/rconnect/core/Log.as','package rconnect.core {public class Log {public static function d(s:String):void {}}}\n')
 g.put('components/rconnect/game/GameBridge.as','package rconnect.game {public class GameBridge {public static function probe(o:Object,k:String):*{try{return o!=null && k in o?o[k]:null;}catch(e:*){}return null;}}}\n')
 host=(HERE/'native/fe/graph/Grafon.as').read_text(encoding='utf-8')
 names=['sceneSurfaces','sceneApply','sceneRestoreMarks','rconnectWallNotify','rconnectWallBaseClips']
 fixture=(HERE/'fixtures/Grafon.template.as').read_text(encoding='utf-8')
 fixture=fixture.replace('// NATIVE_METHODS_HERE','\n'.join(method(host,n) for n in names))
 g.put('components/fe/graph/Grafon.as',fixture)
 g.put('components/WallSurfaceChecks.as',(HERE/'fixtures/WallSurfaceChecks.as').read_text(encoding='utf-8'))
 sources={str(p):g.sha(p) for p in [HERE/'src'/g.WALL,HERE/'src/rconnect/game/WallSurfaceBridge.as',HERE/'src'/g.GAME,HERE/'native/fe/graph/Grafon.as',BASE/'src'/g.WALL]}
 g.put('component-inputs.json',json.dumps({'sources':sources,'files':{str(p.relative_to(dst)):g.sha(p) for p in sorted(dst.rglob('*.as'))},'native_methods':{n:hashlib.sha256(method(host,n).encode()).hexdigest() for n in names},'boundaries':['Real complete before/after WallImpactVisuals, new bridge, RoomCodec/WallCellCodec','Real modified Grafon sceneApply/sceneRestoreMarks and bridge helpers extracted verbatim','Native drawing/art, chunk scheduling, Location and GameBridge.probe are explicit fixtures','No real TCP, world rendering, timing or memory/FPS qualification'],'compiled':False,'air_started':False},indent=2)+'\n')
 print('Prepared exact RC classes + 5 native methods; component not compiled/run')
if __name__=='__main__':main()

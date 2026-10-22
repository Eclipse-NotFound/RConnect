"""Prepare one accurate22 wall overlay and reuse the existing 85-check component.
Source-only: no compiler, JVM, AIR or installation changes.
"""
from pathlib import Path
import difflib,hashlib,json,sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
BASE=ROOT/'build/m52/recovery-22'
OLD=ROOT/'experimental/recovery21-small-wall-component/components'
ACTUAL=ROOT/'build/m52/recovery21-small-wall-component-01'
EVIDENCE=ROOT/'experimental/recovery-ordinary-wall-review/evidence.json'
WALL='rconnect/game/WallImpactVisuals.as'
PIN='746eef5713985f23fe13a57792516789bebd37a5e4142639ba8cc8b6590b3e93'
EXPECTED=132
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def inventory(p):return {x.relative_to(p).as_posix():sha(x) for x in sorted(p.rglob('*.as'))}
def save(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def patched(data):
 newline='\r\n' if b'\r\n' in data else '\n';t=data.decode().replace('\r\n','\n')
 def edit(before,after,count=1):
  nonlocal t
  assert t.count(before)==count,(before,t.count(before));t=t.replace(before,after)
 edit('''         return s;
      }
      private function front''','''         // Grafon is shared: learn the backing kind only while it belongs to
         // this room. Unknown/inactive rooms retain sparse data until real draw.
         var g:Object=get(loc,"grafon");
         if(g!=null && get(g,"loc")===loc) {
            if(get(g,"sceneLarge")===true)s.ordinary=false;
            else if(get(g,"rconnectRasterPending")!==true && get(g,"frontBmp")!=null)s.ordinary=true;
         }
         return s;
      }
      private function front''')
 edit('''      private function rect(x:int,y:int,b:BitmapData):Rectangle''','''      /** Collision cells do not bound ordinary native foreground art. Large
       * scenes keep their existing solid-cell contract. No alpha scan here. */
      private function retainedCell(loc:Object,x:int,y:int):Boolean
      {
         return solid(loc,x,y) || (loc!=null && x>=0 && y>=0 && x<int(loc.spaceX)
            && y<int(loc.spaceY) && state(loc).ordinary!==false);
      }
      private function rect(x:int,y:int,b:BitmapData):Rectangle''')
 edit('''            // Entire removed tiles remain TerrainSync's responsibility. In
            // particular an old coating must never fill a destroyed wall back in.
            if(!solid(loc,tx,ty)) {discard(loc,k);shadow.copyPixels(bitmap,rect(tx,ty,bitmap),new Point(tx*CELL,ty*CELL));continue;}
            captureCell(loc,tx,ty);''','''            // Compare only this already-bounded real contact/terrain region.
            // Native foreground edges can extend into phis==0 cells. Their
            // actual alpha, not collision occupancy, bounds final replay below.
            captureCell(loc,tx,ty);''')
 edit('if(!solid(loc,c.x,c.y)) {discard(loc,k);continue;}','if(!retainedCell(loc,c.x,c.y)) {discard(loc,k);continue;}',2)
 edit('''               var wrote:Boolean=false;var visible:Array=large?[]:null;''','''               var wrote:Boolean=false;var visible:Array=large?[]:null;
               var solidCell:Boolean=solid(loc,c.x,c.y);''')
 edit('var large:Boolean=get(get(loc,"grafon"),"sceneLarge")===true,painted:Array=large?[]:null;',
      'var large:Boolean=s.ordinary===false,painted:Array=large?[]:null;')
 edit('''                  if(b!=null && x<b.width && y<b.height && b.getPixel32(x,y)!=color)
                  {b.setPixel32(x,y,NativeWallColor.setter(color));dirty=true;}''','''                  // Keep logical/ACK data exact, but a received old coating
                  // must not create opacity where the native air-cell mask is
                  // now empty (for example after its neighboring wall broke).
                  if(b!=null && x<b.width && y<b.height && b.getPixel32(x,y)!=color
                     && (solidCell || (color>>>24)==0 || (b.getPixel32(x,y)>>>24)!=0))
                  {b.setPixel32(x,y,NativeWallColor.setter(color));dirty=true;}''')
 edit('if(solid(loc,int(c.x),int(c.y)))accepted.push(c);','if(retainedCell(loc,int(c.x),int(c.y)))accepted.push(c);')
 edit('if(!solid(loc,c.x,c.y))discard(loc,k);','if(!retainedCell(loc,c.x,c.y))discard(loc,k);',2)
 edit('if(solid(loc,c.x,c.y))out.push(packed(c));else discard(loc,k);','if(retainedCell(loc,c.x,c.y))out.push(packed(c));else discard(loc,k);')
 edit('''               for(var key:String in c.values)
               {
                  var i:int=int(key),x:int=int(c.x)*CELL+i%CELL,y:int=int(c.y)*CELL+int(i/CELL);
                  if(x<b.width && y<b.height)b.setPixel32(x,y,NativeWallColor.setter(uint(c.values[key])));
               }''','''               var solidCell:Boolean=solid(loc,c.x,c.y);
               for(var key:String in c.values)
               {
                  var i:int=int(key),x:int=int(c.x)*CELL+i%CELL,y:int=int(c.y)*CELL+int(i/CELL);
                  var color:uint=uint(c.values[key]);
                  if(x<b.width && y<b.height && (solidCell || (color>>>24)==0 || (b.getPixel32(x,y)>>>24)!=0))
                     b.setPixel32(x,y,NativeWallColor.setter(color));
               }''')
 return t.replace('\n',newline).encode()
def verify():
 m=read(HERE/'inputs.json')
 for p,h in m['inputs'].items():assert sha(Path(p))==h,p
 assert inventory(HERE/'components')==m['components'] and inventory(HERE/'src')==m['overlay']
 assert (HERE/'src'/WALL).read_bytes()==patched((BASE/'src'/WALL).read_bytes())==(HERE/'components'/WALL).read_bytes()
 original=(OLD/'WallSurfaceChecks.as').read_text();combined=(HERE/'components/WallSurfaceChecks.as').read_text()
 assert combined.count('    edgeChecks();')==1
 assert original.split('   }catch(error:Error)')[0] in combined
 assert 'if(!binary)for(var i:int=0;i<words.length;i+=2)' in combined or b'if(!binary)for(var i:int=0;i<words.length;i+=2)' in (HERE/'src'/WALL).read_bytes()
 return {'passed':True,'expected_checks':EXPECTED,'original_checks_unchanged':85,'production_overlay_classes':1,'compiled':False,'air_started':False,'performance_qualified':False}
def main():
 assert not (HERE/'components').exists() and not (HERE/'src').exists(),'Use --verify for frozen prepared sources'
 meta=read(BASE/'prepared.json');assert meta['compiled'] and meta['sha256']==PIN==sha(BASE/'RConnectMod.swf')
 assert inventory(BASE/'src')==meta['source']
 actual=read(ACTUAL/'receipt.json');assert actual['passed'] and actual['observed_checks']==85 and actual['checks_failed']==0
 assert inventory(OLD)==read(ACTUAL/'intent.json')['sources']
 inputs=[Path(__file__),HERE/'run_component.py',HERE/'edge-checks.as.txt',HERE/'Bullet.as.txt',BASE/'prepared.json',BASE/'RConnectMod.swf',ACTUAL/'receipt.json',ACTUAL/'intent.json',ACTUAL/'component-result.json',EVIDENCE,ROOT/'tools/validation/run_recovery_component.py']
 inputs.extend(OLD.rglob('*.as'))
 for name in inventory(OLD):
  target=HERE/'components'/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes((OLD/name).read_bytes())
 for name in [WALL,'rconnect/game/NativeWallColor.as','rconnect/game/WallSurfaceBridge.as','rconnect/net/WallCellCodec.as','rconnect/net/RoomCodec.as']:
  inputs.append(BASE/'src'/name);data=(BASE/'src'/name).read_bytes()
  (HERE/'components'/name).write_bytes(patched(data) if name==WALL else data)
 before=(BASE/'src'/WALL).read_bytes();after=patched(before)
 target=HERE/'src'/WALL;target.parent.mkdir(parents=True);target.write_bytes(after)
 control=before.replace(b'class WallImpactVisuals',b'class WallControl').replace(b'function WallImpactVisuals(',b'function WallControl(')
 (HERE/'components/rconnect/game/WallControl.as').write_bytes(control)
 t=(OLD/'WallSurfaceChecks.as').read_text();anchor='   }catch(error:Error){check(false,"uncaught: "+error.getStackTrace());}'
 assert t.count(anchor)==1;t=t.replace(anchor,'    edgeChecks();\n'+anchor)
 assert t.endswith(' }\n}\n');t=t[:-5]+(HERE/'edge-checks.as.txt').read_text()+' }\n}\n'
 (HERE/'components/WallSurfaceChecks.as').write_text(t,encoding='utf-8')
 target=HERE/'components/fe/weapon/Bullet.as';target.parent.mkdir(parents=True);target.write_bytes((HERE/'Bullet.as.txt').read_bytes())
 rows=read(EVIDENCE)['rows']
 generated='package { public final class EdgeObserved { public static const POINTS:Array=['+','.join('[%d,%d,0x%s,0x%s]'%(r['world'][0]-1080,r['world'][1]-320,r['baseline'],r['source_final']) for r in rows)+']; } }\n'
 (HERE/'components/EdgeObserved.as').write_text(generated,encoding='utf-8')
 (HERE/'proposal.patch').write_text(''.join(difflib.unified_diff(before.decode().splitlines(True),after.decode().splitlines(True),fromfile='recovery22/'+WALL,tofile='ordinary-edge/'+WALL)),encoding='utf-8')
 save(HERE/'inputs.json',{'baseline':str(BASE),'baseline_sha256':PIN,'inputs':{str(p):sha(p) for p in inputs},'overlay':inventory(HERE/'src'),'components':inventory(HERE/'components'),'expected_checks':EXPECTED,'compiled':False,'air_started':False,'large_air_edges_modified':False,'performance_qualified':False})
 result=verify();save(HERE/'static-checks.json',result);print(json.dumps(result))
if __name__=='__main__':
 if '--verify' in sys.argv:print(json.dumps(verify()))
 else:main()

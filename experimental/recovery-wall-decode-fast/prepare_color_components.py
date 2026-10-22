"""Optional source-only reuse of the existing 85 color checks after decoder integration.
No effect on the decode comparison or its two-file overlay. No JVM/AIR here.
"""
import argparse,hashlib,json
from pathlib import Path
from prepare import HERE,ROOT,BASE,CODEC,WALL,sha,read,text,once,verify
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--source',type=Path,required=True);ap.add_argument('--output',type=Path,required=True);args=ap.parse_args()
 source=args.source.resolve();output=args.output.resolve()
 assert output.is_relative_to(HERE.resolve()) and not output.exists(),'Fresh directory inside this experiment only'
 old=ROOT/'experimental/recovery-wall-small-color/components'
 receipt=ROOT/'build/m52/recovery-wall-small-color-component-01/receipt.json';r=read(receipt)
 assert r['passed'] and r['observed_checks']==85 and r['checks_failed']==0
 verify();names=(WALL,CODEC,'rconnect/net/RoomCodec.as','rconnect/game/WallSurfaceBridge.as','rconnect/game/NativeWallColor.as')
 inputs={str(receipt):sha(receipt)};prepared={}
 # Use the caller's exact complete source tree, never an old complete WallImpact replacement.
 for name in names:
  p=source/name;inputs[str(p)]=sha(p);prepared[name]=text(p)
 assert 'if(!binary)for(var i:int=0;i<words.length;i+=2)' in prepared[WALL]
 for before,after in [('b.setPixel32(x,y,color);','b.setPixel32(x,y,NativeWallColor.setter(color));'),
  ('b.setPixel32(x,y,uint(c.values[key]));','b.setPixel32(x,y,NativeWallColor.setter(uint(c.values[key])));')]:
  if before in prepared[WALL]:prepared[WALL]=once(prepared[WALL],before,after)
  else:assert prepared[WALL].count(after)==1
 # All 85 assertions and the independent old color control stay byte-identical.
 for p in sorted(old.rglob('*')):
  if not p.is_file():continue
  rel=p.relative_to(old).as_posix();inputs[str(p)]=sha(p);target=output/rel;target.parent.mkdir(parents=True,exist_ok=True)
  if rel in prepared:target.write_text(prepared.pop(rel),encoding='utf-8',newline='\n')
  else:target.write_bytes(p.read_bytes())
 assert not prepared
 assert sha(output/'WallSurfaceChecks.as')==sha(old/'WallSurfaceChecks.as')
 manifest=dict(expected_checks=85,compiled=False,performance_qualified=False,source_inputs=inputs,
  files={p.relative_to(output).as_posix():sha(p) for p in sorted(output.rglob('*')) if p.is_file()},
  modifications='Caller full-source decoder plus two explicit final setters only; original 85 assertions retained')
 (output.parent/(output.name+'-inputs.json')).write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
 for p,h in inputs.items():assert sha(p)==h,p
 print('Prepared exact 85 color assertions against supplied full sources plus two setters; not run')
if __name__=='__main__':main()

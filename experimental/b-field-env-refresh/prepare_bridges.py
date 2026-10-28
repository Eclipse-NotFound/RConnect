"""Freeze committed TDFC/Sandy source and print their candidate build commands.
No compiler, JVM, AIR, launcher selection or deployment is executed here.
Source is from specific git objects, never the mods' mutable work trees.
"""
from pathlib import Path
import argparse, hashlib, json, subprocess, sys
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;RC=HERE.parents[1];GAME=RC.parents[1]
sys.path.insert(0,str(RC/'tools/host_authority'))
from common import JAVA,SDK,FFDEC
PINS={'TDFC':'533a27c','Sandevistan':'3f4a59b'}
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def git(mod,*args):return subprocess.check_output(['git','-C',str(GAME/'mods'/mod),*args])
def freeze(mod,out):
 commit=git(mod,'rev-parse',PINS[mod]+'^{commit}').decode().strip()
 names=git(mod,'ls-tree','-r','--name-only',commit,'src','build/stubs-high-fps').decode().splitlines()
 files={}
 for name in names:
  if not name.endswith('.as'):continue
  data=git(mod,'show',commit+':'+name);p=out/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data);files[name]=sha(p)
 if not files:raise ValueError('No source in pinned revision')
 def compile(jar):return [str(JAVA),'-Xmx512m','-Dsun.io.useCanonCaches=false','-jar',str(SDK/'lib'/jar),'+configname=air','+flexlib='+str(SDK/'frameworks')]
 if mod=='TDFC':
  src=(out/'src/TDFCMod.as').read_text(encoding='utf-8-sig')
  runtime=(out/'src/TdfcRuntime.as').read_text(encoding='utf-8-sig')
  if 'TDFCAuthorityCarrier' not in src or 'attachAuthority' not in runtime:raise ValueError('Missing TDFC authority source')
  commands=[compile('mxmlc.jar')+['-source-path='+str(out/'src'),'-swf-version=38','-debug=false','-optimize=true','-output='+str(out/'TDFCMod.swf'),str(out/'src/TDFCMod.as')]]
 else:
  if not(out/'src/SandyAuthority.as').is_file():raise ValueError('Missing Sandy authority source')
  commands=[compile('compc.jar')+['-source-path='+str(out/'build/stubs-high-fps'),'-include-classes=fe.serv.Gov60','-output='+str(out/'Gov60Stubs.swc'),'-swf-version=38'],
    compile('mxmlc.jar')+['-source-path='+str(out/'src'),'-external-library-path+='+str(out/'Gov60Stubs.swc'),'-swf-version=38','-debug=false','-optimize=true','-output='+str(out/'SandevistanMod.swf'),str(out/'src/SandevistanMod.as')]]
 result=dict(kind='b-environment-bridge-source',mod=mod,git_commit=commit,sources=files,commands=commands,
   compiler={str(p):sha(p) for p in (JAVA,SDK/'lib/mxmlc.jar',SDK/'lib/compc.jar',SDK/'frameworks/libs/air/airglobal.swc')},
   compiled=False,runtime_qualified=False,installed=False,
   qualification='After compilation inspect external class isolation and attach/detach; test both roles, room travel, current mod features.')
 (out/'prepared.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8');return result
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',default='bridge-sources-01');a=ap.parse_args()
 out=(HERE/a.output).resolve()
 if not out.is_relative_to(HERE) or out==HERE:raise ValueError('Output must be inside this preparation directory')
 if out.exists():raise FileExistsError('Use a fresh source directory')
 out.mkdir(parents=True);results={mod:freeze(mod,out/mod) for mod in PINS}
 print(json.dumps({m:{'commit':r['git_commit'],'sources':len(r['sources']),'compiled':False} for m,r in results.items()},ensure_ascii=False,indent=2))
if __name__=='__main__':main()

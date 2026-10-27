"""Second candidate: keep measured visual shortcut, replace unhelpful token hint with typed schema arrays."""
from pathlib import Path
import shutil,difflib,json,hashlib
ROOT=Path(__file__).resolve().parents[2]
base=ROOT/'build/ab/b190-field22-source';prior=ROOT/'build/ab/b190-scalar01-source';out=ROOT/'build/ab/b190-scalar02-source'
if out.exists():raise FileExistsError(out)
shutil.copytree(prior,out)
name='src/authority/NativeFields.as';text=(base/name).read_text(encoding='utf-8')
old='schema={names:[],modes:[]};'
assert text.count(old)==1
text=text.replace(old,'schema={names:new Vector.<String>(),modes:new Vector.<int>()};')
old='var names:Array=schema.names,modes:Array=schema.modes;\n         for(var index:int=0;index<names.length;index++)'
assert text.count(old)==1
text=text.replace(old,'var names:Vector.<String>=schema.names,modes:Vector.<int>=schema.modes;\n         var length:int=names.length;\n         for(var index:int=0;index<length;index++)')
(out/name).write_text(text,encoding='utf-8')
p=out/'src/RConnectMod.as';p.write_text(p.read_text(encoding='utf-8').replace('B3-0.1-scalar1','B3-0.1-scalar2'),encoding='utf-8')
patch=''
for name in ['src/authority/NativeFields.as','src/authority/VisualPose.as','src/RConnectMod.as']:
 a=(base/name).read_text(encoding='utf-8');b=(out/name).read_text(encoding='utf-8')
 patch+=''.join(difflib.unified_diff(a.splitlines(True),b.splitlines(True),fromfile=name,tofile=name))
(Path(__file__).parent/'candidate02.patch').write_text(patch,encoding='utf-8')
files={p.relative_to(out).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(out.rglob('*.as'))}
(Path(__file__).parent/'source-plan02.json').write_text(json.dumps(dict(base=str(base),output=str(out),files=files),indent=2)+'\n',encoding='utf-8')
print(out)

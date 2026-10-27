"""Minimal final candidate: typed scalar schema only. Discard visual and decoder experiments."""
from pathlib import Path
import shutil,difflib,json,hashlib
ROOT=Path(__file__).resolve().parents[2]
base=ROOT/'build/ab/b190-field22-source';typed=ROOT/'build/ab/b190-scalar02-source';out=ROOT/'build/ab/b190-scalar04-source'
if out.exists():raise FileExistsError(out)
out.mkdir()
for name in ('src','stubs'):shutil.copytree(base/name,out/name)
shutil.copy2(typed/'src/authority/NativeFields.as',out/'src/authority/NativeFields.as')
p=out/'src/RConnectMod.as';p.write_text(p.read_text(encoding='utf-8').replace('B3-0.1-field4','B3-0.1-field5'),encoding='utf-8')
patch=''
for name in ['src/authority/NativeFields.as','src/RConnectMod.as']:
 a=(base/name).read_text(encoding='utf-8');b=(out/name).read_text(encoding='utf-8')
 patch+=''.join(difflib.unified_diff(a.splitlines(True),b.splitlines(True),fromfile=name,tofile=name))
(Path(__file__).parent/'candidate04.patch').write_text(patch,encoding='utf-8')
files={p.relative_to(out).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(out.rglob('*.as'))}
(Path(__file__).parent/'source-plan04.json').write_text(json.dumps(dict(base=str(base),output=str(out),files=files),indent=2)+'\n',encoding='utf-8')
print(out)

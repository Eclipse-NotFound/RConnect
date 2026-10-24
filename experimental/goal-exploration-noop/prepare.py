"""Exact current-78C source-only no-op merge recipe; no compiler or AIR."""
from pathlib import Path
import argparse, ast, difflib, hashlib, json, sys, types
if sys.flags.optimize: raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
BASE=ROOT/'build/m52/recovery-room-production-05'
DELEGATE=ROOT/'experimental/recovery-room-production-v5/build.py'
VERSION='0.2.24-explorationnoop1'
PRODUCT_SHA='78c052aea963f1689b705ae1e14d274916ae1a1f7e81933390caf8d1a88f4699'
REL='rconnect/game/ExplorationSync.as'
BEFORE=b'         memories[c.loc] = {key:c.key, data:data, apiApplied:null};'
AFTER=b'''         var unchanged:Boolean = old != null && old.key === c.key && old.data.length === data.length;
         if(unchanged)
            for(var y:int = 0; y < data.length; y++)
               if(data[y] !== old.data[y]) { unchanged = false; break; }
         if(!unchanged) memories[c.loc] = {key:c.key, data:data, apiApplied:null};'''
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text(encoding='utf-8-sig'))
checked=types.SimpleNamespace(data=read)
def inventory(p):return {f.relative_to(p).as_posix():sha(f) for f in sorted(p.rglob('*')) if f.is_file()}
def diff(a,b,n):
 return ''.join(difflib.unified_diff(a.decode('utf8').splitlines(True),b.decode('utf8').splitlines(True),fromfile='production05/src/'+n,tofile='overlay/src/'+n))
def verify():
 m=read(HERE/'source-manifest.json')
 assert m['version']==VERSION and m['base_sha256']==PRODUCT_SHA
 for p,h in m['inputs'].items():assert sha(ROOT/p)==h,p
 assert inventory(BASE/'src')==m['base_source']==read(BASE/'prepared.json')['source']
 assert len(m['base_source'])==81 and inventory(BASE/'tools')==read(BASE/'prepared.json')['inputs']
 receipt=read(BASE/'compile.json');assert receipt['compiled'] and receipt['candidate_sha256']==PRODUCT_SHA
 assert sha(BASE/'RConnectMod.swf')==sha(ROOT/'release/RConnectMod.swf')==PRODUCT_SHA
 actual={p.relative_to(HERE).as_posix():sha(p) for p in sorted(HERE.rglob('*')) if p.is_file() and p.name!='source-manifest.json'}
 assert actual==m['files'],'Recipe files changed'
 original=(BASE/'src'/REL).read_bytes();assert original.count(BEFORE)==1
 candidate=original.replace(BEFORE,AFTER)
 assert (HERE/'src'/REL).read_bytes()==candidate
 assert (HERE/'components'/REL).read_bytes()==candidate
 control=(HERE/'components/rconnect/game/ControlExplorationSync.as').read_bytes()
 assert control==original.replace(b'ExplorationSync',b'ControlExplorationSync')
 entry=(BASE/'src/RConnectMod.as').read_bytes();assert entry.count(b'0.2.24-roomfix5')==1
 assert (HERE/'src/RConnectMod.as').read_bytes()==entry.replace(b'0.2.24-roomfix5',VERSION.encode())
 assert set(inventory(HERE/'src'))=={REL,'RConnectMod.as'}
 changes={n:dict(base_sha256=m['base_source'][n],candidate_sha256=sha(HERE/'src'/n)) for n in sorted(inventory(HERE/'src'))}
 expected=dict(m['base_source']);expected.update({n:r['candidate_sha256'] for n,r in changes.items()})
 assert m['changes']==changes and m['candidate_source']==expected
 assert sum(expected[n]==h for n,h in m['base_source'].items())==79
 source_diff=''.join(diff((BASE/'src'/n).read_bytes(),(HERE/'src'/n).read_bytes(),n) for n in sorted(changes))
 assert (HERE/'source.diff').read_text('utf8')==source_diff
 assert inventory(HERE/'components')==m['component_source']
 for script in ('prepare.py','build.py'):ast.parse((HERE/script).read_text('utf8'))
 return m
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--check',action='store_true',required=True);p.parse_args()
 verify();print(json.dumps(dict(checked=True,production_changed_classes=2,unchanged_classes=79,compiled=False,air_started=False)))

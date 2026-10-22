"""Generate an external bounded probe; never alters frozen original drivers."""
from pathlib import Path
import difflib,hashlib,json
HERE=Path(__file__).resolve().parent
BASE=HERE.parent/'recovery-early-sandy-native'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def replace(s,a,b):
    assert s.count(a)==1,(a,s.count(a))
    return s.replace(a,b,1)
def write(p,s):p.write_text(s,encoding='utf-8',newline='\n')
def main():
    old=(BASE/'tests/FirstRasterSceneProbe.as').read_text(encoding='utf-8-sig')
    new=replace(old,'   import flash.utils.Dictionary;','   import flash.utils.Dictionary;\n   import rconnect.core.Log;')
    new=replace(new,'      private var startPermit:Object,heldSeen:Boolean=false;','      private var startPermit:Object,heldSeen:Boolean=false;\n'+(HERE/'fields.txt').read_text(encoding='utf-8'))
    new=replace(new,'            var ticket:Object=original(w,l,g);','            var ticket:Object=original(w,l,g);\n            if(active)recordBridge(w,l,g,ticket);')
    new=replace(new,'               tickets[ticket]=row;rows.push(row);','               tickets[ticket]=row;rows.push(row);\n               ticketRefs[ticket]={world:w,game:w.game,gg:w.gg,land:w.land,loc:l,grafon:g};')
    new=replace(new,'         active=true;expected=required;tickets=new Dictionary();rows=[];heldSeen=false;startPermit=query();','         active=true;expected=required;tickets=new Dictionary();rows=[];heldSeen=false;startPermit=query();\n         beginDiagnostic();')
    new=replace(new,'            if(ticket.unpainted===false && row.firstPainted<0)row.firstPainted=getTimer();\n         }','            if(ticket.unpainted===false && row.firstPainted<0)row.firstPainted=getTimer();\n         }\n         sampleDiagnostic();')
    new=replace(new,'      public function finish():Object {',(HERE/'methods.txt').read_text(encoding='utf-8')+'\n      public function finish():Object {')
    new=replace(new,'         active=false;tickets=new Dictionary();','         if(active)emitDiagnostic("dispose");\n         active=false;tickets=new Dictionary();ticketRefs=new Dictionary();baseline=null;')
    (HERE/'tests').mkdir(exist_ok=True)
    write(HERE/'tests/FirstRasterSceneProbe.as',new)
    write(HERE/'probe.patch',''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile='original/FirstRasterSceneProbe.as',tofile='diagnostic/FirstRasterSceneProbe.as')))
    old=(BASE/'run_native.py').read_text(encoding='utf-8-sig')
    new=replace(old,'from native_inputs import audit,host_input,verify_host_intent,verify_driver,sandy_input','from native_inputs import audit,host_input,verify_host_intent,verify_driver,sandy_input\nRUNNER=Path(__file__).resolve().parent.parent/"recovery-early-sandy-native/native_runner.py"')
    new=new.replace("Path(__file__).with_name('native_runner.py')",'RUNNER')
    new=replace(new,"            if result['diagnostic_only']:\n                result['roles'][role]['profile']", "            result['roles'][role]['revisit_probe']=[json.loads(s.split('EARLY REVISIT PROBE ',1)[1]) for s in text.splitlines() if s.startswith('EARLY REVISIT PROBE ')]\n            if result['diagnostic_only']:\n                result['roles'][role]['profile']")
    new=replace(new,"            if meta.get('diagnostic_kind')=='raster':","            if meta.get('diagnostic_kind')=='early-revisit':\n                result['profile_valid']=all(valid_probe(value['revisit_probe']) for value in result['roles'].values())\n            elif meta.get('diagnostic_kind')=='raster':")
    new=replace(new,'def main():','def valid_probe(rows):\n    if not rows:return False\n    groups={}\n    for row in rows:\n        group=groups.setdefault(row["segment"],[]);group.append(row)\n        if row.get("faults") or row["sequence"]>20:return False\n    return all(len(group)<=20 and len({r["sequence"] for r in group})==len(group) for group in groups.values())\n\n\ndef main():')
    write(HERE/'run_native.py',new)
    write(HERE/'runner.patch',''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile='original/run_native.py',tofile='diagnostic/run_native.py')))
    inputs={'originals':{str(p):sha(p) for p in [BASE/'inputs.json',BASE/'prepare_scene.py',BASE/'run_native.py',BASE/'native_inputs.py',BASE/'native_runner.py',*sorted((BASE/'tests').glob('*.as'))]},'sources':{p.relative_to(HERE).as_posix():sha(p) for p in sorted(HERE.rglob('*')) if p.is_file() and p.name not in ('inputs.json','check-result.json') and '__pycache__' not in str(p)}}
    write(HERE/'inputs.json',json.dumps(inputs,indent=2)+'\n')
if __name__=='__main__':main()

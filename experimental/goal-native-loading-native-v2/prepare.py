"""Refresh only explicitly reopened v2 text bindings; never touch frozen inputs."""
from pathlib import Path
import ast,difflib,importlib.util,json,sys
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('ui_runtime_v2_source',HERE/'run.py')
entry=importlib.util.module_from_spec(spec);spec.loader.exec_module(entry)
def main():
    assert sys.argv[1:]==[]
    text=entry.adapted();ast.parse(text)
    probe=entry.probe_expansion()
    for part in entry.probe_sources():ast.parse(part)
    historical=entry.read(entry.HISTORICAL_ENV)['installation']
    current={n:entry.sha(entry.ROOT.parents[1]/n) for n in historical}
    assert len(current)==22 and set(current)==set(historical)
    assert {p for p in current if current[p]!=historical[p]}=={entry.RV_KEY}
    assert historical[entry.RV_KEY]==entry.RV_OLD and current[entry.RV_KEY]==entry.RV_NEW
    environment=dict(kind='native-loading-runtime-rv03310',build_environment=historical,runtime_environment=current,
                     rv_receipt=str(entry.RV_RECEIPT),rv_receipt_sha256=entry.sha(entry.RV_RECEIPT))
    with (HERE/'runtime-environment.json').open('w',encoding='utf8',newline='\n') as f:json.dump(environment,f,indent=2);f.write('\n')
    entry.verify_environment_change(historical,current)
    with (HERE/'adapted-entry.py.txt').open('w',encoding='utf8',newline='\n') as f:f.write(text)
    with (HERE/'adapted-probe.py.txt').open('w',encoding='utf8',newline='\n') as f:f.write(probe)
    diff=''.join(difflib.unified_diff(entry.SOURCE.read_text('utf8').splitlines(True),text.splitlines(True),
         fromfile='frozen-native/run.py',tofile='native-v2/adapted-entry.py.txt'))
    originals=(entry.function_text(entry.BASE_BUILDER/'build.py','inputs'),
               entry.function_text(entry.PROBE/'build.py','inputs'),
               entry.function_text(entry.PROBE/'adapted-build.py.txt','verify'))
    for name,old,new in zip(('base-inputs','probe-inputs','probe-verify'),originals,entry.probe_sources()):
        diff+=''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),
                     fromfile='frozen-probe/'+name,tofile='native-v2/'+name))
    with (HERE/'source.diff').open('w',encoding='utf8',newline='\n') as f:f.write(diff)
    m=dict(kind='native-loading-runtime-host-verifier-v2',replacements=len(entry.EDITS),probe_replacements=3,
           original_sha256=entry.SOURCE_SHA,
           original_manifest_sha256=entry.OLD_MANIFEST_SHA,host_verifier=entry.V2_PINS,
           environment_pins=entry.ENVIRONMENT_PINS,
           files={p.name:entry.sha(p) for p in sorted(HERE.iterdir()) if p.is_file() and p.name!='source-manifest.json'},
           air_started=False,xml_parsed=False)
    with (HERE/'source-manifest.json').open('w',encoding='utf8',newline='\n') as f:json.dump(m,f,indent=2);f.write('\n')
    entry.exact_pins()
    print('Prepared reopened v2 text and exact current 22-file binding; no XML parsing, JVM or AIR')
if __name__=='__main__':main()
